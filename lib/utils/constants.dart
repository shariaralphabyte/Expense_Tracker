class AppConstants {
  // Income Categories
  static const List<String> incomeCategories = [
    'Allowance',
    'Salary',
    'Petty Cash',
    'Bonus',
    'Investment',
    'Freelance',
    'Gift',
    'Other Income'
  ];

  // Expense Categories
  static const List<String> expenseCategories = [
    'Food',
    'Social Life',
    'Pets',
    'Transport',
    'Culture',
    'Household',
    'Apparel',
    'Beauty',
    'Health',
    'Education',
    'Gift',
    'Entertainment',
    'Bills',
    'Shopping',
    'Others'
  ];

  // Category Icons for better UI
  static const Map<String, int> categoryIcons = {
    // Income Icons
    'Allowance': 0xe047, // Icons.account_balance_wallet
    'Salary': 0xe8f8, // Icons.work
    'Petty Cash': 0xe263, // Icons.money
    'Bonus': 0xe80e, // Icons.card_giftcard
    'Investment': 0xe1db, // Icons.trending_up
    'Freelance': 0xe30a, // Icons.laptop
    'Gift': 0xe80e, // Icons.card_giftcard
    'Other Income': 0xe145, // Icons.add_circle_outline

    // Expense Icons
    'Food': 0xe56c, // Icons.restaurant
    'Social Life': 0xe7ef, // Icons.people
    'Pets': 0xe91d, // Icons.pets
    'Transport': 0xe530, // Icons.directions_car
    'Culture': 0xe413, // Icons.theater_comedy
    'Household': 0xe88a, // Icons.home
    'Apparel': 0xe8b8, // Icons.shopping_bag
    'Beauty': 0xe3f7, // Icons.face
    'Health': 0xe3f4, // Icons.local_hospital
    'Education': 0xe80c, // Icons.school
    'Entertainment': 0xe01d, // Icons.movie
    'Bills': 0xe850, // Icons.receipt
    'Shopping': 0xe8cc, // Icons.shopping_cart
    'Others': 0xe5c3, // Icons.more_horiz
  };

  // Category Colors for better visual distinction
  static const Map<String, int> categoryColors = {
    // Income Colors (Green shades)
    'Allowance': 0xFF4CAF50,
    'Salary': 0xFF2E7D32,
    'Petty Cash': 0xFF66BB6A,
    'Bonus': 0xFF1B5E20,
    'Investment': 0xFF388E3C,
    'Freelance': 0xFF4CAF50,
    'Gift': 0xFF81C784,
    'Other Income': 0xFF43A047,

    // Expense Colors (Various shades)
    'Food': 0xFFFF7043,
    'Social Life': 0xFFE91E63,
    'Pets': 0xFF8BC34A,
    'Transport': 0xFF2196F3,
    'Culture': 0xFF9C27B0,
    'Household': 0xFF795548,
    'Apparel': 0xFFE91E63,
    'Beauty': 0xFFFF69B4,
    'Health': 0xFFF44336,
    'Education': 0xFF3F51B5,
    'Entertainment': 0xFF9C27B0,
    'Bills': 0xFF607D8B,
    'Shopping': 0xFFFF5722,
    'Others': 0xFF9E9E9E,
  };

  // Month names for navigation
  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
}