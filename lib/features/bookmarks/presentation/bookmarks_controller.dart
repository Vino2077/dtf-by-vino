import 'package:flutter/foundation.dart';

import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/comment.dart';
import '../../../models/post.dart';
import '../data/bookmarks_repository.dart';

class BookmarksController extends ChangeNotifier {
  BookmarksController(this._repository, this.type);
  final BookmarksRepository _repository;
  final String type;
  List<Post> posts = const [];
  List<Comment> comments = const [];
  bool isLoading = false;
  AppFailure? failure;

  Future<void> load() async {
    isLoading = true;
    failure = null;
    notifyListeners();
    final result = await _repository.load(type);
    switch (result) {
      case Success<BookmarksPage>(:final value):
        posts = value.posts;
        comments = value.comments;
      case Failure<BookmarksPage>(:final failure):
        this.failure = failure;
    }
    isLoading = false;
    notifyListeners();
  }
}
