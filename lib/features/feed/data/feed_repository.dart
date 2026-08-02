import '../../../core/api/result.dart';
import '../models/feed_page.dart';
import '../models/feed_type.dart';

abstract interface class FeedRepository {
  Future<Result<FeedPage>> loadPage({
    required FeedType type,
    FeedCursor? cursor,
  });
}
