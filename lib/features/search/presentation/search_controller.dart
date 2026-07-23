import 'package:flutter/foundation.dart';

import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../../../models/subsite.dart';
import '../data/search_repository.dart';

class SearchState {
  const SearchState({
    this.blogs = const [],
    this.comments = const [],
    this.posts = const [],
    this.query = '',
    this.isLandingLoading = false,
    this.isSearching = false,
    this.failure,
  });
  final List<Subsite> blogs;
  final List<Comment> comments;
  final List<Post> posts;
  final String query;
  final bool isLandingLoading;
  final bool isSearching;
  final AppFailure? failure;
}

class SearchController extends ChangeNotifier {
  SearchController(this._repository);
  final SearchRepository _repository;
  SearchState _state = const SearchState();
  SearchState get state => _state;
  int _generation = 0;

  Future<void> loadLanding() async {
    _emit(
      SearchState(
        blogs: _state.blogs,
        comments: _state.comments,
        posts: _state.posts,
        query: _state.query,
        isLandingLoading: true,
      ),
    );
    final result = await _repository.loadLanding();
    switch (result) {
      case Success<SearchLanding>(:final value):
        _emit(SearchState(blogs: value.blogs, comments: value.comments));
      case Failure<SearchLanding>(:final failure):
        _emit(SearchState(failure: failure));
    }
  }

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return clear();
    final generation = ++_generation;
    _emit(
      SearchState(
        blogs: _state.blogs,
        comments: _state.comments,
        query: query,
        isSearching: true,
      ),
    );
    final result = await _repository.search(query);
    if (generation != _generation) return;
    switch (result) {
      case Success<List<Post>>(:final value):
        _emit(
          SearchState(
            blogs: _state.blogs,
            comments: _state.comments,
            posts: value,
            query: query,
          ),
        );
      case Failure<List<Post>>(:final failure):
        _emit(
          SearchState(
            blogs: _state.blogs,
            comments: _state.comments,
            query: query,
            failure: failure,
          ),
        );
    }
  }

  Future<Result<void>> setSubscription(int subsiteId, {required bool value}) =>
      _repository.setSubscription(subsiteId, value: value);

  void clear() {
    _generation++;
    _emit(SearchState(blogs: _state.blogs, comments: _state.comments));
  }

  void _emit(SearchState value) {
    _state = value;
    notifyListeners();
  }
}
