import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/post.dart';
import '../../../services/settings_service.dart';
import '../../../util/json_safe.dart';
import '../models/feed_page.dart';
import '../models/feed_type.dart';
import 'feed_repository.dart';

class DtfFeedRepository implements FeedRepository {
  const DtfFeedRepository(this._apiClient, this._settings);

  final ApiClient _apiClient;
  final SettingsService _settings;

  @override
  Future<Result<FeedPage>> loadPage({
    required FeedType type,
    FeedCursor? cursor,
  }) async {
    final result = await _apiClient.get(_path(type, cursor));
    return switch (result) {
      Failure<Object?>(:final failure) => Failure<FeedPage>(failure),
      Success<Object?>(:final value) => _parsePage(value, type: type),
    };
  }

  String _path(FeedType type, FeedCursor? cursor) {
    final path = switch (type) {
      FeedType.editorial =>
        'search/posts?editorial=true&sorting=date&count=${_settings.batchSize}',
      FeedType.fresh =>
        'feed?pageName=new&count=${_settings.batchSize}&sorting=all',
      FeedType.personal =>
        'feed?pageName=my&count=${_settings.batchSize}&sorting=new',
      FeedType.popular => 'feed?pageName=popular&count=${_settings.batchSize}',
    };
    if (cursor == null) return path;

    final buffer = StringBuffer(path)..write('&lastId=${cursor.lastId}');
    final sortingValue = cursor.lastSortingValue;
    if (sortingValue != null && sortingValue.isNotEmpty) {
      buffer.write(
        '&lastSortingValue=${Uri.encodeQueryComponent(sortingValue)}',
      );
    }
    return buffer.toString();
  }

  Result<FeedPage> _parsePage(Object? value, {required FeedType type}) {
    if (value is! Map) {
      return const Failure(ParsingFailure('Feed response is not an object'));
    }
    final result = asMap(value);
    final rawItems = result['items'];
    if (rawItems is! List) {
      return const Failure(ParsingFailure('Feed items are missing'));
    }

    final posts = <Post>[];
    for (final item in rawItems) {
      if (item is! Map) continue;
      final map = asMap(item);
      if (map['type'] == 'news') {
        if (type == FeedType.editorial) {
          _appendPosts(posts, asList(dig(map, ['data', 'news'])));
        }
        continue;
      }
      _appendPost(posts, map['data']);
    }

    final filtered = posts
        .where((post) => !_settings.isFiltered(post))
        .toList(growable: false);
    final lastId = asInt(result['lastId']);
    final sortingValue = result['lastSortingValue']?.toString();

    return Success(
      FeedPage(
        items: filtered,
        cursor: lastId == null
            ? null
            : FeedCursor(lastId: lastId, lastSortingValue: sortingValue),
      ),
    );
  }

  void _appendPosts(List<Post> posts, Iterable<dynamic> values) {
    for (final value in values) {
      _appendPost(posts, value);
    }
  }

  void _appendPost(List<Post> posts, dynamic value) {
    if (value is! Map) return;
    try {
      posts.add(Post.fromJson(asMap(value)));
    } on FormatException {
      // A single malformed timeline item must not hide the remaining page.
    }
  }
}
