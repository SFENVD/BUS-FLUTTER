import 'user_role.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.creditScore,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;
  final int creditScore;
  final UserRole role;

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    int? creditScore,
    UserRole? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      creditScore: creditScore ?? this.creditScore,
      role: role ?? this.role,
    );
  }
}
