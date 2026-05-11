enum DriverTaskStatus {
  pending('pending', '待发车'),
  running('running', '行程中'),
  completed('completed', '已完成');

  const DriverTaskStatus(this.value, this.label);

  final String value;
  final String label;
}

class PassengerPickup {
  const PassengerPickup({
    required this.name,
    required this.phoneSuffix,
    required this.pickupPoint,
    required this.seatNo,
  });

  final String name;
  final String phoneSuffix;
  final String pickupPoint;
  final int seatNo;
}

class DriverTaskModel {
  const DriverTaskModel({
    required this.id,
    required this.tripNo,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.vehicleId,
    this.driverId = '',
    required this.plateNo,
    required this.departureTime,
    required this.distanceKm,
    required this.passengers,
    required this.status,
  });

  final String id;
  final String tripNo;
  final String routeName;
  final String origin;
  final String destination;
  final String vehicleId;
  final String driverId;
  final String plateNo;
  final DateTime departureTime;
  final double distanceKm;
  final List<PassengerPickup> passengers;
  final DriverTaskStatus status;

  DriverTaskModel copyWith({DriverTaskStatus? status}) {
    return DriverTaskModel(
      id: id,
      tripNo: tripNo,
      routeName: routeName,
      origin: origin,
      destination: destination,
      vehicleId: vehicleId,
      driverId: driverId,
      plateNo: plateNo,
      departureTime: departureTime,
      distanceKm: distanceKm,
      passengers: passengers,
      status: status ?? this.status,
    );
  }
}

class DriverStats {
  const DriverStats({
    required this.period,
    required this.totalTrips,
    required this.totalPassengers,
    required this.totalDistance,
    required this.onTimeRate,
  });

  final String period;
  final int totalTrips;
  final int totalPassengers;
  final double totalDistance;
  final double onTimeRate;
}
