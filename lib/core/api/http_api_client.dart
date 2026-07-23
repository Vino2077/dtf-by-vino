import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../api/api_config.dart';
import 'api_client.dart';
import 'app_failure.dart';
import 'result.dart';

class HttpApiClient implements ApiClient, UploadApiClient {
  HttpApiClient(
    this._client,
    this._tokenProvider, [
    this._timeout = ApiConfig.timeout,
  ]);

  final http.Client _client;
  final String? Function() _tokenProvider;
  final Duration _timeout;

  @override
  Future<Result<Object?>> get(String path, {String? apiVersion}) => _execute(
    () => _client.get(
      ApiConfig.url(path, version: apiVersion ?? ApiConfig.vDefault),
      headers: _headers(),
    ),
  );

  @override
  Future<Result<Object?>> postForm(
    String path, {
    String? apiVersion,
    Map<String, String> body = const {},
  }) => _execute(
    () => _client.post(
      ApiConfig.url(path, version: apiVersion ?? ApiConfig.vDefault),
      headers: _headers(),
      body: body,
    ),
  );

  @override
  Future<Result<Object?>> postMultipart(
    String path, {
    String? apiVersion,
    Map<String, String> fields = const {},
  }) => _execute(() async {
    final request =
        http.MultipartRequest(
            'POST',
            ApiConfig.url(path, version: apiVersion ?? ApiConfig.vDefault),
          )
          ..headers.addAll(_headers())
          ..fields.addAll(fields);
    return http.Response.fromStream(await _client.send(request));
  });

  @override
  Future<Result<Object?>> uploadFile(
    String path, {
    required String field,
    required String filePath,
    String? apiVersion,
  }) => _execute(() async {
    final request = http.MultipartRequest(
      'POST',
      ApiConfig.url(path, version: apiVersion ?? ApiConfig.vDefault),
    )..headers.addAll(_headers());
    request.files.add(await http.MultipartFile.fromPath(field, filePath));
    return http.Response.fromStream(await _client.send(request));
  });

  @override
  Future<Result<Object?>> postJsonMultipart(
    String path, {
    required String field,
    required String json,
    String? apiVersion,
  }) => _execute(() async {
    final request = http.MultipartRequest(
      'POST',
      ApiConfig.url(path, version: apiVersion ?? ApiConfig.vDefault),
    )..headers.addAll(_headers());
    request.files.add(
      http.MultipartFile.fromString(
        field,
        json,
        contentType: MediaType('application', 'json'),
      ),
    );
    return http.Response.fromStream(await _client.send(request));
  });

  Map<String, String> _headers() {
    final headers = <String, String>{'User-Agent': ApiConfig.userAgent};
    final token = _tokenProvider();
    if (token != null && token.isNotEmpty) {
      headers['X-Device-Token'] = token;
    }
    return headers;
  }

  Future<Result<Object?>> _execute(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const Failure(UnauthorizedFailure());
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Failure(
          ServerFailure(
            statusCode: response.statusCode,
            message: _serverMessage(response),
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || !decoded.containsKey('result')) {
        return const Failure(ParsingFailure());
      }
      return Success(decoded['result']);
    } on TimeoutException {
      return const Failure(TimeoutFailure());
    } on SocketException {
      return const Failure(NetworkFailure());
    } on http.ClientException {
      return const Failure(NetworkFailure());
    } on FormatException {
      return const Failure(ParsingFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  String _serverMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
        final error = decoded['error'];
        if (error is Map) {
          final nestedMessage = error['message'];
          if (nestedMessage is String && nestedMessage.isNotEmpty) {
            return nestedMessage;
          }
        }
      }
    } catch (_) {
      // Fall back to the status code when the error body is not JSON.
    }
    return 'HTTP ${response.statusCode}';
  }

  @override
  void close() => _client.close();
}
