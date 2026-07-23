import '../../../core/api/result.dart';

abstract interface class AuthRepository {
  Future<Result<String>> login(String email, String password);
  Future<Result<bool>> validateToken(String token);
}
