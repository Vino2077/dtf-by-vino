import '../../../core/api/result.dart';
import '../../../models/comment.dart';

abstract interface class CommentsRepository {
  Future<Result<List<Comment>>> loadComments(
    int postId, {
    int? lastId,
    String sorting = 'hotness',
    int count = 200,
  });

  Future<Result<List<Comment>>> loadThread(int postId, String threadId);

  Future<Result<Comment?>> loadTopComment(int postId);

  Future<Result<List<Map<String, dynamic>>>> loadReactionUsers({
    required int id,
    required bool isComment,
    int? reactionId,
  });

  Future<Result<Comment>> add({
    required int postId,
    required String text,
    int? replyTo,
    List<Map<String, dynamic>> attachments = const [],
  });

  Future<Result<Comment>> edit({
    required int commentId,
    required int postId,
    required String text,
    List<Map<String, dynamic>> attachments = const [],
  });

  Future<Result<void>> setReaction(int commentId, int reactionId);

  Future<Result<void>> setFavorite(int commentId, {required bool value});
}
