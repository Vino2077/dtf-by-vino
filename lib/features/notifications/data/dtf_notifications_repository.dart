import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/notification.dart';
import '../../../util/json_safe.dart';
import 'notifications_repository.dart';

class DtfNotificationsRepository implements NotificationsRepository {
  const DtfNotificationsRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<AppNotification>>> load({int? lastId}) async {
    final cursor = lastId == null ? '' : '&last_id=$lastId';
    final result = await _api.get(
      'subsite/me/updates?html=true&is_read=2$cursor',
    );
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    try {
      return Success(
        (value is List
                ? value
                : asList(dig(value, ['items']) ?? dig(value, ['updates'])))
            .whereType<Map>()
            .map((json) => AppNotification.fromJson(asMap(json)))
            .toList(growable: false),
      );
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }

  @override
  Future<Result<int>> unreadCount() async {
    final result = await _api.get('subsite/me/updates/count');
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    final value = (result as Success<Object?>).value;
    return Success(
      value is Map
          ? asInt(value['count'] ?? value['counter'] ?? value['unread']) ?? 0
          : asInt(value) ?? 0,
    );
  }
}
