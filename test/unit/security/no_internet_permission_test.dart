import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security & Privacy Audit: Zero-Internet Guarantee', () {
    test('Release AndroidManifest.xml must never contain INTERNET permission', () async {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(await manifestFile.exists(), isTrue, reason: 'AndroidManifest.xml must exist');

      final content = await manifestFile.readAsString();

      // Strict check: No INTERNET permission
      expect(
        content.contains('android.permission.INTERNET'),
        isFalse,
        reason: 'CRITICAL SECURITY VIOLATION: android.permission.INTERNET is forbidden in Enjaz!',
      );

      // Verify offline permissions only
      expect(content.contains('ACCESS_NETWORK_STATE'), isTrue);
      expect(content.contains('RECORD_AUDIO'), isTrue);
      expect(content.contains('POST_NOTIFICATIONS'), isTrue);
    });

    test('pubspec.yaml must not contain external networking client dependencies', () async {
      final pubspecFile = File('pubspec.yaml');
      expect(await pubspecFile.exists(), isTrue);

      final pubspec = await pubspecFile.readAsString();

      // Ensure no http, dio, or network sockets
      final forbiddenPackages = ['dio', 'http', 'retrofit', 'socket_io_client'];
      for (final pkg in forbiddenPackages) {
        final regExp = RegExp('^\\s*${RegExp.escape(pkg)}:', multiLine: true);
        expect(
          regExp.hasMatch(pubspec),
          isFalse,
          reason: 'Forbidden networking package found in pubspec.yaml: $pkg',
        );
      }
    });
  });
}
