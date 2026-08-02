import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../../../util/json_safe.dart';
import 'bookmarks_repository.dart';

class DtfBookmarksRepository implements BookmarksRepository {
  const DtfBookmarksRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<BookmarksPage>> load(String type, {int offset = 0}) async {
    final result = await _api.get(
      'bookmarks?type=$type&count=30&offset=$offset',
    );
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    final items = value is List ? value : asList(dig(value, ['items']));
    try {
      if (type == 'posts') {
        return Success(
          BookmarksPage(
            posts: items
                .map((item) => item is Map ? item['data'] ?? item : item)
                .whereType<Map>()
                .map((item) => Post.fromJson(asMap(item)))
                .toList(growable: false),
          ),
        );
      }
      return Success(
        BookmarksPage(
          comments: items
              .map((item) => item is Map ? item['data'] ?? item : item)
              .whereType<Map>()
              .map((item) => Comment.fromJson(asMap(item)))
              .toList(growable: false),
        ),
      );
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }
}
