import 'dart:collection';

import '../../../core/api/app_failure.dart';
import '../../../models/comment.dart';

const _unset = Object();

class CommentsState {
  CommentsState({
    List<Comment> comments = const [],
    Set<int> collapsedIds = const {},
    Set<String> loadingThreadIds = const {},
    this.isLoading = false,
    this.isSubmitting = false,
    this.loadFailure,
    this.actionFailure,
    this.actionFailureVersion = 0,
  }) : comments = UnmodifiableListView(List.of(comments)),
       collapsedIds = UnmodifiableSetView(Set.of(collapsedIds)),
       loadingThreadIds = UnmodifiableSetView(Set.of(loadingThreadIds));

  final List<Comment> comments;
  final Set<int> collapsedIds;
  final Set<String> loadingThreadIds;
  final bool isLoading;
  final bool isSubmitting;
  final AppFailure? loadFailure;
  final AppFailure? actionFailure;
  final int actionFailureVersion;

  CommentsState copyWith({
    List<Comment>? comments,
    Set<int>? collapsedIds,
    Set<String>? loadingThreadIds,
    bool? isLoading,
    bool? isSubmitting,
    Object? loadFailure = _unset,
    Object? actionFailure = _unset,
    int? actionFailureVersion,
  }) => CommentsState(
    comments: comments ?? this.comments,
    collapsedIds: collapsedIds ?? this.collapsedIds,
    loadingThreadIds: loadingThreadIds ?? this.loadingThreadIds,
    isLoading: isLoading ?? this.isLoading,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    loadFailure: identical(loadFailure, _unset)
        ? this.loadFailure
        : loadFailure as AppFailure?,
    actionFailure: identical(actionFailure, _unset)
        ? this.actionFailure
        : actionFailure as AppFailure?,
    actionFailureVersion: actionFailureVersion ?? this.actionFailureVersion,
  );
}
