import 'package:flutter/foundation.dart';

import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/post.dart';
import '../../../models/subsite.dart';
import '../data/editor_repository.dart';

class EditorController extends ChangeNotifier {
  EditorController(this._repository);
  final EditorRepository _repository;
  List<Subsite> subsites = const [];
  List<Post> drafts = const [];
  bool isBusy = false;
  AppFailure? failure;

  Future<void> loadSubsites() async {
    final result = await _repository.loadMySubsites();
    switch (result) {
      case Success<List<Subsite>>(:final value):
        subsites = value;
      case Failure<List<Subsite>>(:final failure):
        this.failure = failure;
    }
    notifyListeners();
  }

  Future<void> loadDrafts() async {
    isBusy = true;
    notifyListeners();
    final result = await _repository.loadDrafts();
    switch (result) {
      case Success<List<Post>>(:final value):
        drafts = value;
      case Failure<List<Post>>(:final failure):
        this.failure = failure;
    }
    isBusy = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> extractMedia(String url) =>
      _media(_repository.extractMedia(url));
  Future<Map<String, dynamic>?> uploadMedia(String path) =>
      _media(_repository.uploadMedia(path));

  Future<Map<String, dynamic>?> _media(
    Future<Result<Map<String, dynamic>>> request,
  ) async {
    final result = await request;
    if (result case Success<Map<String, dynamic>>(:final value)) return value;
    failure = (result as Failure<Map<String, dynamic>>).failure;
    notifyListeners();
    return null;
  }

  Future<int?> save({
    required String title,
    required List<Map<String, dynamic>> blocks,
    required int subsiteId,
    required bool publish,
    required bool isNsfw,
  }) async {
    isBusy = true;
    notifyListeners();
    final result = await _repository.save(
      title: title,
      blocks: blocks,
      subsiteId: subsiteId,
      publish: publish,
      isNsfw: isNsfw,
    );
    isBusy = false;
    if (result case Success<int>(:final value)) {
      notifyListeners();
      return value;
    }
    failure = (result as Failure<int>).failure;
    notifyListeners();
    return null;
  }
}
