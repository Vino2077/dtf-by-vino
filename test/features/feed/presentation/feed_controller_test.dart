import 'dart:async';

import 'package:dtf_app/core/api/app_failure.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/feed/data/feed_repository.dart';
import 'package:dtf_app/features/feed/models/feed_page.dart';
import 'package:dtf_app/features/feed/models/feed_type.dart';
import 'package:dtf_app/features/feed/presentation/feed_controller.dart';
import 'package:dtf_app/models/post.dart';
import 'package:flutter_test/flutter_test.dart';

Post post(int id) => Post.fromJson({'id': id, 'title': 'Post $id'});

FeedPage page(List<int> ids, {int? nextId}) => FeedPage(
  items: ids.map(post).toList(),
  cursor: nextId == null ? null : FeedCursor(lastId: nextId),
);

class _Request {
  _Request(this.type, this.cursor);

  final FeedType type;
  final FeedCursor? cursor;
  final completer = Completer<Result<FeedPage>>();
}

class _FakeFeedRepository implements FeedRepository {
  final requests = <_Request>[];

  @override
  Future<Result<FeedPage>> loadPage({
    required FeedType type,
    FeedCursor? cursor,
  }) {
    final request = _Request(type, cursor);
    requests.add(request);
    return request.completer.future;
  }
}

void main() {
  late _FakeFeedRepository repository;
  late FeedController controller;

  setUp(() {
    repository = _FakeFeedRepository();
    controller = FeedController(repository, () => true, type: FeedType.fresh);
  });

  tearDown(() => controller.dispose());

  test('loads the first page and exposes pagination state', () async {
    final operation = controller.load();
    repository.requests.single.completer.complete(
      Success(page([1, 2], nextId: 20)),
    );
    await operation;

    expect(controller.state.posts.map((post) => post.id), [1, 2]);
    expect(controller.state.isInitialLoading, isFalse);
    expect(controller.state.hasMore, isTrue);
    expect(controller.state.initialFailure, isNull);
  });

  test('does not issue duplicate loadMore requests', () async {
    final load = controller.load();
    repository.requests[0].completer.complete(Success(page([1], nextId: 20)));
    await load;

    final first = controller.loadMore();
    final duplicate = controller.loadMore();

    expect(repository.requests, hasLength(2));
    repository.requests[1].completer.complete(Success(page([2], nextId: 30)));
    await Future.wait([first, duplicate]);
    expect(controller.state.posts.map((post) => post.id), [1, 2]);
  });

  test('keeps posts when pagination fails and supports retry', () async {
    final load = controller.load();
    repository.requests[0].completer.complete(Success(page([1], nextId: 20)));
    await load;

    final failedLoadMore = controller.loadMore();
    repository.requests[1].completer.complete(
      const Failure<FeedPage>(NetworkFailure()),
    );
    await failedLoadMore;

    expect(controller.state.posts.map((post) => post.id), [1]);
    expect(controller.state.paginationFailure, isA<NetworkFailure>());

    final retry = controller.retryPagination();
    repository.requests[2].completer.complete(Success(page([2])));
    await retry;
    expect(controller.state.posts.map((post) => post.id), [1, 2]);
  });

  test('keeps content and emits a refresh failure version', () async {
    final load = controller.load();
    repository.requests[0].completer.complete(Success(page([1], nextId: 20)));
    await load;

    final refresh = controller.refresh();
    repository.requests[1].completer.complete(
      const Failure<FeedPage>(TimeoutFailure()),
    );
    await refresh;

    expect(controller.state.posts.map((post) => post.id), [1]);
    expect(controller.state.refreshFailure, isA<TimeoutFailure>());
    expect(controller.state.refreshFailureVersion, 1);
  });

  test('ignores an older response after refresh starts', () async {
    final oldLoad = controller.load();
    final refresh = controller.refresh();

    repository.requests[1].completer.complete(Success(page([2])));
    await refresh;
    repository.requests[0].completer.complete(Success(page([1])));
    await oldLoad;

    expect(controller.state.posts.map((post) => post.id), [2]);
  });

  test('personal feed does not call repository while logged out', () async {
    final personal = FeedController(
      repository,
      () => false,
      type: FeedType.personal,
    );
    addTearDown(personal.dispose);

    await personal.load();

    expect(repository.requests, isEmpty);
    expect(personal.state.requiresAuthentication, isTrue);
    expect(personal.state.isInitialLoading, isFalse);
  });
}
