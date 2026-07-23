import 'package:flutter/foundation.dart';

import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/channel.dart';
import '../../../models/message.dart';
import '../data/chat_repository.dart';

class ChatController extends ChangeNotifier {
  ChatController(this._repository);
  final ChatRepository _repository;
  List<Channel> channels = const [];
  List<Message> messages = const [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool isSending = false;
  AppFailure? failure;
  int _channelPage = 0;

  Future<void> loadChannels({bool refresh = false}) async {
    if (isLoadingMore) return;
    isLoadingMore = true;
    final page = refresh ? 1 : _channelPage + 1;
    notifyListeners();
    final result = await _repository.loadChannels(page: page);
    switch (result) {
      case Success<List<Channel>>(:final value):
        channels = refresh ? value : _mergeChannels(channels, value);
        _channelPage = page;
      case Failure<List<Channel>>(:final failure):
        this.failure = failure;
    }
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadMessages(int channelId, {bool refresh = false}) async {
    if (isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();
    final before = refresh || messages.isEmpty
        ? '0'
        : (messages.first.rawJson['dtCreated'] ?? '0').toString();
    final result = await _repository.loadMessages(
      channelId,
      beforeTime: before,
    );
    switch (result) {
      case Success<List<Message>>(:final value):
        messages = refresh
            ? _mergeMessages(messages, value)
            : _mergeMessages(value, messages);
      case Failure<List<Message>>(:final failure):
        this.failure = failure;
    }
    isLoadingMore = false;
    notifyListeners();
  }

  Future<bool> send(int channelId, String text, {String? replyToId}) async {
    isSending = true;
    notifyListeners();
    final result = await _repository.send(
      channelId: channelId,
      text: text,
      replyToId: replyToId,
    );
    isSending = false;
    if (result case Failure<void>(:final failure)) {
      this.failure = failure;
      notifyListeners();
      return false;
    }
    await loadMessages(channelId, refresh: true);
    return true;
  }

  Future<void> markRead(int channelId) => _repository.markRead(channelId);

  List<Channel> _mergeChannels(List<Channel> a, List<Channel> b) =>
      <int, Channel>{
        for (final value in a) value.id: value,
        for (final value in b) value.id: value,
      }.values.toList();
  List<Message> _mergeMessages(List<Message> a, List<Message> b) =>
      <String, Message>{
        for (final value in a) value.id: value,
        for (final value in b) value.id: value,
      }.values.toList();
}
