import 'package:flutter/foundation.dart';

import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../services/auth_service.dart';
import '../data/auth_repository.dart';

class LoginController extends ChangeNotifier {
  LoginController(this._repository, this._authService);
  final AuthRepository _repository;
  final AuthService _authService;
  bool isLoading = false;
  AppFailure? failure;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    failure = null;
    notifyListeners();
    final result = await _repository.login(email, password);
    if (result case Success<String>(:final value)) {
      try {
        await _authService.saveToken(value);
        isLoading = false;
        notifyListeners();
        return true;
      } on AuthStorageException catch (error) {
        failure = UnknownFailure(error.message);
      }
    } else {
      failure = (result as Failure<String>).failure;
    }
    isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> saveValidatedToken(String token) async {
    final result = await _repository.validateToken(token);
    if (result.valueOrNull != true) return false;
    try {
      await _authService.saveToken(token);
      return true;
    } on AuthStorageException catch (error) {
      failure = UnknownFailure(error.message);
      notifyListeners();
      return false;
    }
  }
}
