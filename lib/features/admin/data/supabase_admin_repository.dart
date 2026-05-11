import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/models/admin_driver_model.dart';
import '../../../core/models/dispatch_model.dart';
import '../../../core/models/vehicle_location_model.dart';
import '../../../core/models/vehicle_model.dart';

class SupabaseAdminSnapshot {
  const SupabaseAdminSnapshot({
    required this.vehicles,
    required this.drivers,
    required this.locations,
    required this.dispatchDemands,
    required this.dispatchPlans,
  });

  final List<VehicleModel> vehicles;
  final List<AdminDriverModel> drivers;
  final List<VehicleLocationModel> locations;
  final List<DispatchDemandModel> dispatchDemands;
  final List<DispatchPlanModel> dispatchPlans;
}

class SupabaseAdminRepository {
  const SupabaseAdminRepository(this._client);

  final supabase.SupabaseClient _client;

  Future<SupabaseAdminSnapshot> fetchSnapshot() async {
    final vehicles = await _client.from('vehicles').select().order('plate_no');
    final drivers = await _client.from('drivers').select().order('name');
    final locations = await _client
        .from('vehicle_locations')
        .select()
        .order('updated_at', ascending: false);
    final demands = await _client
        .from('dispatch_demands')
        .select()
        .order('departure_time');
    final plans = await _client
        .from('dispatch_plans')
        .select()
        .order('created_at', ascending: false);

    return SupabaseAdminSnapshot(
      vehicles: vehicles.map(_vehicleFromJson).toList(),
      drivers: drivers.map(_driverFromJson).toList(),
      locations: locations.map(_locationFromJson).toList(),
      dispatchDemands: demands.map(_dispatchDemandFromJson).toList(),
      dispatchPlans: plans.map(_dispatchPlanFromJson).toList(),
    );
  }

  Future<VehicleModel> addVehicle({
    required String plateNo,
    required String model,
    required int seatCount,
    required VehicleStatus status,
  }) async {
    final result = await _client
        .from('vehicles')
        .insert({
          'plate_no': plateNo,
          'model': model,
          'seat_count': seatCount,
          'status': status.value,
        })
        .select()
        .single();
    return _vehicleFromJson(result);
  }

  Future<VehicleModel> updateVehicle(VehicleModel vehicle) async {
    final result = await _client
        .from('vehicles')
        .update({
          'plate_no': vehicle.plateNo,
          'model': vehicle.model,
          'seat_count': vehicle.seatCount,
          'status': vehicle.status.value,
        })
        .eq('id', vehicle.id)
        .select()
        .single();
    return _vehicleFromJson(result);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _client.from('vehicles').delete().eq('id', vehicleId);
  }

  Future<AdminDriverModel> addDriver({
    required String name,
    required String phone,
    required String licenseNo,
    String? boundVehicleId,
  }) async {
    final result = await _client
        .from('drivers')
        .insert({
          'name': name,
          'phone': phone,
          'license_no': licenseNo,
          'bound_vehicle_id': boundVehicleId,
        })
        .select()
        .single();
    return _driverFromJson(result);
  }

  Future<AdminDriverModel> updateDriver(AdminDriverModel driver) async {
    final result = await _client
        .from('drivers')
        .update({
          'name': driver.name,
          'phone': driver.phone,
          'license_no': driver.licenseNo,
          'bound_vehicle_id': driver.boundVehicleId,
        })
        .eq('id', driver.id)
        .select()
        .single();
    return _driverFromJson(result);
  }

  Future<void> deleteDriver(String driverId) async {
    await _client.from('drivers').delete().eq('id', driverId);
  }

  VehicleModel _vehicleFromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      plateNo: json['plate_no'] as String? ?? '',
      model: json['model'] as String? ?? '',
      seatCount: (json['seat_count'] as num?)?.toInt() ?? 0,
      status: _vehicleStatusFromValue(json['status'] as String? ?? ''),
    );
  }

  AdminDriverModel _driverFromJson(Map<String, dynamic> json) {
    return AdminDriverModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      licenseNo: json['license_no'] as String? ?? '',
      boundVehicleId: json['bound_vehicle_id'] as String?,
    );
  }

  VehicleLocationModel _locationFromJson(Map<String, dynamic> json) {
    return VehicleLocationModel(
      vehicleId: json['vehicle_id'] as String? ?? '',
      tripNo: json['trip_no'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  DispatchDemandModel _dispatchDemandFromJson(Map<String, dynamic> json) {
    return DispatchDemandModel(
      id: json['id'] as String,
      routeName: json['route_name'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      passengerCount: (json['passenger_count'] as num?)?.toInt() ?? 0,
      departureTime: DateTime.parse(json['departure_time'] as String),
      status: _dispatchDemandStatusFromValue(json['status'] as String? ?? ''),
    );
  }

  DispatchPlanModel _dispatchPlanFromJson(Map<String, dynamic> json) {
    return DispatchPlanModel(
      id: json['id'] as String,
      demandId: json['demand_id'] as String? ?? '',
      routeName: json['route_name'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      passengerCount: (json['passenger_count'] as num?)?.toInt() ?? 0,
      departureTime: DateTime.parse(json['departure_time'] as String),
      loadRate: (json['load_rate'] as num?)?.toDouble() ?? 0,
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
      isConfirmed: json['is_confirmed'] as bool? ?? false,
    );
  }

  VehicleStatus _vehicleStatusFromValue(String value) {
    return VehicleStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => VehicleStatus.idle,
    );
  }

  DispatchDemandStatus _dispatchDemandStatusFromValue(String value) {
    return DispatchDemandStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DispatchDemandStatus.pending,
    );
  }
}
