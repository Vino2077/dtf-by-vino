import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageException implements Exception {
  const AuthStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class SecureTokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

abstract interface class LegacyTokenStorage {
  String? read();
  bool get containsToken;
  Future<bool> write(String token);
  Future<bool> delete();
}

class FlutterSecureTokenStorage implements SecureTokenStorage {
  const FlutterSecureTokenStorage(this._storage);

  static const key = 'dtf_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String token) => _storage.write(key: key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: key);
}

class SharedPreferencesTokenStorage implements LegacyTokenStorage {
  const SharedPreferencesTokenStorage(this._preferences);

  static const key = 'dtf_token';
  final SharedPreferences _preferences;

  @override
  String? read() => _preferences.getString(key);

  @override
  bool get containsToken => _preferences.containsKey(key);

  @override
  Future<bool> write(String token) => _preferences.setString(key, token);

  @override
  Future<bool> delete() => _preferences.remove(key);
}

class AuthService extends ChangeNotifier {
  AuthService(this._secureStorage, this._legacyStorage, this._useLegacyStorage);

  final SecureTokenStorage _secureStorage;
  final LegacyTokenStorage _legacyStorage;
  final bool _useLegacyStorage;

  String? _token;
  String? _storageError;

  String? get token => _token;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  String? get storageError => _storageError;

  Future<void> initialize() async {
    final legacyToken = _legacyStorage.read();
    if (_useLegacyStorage) {
      _token = legacyToken;
      return;
    }

    try {
      final secureToken = await _secureStorage.read();
      if (secureToken != null && secureToken.isNotEmpty) {
        _token = secureToken;
        if (legacyToken != null && !await _legacyStorage.delete()) {
          _storageError =
              'Не удалось удалить старую небезопасную копию токена.';
        }
        return;
      }
      if (legacyToken == null || legacyToken.isEmpty) return;

      await _secureStorage.write(legacyToken);
      if (!await _legacyStorage.delete()) {
        await _secureStorage.delete();
        throw const AuthStorageException(
          'Не удалось завершить перенос токена в защищённое хранилище.',
        );
      }
      _token = legacyToken;
    } catch (error) {
      _token = null;
      _storageError = error is AuthStorageException
          ? error.message
          : 'Защищённое хранилище авторизации недоступно.';
    }
  }

  Future<void> saveToken(String token) async {
    final currentToken = _token;
    try {
      if (_useLegacyStorage) {
        if (!await _legacyStorage.write(token)) {
          throw const AuthStorageException('Не удалось сохранить токен.');
        }
      } else {
        await _secureStorage.write(token);
        if (_legacyStorage.containsToken && !await _legacyStorage.delete()) {
          if (currentToken == null) {
            await _secureStorage.delete();
          } else {
            await _secureStorage.write(currentToken);
          }
          throw const AuthStorageException(
            'Не удалось удалить старую небезопасную копию токена.',
          );
        }
      }
    } catch (error) {
      if (error is AuthStorageException) rethrow;
      throw const AuthStorageException(
        'Не удалось сохранить токен в защищённом хранилище.',
      );
    }

    _token = token;
    _storageError = null;
    notifyListeners();
  }

  Future<void> clearToken() async {
    final currentToken = _token;
    try {
      if (_useLegacyStorage) {
        if (_legacyStorage.containsToken && !await _legacyStorage.delete()) {
          throw const AuthStorageException('Не удалось удалить токен.');
        }
      } else {
        await _secureStorage.delete();
        if (_legacyStorage.containsToken && !await _legacyStorage.delete()) {
          if (currentToken != null) await _secureStorage.write(currentToken);
          throw const AuthStorageException(
            'Не удалось удалить старую небезопасную копию токена.',
          );
        }
      }
    } catch (error) {
      if (error is AuthStorageException) rethrow;
      throw const AuthStorageException(
        'Не удалось удалить токен из защищённого хранилища.',
      );
    }

    _token = null;
    _storageError = null;
    notifyListeners();
  }
}
