import '../../../core/api/result.dart';
import '../../../features/feed/models/feed_page.dart';
import '../../../models/comment.dart';
import '../../../models/subsite.dart';

abstract interface class ProfileRepository {
  Future<Result<Subsite>> loadMe();
  Future<Result<Subsite>> loadSubsite(int id);
  Future<Result<FeedPage>> loadPosts(
    int subsiteId, {
    String sorting = 'new',
    int? lastId,
    String? lastSortingValue,
  });
  Future<Result<List<Comment>>> loadComments(int subsiteId, {int? lastId});
  Future<Result<void>> setSubscription(int subsiteId, {required bool value});
  Future<Result<void>> setBadge(String badgeId);
}
