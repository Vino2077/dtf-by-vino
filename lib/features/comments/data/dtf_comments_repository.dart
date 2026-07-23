import 'dart:convert';

import '../../../api/api_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../../../util/json_safe.dart';
import 'comments_repository.dart';

class DtfCommentsRepository implements CommentsRepository {
  const DtfCommentsRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<List<Comment>>> loadComments(
    int postId, {
    int? lastId,
    String sorting = 'hotness',
    int count = 200,
  }) async {
    final firstLoad = lastId == null ? '&firstLoad=true' : '';
    final cursor = lastId == null ? '' : '&lastId=$lastId';
    final result = await _apiClient.get(
      'comments?contentId=$postId&sorting=$sorting&count=$count'
      '$firstLoad$cursor',
      apiVersion: ApiConfig.vComments,
    );
    return _commentsResult(result);
  }

  @override
  Future<Result<List<Comment>>> loadThread(int postId, String threadId) async {
    final result = await _apiClient.get(
      'comments?contentId=$postId&threadId=${Uri.encodeQueryComponent(threadId)}',
      apiVersion: ApiConfig.vComments,
    );
    return _commentsResult(result);
  }

  Result<List<Comment>> _commentsResult(Result<Object?> result) {
    switch (result) {
      case Failure<Object?>(:final failure):
        return Failure(failure);
      case Success<Object?>(:final value):
        final values = value is List ? value : asList(dig(value, ['items']));
        try {
          return Success(
            values
                .whereType<Map>()
                .map((item) => Comment.fromJson(asMap(item)))
                .toList(growable: false),
          );
        } on FormatException catch (error) {
          return Failure(ParsingFailure(error.message));
        }
    }
  }

  @override
  Future<Result<Comment>> add({
    required int postId,
    required String text,
    int? replyTo,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final fields = <String, String>{'id': '$postId', 'text': text};
    if (replyTo != null && replyTo > 0) fields['reply_to'] = '$replyTo';
    if (attachments.isNotEmpty) {
      fields['attachments'] = jsonEncode(attachments);
    }
    return _commentResult(
      await _apiClient.postMultipart('comment/add', fields: fields),
    );
  }

  @override
  Future<Result<Comment>> edit({
    required int commentId,
    required int postId,
    required String text,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final fields = <String, String>{
      'comment_id': '$commentId',
      'entry_id': '$postId',
      'text': text,
    };
    if (attachments.isNotEmpty) {
      fields['attachments'] = jsonEncode(attachments);
    }
    return _commentResult(
      await _apiClient.postMultipart('comment/edit', fields: fields),
    );
  }

  Result<Comment> _commentResult(Result<Object?> result) {
    switch (result) {
      case Failure<Object?>(:final failure):
        return Failure(failure);
      case Success<Object?>(:final value):
        final candidate = value is Map && value['comment'] is Map
            ? value['comment']
            : value;
        if (candidate is! Map) {
          return const Failure(ParsingFailure('Comment response is invalid'));
        }
        try {
          return Success(Comment.fromJson(asMap(candidate)));
        } on FormatException catch (error) {
          return Failure(ParsingFailure(error.message));
        }
    }
  }

  @override
  Future<Result<void>> setReaction(int commentId, int reactionId) async {
    final result = await _apiClient.postMultipart(
      'comment/$commentId/react',
      apiVersion: ApiConfig.vComments,
      fields: {'type': '$reactionId', 'referer': 'comments'},
    );
    return _voidResult(result);
  }

  @override
  Future<Result<void>> setFavorite(int commentId, {required bool value}) async {
    final result = await _apiClient.postForm(
      value ? 'favorite' : 'unfavorite',
      body: {'id': '$commentId', 'type': '2'},
    );
    return _voidResult(result);
  }

  Result<void> _voidResult(Result<Object?> result) => switch (result) {
    Failure<Object?>(:final failure) => Failure(failure),
    Success<Object?>() => const Success(null),
  };
}
