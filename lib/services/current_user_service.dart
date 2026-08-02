import 'package:flutter/foundation.dart';

class CurrentUserService extends ChangeNotifier {
  int? _userId;
  bool _isPlus = false;

  int? get userId => _userId;
  bool get isPlus => _isPlus;

  void update(int? userId, bool isPlus) {
    if (userId == _userId && isPlus == _isPlus) return;
    _userId = userId;
    _isPlus = isPlus;
    notifyListeners();
  }

  void clear() => update(null, false);
}
