import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../api/api_config.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import 'auth_repository.dart';

class DtfAuthRepository implements AuthRepository {
  const DtfAuthRepository(this._client);
  final http.Client _client;

  @override
  Future<Result<String>> login(String email, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('https://api.dtf.ru/v3.0/auth/email/login'),
            headers: {
              'User-Agent': ApiConfig.userAgent,
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
            },
            body: {'email': email, 'password': password},
          )
          .timeout(ApiConfig.timeout);
      final body = jsonDecode(response.body);
      if (body is! Map) return const Failure(ParsingFailure());
      final data = body['data'];
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null) {
        return Failure(
          ServerFailure(
            statusCode: response.statusCode,
            message: _friendlyError(
              body['message']?.toString() ?? 'Не удалось войти',
            ),
          ),
        );
      }
      final candidates = _tokenCandidates(data).take(3).toList();
      for (var index = 0; index < candidates.length; index++) {
        if (index > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        final validation = await validateToken(candidates[index].value);
        if (validation.valueOrNull == true) {
          return Success(candidates[index].value);
        }
      }
      return const Failure(ParsingFailure('Сервер не вернул рабочий токен'));
    } on TimeoutException {
      return const Failure(TimeoutFailure());
    } on http.ClientException {
      return const Failure(NetworkFailure());
    } on FormatException {
      return const Failure(ParsingFailure());
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }

  @override
  Future<Result<bool>> validateToken(String token) async {
    try {
      final response = await _client
          .get(
            ApiConfig.url('subsite/me'),
            headers: {
              'User-Agent': ApiConfig.userAgent,
              'X-Device-Token': token,
            },
          )
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const Success(false);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Failure(
          ServerFailure(
            statusCode: response.statusCode,
            message: 'HTTP ${response.statusCode}',
          ),
        );
      }
      final body = jsonDecode(response.body);
      return Success(body is Map && body['result'] != null);
    } on TimeoutException {
      return const Failure(TimeoutFailure());
    } on http.ClientException {
      return const Failure(NetworkFailure());
    } on FormatException {
      return const Failure(ParsingFailure());
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }

  List<MapEntry<String, String>> _tokenCandidates(Object? data) {
    const preferred = [
      'accessToken',
      'access_token',
      'deviceToken',
      'device_token',
      'xDeviceToken',
      'x_device_token',
      'token',
      'authToken',
      'sessionToken',
    ];
    final found = <String, String>{};
    void scan(Object? node, String prefix) {
      if (node is! Map) return;
      for (final entry in node.entries) {
        final key = '$prefix${entry.key}';
        final value = entry.value;
        if (value is String && value.length >= 16) {
          found[key] = value;
        } else if (value is Map) {
          scan(value, '$key.');
        }
      }
    }

    scan(data, '');
    int priority(String key) {
      final leaf = key.split('.').last;
      final index = preferred.indexOf(leaf);
      return index < 0 ? preferred.length : index;
    }

    return found.entries.toList()
      ..sort((a, b) => priority(a.key).compareTo(priority(b.key)));
  }

  @override
  void close() => _client.close();

  String _friendlyError(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('too many')) {
      return 'Слишком много попыток входа. Попробуй позже.';
    }
    if (lower.contains('invalid login or password') ||
        lower.contains('invalid credentials')) {
      return 'Неверная почта или пароль.';
    }
    return value;
  }
}
