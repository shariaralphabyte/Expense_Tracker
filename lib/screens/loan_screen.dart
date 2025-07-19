import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../dialogs/bank_loan_dialog.dart';


class ProfessionalLoanScreen extends StatefulWidget {
  const ProfessionalLoanScreen({super.key});

  @override
  State<ProfessionalLoanScreen> createState() => _ProfessionalLoanScreenState();
}

class _ProfessionalLoanScreenState extends State<ProfessionalLoanScreen>
    with TickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _loans = [];
  Map<String, double> _loanSummary = {};
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  late TabController _tabController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
    _loadLoans();
    _checkAutoInstallments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);

    final loans = await _db.getBankLoans();
    final summary = await _db.getLoanSummary();

    if (mounted) {
      setState(() {
        _loans = loans;
        _loanSummary = summary;
        _isLoading = false;
      });
      _fabAnimationController.forward();
    }
  }

  Future<void> _checkAutoInstallments() async {
    await _db.processAutoInstallments();
    _loadLoans();
  }

  List<Map<String, dynamic>> get _filteredLoans {
    switch (_selectedTabIndex) {
      case 0: // All
        return _loans;
      case 1: // Active
        return _loans.where((loan) =>
        loan['installments_paid'] < loan['total_installments']).toList();
      case 2: // Completed
        return _loans.where((loan) =>
        loan['installments_paid'] >= loan['total_installments']).toList();
      default:
        return _loans;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoading() : _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          ),
        ),
      ),
      title: const Text(
        'Loan Manager',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
            onPressed: () => _showLoanAnalytics(),
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'All Loans'),
          Tab(text: 'Active'),
          Tab(text: 'Completed'),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildLoanSummary(),
        Expanded(
          child: _filteredLoans.isEmpty
              ? _buildEmptyState()
              : _buildLoansList(),
        ),
      ],
    );
  }

  Widget _buildLoanSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryCard(
                'Total Loans',
                _loanSummary['total_amount'] ?? 0,
                Icons.account_balance_rounded,
                const Color(0xFF3B82F6),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[200],
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              _buildSummaryCard(
                'Remaining',
                _loanSummary['remaining_amount'] ?? 0,
                Icons.pending_rounded,
                const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryCard(
                'Monthly EMI',
                _loanSummary['monthly_emi'] ?? 0,
                Icons.calendar_month_rounded,
                const Color(0xFFEF4444),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[200],
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              _buildSummaryCard(
                'Paid Amount',
                _loanSummary['paid_amount'] ?? 0,
                Icons.check_circle_rounded,
                const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _filteredLoans.length,
      itemBuilder: (context, index) {
        final loan = _filteredLoans[index];
        return _buildLoanCard(loan, index == _filteredLoans.length - 1);
      },
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan, bool isLast) {
    final progress = loan['installments_paid'] / loan['total_installments'];
    final isCompleted = progress >= 1.0;
    final nextPaymentDate = _getNextPaymentDate(loan);
    final isOverdue = _isOverdue(loan);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue ? Border.all(color: const Color(0xFFEF4444), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showLoanDetails(loan),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLoanHeader(loan, isCompleted, isOverdue),
              const SizedBox(height: 12),
              _buildLoanProgress(loan, progress),
              const SizedBox(height: 12),
              _buildLoanFooter(loan, nextPaymentDate, isOverdue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanHeader(Map<String, dynamic> loan, bool isCompleted, bool isOverdue) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCompleted
                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                  : isOverdue
                  ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                  : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isCompleted
                ? Icons.check_circle_rounded
                : isOverdue
                ? Icons.warning_rounded
                : Icons.account_balance_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan['bank_name'].toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  if (loan['auto_payment_enabled'] == 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AUTO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '₹${loan['loan_amount'].toStringAsFixed(0)} • ${loan['interest_rate']}% APR',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleLoanAction(value, loan),
          icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'details', child: Text('View Details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit Loan')),
            if (loan['installments_paid'] < loan['total_installments'])
              const PopupMenuItem(value: 'pay', child: Text('Pay Installment')),
            const PopupMenuItem(value: 'auto', child: Text('Auto Payment Settings')),
            const PopupMenuItem(value: 'delete', child: Text('Delete Loan')),
          ],
        ),
      ],
    );
  }

  Widget _buildLoanProgress(Map<String, dynamic> loan, double progress) {
    final remainingAmount = loan['loan_amount'] -
        (loan['installments_paid'] * loan['installment_amount']);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${loan['installments_paid']}/${loan['total_installments']} installments',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(1)}% complete',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
          ),
          minHeight: 6,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Remaining: ₹${remainingAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'EMI: ₹${loan['installment_amount'].toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoanFooter(Map<String, dynamic> loan, String? nextPaymentDate, bool isOverdue) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue
            ? const Color(0xFFEF4444).withOpacity(0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue ? Icons.schedule_rounded : Icons.event_rounded,
            size: 16,
            color: isOverdue ? const Color(0xFFEF4444) : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isOverdue
                  ? 'Payment Overdue!'
                  : nextPaymentDate != null
                  ? 'Next payment: $nextPaymentDate'
                  : 'Loan completed',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? const Color(0xFFEF4444) : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (loan['installments_paid'] < loan['total_installments'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Pay Now',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final messages = {
      0: {'title': 'No loans found', 'subtitle': 'Start by adding your first loan'},
      1: {'title': 'No active loans', 'subtitle': 'All your loans are completed'},
      2: {'title': 'No completed loans', 'subtitle': 'Keep paying to complete your loans'},
    };

    final message = messages[_selectedTabIndex]!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[100]!, Colors.grey[200]!],
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message['title']!,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message['subtitle']!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showLoanDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  void _handleLoanAction(String action, Map<String, dynamic> loan) {
    switch (action) {
      case 'details':
        _showLoanDetails(loan);
        break;
      case 'edit':
        _showLoanDialog(loan: loan);
        break;
      case 'pay':
        _payInstallment(loan);
        break;
      case 'auto':
        _showAutoPaymentSettings(loan);
        break;
      case 'delete':
        _deleteLoan(loan);
        break;
    }
  }

  String? _getNextPaymentDate(Map<String, dynamic> loan) {
    if (loan['installments_paid'] >= loan['total_installments']) return null;

    final startDate = DateTime.parse(loan['start_date']);
    final installmentsPaid = loan['installments_paid'] as int;
    final nextPaymentDate = DateTime(
      startDate.year,
      startDate.month + installmentsPaid + 1,
      startDate.day,
    );

    return DateFormat('MMM dd, yyyy').format(nextPaymentDate);
  }

  bool _isOverdue(Map<String, dynamic> loan) {
    if (loan['installments_paid'] >= loan['total_installments']) return false;

    final startDate = DateTime.parse(loan['start_date']);
    final installmentsPaid = loan['installments_paid'] as int;
    final nextPaymentDate = DateTime(
      startDate.year,
      startDate.month + installmentsPaid + 1,
      startDate.day,
    );

    return DateTime.now().isAfter(nextPaymentDate);
  }

  void _showLoanDetails(Map<String, dynamic> loan) {
    // Implementation for detailed loan view
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Loan Details',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // Add detailed loan information here
            ],
          ),
        ),
      ),
    );
  }

  void _showLoanAnalytics() {
    // Implementation for loan analytics
  }

  Future<void> _payInstallment(Map<String, dynamic> loan) async {
    await _db.payInstallment(loan['id']);
    _loadLoans();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Installment paid successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAutoPaymentSettings(Map<String, dynamic> loan) {
    // Implementation for auto payment settings
  }

  Future<void> _deleteLoan(Map<String, dynamic> loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Loan'),
        content: const Text('Are you sure you want to delete this loan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await _db.deleteBankLoan(loan['id']);
      _loadLoans();
    }
  }

  void _showLoanDialog({Map<String, dynamic>? loan}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProfessionalLoanDialog(
        loan: loan,
        onSaved: _loadLoans,
      ),
    );
  }
}