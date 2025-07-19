import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../dialogs/transaction_dialog.dart';
import '../utils/constants.dart';

class ProfessionalMonthlyTransactionScreen extends StatefulWidget {
  const ProfessionalMonthlyTransactionScreen({super.key});

  @override
  State<ProfessionalMonthlyTransactionScreen> createState() => _ProfessionalMonthlyTransactionScreenState();
}

class _ProfessionalMonthlyTransactionScreenState extends State<ProfessionalMonthlyTransactionScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final PageController _pageController = PageController(initialPage: 1200);

  DateTime _currentMonth = DateTime.now();
  Map<String, List<Map<String, dynamic>>> _groupedTransactions = {};
  Map<String, double> _monthlySummary = {};
  bool _isLoading = true;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
    _loadMonthData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);

    final transactions = await _db.getTransactionsGroupedByDate(
      _currentMonth.year,
      _currentMonth.month,
    );
    final summary = await _db.getMonthlySummary(
      _currentMonth.year,
      _currentMonth.month,
    );

    if (mounted) {
      setState(() {
        _groupedTransactions = transactions;
        _monthlySummary = summary;
        _isLoading = false;
      });
      _fabAnimationController.forward();
    }
  }

  void _onPageChanged(int index) {
    final monthDiff = index - 1200;
    final newMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month + monthDiff,
      1,
    );

    if (newMonth != _currentMonth) {
      setState(() => _currentMonth = newMonth);
      _loadMonthData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) => _buildMonthView(),
      ),
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
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '${_groupedTransactions.length} days with transactions',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.today_rounded, color: Colors.white, size: 20),
            onPressed: () {
              setState(() => _currentMonth = DateTime.now());
              _pageController.animateToPage(
                1200,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Column(
      children: [
        _buildMonthlySummary(),
        _buildSwipeIndicator(),
        Expanded(child: _buildTransactionsList()),
      ],
    );
  }

  Widget _buildMonthlySummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
      child: Row(
        children: [
          _buildSummaryCard(
            'Income',
            _monthlySummary['income'] ?? 0,
            Icons.trending_up_rounded,
            const Color(0xFF10B981),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[200],
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          _buildSummaryCard(
            'Expense',
            _monthlySummary['expense'] ?? 0,
            Icons.trending_down_rounded,
            const Color(0xFFEF4444),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[200],
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          _buildSummaryCard(
            'Balance',
            _monthlySummary['balance'] ?? 0,
            Icons.account_balance_wallet_rounded,
            (_monthlySummary['balance'] ?? 0) >= 0
                ? const Color(0xFF3B82F6)
                : const Color(0xFFF59E0B),
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
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${amount.abs().toStringAsFixed(0)}',
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

  Widget _buildSwipeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe_rounded, color: Colors.grey[400], size: 14),
          const SizedBox(width: 6),
          Text(
            'Swipe to navigate months',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_groupedTransactions.isEmpty) {
      return _buildEmptyState();
    }

    final sortedDates = _groupedTransactions.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final transactions = _groupedTransactions[date]!;
        return _buildDayGroup(date, transactions, index == sortedDates.length - 1);
      },
    );
  }

  Widget _buildDayGroup(String date, List<Map<String, dynamic>> transactions, bool isLast) {
    final parsedDate = DateTime.parse(date);
    final dayName = DateFormat('EEEE').format(parsedDate);
    final dayNumber = DateFormat('dd').format(parsedDate);
    final monthName = DateFormat('MMM').format(parsedDate);

    double dayIncome = 0;
    double dayExpense = 0;

    for (var transaction in transactions) {
      if (transaction['type'] == 'income') {
        dayIncome += transaction['amount'];
      } else {
        dayExpense += transaction['amount'];
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header - More compact and professional
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Row(
              children: [
                // Compact date display
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        monthName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${transactions.length} transaction${transactions.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Compact amount display
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (dayIncome > 0)
                      Text(
                        '+₹${dayIncome.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (dayExpense > 0)
                      Text(
                        '-₹${dayExpense.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Transactions - More compact
          ...transactions.asMap().entries.map((entry) {
            final isLastTransaction = entry.key == transactions.length - 1;
            return _buildCompactTransactionItem(entry.value, isLastTransaction);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCompactTransactionItem(Map<String, dynamic> transaction, bool isLast) {
    final isIncome = transaction['type'] == 'income';
    final category = transaction['category'];
    final color = Color(AppConstants.categoryColors[category] ?? 0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[100]!),
        borderRadius: isLast
            ? const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        )
            : null,
      ),
      child: InkWell(
        onTap: () => _showTransactionOptions(transaction),
        borderRadius: isLast
            ? const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Compact category icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  IconData(
                    AppConstants.categoryIcons[category] ?? 0xe5c3,
                    fontFamily: 'MaterialIcons',
                  ),
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction['description'] ?? 'Transaction',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}₹${transaction['amount'].toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(
                      DateTime.parse(transaction['created_at']),
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[100]!,
                  Colors.grey[200]!,
                ],
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No transactions this month',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add your first transaction',
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showTransactionDialog(),
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

  void _showTransactionOptions(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.edit_rounded,
              title: 'Edit Transaction',
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.pop(context);
                _showTransactionDialog(transaction: transaction);
              },
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              icon: Icons.delete_rounded,
              title: 'Delete Transaction',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.pop(context);
                _deleteTransaction(transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(Map<String, dynamic> transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
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
      await _db.deleteTransaction(transaction['id']);
      _loadMonthData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted successfully'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showTransactionDialog({Map<String, dynamic>? transaction}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProfessionalTransactionDialog(
        transaction: transaction,
        onSaved: _loadMonthData,
      ),
    );
  }
}