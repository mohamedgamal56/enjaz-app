import 'package:flutter/material.dart';

class FinanceIconHelper {
  FinanceIconHelper._();

  static const Map<String, IconData> _icons = {
    'coffee': Icons.local_cafe_rounded,
    'restaurant': Icons.restaurant_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'directions_car': Icons.directions_car_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'home': Icons.home_rounded,
    'wifi': Icons.wifi_rounded,
    'medical_services': Icons.medical_services_rounded,
    'school': Icons.school_rounded,
    'work': Icons.work_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'checkroom': Icons.checkroom_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'account_balance': Icons.account_balance_rounded,
    'payments': Icons.payments_rounded,
    'business_center': Icons.business_center_rounded,
    'attach_money': Icons.attach_money_rounded,
    'more_horiz': Icons.more_horiz_rounded,
  };

  static IconData getIcon(String? key) {
    if (key == null) return Icons.category_rounded;
    return _icons[key] ?? Icons.category_rounded;
  }
}
