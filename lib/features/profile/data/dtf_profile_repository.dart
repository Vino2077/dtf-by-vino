import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../features/feed/models/feed_page.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../../../models/subsite.dart';
import '../../../util/json_safe.dart';
import 'profile_repository.dart';

class DtfProfileRepository implements ProfileRepository {
  const DtfProfileRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<Subsite>> loadMe() async =>
      _subsiteResult(await _api.get('subsite/me'));

  @override
  Future<Result<Subsite>> loadSubsite(int id) async =>
      _subsiteResult(await _api.get('subsite?id=$id'));

  Result<Subsite> _subsiteResult(Result<Object?> result) {
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    final candidate = value is Map && value['subsite'] is Map
        ? value['subsite']
        : value;
    if (candidate is! Map) {
      return const Failure(ParsingFailure('Subsite response is invalid'));
    }
    return Success(Subsite.fromJson(asMap(candidate)));
  }

  @override
  Future<Result<FeedPage>> loadPosts(
    int subsiteId, {
    String sorting = 'new',
    int? lastId,
    String? lastSortingValue,
  }) async {
    final apiSort = sorting == 'popular' ? 'hotness' : 'new';
    var path = 'timeline?subsitesIds=$subsiteId&sorting=$apiSort&count=20';
    if (lastId != null) path += '&lastId=$lastId';
    if (lastSortingValue != null) path += '&lastSortingValue=$lastSortingValue';
    final result = await _api.get(path);
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    try {
      final items = asList(dig(value, ['items']));
      final posts = <Post>[];
      for (final item in items.whereType<Map>()) {
        if (item['type'] == 'news') {
          posts.addAll(
            asList(
              dig(item, ['data', 'news']),
            ).whereType<Map>().map((json) => Post.fromJson(asMap(json))),
          );
        } else if (item['data'] is Map) {
          posts.add(Post.fromJson(asMap(item['data'])));
        }
      }
      final lastId = asInt(dig(value, ['lastId']));
      return Success(
        FeedPage(
          items: posts,
          cursor: lastId == null
              ? null
              : FeedCursor(
                  lastId: lastId,
                  lastSortingValue: digString(value, ['lastSortingValue']),
                ),
        ),
      );
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }

  @override
  Future<Result<List<Comment>>> loadComments(
    int subsiteId, {
    int? lastId,
  }) async {
    var path = 'comments?subsiteId=$subsiteId&sorting=date&count=30';
    if (lastId != null) path += '&lastId=$lastId';
    final result = await _api.get(path);
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    try {
      return Success(
        (value is List ? value : asList(dig(value, ['items'])))
            .whereType<Map>()
            .map((json) => Comment.fromJson(asMap(json)))
            .toList(growable: false),
      );
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }

  @override
  Future<Result<void>> setBadge(String badgeId) async {
    final result = await _api.postMultipart(
      'subscription/changeBadge',
      fields: {'badgeId': badgeId},
    );
    return _void(result);
  }

  @override
  Future<Result<void>> setSubscription(
    int subsiteId, {
    required bool value,
  }) async {
    final result = await _api.postMultipart(
      'subscribe/toggle',
      fields: {'id': '$subsiteId', 'type': '3', 'action': value ? '1' : '0'},
    );
    return _void(result);
  }

  Result<void> _void(Result<Object?> result) => switch (result) {
    Success<Object?>() => const Success(null),
    Failure<Object?>(:final failure) => Failure(failure),
  };
}
