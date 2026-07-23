import 'dart:convert';

import '../../../api/api_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/post.dart';
import '../../../models/subsite.dart';
import '../../../util/json_safe.dart';
import 'editor_repository.dart';

class DtfEditorRepository implements EditorRepository {
  const DtfEditorRepository(this._api, this._uploads);
  final ApiClient _api;
  final UploadApiClient _uploads;

  @override
  Future<Result<Map<String, dynamic>>> extractMedia(String url) async {
    final result = await _api.postForm('uploader/extract', body: {'url': url});
    return _media(result);
  }

  @override
  Future<Result<Map<String, dynamic>>> uploadMedia(String filePath) async =>
      _media(
        await _uploads.uploadFile(
          'uploader/upload',
          field: 'file',
          filePath: filePath,
        ),
      );

  Result<Map<String, dynamic>> _media(Result<Object?> result) {
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    final candidate = value is List && value.isNotEmpty ? value.first : value;
    if (candidate is! Map || candidate['type'] == 'error') {
      return const Failure(ParsingFailure('Media response is invalid'));
    }
    return Success(asMap(candidate));
  }

  @override
  Future<Result<List<Subsite>>> loadMySubsites() async {
    final values = await Future.wait([
      _api.get('subsite/me'),
      _api.get('subsite/me/blogs'),
    ]);
    if (values[0] case Failure<Object?>(:final failure)) {
      return Failure(failure);
    }
    if (values[1] case Failure<Object?>(:final failure)) {
      return Failure(failure);
    }
    final ownValue = (values[0] as Success<Object?>).value;
    final own = ownValue is Map && ownValue['subsite'] is Map
        ? ownValue['subsite']
        : ownValue;
    final extraValue = (values[1] as Success<Object?>).value;
    final extra = extraValue is List
        ? extraValue
        : asList(dig(extraValue, ['items']));
    final result = <Subsite>[];
    if (own is Map) result.add(Subsite.fromJson(asMap(own)));
    result.addAll(
      extra
          .whereType<Map>()
          .map((value) => Subsite.fromJson(asMap(value)))
          .where((value) => result.isEmpty || value.id != result.first.id),
    );
    return Success(result);
  }

  @override
  Future<Result<List<Post>>> loadDrafts() async {
    final result = await _api.get(
      'new/posts/drafts?offset=0&limit=30&markdown=false',
    );
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    try {
      final posts = <Post>[];
      for (final item in asList(dig(value, ['items'])).whereType<Map>()) {
        if (item['data'] is Map) posts.add(Post.fromJson(asMap(item['data'])));
      }
      return Success(posts);
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }

  @override
  Future<Result<int>> save({
    required String title,
    required List<Map<String, dynamic>> blocks,
    required int subsiteId,
    required bool publish,
    required bool isNsfw,
  }) async {
    final payload = {
      'id': 0,
      'title': title,
      'user_id': 0,
      'subsite_id': subsiteId,
      'is_adult': false,
      if (isNsfw) 'is_nsfw': true,
      'entry': {
        'blocks': blocks
            .map((block) => {'hidden': false, 'anchor': '', ...block})
            .toList(),
      },
    };
    final result = await _uploads.postJsonMultipart(
      'editor',
      apiVersion: ApiConfig.vEditor,
      field: 'entry',
      json: jsonEncode(payload),
    );
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    final id = asInt(
      dig(value, ['entry', 'id']) ??
          dig(value, ['post', 'id']) ??
          (value is Map ? value['id'] : null),
    );
    if (id == null) return const Failure(ParsingFailure('Draft id is missing'));
    if (!publish) return Success(id);
    final publication = await _api.postForm(
      'editor/$id/publish',
      apiVersion: ApiConfig.vEditor,
    );
    return switch (publication) {
      Success<Object?>() => Success(id),
      Failure<Object?>(:final failure) => Failure(failure),
    };
  }
}
