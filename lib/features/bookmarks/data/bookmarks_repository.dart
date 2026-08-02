import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';

class BookmarksPage {
  const BookmarksPage({this.posts = const [], this.comments = const []});
  final List<Post> posts;
  final List<Comment> comments;
}

abstract interface class BookmarksRepository {
  Future<Result<BookmarksPage>> load(String type, {int offset = 0});
}
