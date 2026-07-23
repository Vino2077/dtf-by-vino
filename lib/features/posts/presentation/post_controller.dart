import 'package:flutter/foundation.dart';

import '../../../core/api/result.dart';
import '../../../models/post.dart';
import '../data/post_repository.dart';
import 'post_state.dart';

class PostController extends ChangeNotifier {
  PostController(this._repository, {Post? initialPost})
    : _state = PostState(post: initialPost, isLoading: initialPost == null);

  final PostRepository _repository;
  PostState _state;
  PostState get state => _state;

  int _generation = 0;
  bool _disposed = false;

  void replacePost(Post post) {
    _emit(_state.copyWith(post: post));
  }

  Future<void> load(int postId) async {
    final generation = ++_generation;
    _emit(_state.copyWith(isLoading: true, loadFailure: null));
    final result = await _repository.load(postId);
    if (_disposed || generation != _generation) return;

    switch (result) {
      case Success<Post>(:final value):
        _emit(
          _state.copyWith(post: value, isLoading: false, loadFailure: null),
        );
      case Failure<Post>(:final failure):
        _emit(_state.copyWith(isLoading: false, loadFailure: failure));
    }
  }

  Future<void> toggleFavorite() async {
    final post = _state.post;
    if (post == null) return;
    final updated = post.copyWith(isFavorited: !post.isFavorited);
    _emit(_state.copyWith(post: updated, actionFailure: null));

    final result = await _repository.setFavorite(
      post.id,
      value: updated.isFavorited,
    );
    if (_disposed) return;
    if (result case Failure<void>(:final failure)) {
      _emit(
        _state.copyWith(
          post: post,
          actionFailure: failure,
          actionFailureVersion: _state.actionFailureVersion + 1,
        ),
      );
    }
  }

  Future<void> toggleReaction(int reactionId) async {
    final post = _state.post;
    if (post == null) return;
    final reactions = post.reactions.toggle(reactionId);
    _emit(
      _state.copyWith(
        post: post.copyWith(reactions: reactions),
        actionFailure: null,
      ),
    );

    final result = await _repository.setReaction(post.id, reactionId);
    if (_disposed) return;
    if (result case Failure<void>(:final failure)) {
      _emit(
        _state.copyWith(
          post: post,
          actionFailure: failure,
          actionFailureVersion: _state.actionFailureVersion + 1,
        ),
      );
    }
  }

  void _emit(PostState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
