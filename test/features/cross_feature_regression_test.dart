import 'dart:async';

import 'package:dtf_app/core/api/app_failure.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/chat/data/chat_repository.dart';
import 'package:dtf_app/features/chat/presentation/chat_controller.dart';
import 'package:dtf_app/features/notifications/data/notifications_repository.dart';
import 'package:dtf_app/features/notifications/presentation/notifications_controller.dart';
import 'package:dtf_app/features/search/data/search_repository.dart';
import 'package:dtf_app/features/search/presentation/search_controller.dart'
    as feature;
import 'package:dtf_app/models/channel.dart';
import 'package:dtf_app/models/message.dart';
import 'package:dtf_app/models/notification.dart';
import 'package:dtf_app/models/post.dart';
import 'package:dtf_app/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchRepository implements SearchRepository {
  final requests = <Completer<Result<List<Post>>>>[];

  @override
  Future<Result<SearchLanding>> loadLanding() async =>
      const Success(SearchLanding(blogs: [], comments: []));

  @override
  Future<Result<List<Post>>> search(String query) {
    final completer = Completer<Result<List<Post>>>();
    requests.add(completer);
    return completer.future;
  }

  @override
  Future<Result<void>> setSubscription(
    int subsiteId, {
    required bool value,
  }) async => const Success(null);
}

class _NotificationsRepository implements NotificationsRepository {
  @override
  Future<Result<List<AppNotification>>> load({int? lastId}) async =>
      const Success([]);

  @override
  Future<Result<int>> unreadCount() async => const Success(6);
}

class _ChatRepository implements ChatRepository {
  @override
  Future<Result<List<Channel>>> loadChannels({int page = 1}) async =>
      const Success([]);

  @override
  Future<Result<List<Message>>> loadMessages(
    int channelId, {
    String beforeTime = '0',
  }) async => const Success([]);

  @override
  Future<Result<void>> markRead(int channelId) async => const Success(null);

  @override
  Future<Result<void>> send({
    required int channelId,
    required String text,
    String? replyToId,
  }) async => const Failure(NetworkFailure());
}

Post _post(int id) => Post.fromJson({'id': id, 'title': 'Post $id'});

void main() {
  test('search ignores a response from an obsolete query', () async {
    final repository = _SearchRepository();
    final controller = feature.SearchController(repository);
    addTearDown(controller.dispose);

    final oldRequest = controller.search('old');
    final currentRequest = controller.search('current');
    repository.requests[1].complete(Success([_post(2)]));
    await currentRequest;
    repository.requests[0].complete(Success([_post(1)]));
    await oldRequest;

    expect(controller.state.query, 'current');
    expect(controller.state.posts.single.id, 2);
  });

  test('notification polling updates the focused unread service', () async {
    final service = NotificationService();
    final controller = NotificationsController(
      _NotificationsRepository(),
      service,
    );
    addTearDown(controller.dispose);
    addTearDown(service.dispose);

    await controller.refreshUnreadCount();

    expect(service.unreadCount, 6);
  });

  test('chat preserves a typed failure when sending fails', () async {
    final controller = ChatController(_ChatRepository());
    addTearDown(controller.dispose);

    final sent = await controller.send(1, 'message');

    expect(sent, isFalse);
    expect(controller.failure, isA<NetworkFailure>());
  });
}
