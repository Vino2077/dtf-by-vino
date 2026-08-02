import 'dart:collection';

import '../util/json_safe.dart';

class AppNotification {
  AppNotification({required this.id, required Map<String, dynamic> rawJson})
    : rawJson = UnmodifiableMapView(Map<String, dynamic>.from(rawJson));

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['id'] ?? json['updateId']);
    if (id == null) throw const FormatException('Notification id is missing');
    return AppNotification(id: id, rawJson: json);
  }

  final int id;
  final Map<String, dynamic> rawJson;
}
