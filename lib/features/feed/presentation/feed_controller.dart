import 'package:flutter/foundation.dart';

import '../../../core/api/result.dart';
import '../../../models/post.dart';
import '../data/feed_repository.dart';
import '../models/feed_page.dart';
import '../models/feed_type.dart';
import 'feed_state.dart';

class FeedController extends ChangeNotifier {
  FeedController(this._repository, this._isLoggedIn, {required this.type});

  final FeedRepository _repository;
  final bool Function() _isLoggedIn;
  final FeedType type;

  FeedState _state = FeedState.initial();
  FeedState get state => _state;

  FeedCursor? _cursor;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    if (_requiresAuthentication()) {
      _cursor = null;
      _emit(
        FeedState.initial().copyWith(
          isInitialLoading: false,
          requiresAuthentication: true,
        ),
      );
      return;
    }

    _cursor = null;
    _emit(FeedState.initial().copyWith(editorialPosts: _state.editorialPosts));
    final results = await _loadFirstPage();
    if (!_isCurrent(generation)) return;

    final main = results.main;
    switch (main) {
      case Failure<FeedPage>(:final failure):
        _emit(
          _state.copyWith(isInitialLoading: false, initialFailure: failure),
        );
      case Success<FeedPage>(:final value):
        _cursor = value.cursor;
        _emit(
          _state.copyWith(
            posts: value.items,
            editorialPosts: results.editorialPosts,
            isInitialLoading: false,
            hasMore: value.hasMore,
            initialFailure: null,
            requiresAuthentication: false,
          ),
        );
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    if (_requiresAuthentication()) {
      await load();
      return;
    }

    _emit(
      _state.copyWith(
        isRefreshing: true,
        isLoadingMore: false,
        paginationFailure: null,
        refreshFailure: null,
      ),
    );
    final results = await _loadFirstPage();
    if (!_isCurrent(generation)) return;

    switch (results.main) {
      case Failure<FeedPage>(:final failure):
        _emit(
          _state.copyWith(
            isRefreshing: false,
            refreshFailure: failure,
            refreshFailureVersion: _state.refreshFailureVersion + 1,
          ),
        );
      case Success<FeedPage>(:final value):
        _cursor = value.cursor;
        _emit(
          _state.copyWith(
            posts: value.items,
            editorialPosts: results.editorialPosts,
            isRefreshing: false,
            hasMore: value.hasMore,
            refreshFailure: null,
          ),
        );
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (_state.isInitialLoading ||
        _state.isRefreshing ||
        _state.isLoadingMore ||
        cursor == null) {
      return;
    }

    final generation = _generation;
    _emit(_state.copyWith(isLoadingMore: true, paginationFailure: null));
    final result = await _repository.loadPage(type: type, cursor: cursor);
    if (!_isCurrent(generation)) return;

    switch (result) {
      case Failure<FeedPage>(:final failure):
        _emit(
          _state.copyWith(isLoadingMore: false, paginationFailure: failure),
        );
      case Success<FeedPage>(:final value):
        _cursor = value.cursor;
        _emit(
          _state.copyWith(
            posts: _mergePosts(_state.posts, value.items),
            isLoadingMore: false,
            hasMore: value.hasMore,
            paginationFailure: null,
          ),
        );
    }
  }

  Future<void> retryInitial() => load();
  Future<void> retryPagination() => loadMore();

  bool _requiresAuthentication() => type == FeedType.personal && !_isLoggedIn();

  Future<_FirstPageResults> _loadFirstPage() async {
    final mainFuture = _repository.loadPage(type: type);
    final editorialFuture = type == FeedType.popular
        ? _repository.loadPage(type: FeedType.editorial)
        : null;
    final main = await mainFuture;
    final editorial = await editorialFuture;
    final editorialPosts = switch (editorial) {
      Success<FeedPage>(:final value) => value.items.take(4).toList(),
      _ => type == FeedType.popular ? _state.editorialPosts : const <Post>[],
    };
    return _FirstPageResults(main: main, editorialPosts: editorialPosts);
  }

  List<Post> _mergePosts(List<Post> current, List<Post> incoming) {
    final ids = current.map((post) => post.id).toSet();
    return [...current, ...incoming.where((post) => ids.add(post.id))];
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _emit(FeedState value) {
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

class _FirstPageResults {
  const _FirstPageResults({required this.main, required this.editorialPosts});

  final Result<FeedPage> main;
  final List<Post> editorialPosts;
}
