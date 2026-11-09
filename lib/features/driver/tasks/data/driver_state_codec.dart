import '../../../../core/models/driver_task_model.dart';
import '../../../../core/models/location_update.dart';
import '../providers/driver_task_provider.dart';

Map<String, Object?> encodeDriverState(DriverTaskState state) => {
  'tasks': [
    for (final task in state.tasks)
      {
        'id': task.id,
        'tripNo': task.tripNo,
        'routeName': task.routeName,
        'origin': task.origin,
        'destination': task.destination,
        'vehicleId': task.vehicleId,
        'driverId': task.driverId,
        'plateNo': task.plateNo,
        'departureTime': task.departureTime.toIso8601String(),
        'distanceKm': task.distanceKm,
        'status': task.status.name,
        'passengers': [
          for (final passenger in task.passengers)
            {
              'name': passenger.name,
              'phoneSuffix': passenger.phoneSuffix,
              'pickupPoint': passenger.pickupPoint,
              'seatNo': passenger.seatNo,
            },
        ],
      },
  ],
  'selectedStatsPeriod': state.selectedStatsPeriod,
  'activeTaskId': state.activeTaskId,
  'locations': [
    for (final location in state.locationUpdates.take(200))
      {
        'vehicleId': location.vehicleId,
        'lat': location.lat,
        'lng': location.lng,
        'speed': location.speed,
        'timestamp': location.timestamp.toIso8601String(),
      },
  ],
};

DriverTaskState decodeDriverState(
  Map<String, Object?> data,
  DriverTaskState initial,
) {
  final tasks = (data['tasks'] as List).map((value) {
    final task = value as Map<String, dynamic>;
    return DriverTaskModel(
      id: task['id'] as String,
      tripNo: task['tripNo'] as String,
      routeName: task['routeName'] as String,
      origin: task['origin'] as String,
      destination: task['destination'] as String,
      vehicleId: task['vehicleId'] as String,
      driverId: task['driverId'] as String? ?? '',
      plateNo: task['plateNo'] as String,
      departureTime: DateTime.parse(task['departureTime'] as String),
      distanceKm: (task['distanceKm'] as num).toDouble(),
      status: DriverTaskStatus.values.byName(task['status'] as String),
      passengers: [
        for (final value in task['passengers'] as List)
          PassengerPickup(
            name: (value as Map)['name'] as String,
            phoneSuffix: value['phoneSuffix'] as String,
            pickupPoint: value['pickupPoint'] as String,
            seatNo: value['seatNo'] as int,
          ),
      ],
    );
  }).toList();
  final activeId = data['activeTaskId'] as String?;
  final hasActiveTask = tasks.any(
    (task) => task.id == activeId && task.status == DriverTaskStatus.running,
  );
  final period = data['selectedStatsPeriod'] as String;
  return initial.copyWith(
    tasks: tasks,
    selectedStatsPeriod: initial.stats.any((stats) => stats.period == period)
        ? period
        : initial.selectedStatsPeriod,
    activeTaskId: hasActiveTask ? activeId : null,
    clearActiveTask: !hasActiveTask,
    locationUpdates: [
      for (final value in (data['locations'] as List).take(200))
        LocationUpdate(
          vehicleId: (value as Map)['vehicleId'] as String,
          lat: (value['lat'] as num).toDouble(),
          lng: (value['lng'] as num).toDouble(),
          speed: (value['speed'] as num).toDouble(),
          timestamp: DateTime.parse(value['timestamp'] as String),
        ),
    ],
  );
}
