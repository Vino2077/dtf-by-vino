import 'dart:collection';

class Message {
  Message({required this.id, required Map<String, dynamic> rawJson})
    : rawJson = UnmodifiableMapView(Map<String, dynamic>.from(rawJson));

  factory Message.fromJson(Map<String, dynamic> json) {
    final value = json['id'] ?? json['messageId'] ?? json['idTmp'];
    if (value == null) throw const FormatException('Message id is missing');
    return Message(id: value.toString(), rawJson: json);
  }

  final String id;
  final Map<String, dynamic> rawJson;
}
