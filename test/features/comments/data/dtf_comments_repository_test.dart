import 'package:dtf_app/core/api/api_client.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/comments/data/dtf_comments_repository.dart';
import 'package:dtf_app/models/comment.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api implements ApiClient {
  Result<Object?> result = const Success({'items': []});
  String? method;
  String? path;
  String? version;
  Map<String, String>? values;

  @override
  Future<Result<Object?>> get(String path, {String? apiVersion}) async {
    method = 'GET';
    this.path = path;
    version = apiVersion;
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
    version = apiVersion;
    values = fields;
    return result;
  }

  @override
  void close() {}
}

void main() {
  late _Api api;
  late DtfCommentsRepository repository;
  setUp(() {
    api = _Api();
    repository = DtfCommentsRepository(api);
  });

  test('loads typed comments from comments API', () async {
    api.result = const Success({
      'items': [
        {'id': 7, 'replyTo': 0},
      ],
    });

    final result = await repository.loadComments(42);

    expect((result as Success<List<Comment>>).value.single.id, 7);
    expect(api.path, contains('contentId=42'));
    expect(api.version, 'v2.10');
  });

  test('sends comment reaction as multipart', () async {
    api.result = const Success(null);

    await repository.setReaction(7, 5);

    expect(api.method, 'MULTIPART');
    expect(api.path, 'comment/7/react');
    expect(api.values, {'type': '5', 'referer': 'comments'});
  });

  test('encodes reply and attachments when adding', () async {
    api.result = const Success({'id': 8});

    await repository.add(
      postId: 42,
      text: 'hello',
      replyTo: 7,
      attachments: [
        {'type': 'image'},
      ],
    );

    expect(api.path, 'comment/add');
    expect(api.values?['reply_to'], '7');
    expect(api.values?['attachments'], '[{"type":"image"}]');
  });
}
