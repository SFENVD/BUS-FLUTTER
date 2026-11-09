import '../../../core/models/app_mode.dart';
import '../../../core/models/user_model.dart';

abstract interface class AuthRepository {
  Future<UserModel> login({
    required String phone,
    required String password,
    required AppMode mode,
  });

  Future<void> logout();

  UserModel? userById(String userId);

  UserModel adjustCreditScore(String userId, int delta);
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
