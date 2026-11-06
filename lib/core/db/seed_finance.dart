class SeedFinanceCategory {
  final String nameAr;
  final String nameEn;
  final String kind; // 'expense' | 'income'
  final String nature; // 'essential' | 'side' | 'none'
  final String icon;
  final int color;
  final int sortOrder;

  const SeedFinanceCategory({
    required this.nameAr,
    required this.nameEn,
    required this.kind,
    required this.nature,
    required this.icon,
    required this.color,
    required this.sortOrder,
  });
}

class SeedQuickExpense {
  final String label;
  final String categoryNameAr;
  final int defaultAmountMinor; // in piasters (e.g. 1000 = 10 EGP)
  final String nature; // 'essential' | 'side'
  final int sortOrder;

  const SeedQuickExpense({
    required this.label,
    required this.categoryNameAr,
    required this.defaultAmountMinor,
    required this.nature,
    required this.sortOrder,
  });
}

const List<SeedFinanceCategory> initialSeedFinanceCategories = [
  // Expense categories (Roadmap v2.0 Section 5.2)
  SeedFinanceCategory(
    nameAr: 'شاي وقهوة',
    nameEn: 'Tea & Coffee',
    kind: 'expense',
    nature: 'side',
    icon: 'coffee',
    color: 0xFF795548,
    sortOrder: 1,
  ),
  SeedFinanceCategory(
    nameAr: 'أكل من بره',
    nameEn: 'Dining Out',
    kind: 'expense',
    nature: 'side',
    icon: 'restaurant',
    color: 0xFFFF5722,
    sortOrder: 2,
  ),
  SeedFinanceCategory(
    nameAr: 'بقالة وأكل البيت',
    nameEn: 'Groceries & Home Food',
    kind: 'expense',
    nature: 'essential',
    icon: 'shopping_cart',
    color: 0xFF4CAF50,
    sortOrder: 3,
  ),
  SeedFinanceCategory(
    nameAr: 'مواصلات وبنزين',
    nameEn: 'Transport & Fuel',
    kind: 'expense',
    nature: 'essential',
    icon: 'directions_car',
    color: 0xFF2196F3,
    sortOrder: 4,
  ),
  SeedFinanceCategory(
    nameAr: 'فواتير',
    nameEn: 'Bills',
    kind: 'expense',
    nature: 'essential',
    icon: 'receipt_long',
    color: 0xFFFF9800,
    sortOrder: 5,
  ),
  SeedFinanceCategory(
    nameAr: 'سكن وإيجار',
    nameEn: 'Housing & Rent',
    kind: 'expense',
    nature: 'essential',
    icon: 'home',
    color: 0xFF9C27B0,
    sortOrder: 6,
  ),
  SeedFinanceCategory(
    nameAr: 'اتصالات وإنترنت',
    nameEn: 'Telecom & Internet',
    kind: 'expense',
    nature: 'essential',
    icon: 'wifi',
    color: 0xFF00BCD4,
    sortOrder: 7,
  ),
  SeedFinanceCategory(
    nameAr: 'علاج وصحة',
    nameEn: 'Healthcare & Medicine',
    kind: 'expense',
    nature: 'essential',
    icon: 'medical_services',
    color: 0xFFE91E63,
    sortOrder: 8,
  ),
  SeedFinanceCategory(
    nameAr: 'تعليم',
    nameEn: 'Education',
    kind: 'expense',
    nature: 'essential',
    icon: 'school',
    color: 0xFF3F51B5,
    sortOrder: 9,
  ),
  SeedFinanceCategory(
    nameAr: 'شغل ومعدات',
    nameEn: 'Work & Equipment',
    kind: 'expense',
    nature: 'essential',
    icon: 'work',
    color: 0xFF607D8B,
    sortOrder: 10,
  ),
  SeedFinanceCategory(
    nameAr: 'ترفيه',
    nameEn: 'Entertainment',
    kind: 'expense',
    nature: 'side',
    icon: 'sports_esports',
    color: 0xFF009688,
    sortOrder: 11,
  ),
  SeedFinanceCategory(
    nameAr: 'ملابس',
    nameEn: 'Clothing',
    kind: 'expense',
    nature: 'side',
    icon: 'checkroom',
    color: 0xFF8BC34A,
    sortOrder: 12,
  ),
  SeedFinanceCategory(
    nameAr: 'هدايا ومجاملات',
    nameEn: 'Gifts & Socials',
    kind: 'expense',
    nature: 'side',
    icon: 'card_giftcard',
    color: 0xFFE040FB,
    sortOrder: 13,
  ),
  SeedFinanceCategory(
    nameAr: 'أقساط والتزامات',
    nameEn: 'Installments & Dues',
    kind: 'expense',
    nature: 'essential',
    icon: 'account_balance',
    color: 0xFFF44336,
    sortOrder: 14,
  ),
  SeedFinanceCategory(
    nameAr: 'أخرى',
    nameEn: 'Other Expenses',
    kind: 'expense',
    nature: 'side',
    icon: 'more_horiz',
    color: 0xFF9E9E9E,
    sortOrder: 15,
  ),

  // Income categories (Section 5.2)
  SeedFinanceCategory(
    nameAr: 'راتب',
    nameEn: 'Salary',
    kind: 'income',
    nature: 'none',
    icon: 'payments',
    color: 0xFF4CAF50,
    sortOrder: 16,
  ),
  SeedFinanceCategory(
    nameAr: 'شغل وعملاء',
    nameEn: 'Freelance & Clients',
    kind: 'income',
    nature: 'none',
    icon: 'business_center',
    color: 0xFF2196F3,
    sortOrder: 17,
  ),
  SeedFinanceCategory(
    nameAr: 'أخرى',
    nameEn: 'Other Income',
    kind: 'income',
    nature: 'none',
    icon: 'attach_money',
    color: 0xFF8BC34A,
    sortOrder: 18,
  ),
];

const List<SeedQuickExpense> initialSeedQuickExpenses = [
  SeedQuickExpense(
    label: 'شاي',
    categoryNameAr: 'شاي وقهوة',
    defaultAmountMinor: 1000, // 10 EGP
    nature: 'side',
    sortOrder: 1,
  ),
  SeedQuickExpense(
    label: 'قهوة',
    categoryNameAr: 'شاي وقهوة',
    defaultAmountMinor: 2500, // 25 EGP
    nature: 'side',
    sortOrder: 2,
  ),
  SeedQuickExpense(
    label: 'مواصلات',
    categoryNameAr: 'مواصلات وبنزين',
    defaultAmountMinor: 1000, // 10 EGP
    nature: 'essential',
    sortOrder: 3,
  ),
  SeedQuickExpense(
    label: 'بنزين',
    categoryNameAr: 'مواصلات وبنزين',
    defaultAmountMinor: 10000, // 100 EGP
    nature: 'essential',
    sortOrder: 4,
  ),
  SeedQuickExpense(
    label: 'فطار',
    categoryNameAr: 'أكل من بره',
    defaultAmountMinor: 3000, // 30 EGP
    nature: 'side',
    sortOrder: 5,
  ),
];
