class AdminDriverModel {
  const AdminDriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.licenseNo,
    this.boundVehicleId,
  });

  final String id;
  final String name;
  final String phone;
  final String licenseNo;
  final String? boundVehicleId;

  AdminDriverModel copyWith({
    String? name,
    String? phone,
    String? licenseNo,
    String? boundVehicleId,
    bool clearBoundVehicle = false,
  }) {
    return AdminDriverModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      licenseNo: licenseNo ?? this.licenseNo,
      boundVehicleId: clearBoundVehicle
          ? null
          : boundVehicleId ?? this.boundVehicleId,
    );
  }
}
