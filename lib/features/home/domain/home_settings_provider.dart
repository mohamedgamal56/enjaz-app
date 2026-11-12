import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeSettingsState {
  final String userName;
  final List<String> cardOrder;
  final Map<String, bool> cardVisibility;
  final bool hideHealthDetails;

  const HomeSettingsState({
    this.userName = '',
    this.cardOrder = const ['today', 'habits', 'finance', 'health', 'goals_ideas'],
    this.cardVisibility = const {
      'today': true,
      'habits': true,
      'finance': true,
      'health': true,
      'goals_ideas': true,
    },
    this.hideHealthDetails = false,
  });

  HomeSettingsState copyWith({
    String? userName,
    List<String>? cardOrder,
    Map<String, bool>? cardVisibility,
    bool? hideHealthDetails,
  }) {
    return HomeSettingsState(
      userName: userName ?? this.userName,
      cardOrder: cardOrder ?? this.cardOrder,
      cardVisibility: cardVisibility ?? this.cardVisibility,
      hideHealthDetails: hideHealthDetails ?? this.hideHealthDetails,
    );
  }

  bool isCardVisible(String cardId) => cardVisibility[cardId] ?? true;
}

class HomeSettingsNotifier extends StateNotifier<HomeSettingsState> {
  HomeSettingsNotifier({HomeSettingsState? initialState})
      : super(initialState ?? const HomeSettingsState()) {
    if (initialState == null) {
      loadSettings();
    }
  }

  static const _keyUserName = 'home_user_name';
  static const _keyCardOrder = 'home_card_order';
  static const _keyCardVisibility = 'home_card_visibility';
  static const _keyHideHealthDetails = 'home_hide_health_details';

  static const List<String> defaultOrder = [
    'today',
    'habits',
    'finance',
    'health',
    'goals_ideas',
  ];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyUserName) ?? '';
    final orderJson = prefs.getString(_keyCardOrder);
    final visJson = prefs.getString(_keyCardVisibility);
    final hideHealth = prefs.getBool(_keyHideHealthDetails) ?? false;

    List<String> order = defaultOrder;
    if (orderJson != null) {
      try {
        final decoded = List<String>.from(jsonDecode(orderJson));
        // Ensure all default cards are present
        final set = decoded.toSet();
        for (final d in defaultOrder) {
          if (!set.contains(d)) decoded.add(d);
        }
        order = decoded;
      } catch (_) {}
    }

    Map<String, bool> visibility = {
      for (final id in defaultOrder) id: true,
    };
    if (visJson != null) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(visJson));
        visibility = decoded.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }

    state = HomeSettingsState(
      userName: name,
      cardOrder: order,
      cardVisibility: visibility,
      hideHealthDetails: hideHealth,
    );
  }

  Future<void> setUserName(String name) async {
    state = state.copyWith(userName: name.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, state.userName);
  }

  Future<void> setCardOrder(List<String> order) async {
    state = state.copyWith(cardOrder: List.unmodifiable(order));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCardOrder, jsonEncode(state.cardOrder));
  }

  Future<void> setCardVisibility(String cardId, bool visible) async {
    final newVis = Map<String, bool>.from(state.cardVisibility);
    newVis[cardId] = visible;
    state = state.copyWith(cardVisibility: newVis);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCardVisibility, jsonEncode(newVis));
  }

  Future<void> setHideHealthDetails(bool hide) async {
    state = state.copyWith(hideHealthDetails: hide);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideHealthDetails, hide);
  }
}

final homeSettingsProvider =
    StateNotifierProvider<HomeSettingsNotifier, HomeSettingsState>((ref) {
  return HomeSettingsNotifier();
});
