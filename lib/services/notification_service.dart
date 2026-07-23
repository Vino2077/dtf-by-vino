import 'package:flutter/foundation.dart';

class NotificationService extends ChangeNotifier {
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  void updateUnreadCount(int value) {
    if (value == _unreadCount) return;
    _unreadCount = value;
    notifyListeners();
  }

  void clear() => updateUnreadCount(0);
}
