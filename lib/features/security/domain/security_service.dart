import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const MethodChannel _privacyChannel = MethodChannel('com.enjaz.app/privacy');

  /// Check if device supports biometrics or device PIN/pattern
  Future<bool> canAuthenticate() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Authenticate user via fingerprint, face, or device PIN/pattern
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Set native FLAG_SECURE to hide screen in recent apps switcher and prevent screenshots
  Future<void> setPrivacyWindow(bool secure) async {
    try {
      await _privacyChannel.invokeMethod('setSecure', {'secure': secure});
    } catch (_) {
      // Gracefully handle web or non-android platforms
    }
  }
}
