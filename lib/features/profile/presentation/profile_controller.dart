import 'package:flutter/foundation.dart';

import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../../../models/subsite.dart';
import '../data/profile_repository.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._repository, {this.subsiteId});
  final ProfileRepository _repository;
  final int? subsiteId;

  Subsite? subsite;
  List<Post> posts = const [];
  List<Comment> comments = const [];
  bool isLoading = false;
  bool isLoadingMore = false;
  AppFailure? failure;
  int? _lastId;
  String? _lastSortingValue;
  String sorting = 'new';
  bool _hasMore = true;

  Future<void> load() async {
    isLoading = true;
    failure = null;
    notifyListeners();
    final result = subsiteId == null
        ? await _repository.loadMe()
        : await _repository.loadSubsite(subsiteId!);
    switch (result) {
      case Success<Subsite>(:final value):
        subsite = value;
      case Failure<Subsite>(:final failure):
        this.failure = failure;
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadPosts({bool refresh = false}) async {
    final id = subsiteId ?? subsite?.id;
    if (id == null || isLoadingMore || (!refresh && !_hasMore)) return;
    if (refresh) {
      _lastId = null;
      _lastSortingValue = null;
      _hasMore = true;
    }
    isLoadingMore = true;
    notifyListeners();
    final result = await _repository.loadPosts(
      id,
      sorting: sorting,
      lastId: refresh ? null : _lastId,
      lastSortingValue: refresh ? null : _lastSortingValue,
    );
    switch (result) {
      case Success(:final value):
        posts = refresh ? value.items : _mergePosts(posts, value.items);
        _lastId = value.cursor?.lastId;
        _lastSortingValue = value.cursor?.lastSortingValue;
        _hasMore = value.hasMore;
      case Failure(:final failure):
        this.failure = failure;
    }
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadComments() async {
    final id = subsiteId ?? subsite?.id;
    if (id == null) return;
    final result = await _repository.loadComments(id);
    switch (result) {
      case Success<List<Comment>>(:final value):
        comments = value;
      case Failure<List<Comment>>(:final failure):
        this.failure = failure;
    }
    notifyListeners();
  }

  void clear() {
    subsite = null;
    posts = const [];
    comments = const [];
    notifyListeners();
  }

  Future<Result<void>> setSubscription(bool value) {
    final id = subsiteId ?? subsite?.id;
    if (id == null) {
      return Future.value(
        const Failure(ParsingFailure('Subsite id is missing')),
      );
    }
    return _repository.setSubscription(id, value: value);
  }

  Future<Result<void>> setBadge(String badgeId) =>
      _repository.setBadge(badgeId);

  List<Post> _mergePosts(List<Post> current, List<Post> incoming) {
    final values = <int, Post>{for (final post in current) post.id: post};
    for (final post in incoming) {
      values[post.id] = post;
    }
    return values.values.toList(growable: false);
  }
}
