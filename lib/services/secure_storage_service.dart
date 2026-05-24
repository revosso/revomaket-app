import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/errors/exceptions.dart';
import '../core/utils/app_logger.dart';

/// Thin wrapper around `flutter_secure_storage` with sensible production
/// defaults (encrypted shared preferences on Android, keychain on iOS).
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e, s) {
      AppLogger.e('SecureStorage.read($key)', e, s);
      throw StorageException('Could not read $key', cause: e, stackTrace: s);
    }
  }

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, s) {
      AppLogger.e('SecureStorage.write($key)', e, s);
      throw StorageException('Could not write $key', cause: e, stackTrace: s);
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e, s) {
      AppLogger.e('SecureStorage.delete($key)', e, s);
      throw StorageException('Could not delete $key', cause: e, stackTrace: s);
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e, s) {
      AppLogger.e('SecureStorage.deleteAll', e, s);
      throw StorageException('Could not clear storage', cause: e, stackTrace: s);
    }
  }

  Future<bool> contains(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (_) {
      return false;
    }
  }
}
