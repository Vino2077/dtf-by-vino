import 'package:flutter/foundation.dart';

import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/notification.dart';
import '../../../services/notification_service.dart';
import '../data/notifications_repository.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository, this._notificationService);
  final NotificationsRepository _repository;
  final NotificationService _notificationService;

  List<AppNotification> items = const [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  AppFailure? failure;

  Future<void> load({bool refresh = false}) async {
    if (isLoading || isLoadingMore || (!refresh && !hasMore)) return;
    if (refresh || items.isEmpty) {
      isLoading = true;
    } else {
      isLoadingMore = true;
    }
    failure = null;
    notifyListeners();
    final result = await _repository.load(
      lastId: refresh || items.isEmpty ? null : items.last.id,
    );
    switch (result) {
      case Success<List<AppNotification>>(:final value):
        items = refresh ? value : _merge(items, value);
        hasMore = value.isNotEmpty;
      case Failure<List<AppNotification>>(:final failure):
        this.failure = failure;
    }
    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    final result = await _repository.unreadCount();
    if (result case Success<int>(:final value)) {
      _notificationService.updateUnreadCount(value);
    }
  }

  List<AppNotification> _merge(
    List<AppNotification> current,
    List<AppNotification> incoming,
  ) {
    final values = <int, AppNotification>{
      for (final item in current) item.id: item,
    };
    for (final item in incoming) {
      values[item.id] = item;
    }
    return values.values.toList(growable: false);
  }
}
