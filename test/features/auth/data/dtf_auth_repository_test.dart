import 'package:dtf_app/core/api/app_failure.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/auth/data/dtf_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'classifies invalid credentials without exposing response data',
    () async {
      final repository = DtfAuthRepository(
        MockClient((request) async {
          return http.Response(
            '{"message":"Invalid login or password","code":104,"data":null}',
            401,
          );
        }),
      );
      addTearDown(repository.close);

      final result = await repository.login('mail@example.com', 'password');

      expect((result as Failure<String>).failure, isA<ServerFailure>());
      expect(result.failure.message, 'Неверная почта или пароль.');
    },
  );

  test('validates a manual device token', () async {
    final token = 'test-${Object().hashCode}';
    final repository = DtfAuthRepository(
      MockClient((request) async {
        expect(request.headers['X-Device-Token'], token);
        return http.Response('{"result":{"id":1}}', 200);
      }),
    );
    addTearDown(repository.close);

    final result = await repository.validateToken(token);

    expect(result.valueOrNull, isTrue);
  });
}
