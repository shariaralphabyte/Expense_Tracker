import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../dialogs/personal_loan_dialog.dart';

class ProfessionalPersonalLoanScreen extends StatefulWidget {
  const ProfessionalPersonalLoanScreen({super.key});

  @override
  State<ProfessionalPersonalLoanScreen> createState() => _ProfessionalPersonalLoanScreenState();
}

class _ProfessionalPersonalLoanScreenState extends State<ProfessionalPersonalLoanScreen>
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
    _tabController = TabController(length: 4, vsync: this);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
    _loadPersonalLoans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalLoans() async {
    setState(() => _isLoading = true);

    final loans = await _db.getPersonalLoans();
    final summary = await _getPersonalLoanSummary();

    if (mounted) {
      setState(() {
        _loans = loans;
        _loanSummary = summary;
        _isLoading = false;
      });
      _fabAnimationController.forward();
    }
  }

  Future<Map<String, double>> _getPersonalLoanSummary() async {
    final loans = await _db.getPersonalLoans();

    double totalGiven = 0;
    double totalTaken = 0;
    double pendingGiven = 0;
    double pendingTaken = 0;

    for (final loan in loans) {
      final amount = _toDouble(loan['amount']);
      final isGiven = _toString(loan['type']) == 'given';
      final isSettled = _toInt(loan['is_settled']) == 1;

      if (isGiven) {
        totalGiven += amount;
        if (!isSettled) pendingGiven += amount;
      } else {
        totalTaken += amount;
        if (!isSettled) pendingTaken += amount;
      }
    }

    return {
      'total_given': totalGiven,
      'total_taken': totalTaken,
      'pending_given': pendingGiven,
      'pending_taken': pendingTaken,
    };
  }

  // Helper methods for type safety
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _toString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  List<Map<String, dynamic>> get _filteredLoans {
    switch (_selectedTabIndex) {
      case 0: // All
        return _loans;
      case 1: // Given
        return _loans.where((loan) => _toString(loan['type']) == 'given').toList();
      case 2: // Taken
        return _loans.where((loan) => _toString(loan['type']) == 'taken').toList();
      case 3: // Overdue
        return _loans.where((loan) => _isOverdue(loan)).toList();
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
            colors: [Color(0xFF059669), Color(0xFF10B981)],
          ),
        ),
      ),
      title: const Text(
        'Personal Loans',
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
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Given'),
          Tab(text: 'Taken'),
          Tab(text: 'Overdue'),
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
                'Given Out',
                _loanSummary['total_given'] ?? 0,
                Icons.call_made_rounded,
                const Color(0xFFEF4444),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[200],
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              _buildSummaryCard(
                'Borrowed',
                _loanSummary['total_taken'] ?? 0,
                Icons.call_received_rounded,
                const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryCard(
                'Pending Out',
                _loanSummary['pending_given'] ?? 0,
                Icons.schedule_rounded,
                const Color(0xFFF59E0B),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[200],
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              _buildSummaryCard(
                'Pending In',
                _loanSummary['pending_taken'] ?? 0,
                Icons.pending_rounded,
                const Color(0xFF3B82F6),
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
    final isGiven = _toString(loan['type']) == 'given';
    final isSettled = _toInt(loan['is_settled']) == 1;
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
        onTap: () => _showPersonalLoanDetails(loan),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildLoanIcon(isGiven, isSettled, isOverdue),
              const SizedBox(width: 12),
              Expanded(child: _buildLoanInfo(loan, isOverdue)),
              _buildLoanAmount(loan, isGiven),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanIcon(bool isGiven, bool isSettled, bool isOverdue) {
    Color color;
    IconData icon;

    if (isSettled) {
      color = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
    } else if (isOverdue) {
      color = const Color(0xFFEF4444);
      icon = Icons.warning_rounded;
    } else {
      color = isGiven ? const Color(0xFFEF4444) : const Color(0xFF10B981);
      icon = isGiven ? Icons.call_made_rounded : Icons.call_received_rounded;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildLoanInfo(Map<String, dynamic> loan, bool isOverdue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _toString(loan['person_name']),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            _buildStatusChip(loan, isOverdue),
          ],
        ),
        const SizedBox(height: 4),
        if (_toString(loan['description']).isNotEmpty)
          Text(
            _toString(loan['description']),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 12,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 4),
            Text(
              'Given: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(_toString(loan['given_date'])))}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (_toString(loan['return_date']).isNotEmpty)
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 12,
                color: isOverdue ? const Color(0xFFEF4444) : Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                'Due: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(_toString(loan['return_date'])))}',
                style: TextStyle(
                  fontSize: 12,
                  color: isOverdue ? const Color(0xFFEF4444) : Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLoanAmount(Map<String, dynamic> loan, bool isGiven) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${isGiven ? '-' : '+'}₹${_toDouble(loan['amount']).toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isGiven ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          ),
        ),
        const SizedBox(height: 4),
        PopupMenuButton<String>(
          onSelected: (value) => _handleLoanAction(value, loan),
          icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400], size: 18),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'details', child: Text('View Details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit Loan')),
            if (_toInt(loan['is_settled']) == 0)
              const PopupMenuItem(value: 'settle', child: Text('Mark as Settled')),
            const PopupMenuItem(value: 'delete', child: Text('Delete Loan')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> loan, bool isOverdue) {
    String status;
    Color color;

    if (_toInt(loan['is_settled']) == 1) {
      status = 'Settled';
      color = const Color(0xFF10B981);
    } else if (isOverdue) {
      status = 'Overdue';
      color = const Color(0xFFEF4444);
    } else {
      status = 'Pending';
      color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final messages = {
      0: {'title': 'No personal loans found', 'subtitle': 'Start by adding your first loan'},
      1: {'title': 'No loans given', 'subtitle': 'No money lent to others'},
      2: {'title': 'No loans taken', 'subtitle': 'No money borrowed from others'},
      3: {'title': 'No overdue loans', 'subtitle': 'All loans are up to date'},
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
              Icons.people_rounded,
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
            colors: [Color(0xFF059669), Color(0xFF10B981)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showPersonalLoanDialog(),
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

  bool _isOverdue(Map<String, dynamic> loan) {
    if (_toInt(loan['is_settled']) == 1 || _toString(loan['return_date']).isEmpty) return false;
    final returnDate = DateTime.parse(_toString(loan['return_date']));
    return DateTime.now().isAfter(returnDate);
  }

  void _handleLoanAction(String action, Map<String, dynamic> loan) {
    switch (action) {
      case 'details':
        _showPersonalLoanDetails(loan);
        break;
      case 'edit':
        _showPersonalLoanDialog(loan: loan);
        break;
      case 'settle':
        _settleLoan(loan);
        break;
      case 'delete':
        _deleteLoan(loan);
        break;
    }
  }

  void _showPersonalLoanDetails(Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
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
              const SizedBox(height: 20),
              _buildDetailRow('Person', _toString(loan['person_name'])),
              _buildDetailRow('Amount', '₹${_toDouble(loan['amount']).toStringAsFixed(2)}'),
              _buildDetailRow('Type', _toString(loan['type']) == 'given' ? 'Money Given' : 'Money Taken'),
              _buildDetailRow('Description', _toString(loan['description']).isEmpty ? 'N/A' : _toString(loan['description'])),
              _buildDetailRow('Given Date', DateFormat('MMM dd, yyyy').format(DateTime.parse(_toString(loan['given_date'])))),
              if (_toString(loan['return_date']).isNotEmpty)
                _buildDetailRow('Expected Return', DateFormat('MMM dd, yyyy').format(DateTime.parse(_toString(loan['return_date'])))),
              if (_toString(loan['actual_return_date']).isNotEmpty)
                _buildDetailRow('Actual Return', DateFormat('MMM dd, yyyy').format(DateTime.parse(_toString(loan['actual_return_date'])))),
              _buildDetailRow('Status', _toInt(loan['is_settled']) == 1 ? 'Settled' : 'Pending'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  if (_toInt(loan['is_settled']) == 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _settleLoan(loan);
                        },
                        child: const Text('Mark as Settled'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showLoanAnalytics() {
    // Implementation for loan analytics
  }

  Future<void> _settleLoan(Map<String, dynamic> loan) async {
    await _db.settlePersonalLoan(_toInt(loan['id']));
    _loadPersonalLoans();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan marked as settled!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteLoan(Map<String, dynamic> loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Personal Loan'),
        content: const Text('Are you sure you want to delete this personal loan?'),
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
      await _db.deletePersonalLoan(_toInt(loan['id']));
      _loadPersonalLoans();
    }
  }

  void _showPersonalLoanDialog({Map<String, dynamic>? loan}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProfessionalPersonalLoanDialog(
        loan: loan,
        onSaved: _loadPersonalLoans,
      ),
    );
  }
}