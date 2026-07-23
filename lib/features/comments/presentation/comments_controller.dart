import 'package:flutter/foundation.dart';

import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../data/comments_repository.dart';
import 'comments_state.dart';

class CommentsController extends ChangeNotifier {
  CommentsController(this._repository);

  final CommentsRepository _repository;
  CommentsState _state = CommentsState();
  CommentsState get state => _state;

  int _loadGeneration = 0;
  final Map<int, int> _actionGenerations = {};
  bool _disposed = false;

  Future<void> load(
    int postId, {
    String sorting = 'hotness',
    int count = 200,
  }) async {
    final generation = ++_loadGeneration;
    _emit(_state.copyWith(isLoading: true, loadFailure: null));
    final result = await _repository.loadComments(
      postId,
      sorting: sorting,
      count: count,
    );
    if (_disposed || generation != _loadGeneration) return;
    switch (result) {
      case Success<List<Comment>>(:final value):
        _emit(
          _state.copyWith(comments: value, isLoading: false, loadFailure: null),
        );
      case Failure<List<Comment>>(:final failure):
        _emit(_state.copyWith(isLoading: false, loadFailure: failure));
    }
  }

  Future<Comment?> loadTopComment(int postId) async {
    final result = await _repository.loadTopComment(postId);
    if (result case Success<Comment?>(:final value)) return value;
    _actionFailed((result as Failure<Comment?>).failure);
    return null;
  }

  Future<List<Map<String, dynamic>>> loadReactionUsers({
    required int id,
    required bool isComment,
    int? reactionId,
  }) async {
    final result = await _repository.loadReactionUsers(
      id: id,
      isComment: isComment,
      reactionId: reactionId,
    );
    if (result case Success<List<Map<String, dynamic>>>(:final value)) {
      return value;
    }
    _actionFailed((result as Failure<List<Map<String, dynamic>>>).failure);
    return const [];
  }

  Future<void> loadThread(int postId, String threadId) async {
    if (_state.loadingThreadIds.contains(threadId)) return;
    _emit(
      _state.copyWith(
        loadingThreadIds: {..._state.loadingThreadIds, threadId},
        actionFailure: null,
      ),
    );
    final result = await _repository.loadThread(postId, threadId);
    if (_disposed) return;
    final loading = {..._state.loadingThreadIds}..remove(threadId);
    switch (result) {
      case Success<List<Comment>>(:final value):
        _emit(
          _state.copyWith(
            comments: _merge(_state.comments, value),
            loadingThreadIds: loading,
          ),
        );
      case Failure<List<Comment>>(:final failure):
        _actionFailed(failure, loadingThreadIds: loading);
    }
  }

  void toggleCollapse(int commentId) {
    final collapsed = {..._state.collapsedIds};
    collapsed.contains(commentId)
        ? collapsed.remove(commentId)
        : collapsed.add(commentId);
    _emit(_state.copyWith(collapsedIds: collapsed));
  }

  Future<Comment?> add({
    required int postId,
    required String text,
    int? replyTo,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    _emit(_state.copyWith(isSubmitting: true, actionFailure: null));
    final result = await _repository.add(
      postId: postId,
      text: text,
      replyTo: replyTo,
      attachments: attachments,
    );
    if (_disposed) return null;
    switch (result) {
      case Success<Comment>(:final value):
        _emit(
          _state.copyWith(
            comments: _merge(_state.comments, [value]),
            isSubmitting: false,
          ),
        );
        return value;
      case Failure<Comment>(:final failure):
        _actionFailed(failure, isSubmitting: false);
        return null;
    }
  }

  Future<void> edit({
    required int postId,
    required int commentId,
    required String text,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    _emit(_state.copyWith(isSubmitting: true, actionFailure: null));
    final result = await _repository.edit(
      commentId: commentId,
      postId: postId,
      text: text,
      attachments: attachments,
    );
    if (_disposed) return;
    switch (result) {
      case Success<Comment>(:final value):
        _replace(value);
        _emit(_state.copyWith(isSubmitting: false));
      case Failure<Comment>(:final failure):
        _actionFailed(failure, isSubmitting: false);
    }
  }

  Future<void> toggleReaction(int commentId, int reactionId) async {
    final previous = _find(commentId);
    if (previous == null) return;
    final generation = (_actionGenerations[commentId] ?? 0) + 1;
    _actionGenerations[commentId] = generation;
    _replace(
      previous.copyWith(reactions: previous.reactions.toggle(reactionId)),
    );
    final result = await _repository.setReaction(commentId, reactionId);
    if (_disposed || _actionGenerations[commentId] != generation) return;
    if (result case Failure<void>(:final failure)) {
      _replace(previous);
      _actionFailed(failure);
    }
  }

  Future<void> toggleFavorite(int commentId) async {
    final previous = _find(commentId);
    if (previous == null) return;
    final generation = (_actionGenerations[commentId] ?? 0) + 1;
    _actionGenerations[commentId] = generation;
    final updated = previous.copyWith(isFavorited: !previous.isFavorited);
    _replace(updated);
    final result = await _repository.setFavorite(
      commentId,
      value: updated.isFavorited,
    );
    if (_disposed || _actionGenerations[commentId] != generation) return;
    if (result case Failure<void>(:final failure)) {
      _replace(previous);
      _actionFailed(failure);
    }
  }

  void replaceAll(List<Comment> comments) =>
      _emit(_state.copyWith(comments: comments));

  Comment? _find(int id) {
    for (final comment in _state.comments) {
      if (comment.id == id) return comment;
    }
    return null;
  }

  void _replace(Comment comment) {
    _emit(
      _state.copyWith(
        comments: [
          for (final value in _state.comments)
            if (value.id == comment.id) comment else value,
        ],
      ),
    );
  }

  List<Comment> _merge(List<Comment> current, List<Comment> incoming) {
    final values = <int, Comment>{for (final value in current) value.id: value};
    for (final value in incoming) {
      values[value.id] = value;
    }
    return values.values.toList(growable: false);
  }

  void _actionFailed(
    AppFailure failure, {
    Set<String>? loadingThreadIds,
    bool? isSubmitting,
  }) {
    _emit(
      _state.copyWith(
        loadingThreadIds: loadingThreadIds,
        isSubmitting: isSubmitting,
        actionFailure: failure,
        actionFailureVersion: _state.actionFailureVersion + 1,
      ),
    );
  }

  void _emit(CommentsState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
