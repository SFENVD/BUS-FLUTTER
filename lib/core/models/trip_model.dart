enum TripStatus {
  scheduled('scheduled', '待发车'),
  running('running', '运行中'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消');

  const TripStatus(this.value, this.label);

  final String value;
  final String label;
}

class TripModel {
  const TripModel({
    required this.id,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.vehicleId,
    required this.driverId,
    required this.departureTime,
    required this.totalSeats,
    required this.bookedSeats,
    required this.fare,
    required this.status,
  });

  final String id;
  final String routeName;
  final String origin;
  final String destination;
  final String vehicleId;
  final String driverId;
  final DateTime departureTime;
  final int totalSeats;
  final int bookedSeats;
  final double fare;
  final TripStatus status;

  bool get isBookable =>
      status == TripStatus.scheduled && departureTime.isAfter(DateTime.now());
}
