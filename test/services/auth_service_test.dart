import 'package:dtf_app/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStorage implements SecureTokenStorage {
  String? token;
  Object? readError;
  Object? writeError;
  Object? deleteError;
  final operations = <String>[];

  @override
  Future<String?> read() async {
    operations.add('secure.read');
    if (readError != null) throw readError!;
    return token;
  }

  @override
  Future<void> write(String value) async {
    operations.add('secure.write:$value');
    if (writeError != null) throw writeError!;
    token = value;
  }

  @override
  Future<void> delete() async {
    operations.add('secure.delete');
    if (deleteError != null) throw deleteError!;
    token = null;
  }
}

class _FakeLegacyStorage implements LegacyTokenStorage {
  String? token;
  bool writeSucceeds = true;
  bool deleteSucceeds = true;
  final operations = <String>[];

  @override
  String? read() {
    operations.add('legacy.read');
    return token;
  }

  @override
  bool get containsToken => token != null;

  @override
  Future<bool> write(String value) async {
    operations.add('legacy.write:$value');
    if (writeSucceeds) token = value;
    return writeSucceeds;
  }

  @override
  Future<bool> delete() async {
    operations.add('legacy.delete');
    if (deleteSucceeds) token = null;
    return deleteSucceeds;
  }
}

void main() {
  late _FakeSecureStorage secure;
  late _FakeLegacyStorage legacy;

  setUp(() {
    secure = _FakeSecureStorage();
    legacy = _FakeLegacyStorage();
  });

  test('migrates legacy token only after secure write succeeds', () async {
    legacy.token = 'legacy-token';
    final auth = AuthService(secure, legacy, false);

    await auth.initialize();

    expect(auth.token, 'legacy-token');
    expect(secure.token, 'legacy-token');
    expect(legacy.token, isNull);
    expect(secure.operations, ['secure.read', 'secure.write:legacy-token']);
    expect(legacy.operations, ['legacy.read', 'legacy.delete']);
  });

  test('secure token has priority and removes plaintext copy', () async {
    secure.token = 'secure-token';
    legacy.token = 'legacy-token';
    final auth = AuthService(secure, legacy, false);

    await auth.initialize();

    expect(auth.token, 'secure-token');
    expect(secure.token, 'secure-token');
    expect(legacy.token, isNull);
  });

  test(
    'rolls secure migration back when plaintext cannot be removed',
    () async {
      legacy
        ..token = 'legacy-token'
        ..deleteSucceeds = false;
      final auth = AuthService(secure, legacy, false);

      await auth.initialize();

      expect(auth.token, isNull);
      expect(secure.token, isNull);
      expect(legacy.token, 'legacy-token');
      expect(auth.storageError, contains('перенос токена'));
    },
  );

  test('does not change current token when a secure write fails', () async {
    secure.token = 'old-token';
    final auth = AuthService(secure, legacy, false);
    await auth.initialize();
    secure.writeError = StateError('keychain unavailable');

    await expectLater(
      auth.saveToken('new-token'),
      throwsA(isA<AuthStorageException>()),
    );

    expect(auth.token, 'old-token');
  });

  test('uses legacy storage only in explicit insecure mode', () async {
    legacy.token = 'http-token';
    secure.readError = StateError('must not be read');
    final auth = AuthService(secure, legacy, true);

    await auth.initialize();
    await auth.saveToken('updated-token');

    expect(auth.token, 'updated-token');
    expect(legacy.token, 'updated-token');
    expect(secure.operations, isEmpty);
  });
}
