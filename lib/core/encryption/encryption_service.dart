// lib/core/encryption/encryption_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:suivi_cancer/utils/logger.dart';

class EncryptionService {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> storePassword(String password) async {
    await _secureStorage.write(key: 'user_password', value: password);
  }

  Future<String?> getPassword() async {
    try {
      final pwd = await _secureStorage.read(key: 'user_password');
      Log.d("mot de passe dans user_password:[$pwd]");
      return await _secureStorage.read(key: 'user_password');
    } catch (e) {
      print("Erreur lors de la récupération du mot de passe: $e");
    }
    return null;
  }

  Future<String> encryptData(String data) async {
    final password = await getPassword();
    final key = encrypt.Key.fromUtf8(password!.padRight(32, '0'));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.encrypt(data, iv: iv).base64;
  }
}
