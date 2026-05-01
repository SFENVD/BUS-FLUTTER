import '../../../core/models/user_model.dart';

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;
}
