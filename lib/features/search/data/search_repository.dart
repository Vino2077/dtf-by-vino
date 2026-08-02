import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../../../models/subsite.dart';

class SearchLanding {
  const SearchLanding({required this.blogs, required this.comments});
  final List<Subsite> blogs;
  final List<Comment> comments;
}

abstract interface class SearchRepository {
  Future<Result<SearchLanding>> loadLanding();
  Future<Result<List<Post>>> search(String query);
  Future<Result<void>> setSubscription(int subsiteId, {required bool value});
}
