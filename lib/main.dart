import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue[600],
          unselectedItemColor: Colors.grey[600],
          elevation: 8,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DailyTransactionScreen(),
    LoanScreen(),
    PersonalLoanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'Daily',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance),
              label: 'Bank Loans',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Personal',
            ),
          ],
        ),
      ),
    );
  }
}

// Constants
class AppConstants {
  static const List<String> categories = [
    'Food',
    'Transport',
    'Shopping',
    'Personal',
    'Travel',
    'Health',
    'Entertainment',
    'Bills',
    'Education',
    'Other'
  ];
}

// Database Helper
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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('DROP TABLE IF EXISTS bank_loans');
      await db.execute('DROP TABLE IF EXISTS personal_loans');
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

    await db.execute('''
      CREATE TABLE bank_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_name TEXT NOT NULL,
        loan_amount REAL NOT NULL,
        installment_amount REAL NOT NULL,
        installments_paid INTEGER DEFAULT 0,
        total_installments INTEGER NOT NULL,
        interest_rate REAL,
        start_date TEXT NOT NULL,
        last_payment_date TEXT,
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
  }

  // Transaction CRUD
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

  Future<void> updateTransaction(int id, Map<String, dynamic> transaction) async {
    final db = await database;
    await db.update('transactions', transaction, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Bank loan CRUD
  Future<int> insertBankLoan(Map<String, dynamic> loan) async {
    final db = await database;
    return await db.insert('bank_loans', loan);
  }

  Future<List<Map<String, dynamic>>> getBankLoans() async {
    final db = await database;
    return await db.query('bank_loans', orderBy: 'created_at DESC');
  }

  Future<void> updateBankLoan(int id, Map<String, dynamic> loan) async {
    final db = await database;
    await db.update('bank_loans', loan, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBankLoan(int id) async {
    final db = await database;
    await db.delete('bank_loans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> payInstallment(int loanId) async {
    final db = await database;
    final loans = await db.query('bank_loans', where: 'id = ?', whereArgs: [loanId]);
    if (loans.isNotEmpty) {
      final loan = loans.first;
      final newInstallments = (loan['installments_paid'] as int) + 1;
      await db.update(
        'bank_loans',
        {
          'installments_paid': newInstallments,
          'last_payment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        },
        where: 'id = ?',
        whereArgs: [loanId],
      );
    }
  }

  // Personal loan CRUD
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
}

// Reusable Components
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AmountCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const AmountCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StyledDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const StyledDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            content,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

// Utility Functions
class DialogUtils {
  static Future<bool> showConfirmDialog(
      BuildContext context,
      String title,
      String message,
      ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  static Future<DateTime?> selectDate(BuildContext context, {DateTime? initialDate}) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
  }
}

// Daily Transaction Screen
class DailyTransactionScreen extends StatefulWidget {
  const DailyTransactionScreen({super.key});

  @override
  State<DailyTransactionScreen> createState() => _DailyTransactionScreenState();
}

class _DailyTransactionScreenState extends State<DailyTransactionScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _transactions = [];
  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayTransactions();
  }

  Future<void> _loadTodayTransactions() async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final transactions = await _db.getTransactionsByDate(today);

    double income = 0;
    double expense = 0;

    for (var transaction in transactions) {
      if (transaction['type'] == 'income') {
        income += transaction['amount'];
      } else {
        expense += transaction['amount'];
      }
    }

    if (mounted) {
      setState(() {
        _transactions = transactions;
        _totalIncome = income;
        _totalExpense = expense;
      });
    }
  }

  Future<void> _deleteTransaction(BuildContext context, Map<String, dynamic> transaction) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      'Delete Transaction',
      'Are you sure you want to delete this transaction?',
    );

    if (confirmed) {
      await _db.deleteTransaction(transaction['id']);
      _loadTodayTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Google Drive backup coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AmountCard(
                  title: 'Income',
                  amount: _totalIncome,
                  color: Colors.green,
                  icon: Icons.trending_up,
                ),
                const SizedBox(width: 12),
                AmountCard(
                  title: 'Expense',
                  amount: _totalExpense,
                  color: Colors.red,
                  icon: Icons.trending_down,
                ),
                const SizedBox(width: 12),
                AmountCard(
                  title: 'Balance',
                  amount: _totalIncome - _totalExpense,
                  color: Colors.blue,
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
          ),

          Expanded(
            child: _transactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions today',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final transaction = _transactions[index];
                final isIncome = transaction['type'] == 'income';

                return CustomCard(
                  onTap: () => _showTransactionOptions(context, transaction),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isIncome
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(
                          isIncome ? Icons.add : Icons.remove,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transaction['description']?.toString() ?? 'Transaction',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transaction['category']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isIncome ? '+' : '-'}₹${transaction['amount'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isIncome ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTransactionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTransactionOptions(BuildContext context, Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Transaction'),
              onTap: () {
                Navigator.pop(context);
                _showTransactionDialog(context, transaction: transaction);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Transaction'),
              onTap: () {
                Navigator.pop(context);
                _deleteTransaction(context, transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDialog(BuildContext context, {Map<String, dynamic>? transaction}) {
    showDialog(
      context: context,
      builder: (context) => TransactionDialog(
        transaction: transaction,
        onSaved: _loadTodayTransactions,
      ),
    );
  }
}

class TransactionDialog extends StatefulWidget {
  final Map<String, dynamic>? transaction;
  final VoidCallback onSaved;

  const TransactionDialog({
    super.key,
    this.transaction,
    required this.onSaved,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'expense';
  String _selectedCategory = AppConstants.categories.first;
  final DatabaseHelper _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!['amount'].toString();
      _descriptionController.text = widget.transaction!['description'] ?? '';
      _selectedType = widget.transaction!['type'];
      _selectedCategory = widget.transaction!['category'] ?? AppConstants.categories.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyledDialog(
      title: widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Income'),
                      value: 'income',
                      groupValue: _selectedType,
                      onChanged: (value) => setState(() => _selectedType = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Expense'),
                      value: 'expense',
                      groupValue: _selectedType,
                      onChanged: (value) => setState(() => _selectedType = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: AppConstants.categories.map((category) {
                  return DropdownMenuItem(value: category, child: Text(category));
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            _saveTransaction(context);
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(widget.transaction == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _saveTransaction(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final transactionData = {
        'type': _selectedType,
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'created_at': DateTime.now().toIso8601String(),
      };

      if (widget.transaction == null) {
        await _db.insertTransaction(transactionData);
      } else {
        await _db.updateTransaction(widget.transaction!['id'], transactionData);
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    }
  }
}

// Bank Loan Screen
class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _loans = [];

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    final loans = await _db.getBankLoans();
    if (mounted) {
      setState(() => _loans = loans);
    }
  }

  Future<void> _deleteLoan(BuildContext context, Map<String, dynamic> loan) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      'Delete Loan',
      'Are you sure you want to delete this loan?',
    );

    if (confirmed) {
      await _db.deleteBankLoan(loan['id']);
      _loadLoans();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Loans')),
      body: _loans.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No bank loans found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _loans.length,
        itemBuilder: (context, index) {
          final loan = _loans[index];
          final progress = loan['installments_paid'] / loan['total_installments'];

          return CustomCard(
            onTap: () => _showLoanDetails(context, loan),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loan['bank_name'].toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showLoanDialog(context, loan: loan);
                            break;
                          case 'delete':
                            _deleteLoan(context, loan);
                            break;
                          case 'pay':
                            _payInstallment(context, loan);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        if (loan['installments_paid'] < loan['total_installments'])
                          const PopupMenuItem(value: 'pay', child: Text('Pay Installment')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${loan['loan_amount'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress: ${loan['installments_paid']}/${loan['total_installments']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      'EMI: ₹${loan['installment_amount'].toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLoanDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _payInstallment(BuildContext context, Map<String, dynamic> loan) async {
    await _db.payInstallment(loan['id']);
    _loadLoans();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installment paid successfully!')),
      );
    }
  }

  void _showLoanDetails(BuildContext context, Map<String, dynamic> loan) {
    final progress = loan['installments_paid'] / loan['total_installments'];
    final remainingAmount = loan['loan_amount'] - (loan['installments_paid'] * loan['installment_amount']);

    showDialog(
      context: context,
      builder: (context) => StyledDialog(
        title: 'Loan Details',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Bank Name', loan['bank_name'].toString()),
            _buildDetailRow('Loan Amount', '₹${loan['loan_amount'].toStringAsFixed(2)}'),
            _buildDetailRow('EMI Amount', '₹${loan['installment_amount'].toStringAsFixed(2)}'),
            _buildDetailRow('Interest Rate', '${loan['interest_rate']}%'),
            _buildDetailRow('Start Date', loan['start_date'].toString()),
            if (loan['last_payment_date'] != null)
              _buildDetailRow('Last Payment', loan['last_payment_date'].toString()),
            _buildDetailRow('Progress', '${loan['installments_paid']}/${loan['total_installments']} (${(progress * 100).toStringAsFixed(1)}%)'),
            _buildDetailRow('Remaining Amount', '₹${remainingAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (loan['installments_paid'] < loan['total_installments'])
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _payInstallment(context, loan);
              },
              child: const Text('Pay Installment'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showLoanDialog(BuildContext context, {Map<String, dynamic>? loan}) {
    showDialog(
      context: context,
      builder: (context) => BankLoanDialog(
        loan: loan,
        onSaved: _loadLoans,
      ),
    );
  }
}

class BankLoanDialog extends StatefulWidget {
  final Map<String, dynamic>? loan;
  final VoidCallback onSaved;

  const BankLoanDialog({
    super.key,
    this.loan,
    required this.onSaved,
  });

  @override
  State<BankLoanDialog> createState() => _BankLoanDialogState();
}

class _BankLoanDialogState extends State<BankLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _loanAmountController = TextEditingController();
  final _installmentAmountController = TextEditingController();
  final _totalInstallmentsController = TextEditingController();
  final _interestRateController = TextEditingController();
  DateTime _startDate = DateTime.now();
  final DatabaseHelper _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    if (widget.loan != null) {
      _bankNameController.text = widget.loan!['bank_name'];
      _loanAmountController.text = widget.loan!['loan_amount'].toString();
      _installmentAmountController.text = widget.loan!['installment_amount'].toString();
      _totalInstallmentsController.text = widget.loan!['total_installments'].toString();
      _interestRateController.text = widget.loan!['interest_rate'].toString();
      _startDate = DateTime.parse(widget.loan!['start_date']);
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _loanAmountController.dispose();
    _installmentAmountController.dispose();
    _totalInstallmentsController.dispose();
    _interestRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyledDialog(
      title: widget.loan == null ? 'Add Bank Loan' : 'Edit Bank Loan',
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: 'Bank Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Enter bank name' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _loanAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Loan Amount',
                  prefixText: '₹',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Enter loan amount' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _installmentAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'EMI Amount',
                  prefixText: '₹',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Enter EMI amount' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _totalInstallmentsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Installments',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Enter total installments' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _interestRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Interest Rate',
                  suffixText: '%',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () async {
                  final date = await DialogUtils.selectDate(context, initialDate: _startDate);
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Start Date: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            _saveLoan(context);
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(widget.loan == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _saveLoan(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final loanData = {
        'bank_name': _bankNameController.text,
        'loan_amount': double.parse(_loanAmountController.text),
        'installment_amount': double.parse(_installmentAmountController.text),
        'total_installments': int.parse(_totalInstallmentsController.text),
        'interest_rate': double.tryParse(_interestRateController.text) ?? 0.0,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'created_at': DateTime.now().toIso8601String(),
      };

      if (widget.loan == null) {
        await _db.insertBankLoan(loanData);
      } else {
        await _db.updateBankLoan(widget.loan!['id'], loanData);
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    }
  }
}

// Personal Loan Screen
class PersonalLoanScreen extends StatefulWidget {
  const PersonalLoanScreen({super.key});

  @override
  State<PersonalLoanScreen> createState() => _PersonalLoanScreenState();
}

class _PersonalLoanScreenState extends State<PersonalLoanScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _loans = [];

  @override
  void initState() {
    super.initState();
    _loadPersonalLoans();
  }

  Future<void> _loadPersonalLoans() async {
    final loans = await _db.getPersonalLoans();
    if (mounted) {
      setState(() => _loans = loans);
    }
  }

  Future<void> _deletePersonalLoan(BuildContext context, Map<String, dynamic> loan) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      'Delete Personal Loan',
      'Are you sure you want to delete this personal loan?',
    );

    if (confirmed) {
      await _db.deletePersonalLoan(loan['id']);
      _loadPersonalLoans();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Loans')),
      body: _loans.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No personal loans found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _loans.length,
        itemBuilder: (context, index) {
          final loan = _loans[index];
          final isGiven = loan['type'] == 'given';
          final isOverdue = _isOverdue(loan);

          return CustomCard(
            onTap: () => _showPersonalLoanDetails(context, loan),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isGiven
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    isGiven ? Icons.call_made : Icons.call_received,
                    color: isGiven ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan['person_name'].toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loan['description']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Given: ${loan['given_date']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (loan['return_date'] != null)
                        Text(
                          'Due: ${loan['return_date']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue ? Colors.red : Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${loan['amount'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isGiven ? Colors.orange : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: loan['is_settled'] == 1
                            ? Colors.green.withOpacity(0.1)
                            : isOverdue
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        loan['is_settled'] == 1
                            ? 'Settled'
                            : isOverdue
                            ? 'Overdue'
                            : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: loan['is_settled'] == 1
                              ? Colors.green
                              : isOverdue
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showPersonalLoanDialog(context, loan: loan);
                            break;
                          case 'delete':
                            _deletePersonalLoan(context, loan);
                            break;
                          case 'settle':
                            _settleLoan(context, loan);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        if (loan['is_settled'] == 0)
                          const PopupMenuItem(value: 'settle', child: Text('Mark as Settled')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPersonalLoanDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _isOverdue(Map<String, dynamic> loan) {
    if (loan['is_settled'] == 1 || loan['return_date'] == null) return false;
    final returnDate = DateTime.parse(loan['return_date']);
    return DateTime.now().isAfter(returnDate);
  }

  Future<void> _settleLoan(BuildContext context, Map<String, dynamic> loan) async {
    await _db.settlePersonalLoan(loan['id']);
    _loadPersonalLoans();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan marked as settled!')),
      );
    }
  }

  void _showPersonalLoanDetails(BuildContext context, Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder: (context) => StyledDialog(
        title: 'Personal Loan Details',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Person', loan['person_name'].toString()),
            _buildDetailRow('Amount', '₹${loan['amount'].toStringAsFixed(2)}'),
            _buildDetailRow('Type', loan['type'] == 'given' ? 'Money Given' : 'Money Taken'),
            _buildDetailRow('Description', loan['description']?.toString() ?? 'N/A'),
            _buildDetailRow('Given Date', loan['given_date'].toString()),
            if (loan['return_date'] != null)
              _buildDetailRow('Expected Return', loan['return_date'].toString()),
            if (loan['actual_return_date'] != null)
              _buildDetailRow('Actual Return', loan['actual_return_date'].toString()),
            _buildDetailRow('Status', loan['is_settled'] == 1 ? 'Settled' : 'Pending'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (loan['is_settled'] == 0)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _settleLoan(context, loan);
              },
              child: const Text('Mark as Settled'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showPersonalLoanDialog(BuildContext context, {Map<String, dynamic>? loan}) {
    showDialog(
      context: context,
      builder: (context) => PersonalLoanDialog(
        loan: loan,
        onSaved: _loadPersonalLoans,
      ),
    );
  }
}

class PersonalLoanDialog extends StatefulWidget {
  final Map<String, dynamic>? loan;
  final VoidCallback onSaved;

  const PersonalLoanDialog({
    super.key,
    this.loan,
    required this.onSaved,
  });

  @override
  State<PersonalLoanDialog> createState() => _PersonalLoanDialogState();
}

class _PersonalLoanDialogState extends State<PersonalLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _personNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'given';
  DateTime _givenDate = DateTime.now();
  DateTime? _returnDate;
  final DatabaseHelper _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    if (widget.loan != null) {
      _personNameController.text = widget.loan!['person_name'];
      _amountController.text = widget.loan!['amount'].toString();
      _descriptionController.text = widget.loan!['description'] ?? '';
      _selectedType = widget.loan!['type'];
      _givenDate = DateTime.parse(widget.loan!['given_date']);
      if (widget.loan!['return_date'] != null) {
        _returnDate = DateTime.parse(widget.loan!['return_date']);
      }
    }
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyledDialog(
      title: widget.loan == null ? 'Add Personal Loan' : 'Edit Personal Loan',
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Given'),
                      value: 'given',
                      groupValue: _selectedType,
                      onChanged: (value) => setState(() => _selectedType = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Taken'),
                      value: 'taken',
                      groupValue: _selectedType,
                      onChanged: (value) => setState(() => _selectedType = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _personNameController,
                decoration: InputDecoration(
                  labelText: 'Person Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Enter person name' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () async {
                  final date = await DialogUtils.selectDate(context, initialDate: _givenDate);
                  if (date != null) {
                    setState(() => _givenDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Given Date: ${DateFormat('yyyy-MM-dd').format(_givenDate)}'),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () async {
                  final date = await DialogUtils.selectDate(context, initialDate: _returnDate ?? DateTime.now().add(const Duration(days: 30)));
                  if (date != null) {
                    setState(() => _returnDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_returnDate == null
                          ? 'Select Return Date (Optional)'
                          : 'Return Date: ${DateFormat('yyyy-MM-dd').format(_returnDate!)}'),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            _savePersonalLoan(context);
          },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(widget.loan == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _savePersonalLoan(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final loanData = {
        'person_name': _personNameController.text,
        'amount': double.parse(_amountController.text),
        'type': _selectedType,
        'description': _descriptionController.text,
        'given_date': DateFormat('yyyy-MM-dd').format(_givenDate),
        'return_date': _returnDate != null ? DateFormat('yyyy-MM-dd').format(_returnDate!) : null,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (widget.loan == null) {
        await _db.insertPersonalLoan(loanData);
      } else {
        await _db.updatePersonalLoan(widget.loan!['id'], loanData);
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    }
  }
}