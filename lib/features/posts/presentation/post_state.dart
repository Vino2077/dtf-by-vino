import '../../../core/api/app_failure.dart';
import '../../../models/post.dart';

const _notProvided = Object();

class PostState {
  const PostState({
    this.post,
    this.isLoading = false,
    this.loadFailure,
    this.actionFailure,
    this.actionFailureVersion = 0,
  });

  final Post? post;
  final bool isLoading;
  final AppFailure? loadFailure;
  final AppFailure? actionFailure;
  final int actionFailureVersion;

  PostState copyWith({
    Object? post = _notProvided,
    bool? isLoading,
    Object? loadFailure = _notProvided,
    Object? actionFailure = _notProvided,
    int? actionFailureVersion,
  }) => PostState(
    post: identical(post, _notProvided) ? this.post : post as Post?,
    isLoading: isLoading ?? this.isLoading,
    loadFailure: identical(loadFailure, _notProvided)
        ? this.loadFailure
        : loadFailure as AppFailure?,
    actionFailure: identical(actionFailure, _notProvided)
        ? this.actionFailure
        : actionFailure as AppFailure?,
    actionFailureVersion: actionFailureVersion ?? this.actionFailureVersion,
  );
}
