import 'dart:collection';

import '../../../core/api/app_failure.dart';
import '../../../models/post.dart';

const _notProvided = Object();

class FeedState {
  FeedState({
    required List<Post> posts,
    required List<Post> editorialPosts,
    required this.isInitialLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.hasMore,
    required this.requiresAuthentication,
    required this.refreshFailureVersion,
    this.initialFailure,
    this.paginationFailure,
    this.refreshFailure,
  }) : posts = UnmodifiableListView(List<Post>.from(posts)),
       editorialPosts = UnmodifiableListView(List<Post>.from(editorialPosts));

  factory FeedState.initial() => FeedState(
    posts: const [],
    editorialPosts: const [],
    isInitialLoading: true,
    isRefreshing: false,
    isLoadingMore: false,
    hasMore: false,
    requiresAuthentication: false,
    refreshFailureVersion: 0,
  );

  final List<Post> posts;
  final List<Post> editorialPosts;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final bool requiresAuthentication;
  final AppFailure? initialFailure;
  final AppFailure? paginationFailure;
  final AppFailure? refreshFailure;
  final int refreshFailureVersion;

  FeedState copyWith({
    List<Post>? posts,
    List<Post>? editorialPosts,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    bool? requiresAuthentication,
    Object? initialFailure = _notProvided,
    Object? paginationFailure = _notProvided,
    Object? refreshFailure = _notProvided,
    int? refreshFailureVersion,
  }) => FeedState(
    posts: posts ?? this.posts,
    editorialPosts: editorialPosts ?? this.editorialPosts,
    isInitialLoading: isInitialLoading ?? this.isInitialLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    requiresAuthentication:
        requiresAuthentication ?? this.requiresAuthentication,
    initialFailure: identical(initialFailure, _notProvided)
        ? this.initialFailure
        : initialFailure as AppFailure?,
    paginationFailure: identical(paginationFailure, _notProvided)
        ? this.paginationFailure
        : paginationFailure as AppFailure?,
    refreshFailure: identical(refreshFailure, _notProvided)
        ? this.refreshFailure
        : refreshFailure as AppFailure?,
    refreshFailureVersion: refreshFailureVersion ?? this.refreshFailureVersion,
  );
}
