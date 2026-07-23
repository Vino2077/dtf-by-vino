import 'package:dtf_app/core/api/api_client.dart';
import 'package:dtf_app/core/api/app_failure.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/posts/data/dtf_post_repository.dart';
import 'package:dtf_app/models/post.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient implements ApiClient {
  Result<Object?> result = const Success<Object?>(null);
  String? method;
  String? path;
  String? apiVersion;
  Map<String, String>? values;

  @override
  Future<Result<Object?>> get(String path, {String? apiVersion}) async {
    method = 'GET';
    this.path = path;
    this.apiVersion = apiVersion;
    return result;
  }

  @override
  Future<Result<Object?>> postForm(
    String path, {
    String? apiVersion,
    Map<String, String> body = const {},
  }) async {
    method = 'FORM';
    this.path = path;
    this.apiVersion = apiVersion;
    values = body;
    return result;
  }

  @override
  Future<Result<Object?>> postMultipart(
    String path, {
    String? apiVersion,
    Map<String, String> fields = const {},
  }) async {
    method = 'MULTIPART';
    this.path = path;
    this.apiVersion = apiVersion;
    values = fields;
    return result;
  }

  @override
  void close() {}
}

void main() {
  late _FakeApiClient apiClient;
  late DtfPostRepository repository;

  setUp(() {
    apiClient = _FakeApiClient();
    repository = DtfPostRepository(apiClient);
  });

  test('loads and parses a post', () async {
    apiClient.result = const Success<Object?>({'id': 42, 'title': 'Post'});

    final result = await repository.load(42);

    expect((result as Success<Post>).value.id, 42);
    expect(apiClient.path, 'content?id=42');
  });

  test('returns parsing failure for malformed post', () async {
    apiClient.result = const Success<Object?>({'title': 'No id'});

    final result = await repository.load(42);

    expect((result as Failure<Post>).failure, isA<ParsingFailure>());
  });

  test('uses favorite form endpoint', () async {
    apiClient.result = const Success<Object?>(null);

    final result = await repository.setFavorite(42, value: true);

    expect(result, isA<Success<void>>());
    expect(apiClient.method, 'FORM');
    expect(apiClient.path, 'favorite');
    expect(apiClient.values, {'id': '42', 'type': '1'});
  });

  test('uses comments API multipart endpoint for reactions', () async {
    apiClient.result = const Success<Object?>(null);

    await repository.setReaction(42, 5);

    expect(apiClient.method, 'MULTIPART');
    expect(apiClient.path, 'content/42/react');
    expect(apiClient.apiVersion, 'v2.10');
    expect(apiClient.values, {'type': '5', 'referer': 'feed'});
  });
}
