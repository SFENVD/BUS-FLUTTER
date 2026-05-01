class LocationUpdate {
  const LocationUpdate({
    required this.vehicleId,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.timestamp,
  });

  final String vehicleId;
  final double lat;
  final double lng;
  final double speed;
  final DateTime timestamp;
}
