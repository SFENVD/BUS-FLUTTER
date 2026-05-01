enum UserRole {
  passenger('passenger', '普通用户'),
  driver('driver', '司机'),
  admin('admin', '管理员');

  const UserRole(this.value, this.label);

  final String value;
  final String label;
}
