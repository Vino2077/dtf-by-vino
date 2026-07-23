import 'result.dart';

abstract interface class UploadApiClient {
  Future<Result<Object?>> uploadFile(
    String path, {
    required String field,
    required String filePath,
    String? apiVersion,
  });

  Future<Result<Object?>> postJsonMultipart(
    String path, {
    required String field,
    required String json,
    String? apiVersion,
  });
}

abstract interface class ApiClient {
  Future<Result<Object?>> get(String path, {String? apiVersion});

  Future<Result<Object?>> postForm(
    String path, {
    String? apiVersion,
    Map<String, String> body = const {},
  });

  Future<Result<Object?>> postJson(
    String path, {
    String? apiVersion,
    Map<String, Object?> body = const {},
  });

  Future<Result<Object?>> postMultipart(
    String path, {
    String? apiVersion,
    Map<String, String> fields = const {},
  });

  void close();
}
