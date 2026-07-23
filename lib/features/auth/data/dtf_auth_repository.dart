import '../../../api/dtf_api.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import 'auth_repository.dart';

class DtfAuthRepository implements AuthRepository {
  const DtfAuthRepository();

  @override
  Future<Result<String>> login(String email, String password) async {
    final value = await DtfApi.loginWithPassword(email, password);
    final token = value['token'];
    if (value['ok'] == true && token is String && token.isNotEmpty) {
      return Success(token);
    }
    return Failure(
      ServerFailure(
        statusCode: 0,
        message: value['error']?.toString() ?? 'Не удалось войти',
      ),
    );
  }

  @override
  Future<Result<bool>> validateToken(String token) async =>
      Success(await DtfApi.validateToken(token));
}
