import 'dart:async';

import 'package:dtf_app/core/api/app_failure.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/comments/data/comments_repository.dart';
import 'package:dtf_app/features/comments/presentation/comments_controller.dart';
import 'package:dtf_app/models/comment.dart';
import 'package:flutter_test/flutter_test.dart';

Comment comment(int id, {int replyTo = 0}) => Comment.fromJson({
  'id': id,
  'replyTo': replyTo,
  'reactions': {'reactionId': 0, 'counters': <dynamic>[]},
});

class _FakeRepository implements CommentsRepository {
  Result<List<Comment>> loadResult = Success([comment(1)]);
  Result<List<Comment>> threadResult = Success([comment(2, replyTo: 1)]);
  Result<Comment> addResult = Success(comment(3));
  Result<Comment> editResult = Success(comment(1));
  Result<void> reactionResult = const Success(null);
  Result<void> favoriteResult = const Success(null);
  Completer<Result<List<Comment>>>? threadCompleter;
  var threadCalls = 0;

  @override
  Future<Result<List<Comment>>> loadComments(
    int postId, {
    int? lastId,
    String sorting = 'hotness',
    int count = 200,
  }) async => loadResult;

  @override
  Future<Result<List<Comment>>> loadThread(int postId, String threadId) {
    threadCalls++;
    return threadCompleter?.future ?? Future.value(threadResult);
  }

  @override
  Future<Result<Comment>> add({
    required int postId,
    required String text,
    int? replyTo,
    List<Map<String, dynamic>> attachments = const [],
  }) async => addResult;

  @override
  Future<Result<Comment>> edit({
    required int commentId,
    required int postId,
    required String text,
    List<Map<String, dynamic>> attachments = const [],
  }) async => editResult;

  @override
  Future<Result<void>> setFavorite(
    int commentId, {
    required bool value,
  }) async => favoriteResult;

  @override
  Future<Result<void>> setReaction(int commentId, int reactionId) async =>
      reactionResult;
}

void main() {
  late _FakeRepository repository;
  late CommentsController controller;

  setUp(() {
    repository = _FakeRepository();
    controller = CommentsController(repository);
  });
  tearDown(() => controller.dispose());

  test('loads comments and tracks collapse state', () async {
    await controller.load(10);
    controller.toggleCollapse(1);

    expect(controller.state.comments.map((value) => value.id), [1]);
    expect(controller.state.collapsedIds, {1});
  });

  test('deduplicates simultaneous thread loads', () async {
    repository.threadCompleter = Completer();

    final first = controller.loadThread(10, 'thread');
    final second = controller.loadThread(10, 'thread');
    repository.threadCompleter!.complete(repository.threadResult);
    await Future.wait([first, second]);

    expect(repository.threadCalls, 1);
    expect(controller.state.comments.map((value) => value.id), [2]);
  });

  test('rolls optimistic reaction back on failure', () async {
    await controller.load(10);
    repository.reactionResult = const Failure(NetworkFailure());

    await controller.toggleReaction(1, 5);

    expect(controller.state.comments.single.reactions.selectedId, 0);
    expect(controller.state.actionFailure, isA<NetworkFailure>());
  });

  test('adds a comment without reloading the thread', () async {
    await controller.load(10);

    await controller.add(postId: 10, text: 'New');

    expect(controller.state.comments.map((value) => value.id), [1, 3]);
  });
}
