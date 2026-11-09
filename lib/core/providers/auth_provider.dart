import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/auth_state.dart';
import '../../features/auth/data/mock_auth_repository.dart';
import '../models/app_mode.dart';
import '../persistence/demo_persistence.dart';

final mockAuthRepositoryProvider = Provider<MockAuthRepository>((ref) {
  return MockAuthRepository(persistence: ref.read(demoPersistenceProvider));
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
  int _loginAttempt = 0;

  @override
  AuthState build() {
    final subscription = ref.read(demoPersistenceProvider).changes.listen((
      key,
    ) {
      if (!ref.mounted) {
        return;
      }
      if (key == '*') {
        logout();
        return;
      }
      if (key != 'scores') {
        return;
      }
      final currentUser = state.user;
      if (currentUser == null) {
        return;
      }
      final user = ref.read(authRepositoryProvider).userById(currentUser.id);
      if (user != null && user.creditScore != currentUser.creditScore) {
        state = AuthState(
          user: user,
          isLoading: state.isLoading,
          errorMessage: state.errorMessage,
        );
      }
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    return const AuthState();
  }

  Future<bool> login({
    required String phone,
    required String password,
    required AppMode mode,
  }) async {
    final attempt = ++_loginAttempt;
    state = AuthState(user: state.user, isLoading: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(phone: phone, password: password, mode: mode);
      if (!_canFinishLogin(attempt)) {
        return false;
      }
      state = AuthState(user: user);
      return true;
    } on AuthException catch (error) {
      if (!_canFinishLogin(attempt)) {
        return false;
      }
      state = AuthState(errorMessage: error.message);
      return false;
    } catch (_) {
      if (!_canFinishLogin(attempt)) {
        return false;
      }
      state = const AuthState(errorMessage: '登录失败，请稍后重试');
      return false;
    }
  }

  void logout() {
    _loginAttempt++;
    unawaited(ref.read(authRepositoryProvider).logout());
    state = const AuthState();
  }

  void adjustCreditScore(int delta) {
    final user = state.user;
    if (user == null) {
      return;
    }

    final updatedUser = ref
        .read(authRepositoryProvider)
        .adjustCreditScore(user.id, delta);
    state = AuthState(user: updatedUser);
  }

  bool _canFinishLogin(int attempt) {
    return ref.mounted && attempt == _loginAttempt;
  }
}
