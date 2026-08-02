import '../../../core/api/result.dart';
import '../../../models/post.dart';

abstract interface class PostRepository {
  Future<Result<Post>> load(int postId);

  Future<Result<void>> setFavorite(int postId, {required bool value});

  Future<Result<void>> setReaction(int postId, int reactionId);
}
