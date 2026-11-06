import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/backup/domain/backup_encryption_service.dart';

void main() {
  group('BackupEncryptionService Unit Tests (Round 3 Spec 3.4)', () {
    late BackupEncryptionService service;

    setUp(() {
      service = BackupEncryptionService.instance;
    });

    test('1. Encrypt and decrypt with valid password recovers original plaintext', () async {
      const plaintext = 'تطبيق إنجاز — اختبار النسخ الاحتياطي المشفر بكلمة سر AES-256-GCM';
      final originalBytes = utf8.encode(plaintext);
      const password = 'SecretPassword123!';

      final encrypted = await service.encrypt(
        plaintextBytes: originalBytes,
        password: password,
      );

      expect(encrypted.length, greaterThan(originalBytes.length));
      expect(service.isEncryptedBackup(encrypted), isTrue);

      final decrypted = await service.decrypt(
        encryptedBytes: encrypted,
        password: password,
      );

      final decryptedText = utf8.decode(decrypted);
      expect(decryptedText, equals(plaintext));
    });

    test('2. Decrypt with wrong password throws BackupEncryptionException with clear Arabic message', () async {
      final originalBytes = utf8.encode('بيانات سرية');
      final encrypted = await service.encrypt(
        plaintextBytes: originalBytes,
        password: 'CorrectPassword123',
      );

      expect(
        () async => await service.decrypt(
          encryptedBytes: encrypted,
          password: 'WrongPassword456',
        ),
        throwsA(isA<BackupEncryptionException>().having(
          (e) => e.message,
          'message',
          contains('كلمة المرور غير صحيحة'),
        )),
      );
    });

    test('3. Decrypt invalid or tampered container throws BackupEncryptionException', () async {
      final invalidBytes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      expect(service.isEncryptedBackup(invalidBytes), isFalse);

      expect(
        () async => await service.decrypt(
          encryptedBytes: invalidBytes,
          password: 'any',
        ),
        throwsA(isA<BackupEncryptionException>()),
      );
    });

    test('4. Empty password is rejected', () async {
      final data = utf8.encode('test');
      expect(
        () async => await service.encrypt(
          plaintextBytes: data,
          password: '   ',
        ),
        throwsA(isA<BackupEncryptionException>()),
      );
    });
  });
}
