import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../../../models/subsite.dart';
import '../../../util/json_safe.dart';
import 'search_repository.dart';

class DtfSearchRepository implements SearchRepository {
  const DtfSearchRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<SearchLanding>> loadLanding() async {
    final values = await Future.wait([
      _api.get('discovery/blogs'),
      _api.get('comments/popular'),
    ]);
    if (values[0] case Failure<Object?>(:final failure)) {
      return Failure(failure);
    }
    if (values[1] case Failure<Object?>(:final failure)) {
      return Failure(failure);
    }
    try {
      final blogsValue = (values[0] as Success<Object?>).value;
      final commentsValue = (values[1] as Success<Object?>).value;
      final blogs =
          (blogsValue is List ? blogsValue : asList(dig(blogsValue, ['items'])))
              .whereType<Map>()
              .map((value) => Subsite.fromJson(asMap(value)))
              .toList(growable: false);
      final comments =
          (commentsValue is List
                  ? commentsValue
                  : asList(dig(commentsValue, ['items'])))
              .whereType<Map>()
              .map((value) => Comment.fromJson(asMap(value)))
              .toList(growable: false);
      return Success(SearchLanding(blogs: blogs, comments: comments));
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }

  @override
  Future<Result<List<Post>>> search(String query) async {
    final result = await _api.get(
      'search?query=${Uri.encodeQueryComponent(query)}&section=entries&count=20',
    );
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    try {
      final value = (result as Success<Object?>).value;
      return Success(
        asList(dig(value, ['contents']))
            .map((item) => item is Map ? item['data'] ?? item : item)
            .whereType<Map>()
            .map((item) => Post.fromJson(asMap(item)))
            .toList(growable: false),
      );
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }

  @override
  Future<Result<void>> setSubscription(
    int subsiteId, {
    required bool value,
  }) async {
    final attempts = [
      () => _api.postMultipart(
        'subscribe/toggle',
        fields: {'id': '$subsiteId', 'type': '3', 'action': value ? '1' : '0'},
      ),
      () => _api.postForm(
        'subsite/$subsiteId/${value ? 'subscribe' : 'unsubscribe'}',
      ),
      () => _api.postForm(
        'subscription/${value ? 'subscribe' : 'unsubscribe'}',
        body: {'subsiteId': '$subsiteId'},
      ),
    ];
    Failure<Object?>? lastFailure;
    for (final attempt in attempts) {
      final result = await attempt();
      if (result is Success<Object?>) return const Success(null);
      lastFailure = result as Failure<Object?>;
    }
    return Failure(lastFailure?.failure ?? const UnknownFailure());
  }
}
