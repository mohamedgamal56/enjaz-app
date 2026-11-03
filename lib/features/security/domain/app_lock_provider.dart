import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'security_service.dart';

class AppLockState {
  final bool isEnabled;
  final bool isLocked;
  final bool isAuthenticating;

  const AppLockState({
    this.isEnabled = false,
    this.isLocked = false,
    this.isAuthenticating = false,
  });

  AppLockState copyWith({
    bool? isEnabled,
    bool? isLocked,
    bool? isAuthenticating,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
    );
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  return AppLockNotifier();
});

class AppLockNotifier extends StateNotifier<AppLockState> with WidgetsBindingObserver {
  AppLockNotifier() : super(const AppLockState()) {
    WidgetsBinding.instance.addObserver(this);
    _loadFromPrefs();
  }

  static const String _prefKey = 'app_lock_enabled';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (!state.isEnabled) return;

    if (lifecycleState == AppLifecycleState.paused || lifecycleState == AppLifecycleState.hidden) {
      state = state.copyWith(isLocked: true);
    } else if (lifecycleState == AppLifecycleState.resumed && state.isLocked) {
      unlock();
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefKey) ?? false;
      if (enabled) {
        state = state.copyWith(isEnabled: true, isLocked: true);
        await SecurityService.instance.setPrivacyWindow(true);
        // Automatically attempt initial unlock
        unlock();
      }
    } catch (_) {}
  }

  /// Attempt to unlock the app
  Future<bool> unlock({String? localizedReason}) async {
    if (!state.isEnabled || !state.isLocked) return true;
    if (state.isAuthenticating) return false;

    state = state.copyWith(isAuthenticating: true);
    final success = await SecurityService.instance.authenticate(
      localizedReason: localizedReason ?? 'يرجى تأكيد هويتك لفتح تطبيق إنجاز',
    );

    if (success) {
      state = state.copyWith(isLocked: false, isAuthenticating: false);
    } else {
      state = state.copyWith(isAuthenticating: false);
    }
    return success;
  }

  /// Toggle App Lock enabled state (requires authentication)
  Future<bool> setLockEnabled(bool enable, {required String localizedReason}) async {
    final authenticated = await SecurityService.instance.authenticate(
      localizedReason: localizedReason,
    );

    if (!authenticated) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enable);

    state = state.copyWith(
      isEnabled: enable,
      isLocked: false,
    );

    await SecurityService.instance.setPrivacyWindow(enable);
    return true;
  }
}
