import 'dart:async';

import '../../../core/models/app_mode.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/user_role.dart';
import 'auth_repository.dart';

class MockCredential {
  const MockCredential({required this.user, required this.password});

  final UserModel user;
  final String password;

  AppMode get mode => user.role.appMode;
}

class MockAuthRepository implements AuthRepository {
  static const credentials = <MockCredential>[
    MockCredential(
      password: '123456',
      user: UserModel(
        id: 'u-passenger-001',
        name: '张同学',
        phone: '13800000001',
        creditScore: 96,
        role: UserRole.passenger,
      ),
    ),
    MockCredential(
      password: '123456',
      user: UserModel(
        id: 'u-driver-001',
        name: '王师傅',
        phone: '13800000002',
        creditScore: 100,
        role: UserRole.driver,
      ),
    ),
    MockCredential(
      password: '123456',
      user: UserModel(
        id: 'u-admin-001',
        name: '李管理员',
        phone: '13800000003',
        creditScore: 100,
        role: UserRole.admin,
      ),
    ),
  ];

  @override
  Future<UserModel> login({
    required String phone,
    required String password,
    required AppMode mode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty || password.isEmpty) {
      throw const AuthException('请输入手机号和密码');
    }

    final credential = credentials.where(
      (item) => item.user.phone == normalizedPhone,
    );
    if (credential.isEmpty) {
      throw const AuthException('用户不存在，请使用页面提供的演示账号');
    }

    final matchedCredential = credential.first;
    if (matchedCredential.password != password) {
      throw const AuthException('密码错误，演示账号默认密码为 123456');
    }

    if (matchedCredential.user.role != mode.role) {
      throw AuthException('当前入口是${mode.title}，请切换入口后再登录');
    }

    return matchedCredential.user;
  }

  @override
  Future<void> logout() async {}
}
