import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expense_tracker.db');
    return await openDatabase(
      path,
      version: 4, // Updated version for new features
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('DROP TABLE IF EXISTS bank_loans');
      await db.execute('DROP TABLE IF EXISTS personal_loans');
      await db.execute('DROP TABLE IF EXISTS payment_history');
      await db.execute('DROP TABLE IF EXISTS loan_reminders');
      await _createTables(db);
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        category TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Enhanced bank_loans table with auto-payment features
    await db.execute('''
      CREATE TABLE bank_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_name TEXT NOT NULL,
        loan_amount REAL NOT NULL,
        installment_amount REAL NOT NULL,
        installments_paid INTEGER DEFAULT 0,
        total_installments INTEGER NOT NULL,
        interest_rate REAL DEFAULT 0.0,
        start_date TEXT NOT NULL,
        last_payment_date TEXT,
        auto_payment_enabled INTEGER DEFAULT 0,
        auto_payment_frequency TEXT DEFAULT 'monthly',
        next_payment_date TEXT,
        loan_status TEXT DEFAULT 'active',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE personal_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        given_date TEXT NOT NULL,
        return_date TEXT,
        actual_return_date TEXT,
        is_settled INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Payment history table for tracking all payments
    await db.execute('''
      CREATE TABLE payment_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL,
        payment_amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_type TEXT DEFAULT 'manual',
        created_at TEXT NOT NULL,
        FOREIGN KEY (loan_id) REFERENCES bank_loans (id) ON DELETE CASCADE
      )
    ''');

    // Loan reminders table
    await db.execute('''
      CREATE TABLE loan_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL,
        reminder_date TEXT NOT NULL,
        reminder_type TEXT NOT NULL,
        is_sent INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (loan_id) REFERENCES bank_loans (id) ON DELETE CASCADE
      )
    ''');
  }

  // Helper method to safely cast to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper method to safely cast to int
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Helper method to safely cast to string
  String _toString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  // Enhanced Bank loan CRUD operations with auto-payment
  Future<int> insertBankLoan(Map<String, dynamic> loan) async {
    final db = await database;

    // Calculate next payment date based on frequency
    if (_toInt(loan['auto_payment_enabled']) == 1) {
      loan['next_payment_date'] = _calculateNextPaymentDate(
        _toString(loan['start_date']),
        _toString(loan['auto_payment_frequency']),
        0, // No payments made yet
      );
    }

    final loanId = await db.insert('bank_loans', loan);

    // Create initial reminder if auto-payment is enabled
    if (_toInt(loan['auto_payment_enabled']) == 1) {
      await _createPaymentReminder(loanId, loan['next_payment_date']);
    }

    return loanId;
  }

  Future<List<Map<String, dynamic>>> getBankLoans() async {
    final db = await database;
    return await db.query('bank_loans', orderBy: 'created_at DESC');
  }

  Future<void> updateBankLoan(int id, Map<String, dynamic> loan) async {
    final db = await database;

    // Update next payment date if auto-payment settings changed
    if (loan.containsKey('auto_payment_enabled') ||
        loan.containsKey('auto_payment_frequency')) {
      final currentLoan = await db.query('bank_loans', where: 'id = ?', whereArgs: [id]);
      if (currentLoan.isNotEmpty) {
        final installmentsPaid = _toInt(currentLoan.first['installments_paid']);
        loan['next_payment_date'] = _calculateNextPaymentDate(
          _toString(loan['start_date'] ?? currentLoan.first['start_date']),
          _toString(loan['auto_payment_frequency'] ?? currentLoan.first['auto_payment_frequency']),
          installmentsPaid,
        );
      }
    }

    await db.update('bank_loans', loan, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBankLoan(int id) async {
    final db = await database;
    // Delete loan and related records (cascade delete)
    await db.delete('bank_loans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> payInstallment(int loanId, {bool isAutoPayment = false}) async {
    final db = await database;
    final loans = await db.query('bank_loans', where: 'id = ?', whereArgs: [loanId]);

    if (loans.isNotEmpty) {
      final loan = loans.first;
      final newInstallments = _toInt(loan['installments_paid']) + 1;
      final paymentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Update loan record
      final updateData = <String, dynamic>{
        'installments_paid': newInstallments,
        'last_payment_date': paymentDate,
      };

      // Calculate next payment date if auto-payment is enabled and loan not completed
      if (_toInt(loan['auto_payment_enabled']) == 1 &&
          newInstallments < _toInt(loan['total_installments'])) {
        updateData['next_payment_date'] = _calculateNextPaymentDate(
          _toString(loan['start_date']),
          _toString(loan['auto_payment_frequency']),
          newInstallments,
        );
      } else if (newInstallments >= _toInt(loan['total_installments'])) {
        updateData['loan_status'] = 'completed';
        updateData['next_payment_date'] = null;
      }

      await db.update('bank_loans', updateData, where: 'id = ?', whereArgs: [loanId]);

      // Add payment history record
      await db.insert('payment_history', {
        'loan_id': loanId,
        'payment_amount': _toDouble(loan['installment_amount']),
        'payment_date': paymentDate,
        'payment_type': isAutoPayment ? 'auto' : 'manual',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create next reminder if loan not completed and auto-payment enabled
      if (_toInt(loan['auto_payment_enabled']) == 1 &&
          newInstallments < _toInt(loan['total_installments'])) {
        await _createPaymentReminder(loanId, updateData['next_payment_date']);
      }

      // Add transaction record for expense tracking
      await insertTransaction({
        'type': 'expense',
        'amount': _toDouble(loan['installment_amount']),
        'description': 'Loan EMI - ${_toString(loan['bank_name'])}',
        'category': 'Bills',
        'date': paymentDate,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // Process automatic payments
  Future<void> processAutoInstallments() async {
    final db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Get all loans with auto-payment enabled and due payments
    final dueLoans = await db.query(
      'bank_loans',
      where: 'auto_payment_enabled = 1 AND next_payment_date <= ? AND loan_status = ? AND installments_paid < total_installments',
      whereArgs: [today, 'active'],
    );

    for (final loan in dueLoans) {
      await payInstallment(_toInt(loan['id']), isAutoPayment: true);
    }
  }

  // Get loan summary statistics
  Future<Map<String, double>> getLoanSummary() async {
    final db = await database;
    final loans = await db.query('bank_loans');

    double totalAmount = 0;
    double remainingAmount = 0;
    double monthlyEmi = 0;
    double paidAmount = 0;

    for (final loan in loans) {
      final loanAmount = _toDouble(loan['loan_amount']);
      final installmentAmount = _toDouble(loan['installment_amount']);
      final installmentsPaid = _toInt(loan['installments_paid']);
      final totalInstallments = _toInt(loan['total_installments']);

      totalAmount += loanAmount;
      paidAmount += installmentsPaid * installmentAmount;

      if (installmentsPaid < totalInstallments) {
        remainingAmount += loanAmount - (installmentsPaid * installmentAmount);

        // Only add to monthly EMI if it's an active monthly loan
        final frequency = _toString(loan['auto_payment_frequency']);
        if (frequency == 'monthly') {
          monthlyEmi += installmentAmount;
        }
      }
    }

    return {
      'total_amount': totalAmount,
      'remaining_amount': remainingAmount,
      'monthly_emi': monthlyEmi,
      'paid_amount': paidAmount,
    };
  }

  // Get payment history for a loan
  Future<List<Map<String, dynamic>>> getPaymentHistory(int loanId) async {
    final db = await database;
    return await db.query(
      'payment_history',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'payment_date DESC',
    );
  }

  // Get overdue loans
  Future<List<Map<String, dynamic>>> getOverdueLoans() async {
    final db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return await db.query(
      'bank_loans',
      where: 'next_payment_date < ? AND loan_status = ? AND installments_paid < total_installments',
      whereArgs: [today, 'active'],
      orderBy: 'next_payment_date ASC',
    );
  }

  // Get upcoming payments (next 7 days)
  Future<List<Map<String, dynamic>>> getUpcomingPayments() async {
    final db = await database;
    final today = DateTime.now();
    final nextWeek = today.add(const Duration(days: 7));

    return await db.query(
      'bank_loans',
      where: 'next_payment_date >= ? AND next_payment_date <= ? AND loan_status = ? AND installments_paid < total_installments',
      whereArgs: [
        DateFormat('yyyy-MM-dd').format(today),
        DateFormat('yyyy-MM-dd').format(nextWeek),
        'active',
      ],
      orderBy: 'next_payment_date ASC',
    );
  }

  // Helper method to calculate next payment date
  String _calculateNextPaymentDate(String startDate, String frequency, int installmentsPaid) {
    final start = DateTime.parse(startDate);
    DateTime nextPayment;

    switch (frequency) {
      case 'weekly':
        nextPayment = start.add(Duration(days: 7 * (installmentsPaid + 1)));
        break;
      case 'biweekly':
        nextPayment = start.add(Duration(days: 14 * (installmentsPaid + 1)));
        break;
      case 'monthly':
        nextPayment = DateTime(
          start.year,
          start.month + (installmentsPaid + 1),
          start.day,
        );
        break;
      case 'bimonthly':
        nextPayment = DateTime(
          start.year,
          start.month + (2 * (installmentsPaid + 1)),
          start.day,
        );
        break;
      case 'quarterly':
        nextPayment = DateTime(
          start.year,
          start.month + (3 * (installmentsPaid + 1)),
          start.day,
        );
        break;
      case 'semiannual':
        nextPayment = DateTime(
          start.year,
          start.month + (6 * (installmentsPaid + 1)),
          start.day,
        );
        break;
      case 'annual':
        nextPayment = DateTime(
          start.year + (installmentsPaid + 1),
          start.month,
          start.day,
        );
        break;
      default:
        nextPayment = DateTime(
          start.year,
          start.month + (installmentsPaid + 1),
          start.day,
        );
    }

    return DateFormat('yyyy-MM-dd').format(nextPayment);
  }

  // Create payment reminder
  Future<void> _createPaymentReminder(int loanId, dynamic reminderDate) async {
    if (reminderDate == null) return;

    final db = await database;
    await db.insert('loan_reminders', {
      'loan_id': loanId,
      'reminder_date': _toString(reminderDate),
      'reminder_type': 'payment_due',
      'is_sent': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get pending reminders
  Future<List<Map<String, dynamic>>> getPendingReminders() async {
    final db = await database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return await db.rawQuery('''
      SELECT r.*, l.bank_name, l.installment_amount 
      FROM loan_reminders r
      JOIN bank_loans l ON r.loan_id = l.id
      WHERE r.reminder_date <= ? AND r.is_sent = 0
      ORDER BY r.reminder_date ASC
    ''', [today]);
  }

  // Mark reminder as sent
  Future<void> markReminderAsSent(int reminderId) async {
    final db = await database;
    await db.update(
      'loan_reminders',
      {'is_sent': 1},
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  // Get loan analytics
  Future<Map<String, dynamic>> getLoanAnalytics() async {
    final db = await database;

    // Total loans count
    final totalLoans = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM bank_loans'),
    ) ?? 0;

    // Active loans count
    final activeLoans = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM bank_loans WHERE loan_status = ?', ['active']),
    ) ?? 0;

    // Completed loans count
    final completedLoans = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM bank_loans WHERE loan_status = ?', ['completed']),
    ) ?? 0;

    // Auto-payment enabled loans count
    final autoPaymentLoans = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM bank_loans WHERE auto_payment_enabled = 1'),
    ) ?? 0;

    // Average interest rate
    final avgResult = await db.rawQuery('SELECT AVG(interest_rate) as avg_rate FROM bank_loans WHERE loan_status = ?', ['active']);
    final avgInterestRate = _toDouble(avgResult.isNotEmpty ? avgResult.first['avg_rate'] : 0);

    // Total payments made this month
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final monthlyPayments = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM payment_history WHERE payment_date LIKE ?',
        ['$currentMonth%'],
      ),
    ) ?? 0;

    // Overdue count
    final overdueCount = (await getOverdueLoans()).length;

    // Total interest paid calculation
    final interestResult = await db.rawQuery('''
      SELECT SUM((installments_paid * installment_amount) - 
                 (loan_amount * installments_paid / total_installments)) as interest_paid
      FROM bank_loans WHERE installments_paid > 0
    ''');
    final totalInterestPaid = _toDouble(interestResult.isNotEmpty ? interestResult.first['interest_paid'] : 0);

    return {
      'total_loans': totalLoans,
      'active_loans': activeLoans,
      'completed_loans': completedLoans,
      'auto_payment_loans': autoPaymentLoans,
      'average_interest_rate': avgInterestRate,
      'monthly_payments': monthlyPayments,
      'overdue_count': overdueCount,
      'total_interest_paid': totalInterestPaid,
    };
  }

  // Get loan details with payment history
  Future<Map<String, dynamic>?> getLoanDetails(int loanId) async {
    final db = await database;

    final loanResult = await db.query('bank_loans', where: 'id = ?', whereArgs: [loanId]);
    if (loanResult.isEmpty) return null;

    final loan = Map<String, dynamic>.from(loanResult.first);

    // Get payment history
    final paymentHistory = await getPaymentHistory(loanId);
    loan['payment_history'] = paymentHistory;

    // Calculate additional metrics
    final totalPaid = paymentHistory.fold<double>(
      0.0,
          (sum, payment) => sum + _toDouble(payment['payment_amount']),
    );

    final remainingAmount = _toDouble(loan['loan_amount']) - totalPaid;
    final progressPercentage = _toInt(loan['installments_paid']) / _toInt(loan['total_installments']) * 100;

    loan['total_paid'] = totalPaid;
    loan['remaining_amount'] = remainingAmount;
    loan['progress_percentage'] = progressPercentage;

    return loan;
  }

  // Bulk payment operations
  Future<void> payMultipleInstallments(List<int> loanIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final loanId in loanIds) {
        await payInstallment(loanId);
      }
    });
  }

  // Get amortization schedule for a loan
  Future<List<Map<String, dynamic>>> getAmortizationSchedule(int loanId) async {
    final db = await database;
    final loanResult = await db.query('bank_loans', where: 'id = ?', whereArgs: [loanId]);

    if (loanResult.isEmpty) return [];

    final loan = loanResult.first;
    final loanAmount = _toDouble(loan['loan_amount']);
    final installmentAmount = _toDouble(loan['installment_amount']);
    final totalInstallments = _toInt(loan['total_installments']);
    final interestRate = _toDouble(loan['interest_rate']) / 100 / 12; // Monthly rate
    final startDate = DateTime.parse(_toString(loan['start_date']));
    final frequency = _toString(loan['auto_payment_frequency']);

    List<Map<String, dynamic>> schedule = [];
    double balance = loanAmount;

    for (int i = 1; i <= totalInstallments; i++) {
      final interestPayment = balance * interestRate;
      final principalPayment = installmentAmount - interestPayment;
      balance = balance - principalPayment;

      final paymentDate = _calculatePaymentDate(startDate, frequency, i - 1);

      schedule.add({
        'installment_number': i,
        'payment_date': paymentDate,
        'installment_amount': installmentAmount,
        'principal_payment': principalPayment,
        'interest_payment': interestPayment,
        'remaining_balance': balance > 0 ? balance : 0,
      });
    }

    return schedule;
  }

  // Helper method to calculate payment date based on frequency
  String _calculatePaymentDate(DateTime startDate, String frequency, int installmentNumber) {
    DateTime paymentDate;

    switch (frequency) {
      case 'weekly':
        paymentDate = startDate.add(Duration(days: 7 * installmentNumber));
        break;
      case 'biweekly':
        paymentDate = startDate.add(Duration(days: 14 * installmentNumber));
        break;
      case 'monthly':
        paymentDate = DateTime(
          startDate.year,
          startDate.month + installmentNumber,
          startDate.day,
        );
        break;
      case 'bimonthly':
        paymentDate = DateTime(
          startDate.year,
          startDate.month + (2 * installmentNumber),
          startDate.day,
        );
        break;
      case 'quarterly':
        paymentDate = DateTime(
          startDate.year,
          startDate.month + (3 * installmentNumber),
          startDate.day,
        );
        break;
      case 'semiannual':
        paymentDate = DateTime(
          startDate.year,
          startDate.month + (6 * installmentNumber),
          startDate.day,
        );
        break;
      case 'annual':
        paymentDate = DateTime(
          startDate.year + installmentNumber,
          startDate.month,
          startDate.day,
        );
        break;
      default:
        paymentDate = DateTime(
          startDate.year,
          startDate.month + installmentNumber,
          startDate.day,
        );
    }

    return DateFormat('yyyy-MM-dd').format(paymentDate);
  }

  // Advanced loan analytics
  Future<Map<String, dynamic>> getAdvancedLoanAnalytics() async {
    final db = await database;

    // Loan distribution by status
    final statusDistribution = await db.rawQuery('''
      SELECT loan_status, COUNT(*) as count, SUM(loan_amount) as total_amount
      FROM bank_loans 
      GROUP BY loan_status
    ''');

    // Payment frequency distribution
    final frequencyDistribution = await db.rawQuery('''
      SELECT auto_payment_frequency, COUNT(*) as count
      FROM bank_loans 
      WHERE auto_payment_enabled = 1
      GROUP BY auto_payment_frequency
    ''');

    // Monthly payment trends (last 6 months)
    final paymentTrends = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime.now().subtract(Duration(days: 30 * i));
      final monthStr = DateFormat('yyyy-MM').format(monthDate);

      final monthlyData = await db.rawQuery('''
        SELECT COUNT(*) as payment_count, SUM(payment_amount) as total_amount
        FROM payment_history 
        WHERE payment_date LIKE ?
      ''', ['$monthStr%']);

      paymentTrends.add({
        'month': DateFormat('MMM yyyy').format(monthDate),
        'payment_count': _toInt(monthlyData.first['payment_count']),
        'total_amount': _toDouble(monthlyData.first['total_amount']),
      });
    }

    // Interest rate analysis
    final interestAnalysis = await db.rawQuery('''
      SELECT 
        MIN(interest_rate) as min_rate,
        MAX(interest_rate) as max_rate,
        AVG(interest_rate) as avg_rate,
        COUNT(CASE WHEN interest_rate > 10 THEN 1 END) as high_interest_count
      FROM bank_loans 
      WHERE loan_status = 'active'
    ''');

    // Auto vs Manual payment comparison
    final paymentComparison = await db.rawQuery('''
      SELECT 
        payment_type,
        COUNT(*) as count,
        SUM(payment_amount) as total_amount,
        AVG(payment_amount) as avg_amount
      FROM payment_history 
      GROUP BY payment_type
    ''');

    return {
      'status_distribution': statusDistribution,
      'frequency_distribution': frequencyDistribution,
      'payment_trends': paymentTrends,
      'interest_analysis': interestAnalysis.isNotEmpty ? interestAnalysis.first : {},
      'payment_comparison': paymentComparison,
    };
  }

  // Loan performance metrics
  Future<Map<String, dynamic>> getLoanPerformanceMetrics() async {
    final db = await database;

    // On-time payment rate
    final onTimePayments = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_payments,
        COUNT(CASE WHEN payment_type = 'auto' THEN 1 END) as auto_payments,
        COUNT(CASE WHEN payment_type = 'manual' THEN 1 END) as manual_payments
      FROM payment_history
    ''');

    // Average loan completion rate
    final completionRate = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_loans,
        COUNT(CASE WHEN loan_status = 'completed' THEN 1 END) as completed_loans,
        AVG(installments_paid * 100.0 / total_installments) as avg_completion_percentage
      FROM bank_loans
    ''');

    // Early payment analysis
    final earlyPayments = await db.rawQuery('''
      SELECT COUNT(*) as early_payment_count
      FROM payment_history ph
      JOIN bank_loans bl ON ph.loan_id = bl.id
      WHERE ph.payment_date < bl.next_payment_date
    ''');

    return {
      'payment_metrics': onTimePayments.isNotEmpty ? onTimePayments.first : {},
      'completion_metrics': completionRate.isNotEmpty ? completionRate.first : {},
      'early_payments': earlyPayments.isNotEmpty ? earlyPayments.first : {},
    };
  }

  // Loan health score calculation
  Future<Map<String, dynamic>> getLoanHealthScore() async {
    final overdue = await getOverdueLoans();
    final total = await getBankLoans();
    final activeLoans = total.where((loan) => _toString(loan['loan_status']) == 'active').toList();

    if (activeLoans.isEmpty) {
      return {
        'score': 100,
        'grade': 'A+',
        'status': 'Excellent',
        'factors': <String>[],
      };
    }

    int score = 100;
    List<String> factors = [];

    // Factor 1: Overdue payments (40% weight)
    final overdueRate = overdue.length / activeLoans.length;
    if (overdueRate > 0.1) {
      score -= 40;
      factors.add('High overdue rate (${(overdueRate * 100).toStringAsFixed(1)}%)');
    } else if (overdueRate > 0.05) {
      score -= 20;
      factors.add('Moderate overdue rate (${(overdueRate * 100).toStringAsFixed(1)}%)');
    }

    // Factor 2: Auto-payment adoption (20% weight)
    final autoPaymentRate = activeLoans.where((loan) => _toInt(loan['auto_payment_enabled']) == 1).length / activeLoans.length;
    if (autoPaymentRate < 0.5) {
      score -= 20;
      factors.add('Low auto-payment adoption (${(autoPaymentRate * 100).toStringAsFixed(1)}%)');
    } else if (autoPaymentRate < 0.8) {
      score -= 10;
      factors.add('Moderate auto-payment adoption (${(autoPaymentRate * 100).toStringAsFixed(1)}%)');
    }

    // Factor 3: High interest loans (20% weight)
    final highInterestLoans = activeLoans.where((loan) => _toDouble(loan['interest_rate']) > 15).length;
    if (highInterestLoans > 0) {
      score -= (highInterestLoans / activeLoans.length * 20).round();
      factors.add('$highInterestLoans high-interest loans (>15%)');
    }

    // Factor 4: Payment consistency (20% weight)
    final summary = await getLoanSummary();
    final monthlyEmi = summary['monthly_emi'] ?? 0;
    final totalIncome = summary['total_amount'] ?? 1; // Avoid division by zero
    final emiRatio = monthlyEmi / totalIncome;

    if (emiRatio > 0.4) {
      score -= 20;
      factors.add('High EMI-to-loan ratio (${(emiRatio * 100).toStringAsFixed(1)}%)');
    } else if (emiRatio > 0.3) {
      score -= 10;
      factors.add('Moderate EMI-to-loan ratio (${(emiRatio * 100).toStringAsFixed(1)}%)');
    }

    score = score.clamp(0, 100);

    String grade;
    String status;

    if (score >= 90) {
      grade = 'A+';
      status = 'Excellent';
    } else if (score >= 80) {
      grade = 'A';
      status = 'Very Good';
    } else if (score >= 70) {
      grade = 'B';
      status = 'Good';
    } else if (score >= 60) {
      grade = 'C';
      status = 'Fair';
    } else if (score >= 50) {
      grade = 'D';
      status = 'Poor';
    } else {
      grade = 'F';
      status = 'Critical';
    }

    return {
      'score': score,
      'grade': grade,
      'status': status,
      'factors': factors,
      'total_loans': activeLoans.length,
      'overdue_loans': overdue.length,
    };
  }

  // Predictive analytics for loan management
  Future<Map<String, dynamic>> getPredictiveAnalytics() async {
    final db = await database;

    // Predict next 3 months payment schedule
    final upcoming = await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', next_payment_date) as month,
        COUNT(*) as payment_count,
        SUM(installment_amount) as total_amount
      FROM bank_loans 
      WHERE next_payment_date IS NOT NULL 
        AND next_payment_date >= date('now')
        AND next_payment_date <= date('now', '+3 months')
        AND loan_status = 'active'
      GROUP BY strftime('%Y-%m', next_payment_date)
      ORDER BY month
    ''');

    // Calculate loan completion timeline
    final completionTimeline = await db.rawQuery('''
      SELECT 
        bank_name,
        (total_installments - installments_paid) as remaining_installments,
        installment_amount,
        auto_payment_frequency,
        CASE 
          WHEN auto_payment_frequency = 'weekly' THEN (total_installments - installments_paid) * 7
          WHEN auto_payment_frequency = 'biweekly' THEN (total_installments - installments_paid) * 14
          WHEN auto_payment_frequency = 'monthly' THEN (total_installments - installments_paid) * 30
          WHEN auto_payment_frequency = 'quarterly' THEN (total_installments - installments_paid) * 90
          ELSE (total_installments - installments_paid) * 30
        END as estimated_days_to_completion
      FROM bank_loans 
      WHERE loan_status = 'active' AND installments_paid < total_installments
      ORDER BY estimated_days_to_completion
    ''');

    return {
      'upcoming_payments': upcoming,
      'completion_timeline': completionTimeline,
    };
  }

  // Export loan data
  Future<Map<String, dynamic>> exportLoanData() async {
    final db = await database;

    final loans = await db.query('bank_loans');
    final paymentHistory = await db.query('payment_history');
    final reminders = await db.query('loan_reminders');

    return {
      'loans': loans,
      'payment_history': paymentHistory,
      'reminders': reminders,
      'export_date': DateTime.now().toIso8601String(),
      'version': 4,
    };
  }

  // Import loan data
  Future<void> importLoanData(Map<String, dynamic> data) async {
    final db = await database;

    await db.transaction((txn) async {
      // Clear existing loan data
      await txn.delete('loan_reminders');
      await txn.delete('payment_history');
      await txn.delete('bank_loans');

      // Import loans
      if (data['loans'] != null) {
        for (var loan in data['loans']) {
          await txn.insert('bank_loans', loan);
        }
      }

      // Import payment history
      if (data['payment_history'] != null) {
        for (var payment in data['payment_history']) {
          await txn.insert('payment_history', payment);
        }
      }

      // Import reminders
      if (data['reminders'] != null) {
        for (var reminder in data['reminders']) {
          await txn.insert('loan_reminders', reminder);
        }
      }
    });
  }

  // Notification management
  Future<void> scheduleNotifications() async {
    final pendingReminders = await getPendingReminders();
    final upcomingPayments = await getUpcomingPayments();

    // This would integrate with a notification service
    // For now, we'll just mark important notifications
    for (final reminder in pendingReminders) {
      // Create notification logic here
      await markReminderAsSent(_toInt(reminder['id']));
    }
  }

  // Financial health integration
  Future<Map<String, dynamic>> getFinancialHealthReport() async {
    final loanSummary = await getLoanSummary();
    final loanHealth = await getLoanHealthScore();
    final analytics = await getLoanAnalytics();
    final performance = await getLoanPerformanceMetrics();

    return {
      'loan_summary': loanSummary,
      'health_score': loanHealth,
      'analytics': analytics,
      'performance': performance,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  // Backup specific loan data
  Future<String> backupLoanToJson(int loanId) async {
    final loanDetails = await getLoanDetails(loanId);
    final paymentHistory = await getPaymentHistory(loanId);
    final amortization = await getAmortizationSchedule(loanId);

    final backup = {
      'loan_details': loanDetails,
      'payment_history': paymentHistory,
      'amortization_schedule': amortization,
      'backup_date': DateTime.now().toIso8601String(),
    };

    return backup.toString(); // In real app, use json.encode()
  }

  // Advanced search and filtering
  Future<List<Map<String, dynamic>>> searchLoans({
    String? bankName,
    double? minAmount,
    double? maxAmount,
    String? status,
    bool? autoPaymentEnabled,
    String? frequency,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (bankName != null && bankName.isNotEmpty) {
      whereClause += ' AND bank_name LIKE ?';
      whereArgs.add('%$bankName%');
    }

    if (minAmount != null) {
      whereClause += ' AND loan_amount >= ?';
      whereArgs.add(minAmount);
    }

    if (maxAmount != null) {
      whereClause += ' AND loan_amount <= ?';
      whereArgs.add(maxAmount);
    }

    if (status != null) {
      whereClause += ' AND loan_status = ?';
      whereArgs.add(status);
    }

    if (autoPaymentEnabled != null) {
      whereClause += ' AND auto_payment_enabled = ?';
      whereArgs.add(autoPaymentEnabled ? 1 : 0);
    }

    if (frequency != null) {
      whereClause += ' AND auto_payment_frequency = ?';
      whereArgs.add(frequency);
    }

    return await db.query(
      'bank_loans',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  // Transaction CRUD operations
  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByDate(String date) async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsByMonth(int year, int month) async {
    final db = await database;
    String startDate = DateFormat('yyyy-MM-dd').format(DateTime(year, month, 1));
    String endDate = DateFormat('yyyy-MM-dd').format(DateTime(year, month + 1, 0));

    return await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, created_at DESC',
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> getTransactionsGroupedByDate(int year, int month) async {
    final transactions = await getTransactionsByMonth(year, month);
    final Map<String, List<Map<String, dynamic>>> groupedTransactions = {};

    for (var transaction in transactions) {
      final date = _toString(transaction['date']);
      if (!groupedTransactions.containsKey(date)) {
        groupedTransactions[date] = [];
      }
      groupedTransactions[date]!.add(transaction);
    }

    return groupedTransactions;
  }

  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    final transactions = await getTransactionsByMonth(year, month);
    double totalIncome = 0;
    double totalExpense = 0;

    for (var transaction in transactions) {
      if (_toString(transaction['type']) == 'income') {
        totalIncome += _toDouble(transaction['amount']);
      } else {
        totalExpense += _toDouble(transaction['amount']);
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> transaction) async {
    final db = await database;
    await db.update('transactions', transaction, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Personal loan CRUD operations
  Future<int> insertPersonalLoan(Map<String, dynamic> loan) async {
    final db = await database;
    return await db.insert('personal_loans', loan);
  }

  Future<List<Map<String, dynamic>>> getPersonalLoans() async {
    final db = await database;
    return await db.query('personal_loans', orderBy: 'created_at DESC');
  }

  Future<void> updatePersonalLoan(int id, Map<String, dynamic> loan) async {
    final db = await database;
    await db.update('personal_loans', loan, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePersonalLoan(int id) async {
    final db = await database;
    await db.delete('personal_loans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> settlePersonalLoan(int id) async {
    final db = await database;
    await db.update(
      'personal_loans',
      {
        'is_settled': 1,
        'actual_return_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Utility methods for backup and restore
  Future<Map<String, dynamic>> exportData() async {
    final db = await database;

    final transactions = await db.query('transactions');
    final bankLoans = await db.query('bank_loans');
    final personalLoans = await db.query('personal_loans');
    final paymentHistory = await db.query('payment_history');
    final loanReminders = await db.query('loan_reminders');

    return {
      'transactions': transactions,
      'bank_loans': bankLoans,
      'personal_loans': personalLoans,
      'payment_history': paymentHistory,
      'loan_reminders': loanReminders,
      'export_date': DateTime.now().toIso8601String(),
      'version': 4,
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await database;

    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('loan_reminders');
      await txn.delete('payment_history');
      await txn.delete('transactions');
      await txn.delete('bank_loans');
      await txn.delete('personal_loans');

      // Import new data
      if (data['transactions'] != null) {
        for (var transaction in data['transactions']) {
          await txn.insert('transactions', transaction);
        }
      }

      if (data['bank_loans'] != null) {
        for (var loan in data['bank_loans']) {
          await txn.insert('bank_loans', loan);
        }
      }

      if (data['personal_loans'] != null) {
        for (var loan in data['personal_loans']) {
          await txn.insert('personal_loans', loan);
        }
      }

      if (data['payment_history'] != null) {
        for (var payment in data['payment_history']) {
          await txn.insert('payment_history', payment);
        }
      }

      if (data['loan_reminders'] != null) {
        for (var reminder in data['loan_reminders']) {
          await txn.insert('loan_reminders', reminder);
        }
      }
    });
  }

  // Database cleanup and maintenance
  Future<void> cleanupOldData({int daysToKeep = 365}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffDateString = DateFormat('yyyy-MM-dd').format(cutoffDate);

    await db.delete(
      'transactions',
      where: 'date < ?',
      whereArgs: [cutoffDateString],
    );

    await db.delete(
      'loan_reminders',
      where: 'reminder_date < ? AND is_sent = 1',
      whereArgs: [cutoffDateString],
    );
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final transactionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM transactions'),
    ) ?? 0;

    final bankLoanCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM bank_loans'),
    ) ?? 0;

    final personalLoanCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM personal_loans'),
    ) ?? 0;

    final paymentHistoryCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM payment_history'),
    ) ?? 0;

    final reminderCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM loan_reminders'),
    ) ?? 0;

    return {
      'transactions': transactionCount,
      'bank_loans': bankLoanCount,
      'personal_loans': personalLoanCount,
      'payment_history': paymentHistoryCount,
      'loan_reminders': reminderCount,
    };
  }
}