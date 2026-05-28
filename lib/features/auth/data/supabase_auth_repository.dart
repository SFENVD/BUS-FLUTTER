import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/models/app_mode.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/user_role.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<UserModel> login({
    required String phone,
    required String password,
    required AppMode mode,
  }) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty || password.isEmpty) {
      throw const AuthException('请输入手机号和密码');
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: _emailForPhone(normalizedPhone),
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) {
        throw const AuthException('登录失败，请检查账号信息');
      }

      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .single();
      final role = UserRole.fromValue(profile['role'] as String? ?? '');
      if (role != mode.role) {
        await _client.auth.signOut();
        throw AuthException('当前入口是${mode.title}，请切换入口后再登录');
      }

      final profilePhone = profile['phone'] as String? ?? normalizedPhone;
      if (profilePhone != normalizedPhone) {
        await _client.auth.signOut();
        throw const AuthException('手机号与账号资料不一致');
      }

      return UserModel(
        id: authUser.id,
        name: profile['name'] as String? ?? '未命名用户',
        phone: profilePhone,
        creditScore: (profile['credit_score'] as num?)?.toInt() ?? 100,
        role: role,
      );
    } on AuthException {
      rethrow;
    } on supabase.AuthApiException catch (error) {
      throw AuthException(error.message);
    } on supabase.PostgrestException catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException('登录失败，请稍后重试');
    }
  }

  @override
  Future<void> logout() {
    return _client.auth.signOut();
  }

  String _emailForPhone(String phone) {
    return '$phone@school-bus.local';
  }
}
