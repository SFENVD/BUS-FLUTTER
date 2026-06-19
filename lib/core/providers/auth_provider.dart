import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/auth_state.dart';
import '../../features/auth/data/mock_auth_repository.dart';
import '../models/app_mode.dart';

final mockAuthRepositoryProvider = Provider<MockAuthRepository>((ref) {
  return MockAuthRepository();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(mockAuthRepositoryProvider);
});

final mockCredentialsProvider = Provider<List<MockCredential>>((ref) {
  return MockAuthRepository.credentials;
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  Future<bool> login({
    required String phone,
    required String password,
    required AppMode mode,
  }) async {
    state = AuthState(user: state.user, isLoading: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(phone: phone, password: password, mode: mode);
      state = AuthState(user: user);
      return true;
    } on AuthException catch (error) {
      state = AuthState(errorMessage: error.message);
      return false;
    } catch (_) {
      state = const AuthState(errorMessage: '登录失败，请稍后重试');
      return false;
    }
  }

  void logout() {
    unawaited(ref.read(authRepositoryProvider).logout());
    state = const AuthState();
  }

  void adjustCreditScore(int delta) {
    final user = state.user;
    if (user == null) {
      return;
    }

    final nextScore = (user.creditScore + delta).clamp(0, 100);
    state = AuthState(user: user.copyWith(creditScore: nextScore));
  }
}
