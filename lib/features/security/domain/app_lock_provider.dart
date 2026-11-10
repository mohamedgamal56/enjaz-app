import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'security_service.dart';

class AppLockState {
  final bool isLoading;
  final bool isEnabled;
  final bool isLocked;
  final bool isAuthenticating;
  final int timeoutSeconds; // 0 (immediately), 30, 60, 300
  final bool hideNotificationDetails;
  final bool hasDeviceSecurity;

  const AppLockState({
    this.isLoading = true,
    this.isEnabled = false,
    this.isLocked = false,
    this.isAuthenticating = false,
    this.timeoutSeconds = 0,
    this.hideNotificationDetails = true,
    this.hasDeviceSecurity = true,
  });

  AppLockState copyWith({
    bool? isLoading,
    bool? isEnabled,
    bool? isLocked,
    bool? isAuthenticating,
    int? timeoutSeconds,
    bool? hideNotificationDetails,
    bool? hasDeviceSecurity,
  }) {
    return AppLockState(
      isLoading: isLoading ?? this.isLoading,
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      hideNotificationDetails: hideNotificationDetails ?? this.hideNotificationDetails,
      hasDeviceSecurity: hasDeviceSecurity ?? this.hasDeviceSecurity,
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

  static const String _prefKeyEnabled = 'app_lock_enabled';
  static const String _prefKeyTimeout = 'app_lock_timeout_seconds';
  static const String _prefKeyHideNotifs = 'app_lock_hide_notifications';

  DateTime? _pausedAt;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (!state.isEnabled) return;

    if (lifecycleState == AppLifecycleState.paused || lifecycleState == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
      if (state.timeoutSeconds == 0) {
        state = state.copyWith(isLocked: true);
      }
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (state.isLocked) {
        unlock();
      } else if (_pausedAt != null && state.timeoutSeconds > 0) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        if (elapsed >= state.timeoutSeconds) {
          state = state.copyWith(isLocked: true);
          unlock();
        }
      }
      _pausedAt = null;
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final canAuth = await SecurityService.instance.canAuthenticate();
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefKeyEnabled) ?? false;
      final timeout = prefs.getInt(_prefKeyTimeout) ?? 0;
      final hideNotifs = prefs.getBool(_prefKeyHideNotifs) ?? true;
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isEnabled: enabled,
        isLocked: enabled,
        timeoutSeconds: timeout,
        hideNotificationDetails: hideNotifs,
        hasDeviceSecurity: canAuth,
      );

      if (enabled) {
        await SecurityService.instance.setPrivacyWindow(true);
        unlock();
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isLoading: false, isEnabled: true, isLocked: true);
    }
  }

  /// Check whether device has screen security set up
  Future<bool> checkDeviceSecurity() async {
    final canAuth = await SecurityService.instance.canAuthenticate();
    state = state.copyWith(hasDeviceSecurity: canAuth);
    return canAuth;
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
    final canAuth = await checkDeviceSecurity();
    if (!canAuth && enable) {
      return false;
    }

    final authenticated = await SecurityService.instance.authenticate(
      localizedReason: localizedReason,
    );

    if (!authenticated) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enable);

    state = state.copyWith(
      isEnabled: enable,
      isLocked: false,
    );

    await SecurityService.instance.setPrivacyWindow(enable);
    return true;
  }

  /// Set timeout in seconds before locking when app is in background
  Future<void> setTimeoutSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyTimeout, seconds);
    state = state.copyWith(timeoutSeconds: seconds);
  }

  /// Toggle hiding notification details on the phone lock screen
  Future<void> setHideNotificationDetails(bool hide) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyHideNotifs, hide);
    state = state.copyWith(hideNotificationDetails: hide);
  }
}
