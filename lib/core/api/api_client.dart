import 'result.dart';

abstract interface class ApiClient {
  Future<Result<Object?>> get(String path, {String? apiVersion});

  Future<Result<Object?>> postForm(
    String path, {
    String? apiVersion,
    Map<String, String> body = const {},
  });

  Future<Result<Object?>> postMultipart(
    String path, {
    String? apiVersion,
    Map<String, String> fields = const {},
  });

  void close();
}
