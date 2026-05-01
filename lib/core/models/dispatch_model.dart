enum DispatchDemandStatus {
  pending('pending', '待调度'),
  assigned('assigned', '已调度');

  const DispatchDemandStatus(this.value, this.label);

  final String value;
  final String label;
}

class DispatchDemandModel {
  const DispatchDemandModel({
    required this.id,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.passengerCount,
    required this.departureTime,
    required this.status,
  });

  final String id;
  final String routeName;
  final String origin;
  final String destination;
  final int passengerCount;
  final DateTime departureTime;
  final DispatchDemandStatus status;

  DispatchDemandModel copyWith({DispatchDemandStatus? status}) {
    return DispatchDemandModel(
      id: id,
      routeName: routeName,
      origin: origin,
      destination: destination,
      passengerCount: passengerCount,
      departureTime: departureTime,
      status: status ?? this.status,
    );
  }
}

class DispatchPlanModel {
  const DispatchPlanModel({
    required this.id,
    required this.demandId,
    required this.routeName,
    required this.vehicleId,
    required this.driverId,
    required this.passengerCount,
    required this.departureTime,
    required this.loadRate,
    required this.isAiGenerated,
    required this.isConfirmed,
  });

  final String id;
  final String demandId;
  final String routeName;
  final String vehicleId;
  final String driverId;
  final int passengerCount;
  final DateTime departureTime;
  final double loadRate;
  final bool isAiGenerated;
  final bool isConfirmed;

  DispatchPlanModel copyWith({bool? isConfirmed}) {
    return DispatchPlanModel(
      id: id,
      demandId: demandId,
      routeName: routeName,
      vehicleId: vehicleId,
      driverId: driverId,
      passengerCount: passengerCount,
      departureTime: departureTime,
      loadRate: loadRate,
      isAiGenerated: isAiGenerated,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}
