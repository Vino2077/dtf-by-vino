import 'dart:collection';

import '../util/json_safe.dart';
import 'reaction.dart';
import 'user.dart';

class Comment {
  Comment({
    required this.id,
    required this.replyTo,
    required this.text,
    required this.reactions,
    required Map<String, dynamic> rawJson,
    this.author,
    this.threadId,
    this.replyCount = 0,
    this.level = 0,
    this.isFavorited = false,
  }) : rawJson = UnmodifiableMapView(Map<String, dynamic>.from(rawJson));

  factory Comment.fromJson(Map<String, dynamic> json) {
    final id = asInt(json['id']);
    if (id == null) throw const FormatException('Comment id is missing');
    final authorJson = json['author'];
    return Comment(
      id: id,
      replyTo: asInt(json['replyTo']) ?? 0,
      text: asStringOr(json['text']),
      author: authorJson is Map ? User.fromJson(asMap(authorJson)) : null,
      threadId: json['threadId']?.toString(),
      replyCount: asInt(json['replyCount']) ?? 0,
      level: asInt(json['level']) ?? 0,
      isFavorited: json['isFavorited'] == true,
      reactions: json['reactions'] is Map
          ? PostReactions.fromJson(asMap(json['reactions']))
          : PostReactions.empty,
      rawJson: json,
    );
  }

  final int id;
  final int replyTo;
  final String text;
  final User? author;
  final String? threadId;
  final int replyCount;
  final int level;
  final bool isFavorited;
  final PostReactions reactions;
  final Map<String, dynamic> rawJson;

  Comment copyWith({
    String? text,
    bool? isFavorited,
    PostReactions? reactions,
    Map<String, dynamic>? rawJson,
  }) {
    final json = Map<String, dynamic>.from(rawJson ?? this.rawJson)
      ..['text'] = text ?? this.text
      ..['isFavorited'] = isFavorited ?? this.isFavorited
      ..['reactions'] = (reactions ?? this.reactions).toJson();
    return Comment.fromJson(json);
  }

  Comment mergeRaw(Map<String, dynamic> values) =>
      copyWith(rawJson: {...rawJson, ...values});

  Map<String, dynamic> toJson() => {
    ...rawJson,
    'id': id,
    'replyTo': replyTo,
    'text': text,
    'threadId': threadId,
    'replyCount': replyCount,
    'level': level,
    'isFavorited': isFavorited,
    'reactions': reactions.toJson(),
    if (author != null) 'author': author!.rawJson,
  };
}
