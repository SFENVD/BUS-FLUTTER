import 'user_role.dart';

enum AppMode {
  passenger(
    value: 'passenger',
    title: '普通用户端',
    shortLabel: '用户端',
    description: '预约车次、支付车费、查看信用等级',
    homeLocation: '/passenger',
    role: UserRole.passenger,
  ),
  driver(
    value: 'driver',
    title: '司机端',
    shortLabel: '司机端',
    description: '查看派车任务、统计服务数据、上报位置',
    homeLocation: '/driver',
    role: UserRole.driver,
  ),
  admin(
    value: 'admin',
    title: '后台管理端',
    shortLabel: '后台',
    description: '管理车辆司机、调度车次、查看运营数据',
    homeLocation: '/admin',
    role: UserRole.admin,
  );

  const AppMode({
    required this.value,
    required this.title,
    required this.shortLabel,
    required this.description,
    required this.homeLocation,
    required this.role,
  });

  final String value;
  final String title;
  final String shortLabel;
  final String description;
  final String homeLocation;
  final UserRole role;

  static AppMode fromValue(String value) {
    return AppMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => AppMode.passenger,
    );
  }
}

extension UserRoleModeX on UserRole {
  AppMode get appMode {
    return AppMode.values.firstWhere((mode) => mode.role == this);
  }
}
