import '../../../core/api/result.dart';
import '../../../models/notification.dart';

abstract interface class NotificationsRepository {
  Future<Result<List<AppNotification>>> load({int? lastId});
  Future<Result<int>> unreadCount();
}
