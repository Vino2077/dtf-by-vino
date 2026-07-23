import 'package:dtf_app/core/api/app_failure.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/posts/data/post_repository.dart';
import 'package:dtf_app/features/posts/presentation/post_controller.dart';
import 'package:dtf_app/models/post.dart';
import 'package:flutter_test/flutter_test.dart';

Post post({bool favorite = false}) => Post.fromJson({
  'id': 1,
  'title': 'Post',
  'isFavorited': favorite,
  'reactions': {'reactionId': 0, 'counters': <dynamic>[]},
});

class _FakePostRepository implements PostRepository {
  Result<Post> loadResult = Success(post());
  Result<void> favoriteResult = const Success<void>(null);
  Result<void> reactionResult = const Success<void>(null);

  @override
  Future<Result<Post>> load(int postId) async => loadResult;

  @override
  Future<Result<void>> setFavorite(int postId, {required bool value}) async =>
      favoriteResult;

  @override
  Future<Result<void>> setReaction(int postId, int reactionId) async =>
      reactionResult;
}

void main() {
  late _FakePostRepository repository;

  setUp(() => repository = _FakePostRepository());

  test('loads a post into state', () async {
    final controller = PostController(repository);
    addTearDown(controller.dispose);

    await controller.load(1);

    expect(controller.state.post?.id, 1);
    expect(controller.state.isLoading, isFalse);
    expect(controller.state.loadFailure, isNull);
  });

  test('rolls favorite state back when request fails', () async {
    repository.favoriteResult = const Failure<void>(NetworkFailure());
    final controller = PostController(repository, initialPost: post());
    addTearDown(controller.dispose);

    await controller.toggleFavorite();

    expect(controller.state.post?.isFavorited, isFalse);
    expect(controller.state.actionFailure, isA<NetworkFailure>());
    expect(controller.state.actionFailureVersion, 1);
  });

  test('rolls reactions back when request fails', () async {
    repository.reactionResult = const Failure<void>(TimeoutFailure());
    final controller = PostController(repository, initialPost: post());
    addTearDown(controller.dispose);

    await controller.toggleReaction(5);

    expect(controller.state.post?.reactions.selectedId, 0);
    expect(controller.state.actionFailure, isA<TimeoutFailure>());
  });
}
