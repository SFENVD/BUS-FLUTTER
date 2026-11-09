import '../../../core/models/admin_driver_model.dart';
import '../../../core/models/analytics_model.dart';
import '../../../core/models/dispatch_model.dart';
import '../../../core/models/vehicle_location_model.dart';
import '../../../core/models/vehicle_model.dart';
import '../providers/admin_provider.dart';

/// Coordinates and analytics are local simulations, not shared business data.
Map<String, Object?> encodeAdminState(AdminState state) => {
  'version': 1,
  'vehicles': [
    for (final vehicle in state.vehicles)
      {
        'id': vehicle.id,
        'plateNo': vehicle.plateNo,
        'model': vehicle.model,
        'seatCount': vehicle.seatCount,
        'status': vehicle.status.name,
      },
  ],
  'drivers': [
    for (final driver in state.drivers)
      {
        'id': driver.id,
        'name': driver.name,
        'phone': driver.phone,
        'licenseNo': driver.licenseNo,
        'boundVehicleId': driver.boundVehicleId,
      },
  ],
  'demands': [
    for (final demand in state.dispatchDemands)
      {
        'id': demand.id,
        'routeName': demand.routeName,
        'origin': demand.origin,
        'destination': demand.destination,
        'passengerCount': demand.passengerCount,
        'departureTime': demand.departureTime.toIso8601String(),
        'status': demand.status.name,
      },
  ],
  'plans': [
    for (final plan in state.dispatchPlans)
      {
        'id': plan.id,
        'demandId': plan.demandId,
        'routeName': plan.routeName,
        'vehicleId': plan.vehicleId,
        'driverId': plan.driverId,
        'passengerCount': plan.passengerCount,
        'departureTime': plan.departureTime.toIso8601String(),
        'loadRate': plan.loadRate,
        'isAiGenerated': plan.isAiGenerated,
        'isConfirmed': plan.isConfirmed,
      },
  ],
  'selectedVehicleId': state.selectedVehicleId,
  'selectedAnalyticsPeriod': state.selectedAnalyticsPeriod.name,
};

AdminState decodeAdminState(
  Map<String, Object?> data,
  AdminState local, {
  bool preserveSelection = false,
}) {
  if (data['version'] != 1) {
    throw const FormatException('Unsupported admin snapshot');
  }
  final vehicles = [
    for (final row in _rows(data, 'vehicles'))
      VehicleModel(
        id: row['id'] as String,
        plateNo: row['plateNo'] as String,
        model: row['model'] as String,
        seatCount: _positiveInteger(row['seatCount']),
        status: VehicleStatus.values.byName(row['status'] as String),
      ),
  ];
  final drivers = [
    for (final row in _rows(data, 'drivers'))
      AdminDriverModel(
        id: row['id'] as String,
        name: row['name'] as String,
        phone: row['phone'] as String,
        licenseNo: row['licenseNo'] as String,
        boundVehicleId: row['boundVehicleId'] as String?,
      ),
  ];
  final demands = [
    for (final row in _rows(data, 'demands'))
      DispatchDemandModel(
        id: row['id'] as String,
        routeName: row['routeName'] as String,
        origin: row['origin'] as String,
        destination: row['destination'] as String,
        passengerCount: _positiveInteger(row['passengerCount']),
        departureTime: DateTime.parse(row['departureTime'] as String),
        status: DispatchDemandStatus.values.byName(row['status'] as String),
      ),
  ];
  final plans = [
    for (final row in _rows(data, 'plans'))
      DispatchPlanModel(
        id: row['id'] as String,
        demandId: row['demandId'] as String,
        routeName: row['routeName'] as String,
        vehicleId: row['vehicleId'] as String,
        driverId: row['driverId'] as String,
        passengerCount: _positiveInteger(row['passengerCount']),
        departureTime: DateTime.parse(row['departureTime'] as String),
        loadRate: (row['loadRate'] as num).toDouble(),
        isAiGenerated: row['isAiGenerated'] as bool,
        isConfirmed: row['isConfirmed'] as bool,
      ),
  ];
  _checkIds(vehicles.map((vehicle) => vehicle.id));
  _checkIds(drivers.map((driver) => driver.id));
  _checkIds(demands.map((demand) => demand.id));
  _checkIds(plans.map((plan) => plan.id));
  final vehicleIds = vehicles.map((vehicle) => vehicle.id).toSet();
  final boundVehicles = <String>{};
  for (final driver in drivers) {
    final vehicleId = driver.boundVehicleId;
    if (vehicleId != null &&
        (!vehicleIds.contains(vehicleId) || !boundVehicles.add(vehicleId))) {
      throw const FormatException('Invalid driver binding');
    }
  }
  if (plans.any((plan) => !plan.loadRate.isFinite || plan.loadRate < 0)) {
    throw const FormatException('Invalid dispatch load rate');
  }

  final selectedVehicleId = preserveSelection
      ? local.selectedVehicleId
      : data['selectedVehicleId'] as String?;
  final restored = AdminState(
    vehicles: vehicles,
    drivers: drivers,
    locations: const [],
    dispatchDemands: demands,
    dispatchPlans: plans,
    analytics: local.analytics,
    selectedAnalyticsPeriod: preserveSelection
        ? local.selectedAnalyticsPeriod
        : AnalyticsPeriod.values.byName(
            data['selectedAnalyticsPeriod'] as String,
          ),
    selectedVehicleId: vehicleIds.contains(selectedVehicleId)
        ? selectedVehicleId
        : null,
  );
  return restored.copyWith(
    locations: _localLocations(restored, local.locations),
  );
}

List<VehicleLocationModel> _localLocations(
  AdminState restored,
  List<VehicleLocationModel> current,
) {
  final locations = [
    for (final location in current)
      if (restored.vehicleById(location.vehicleId) != null &&
          restored.driverById(location.driverId) != null)
        location,
  ];
  final latestPlans = {
    for (final plan in restored.confirmedDispatchPlans) plan.vehicleId: plan,
  };
  for (final plan in latestPlans.values) {
    if (restored.vehicleById(plan.vehicleId)?.status != VehicleStatus.running ||
        restored.driverById(plan.driverId) == null) {
      continue;
    }
    if (locations.any(
      (location) =>
          location.vehicleId == plan.vehicleId &&
          location.driverId == plan.driverId &&
          location.tripNo == plan.id,
    )) {
      continue;
    }
    locations.removeWhere((location) => location.vehicleId == plan.vehicleId);
    locations.add(
      VehicleLocationModel(
        vehicleId: plan.vehicleId,
        driverId: plan.driverId,
        tripNo: plan.id,
        lat: 31.2240 + locations.length * 0.002,
        lng: 121.4690 + locations.length * 0.002,
        speed: 0,
        updatedAt: DateTime.now(),
      ),
    );
  }
  return locations;
}

Iterable<Map<String, Object?>> _rows(Map<String, Object?> data, String key) {
  return (data[key] as List).cast<Map<String, Object?>>();
}

int _positiveInteger(Object? value) {
  final integer = value as int;
  if (integer <= 0) throw const FormatException('Expected positive integer');
  return integer;
}

void _checkIds(Iterable<String> ids) {
  final seen = <String>{};
  for (final id in ids) {
    if (id.isEmpty || !seen.add(id)) {
      throw const FormatException('Invalid or duplicate identifier');
    }
  }
}
