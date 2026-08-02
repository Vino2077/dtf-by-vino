import 'dart:collection';

import '../util/json_safe.dart';

class Channel {
  Channel({required this.id, required Map<String, dynamic> rawJson})
    : rawJson = UnmodifiableMapView(Map<String, dynamic>.from(rawJson));

  factory Channel.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['id'] ?? json['channelId']);
    if (id == null) throw const FormatException('Channel id is missing');
    return Channel(id: id, rawJson: json);
  }

  final int id;
  final Map<String, dynamic> rawJson;
}
