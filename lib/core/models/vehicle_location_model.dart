class VehicleLocationModel {
  const VehicleLocationModel({
    required this.vehicleId,
    required this.tripNo,
    required this.driverId,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.updatedAt,
  });

  final String vehicleId;
  final String tripNo;
  final String driverId;
  final double lat;
  final double lng;
  final double speed;
  final DateTime updatedAt;

  VehicleLocationModel copyWith({
    double? lat,
    double? lng,
    double? speed,
    DateTime? updatedAt,
  }) {
    return VehicleLocationModel(
      vehicleId: vehicleId,
      tripNo: tripNo,
      driverId: driverId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      speed: speed ?? this.speed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
