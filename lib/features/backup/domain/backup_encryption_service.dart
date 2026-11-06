import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class BackupEncryptionException implements Exception {
  final String message;
  const BackupEncryptionException(this.message);

  @override
  String toString() => message;
}

class BackupEncryptionService {
  BackupEncryptionService._();
  static final BackupEncryptionService instance = BackupEncryptionService._();

  static const List<int> magicBytes = [0x45, 0x4E, 0x4A, 0x41, 0x5A, 0x45, 0x4E, 0x43]; // "ENJAZENC"
  static const int formatVersion = 1;

  final AesGcm _aesGcm = AesGcm.with256Bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  /// Returns true if bytes start with the Enjaz Encrypted Backup magic header
  bool isEncryptedBackup(List<int> bytes) {
    if (bytes.length < magicBytes.length + 1) return false;
    for (int i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  /// Encrypt arbitrary bytes with AES-256-GCM and PBKDF2 derived key
  Future<Uint8List> encrypt({
    required List<int> plaintextBytes,
    required String password,
  }) async {
    if (password.trim().isEmpty) {
      throw const BackupEncryptionException('كلمة المرور لا يمكن أن تكون فارغة');
    }

    // 1. Generate 16-byte random salt
    final random = Random.secure();
    final salt = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      salt[i] = random.nextInt(256);
    }

    // 2. Derive 256-bit SecretKey using PBKDF2 (100,000 iterations)
    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    // 3. Generate 12-byte nonce for AES-GCM
    final nonce = _aesGcm.newNonce();

    // 4. Encrypt with AES-GCM
    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 5. Serialize into container
    final bb = BytesBuilder();
    bb.add(magicBytes);
    bb.addByte(formatVersion);
    bb.addByte(salt.length);
    bb.add(salt);
    bb.addByte(secretBox.nonce.length);
    bb.add(secretBox.nonce);
    bb.add(secretBox.mac.bytes);
    bb.add(secretBox.cipherText);

    return bb.toBytes();
  }

  /// Decrypt an Enjaz encrypted backup container
  Future<Uint8List> decrypt({
    required List<int> encryptedBytes,
    required String password,
  }) async {
    if (!isEncryptedBackup(encryptedBytes)) {
      throw const BackupEncryptionException('الملف المحدد ليس ملف نسخ احتياطي مشفر صالح لتطبيق إنجاز');
    }

    int offset = magicBytes.length;
    final version = encryptedBytes[offset++];
    if (version != formatVersion) {
      throw BackupEncryptionException('إصدار التشفير ($version) غير مدعوم في هذا الإصدار');
    }

    final saltLen = encryptedBytes[offset++];
    final salt = encryptedBytes.sublist(offset, offset + saltLen);
    offset += saltLen;

    final nonceLen = encryptedBytes[offset++];
    final nonce = encryptedBytes.sublist(offset, offset + nonceLen);
    offset += nonceLen;

    const macLen = 16;
    if (encryptedBytes.length < offset + macLen) {
      throw const BackupEncryptionException('الملف المشفر تالف أو غير مكتمل');
    }

    final macBytes = encryptedBytes.sublist(offset, offset + macLen);
    offset += macLen;

    final cipherText = encryptedBytes.sublist(offset);

    // Derive SecretKey using PBKDF2
    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    try {
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final clearText = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError {
      throw const BackupEncryptionException('كلمة المرور غير صحيحة، تعذر فك تشفير النسخة الاحتياطية');
    } catch (e) {
      throw BackupEncryptionException('فشل فك تشفير الملف: $e');
    }
  }
}
