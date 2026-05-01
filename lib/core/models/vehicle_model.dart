enum VehicleStatus {
  idle('idle', '空闲'),
  running('running', '运行中'),
  maintenance('maintenance', '维修中');

  const VehicleStatus(this.value, this.label);

  final String value;
  final String label;
}

class VehicleModel {
  const VehicleModel({
    required this.id,
    required this.plateNo,
    required this.model,
    required this.seatCount,
    required this.status,
  });

  final String id;
  final String plateNo;
  final String model;
  final int seatCount;
  final VehicleStatus status;

  VehicleModel copyWith({
    String? plateNo,
    String? model,
    int? seatCount,
    VehicleStatus? status,
  }) {
    return VehicleModel(
      id: id,
      plateNo: plateNo ?? this.plateNo,
      model: model ?? this.model,
      seatCount: seatCount ?? this.seatCount,
      status: status ?? this.status,
    );
  }
}
