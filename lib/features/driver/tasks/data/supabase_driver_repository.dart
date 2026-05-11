import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/models/driver_task_model.dart';
import '../../../../core/models/location_update.dart';

class SupabaseDriverSnapshot {
  const SupabaseDriverSnapshot({
    required this.tasks,
    required this.stats,
    required this.locationUpdates,
    this.activeTaskId,
  });

  final List<DriverTaskModel> tasks;
  final List<DriverStats> stats;
  final List<LocationUpdate> locationUpdates;
  final String? activeTaskId;
}

class SupabaseDriverRepository {
  const SupabaseDriverRepository(this._client);

  final supabase.SupabaseClient _client;

  Future<SupabaseDriverSnapshot> fetchSnapshot(String profileId) async {
    final driverResult = await _client
        .from('drivers')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    if (driverResult == null) {
      return const SupabaseDriverSnapshot(
        tasks: [],
        stats: [
          DriverStats(
            period: '日',
            totalTrips: 0,
            totalPassengers: 0,
            totalDistance: 0,
            onTimeRate: 1,
          ),
          DriverStats(
            period: '周',
            totalTrips: 0,
            totalPassengers: 0,
            totalDistance: 0,
            onTimeRate: 1,
          ),
          DriverStats(
            period: '月',
            totalTrips: 0,
            totalPassengers: 0,
            totalDistance: 0,
            onTimeRate: 1,
          ),
        ],
        locationUpdates: [],
      );
    }

    final driverId = driverResult['id'] as String;
    final tripRows = await _client
        .from('trips')
        .select('*, vehicles(plate_no)')
        .eq('driver_id', driverId)
        .order('departure_time');
    final bookingRows = await _client
        .from('bookings')
        .select('*, profiles(name, phone)')
        .inFilter('trip_id', tripRows.map((trip) => trip['id']).toList())
        .neq('status', 'cancelled')
        .order('seat_no');
    final locationRows = await _client
        .from('vehicle_locations')
        .select()
        .eq('driver_id', driverId)
        .order('updated_at', ascending: false)
        .limit(50);

    final bookingsByTrip = <String, List<Map<String, dynamic>>>{};
    for (final row in bookingRows) {
      final tripId = row['trip_id'] as String;
      bookingsByTrip.putIfAbsent(tripId, () => []).add(row);
    }

    final tasks = tripRows.map((trip) {
      return _taskFromJson(
        trip: trip,
        bookings: bookingsByTrip[trip['id'] as String] ?? const [],
      );
    }).toList();
    final locationUpdates = locationRows.map(_locationFromJson).toList();
    final activeTask = tasks.where(
      (task) => task.status == DriverTaskStatus.running,
    );

    return SupabaseDriverSnapshot(
      tasks: tasks,
      stats: _buildStats(tasks),
      locationUpdates: locationUpdates,
      activeTaskId: activeTask.firstOrNull?.id,
    );
  }

  Future<void> updateTripStatus({
    required String tripId,
    required DriverTaskStatus status,
  }) async {
    await _client
        .from('trips')
        .update({'status': status.value})
        .eq('id', tripId);
  }

  Future<void> insertLocation({
    required DriverTaskModel task,
    required LocationUpdate update,
  }) async {
    await _client.from('vehicle_locations').insert({
      'vehicle_id': update.vehicleId,
      'trip_no': task.tripNo,
      'driver_id': task.driverId,
      'lat': update.lat,
      'lng': update.lng,
      'speed': update.speed,
      'updated_at': update.timestamp.toIso8601String(),
    });
  }

  DriverTaskModel _taskFromJson({
    required Map<String, dynamic> trip,
    required List<Map<String, dynamic>> bookings,
  }) {
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;

    return DriverTaskModel(
      id: trip['id'] as String,
      tripNo: trip['trip_no'] as String? ?? trip['id'] as String,
      routeName: trip['route_name'] as String? ?? '',
      origin: trip['origin'] as String? ?? '',
      destination: trip['destination'] as String? ?? '',
      vehicleId: trip['vehicle_id'] as String? ?? '',
      driverId: trip['driver_id'] as String? ?? '',
      plateNo: vehicle?['plate_no'] as String? ?? '未绑定车辆',
      departureTime: DateTime.parse(trip['departure_time'] as String),
      distanceKm: (trip['distance_km'] as num?)?.toDouble() ?? 0,
      passengers: bookings.map(_passengerFromBooking).toList(),
      status: _taskStatusFromTripStatus(trip['status'] as String? ?? ''),
    );
  }

  PassengerPickup _passengerFromBooking(Map<String, dynamic> booking) {
    final profile = booking['profiles'] as Map<String, dynamic>?;
    final phone = profile?['phone'] as String? ?? '';

    return PassengerPickup(
      name: profile?['name'] as String? ?? '乘客',
      phoneSuffix: phone.length >= 4
          ? phone.substring(phone.length - 4)
          : phone,
      pickupPoint: booking['pickup_point'] as String? ?? '未填写上车点',
      seatNo: (booking['seat_no'] as num?)?.toInt() ?? 0,
    );
  }

  LocationUpdate _locationFromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      vehicleId: json['vehicle_id'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.parse(json['updated_at'] as String),
    );
  }

  DriverTaskStatus _taskStatusFromTripStatus(String value) {
    return switch (value) {
      'running' => DriverTaskStatus.running,
      'completed' => DriverTaskStatus.completed,
      _ => DriverTaskStatus.pending,
    };
  }

  List<DriverStats> _buildStats(List<DriverTaskModel> tasks) {
    final completed = tasks.where(
      (task) => task.status == DriverTaskStatus.completed,
    );
    final totalPassengers = tasks.fold<int>(
      0,
      (total, task) => total + task.passengers.length,
    );
    final totalDistance = tasks.fold<double>(
      0,
      (total, task) => total + task.distanceKm,
    );

    return [
      DriverStats(
        period: '日',
        totalTrips: completed.length,
        totalPassengers: totalPassengers,
        totalDistance: totalDistance,
        onTimeRate: 0.98,
      ),
      DriverStats(
        period: '周',
        totalTrips: completed.length * 6,
        totalPassengers: totalPassengers * 6,
        totalDistance: totalDistance * 6,
        onTimeRate: 0.96,
      ),
      DriverStats(
        period: '月',
        totalTrips: completed.length * 24,
        totalPassengers: totalPassengers * 24,
        totalDistance: totalDistance * 24,
        onTimeRate: 0.95,
      ),
    ];
  }
}

extension _IterableFirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
