import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../core/config/backend_config.dart';
import '../../../core/models/admin_driver_model.dart';
import '../../../core/models/analytics_model.dart';
import '../../../core/models/dispatch_model.dart';
import '../../../core/models/vehicle_location_model.dart';
import '../../../core/models/vehicle_model.dart';
import '../data/mock_admin_repository.dart';
import '../data/supabase_admin_repository.dart';

final mockAdminRepositoryProvider = Provider<MockAdminRepository>((ref) {
  return MockAdminRepository();
});

final supabaseAdminRepositoryProvider = Provider<SupabaseAdminRepository>((
  ref,
) {
  return SupabaseAdminRepository(Supabase.instance.client);
});

final adminProvider = NotifierProvider<AdminController, AdminState>(
  AdminController.new,
);

class AdminState {
  const AdminState({
    required this.vehicles,
    required this.drivers,
    required this.locations,
    required this.dispatchDemands,
    required this.dispatchPlans,
    required this.analytics,
    required this.selectedAnalyticsPeriod,
    this.selectedVehicleId,
  });

  final List<VehicleModel> vehicles;
  final List<AdminDriverModel> drivers;
  final List<VehicleLocationModel> locations;
  final List<DispatchDemandModel> dispatchDemands;
  final List<DispatchPlanModel> dispatchPlans;
  final List<AdminAnalyticsSnapshot> analytics;
  final AnalyticsPeriod selectedAnalyticsPeriod;
  final String? selectedVehicleId;

  int get runningVehicleCount {
    return vehicles
        .where((vehicle) => vehicle.status == VehicleStatus.running)
        .length;
  }

  int get idleVehicleCount {
    return vehicles
        .where((vehicle) => vehicle.status == VehicleStatus.idle)
        .length;
  }

  int get maintenanceVehicleCount {
    return vehicles
        .where((vehicle) => vehicle.status == VehicleStatus.maintenance)
        .length;
  }

  VehicleModel? vehicleById(String? vehicleId) {
    if (vehicleId == null) {
      return null;
    }
    return vehicles.where((vehicle) => vehicle.id == vehicleId).firstOrNull;
  }

  AdminDriverModel? driverById(String? driverId) {
    if (driverId == null) {
      return null;
    }
    return drivers.where((driver) => driver.id == driverId).firstOrNull;
  }

  AdminDriverModel? driverForVehicle(String vehicleId) {
    return drivers
        .where((driver) => driver.boundVehicleId == vehicleId)
        .firstOrNull;
  }

  VehicleLocationModel? locationForVehicle(String vehicleId) {
    return locations
        .where((location) => location.vehicleId == vehicleId)
        .firstOrNull;
  }

  VehicleModel? get selectedVehicle {
    return vehicleById(selectedVehicleId);
  }

  VehicleLocationModel? get selectedLocation {
    final vehicleId = selectedVehicleId;
    if (vehicleId == null) {
      return locations.firstOrNull;
    }
    return locationForVehicle(vehicleId);
  }

  List<DispatchDemandModel> get pendingDispatchDemands {
    return dispatchDemands
        .where((demand) => demand.status == DispatchDemandStatus.pending)
        .toList();
  }

  List<DispatchPlanModel> get pendingDispatchPlans {
    return dispatchPlans.where((plan) => !plan.isConfirmed).toList();
  }

  List<DispatchPlanModel> get confirmedDispatchPlans {
    return dispatchPlans.where((plan) => plan.isConfirmed).toList();
  }

  AdminAnalyticsSnapshot get selectedAnalytics {
    return analytics.firstWhere(
      (snapshot) => snapshot.period == selectedAnalyticsPeriod,
    );
  }

  int get pendingDemandPassengerCount {
    return pendingDispatchDemands.fold<int>(
      0,
      (total, demand) => total + demand.passengerCount,
    );
  }

  AdminState copyWith({
    List<VehicleModel>? vehicles,
    List<AdminDriverModel>? drivers,
    List<VehicleLocationModel>? locations,
    List<DispatchDemandModel>? dispatchDemands,
    List<DispatchPlanModel>? dispatchPlans,
    List<AdminAnalyticsSnapshot>? analytics,
    AnalyticsPeriod? selectedAnalyticsPeriod,
    String? selectedVehicleId,
    bool clearSelectedVehicle = false,
  }) {
    return AdminState(
      vehicles: vehicles ?? this.vehicles,
      drivers: drivers ?? this.drivers,
      locations: locations ?? this.locations,
      dispatchDemands: dispatchDemands ?? this.dispatchDemands,
      dispatchPlans: dispatchPlans ?? this.dispatchPlans,
      analytics: analytics ?? this.analytics,
      selectedAnalyticsPeriod:
          selectedAnalyticsPeriod ?? this.selectedAnalyticsPeriod,
      selectedVehicleId: clearSelectedVehicle
          ? null
          : selectedVehicleId ?? this.selectedVehicleId,
    );
  }
}

class AdminActionResult {
  const AdminActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class AdminController extends Notifier<AdminState> {
  Timer? _locationTimer;

  @override
  AdminState build() {
    ref.onDispose(_stopLocationTimer);

    final repository = ref.read(mockAdminRepositoryProvider);
    final locations = repository.fetchLocations();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      simulateLocationTick();
    });

    final initialState = AdminState(
      vehicles: repository.fetchVehicles(),
      drivers: repository.fetchDrivers(),
      locations: locations,
      dispatchDemands: repository.fetchDispatchDemands(),
      dispatchPlans: const [],
      analytics: repository.fetchAnalytics(),
      selectedAnalyticsPeriod: AnalyticsPeriod.day,
      selectedVehicleId: locations.firstOrNull?.vehicleId,
    );

    if (BackendConfig.useSupabase) {
      unawaited(_loadSupabaseSnapshot());
    }

    return initialState;
  }

  AdminActionResult addVehicle({
    required String plateNo,
    required String model,
    required int seatCount,
    required VehicleStatus status,
  }) {
    final normalizedPlate = plateNo.trim();
    if (normalizedPlate.isEmpty || model.trim().isEmpty || seatCount <= 0) {
      return const AdminActionResult(success: false, message: '请填写完整车辆信息');
    }
    if (state.vehicles.any((vehicle) => vehicle.plateNo == normalizedPlate)) {
      return const AdminActionResult(success: false, message: '车牌号已存在');
    }

    final vehicle = VehicleModel(
      id: 'bus-${DateTime.now().microsecondsSinceEpoch}',
      plateNo: normalizedPlate,
      model: model.trim(),
      seatCount: seatCount,
      status: status,
    );
    state = state.copyWith(vehicles: [vehicle, ...state.vehicles]);
    if (BackendConfig.useSupabase) {
      unawaited(_persistAddVehicle(vehicle));
    }
    return const AdminActionResult(success: true, message: '车辆已新增');
  }

  AdminActionResult updateVehicle(VehicleModel updatedVehicle) {
    final index = state.vehicles.indexWhere(
      (vehicle) => vehicle.id == updatedVehicle.id,
    );
    if (index < 0) {
      return const AdminActionResult(success: false, message: '车辆不存在');
    }

    final duplicatedPlate = state.vehicles.any(
      (vehicle) =>
          vehicle.id != updatedVehicle.id &&
          vehicle.plateNo == updatedVehicle.plateNo,
    );
    if (duplicatedPlate) {
      return const AdminActionResult(success: false, message: '车牌号已存在');
    }

    final nextVehicles = [...state.vehicles];
    nextVehicles[index] = updatedVehicle;
    state = state.copyWith(vehicles: nextVehicles);
    if (BackendConfig.useSupabase) {
      unawaited(_persistUpdateVehicle(updatedVehicle));
    }
    return const AdminActionResult(success: true, message: '车辆已更新');
  }

  AdminActionResult deleteVehicle(String vehicleId) {
    final vehicle = state.vehicleById(vehicleId);
    if (vehicle == null) {
      return const AdminActionResult(success: false, message: '车辆不存在');
    }
    if (vehicle.status == VehicleStatus.running) {
      return const AdminActionResult(success: false, message: '运行中车辆不可删除');
    }

    final nextDrivers = state.drivers.map((driver) {
      if (driver.boundVehicleId == vehicleId) {
        return driver.copyWith(clearBoundVehicle: true);
      }
      return driver;
    }).toList();
    final nextLocations = state.locations
        .where((location) => location.vehicleId != vehicleId)
        .toList();

    state = state.copyWith(
      vehicles: state.vehicles.where((item) => item.id != vehicleId).toList(),
      drivers: nextDrivers,
      locations: nextLocations,
      clearSelectedVehicle: state.selectedVehicleId == vehicleId,
    );
    if (BackendConfig.useSupabase) {
      unawaited(_persistDeleteVehicle(vehicleId));
    }
    return const AdminActionResult(success: true, message: '车辆已删除');
  }

  AdminActionResult addDriver({
    required String name,
    required String phone,
    required String licenseNo,
    String? boundVehicleId,
  }) {
    if (name.trim().isEmpty ||
        phone.trim().isEmpty ||
        licenseNo.trim().isEmpty) {
      return const AdminActionResult(success: false, message: '请填写完整司机信息');
    }
    if (state.drivers.any((driver) => driver.phone == phone.trim())) {
      return const AdminActionResult(success: false, message: '手机号已存在');
    }

    final bindCheck = _validateVehicleBinding(null, boundVehicleId);
    if (!bindCheck.success) {
      return bindCheck;
    }

    final driver = AdminDriverModel(
      id: 'driver-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      phone: phone.trim(),
      licenseNo: licenseNo.trim(),
      boundVehicleId: boundVehicleId,
    );
    state = state.copyWith(drivers: [driver, ...state.drivers]);
    if (BackendConfig.useSupabase) {
      unawaited(_persistAddDriver(driver));
    }
    return const AdminActionResult(success: true, message: '司机已新增');
  }

  AdminActionResult updateDriver(AdminDriverModel updatedDriver) {
    final index = state.drivers.indexWhere(
      (driver) => driver.id == updatedDriver.id,
    );
    if (index < 0) {
      return const AdminActionResult(success: false, message: '司机不存在');
    }

    final duplicatedPhone = state.drivers.any(
      (driver) =>
          driver.id != updatedDriver.id && driver.phone == updatedDriver.phone,
    );
    if (duplicatedPhone) {
      return const AdminActionResult(success: false, message: '手机号已存在');
    }

    final bindCheck = _validateVehicleBinding(
      updatedDriver.id,
      updatedDriver.boundVehicleId,
    );
    if (!bindCheck.success) {
      return bindCheck;
    }

    final nextDrivers = [...state.drivers];
    nextDrivers[index] = updatedDriver;
    state = state.copyWith(drivers: nextDrivers);
    if (BackendConfig.useSupabase) {
      unawaited(_persistUpdateDriver(updatedDriver));
    }
    return const AdminActionResult(success: true, message: '司机已更新');
  }

  AdminActionResult deleteDriver(String driverId) {
    final driver = state.driverById(driverId);
    if (driver == null) {
      return const AdminActionResult(success: false, message: '司机不存在');
    }
    if (state.locations.any((location) => location.driverId == driverId)) {
      return const AdminActionResult(success: false, message: '在途司机不可删除');
    }

    state = state.copyWith(
      drivers: state.drivers.where((item) => item.id != driverId).toList(),
    );
    if (BackendConfig.useSupabase) {
      unawaited(_persistDeleteDriver(driverId));
    }
    return const AdminActionResult(success: true, message: '司机已删除');
  }

  void selectVehicle(String vehicleId) {
    state = state.copyWith(selectedVehicleId: vehicleId);
  }

  void simulateLocationTick() {
    final changedLocations = <VehicleLocationModel>[];
    final nextLocations = state.locations.map((location) {
      final vehicle = state.vehicleById(location.vehicleId);
      if (vehicle?.status != VehicleStatus.running) {
        return location;
      }

      final seed = location.updatedAt.second % 5;
      final nextLocation = location.copyWith(
        lat: location.lat + 0.0007 + seed * 0.00005,
        lng: location.lng + 0.0005 + seed * 0.00004,
        speed: 24 + seed * 4,
        updatedAt: DateTime.now(),
      );
      changedLocations.add(nextLocation);
      return nextLocation;
    }).toList();

    state = state.copyWith(locations: nextLocations);
    if (BackendConfig.useSupabase) {
      unawaited(_persistVehicleLocations(changedLocations));
    }
  }

  void selectAnalyticsPeriod(AnalyticsPeriod period) {
    state = state.copyWith(selectedAnalyticsPeriod: period);
  }

  Future<AdminActionResult> generateAiDispatchPlans() async {
    final candidates = _availableVehicleDriverPairs();
    if (candidates.isEmpty) {
      return const AdminActionResult(
        success: false,
        message: '没有可用于调度的空闲车辆和司机',
      );
    }

    final sortedDemands = [...state.pendingDispatchDemands]
      ..sort((a, b) => b.passengerCount.compareTo(a.passengerCount));
    if (sortedDemands.isEmpty) {
      return const AdminActionResult(success: false, message: '暂无待调度需求');
    }

    final nextPlans = <DispatchPlanModel>[];
    final usedVehicleIds = <String>{};

    for (final demand in sortedDemands) {
      final pair = candidates.where((item) {
        return !usedVehicleIds.contains(item.vehicle.id) &&
            item.vehicle.seatCount >= demand.passengerCount;
      }).firstOrNull;
      if (pair == null) {
        continue;
      }

      usedVehicleIds.add(pair.vehicle.id);
      nextPlans.add(
        _buildDispatchPlan(
          demand: demand,
          vehicle: pair.vehicle,
          driver: pair.driver,
          isAiGenerated: true,
        ),
      );
    }

    if (nextPlans.isEmpty) {
      return const AdminActionResult(
        success: false,
        message: '当前空闲车辆座位数无法覆盖待调度需求',
      );
    }

    var plansToApply = nextPlans;
    if (BackendConfig.useSupabase) {
      try {
        plansToApply = await ref
            .read(supabaseAdminRepositoryProvider)
            .createDispatchPlans(nextPlans);
      } catch (_) {
        return const AdminActionResult(success: false, message: 'AI 调度建议保存失败');
      }
    }

    state = state.copyWith(
      dispatchPlans: [...state.confirmedDispatchPlans, ...plansToApply],
    );
    return AdminActionResult(
      success: true,
      message: '已生成 ${plansToApply.length} 条 AI 调度建议',
    );
  }

  Future<AdminActionResult> createManualDispatchPlan({
    required String demandId,
    required String vehicleId,
    required String driverId,
  }) async {
    final demand = state.dispatchDemands
        .where((item) => item.id == demandId)
        .firstOrNull;
    final vehicle = state.vehicleById(vehicleId);
    final driver = state.driverById(driverId);

    if (demand == null || demand.status != DispatchDemandStatus.pending) {
      return const AdminActionResult(success: false, message: '待调度需求不存在');
    }
    if (vehicle == null || vehicle.status != VehicleStatus.idle) {
      return const AdminActionResult(success: false, message: '请选择空闲车辆');
    }
    if (driver == null) {
      return const AdminActionResult(success: false, message: '请选择司机');
    }
    if (driver.boundVehicleId != null && driver.boundVehicleId != vehicle.id) {
      return const AdminActionResult(success: false, message: '司机已绑定其他车辆');
    }
    if (vehicle.seatCount < demand.passengerCount) {
      return const AdminActionResult(success: false, message: '车辆座位数不足');
    }

    var plan = _buildDispatchPlan(
      demand: demand,
      vehicle: vehicle,
      driver: driver,
      isAiGenerated: false,
    );
    if (BackendConfig.useSupabase) {
      try {
        final persistedPlans = await ref
            .read(supabaseAdminRepositoryProvider)
            .createDispatchPlans([plan]);
        plan = persistedPlans.firstOrNull ?? plan;
      } catch (_) {
        return const AdminActionResult(success: false, message: '人工调度方案保存失败');
      }
    }

    state = state.copyWith(
      dispatchPlans: [
        ...state.confirmedDispatchPlans,
        ...state.pendingDispatchPlans.where(
          (item) => item.demandId != demandId,
        ),
        plan,
      ],
    );
    return const AdminActionResult(success: true, message: '人工调度方案已生成');
  }

  Future<AdminActionResult> confirmDispatchPlan(String planId) async {
    final planIndex = state.dispatchPlans.indexWhere(
      (plan) => plan.id == planId,
    );
    if (planIndex < 0) {
      return const AdminActionResult(success: false, message: '调度方案不存在');
    }

    final plan = state.dispatchPlans[planIndex];
    if (plan.isConfirmed) {
      return const AdminActionResult(success: false, message: '调度方案已确认');
    }

    final demandIndex = state.dispatchDemands.indexWhere(
      (demand) => demand.id == plan.demandId,
    );
    final vehicleIndex = state.vehicles.indexWhere(
      (vehicle) => vehicle.id == plan.vehicleId,
    );
    final driverIndex = state.drivers.indexWhere(
      (driver) => driver.id == plan.driverId,
    );

    if (demandIndex < 0 || vehicleIndex < 0 || driverIndex < 0) {
      return const AdminActionResult(success: false, message: '调度数据不完整');
    }

    final vehicle = state.vehicles[vehicleIndex];
    if (vehicle.status != VehicleStatus.idle) {
      return const AdminActionResult(success: false, message: '车辆当前不可调度');
    }

    final nextPlans = [...state.dispatchPlans];
    nextPlans[planIndex] = plan.copyWith(isConfirmed: true);

    final nextDemands = [...state.dispatchDemands];
    nextDemands[demandIndex] = nextDemands[demandIndex].copyWith(
      status: DispatchDemandStatus.assigned,
    );

    final nextVehicles = [...state.vehicles];
    nextVehicles[vehicleIndex] = vehicle.copyWith(
      status: VehicleStatus.running,
    );

    final nextDrivers = [...state.drivers];
    final driver = nextDrivers[driverIndex];
    if (driver.boundVehicleId == null) {
      nextDrivers[driverIndex] = driver.copyWith(
        boundVehicleId: plan.vehicleId,
      );
    }

    final location = VehicleLocationModel(
      vehicleId: plan.vehicleId,
      tripNo: plan.id,
      driverId: plan.driverId,
      lat: 31.2240 + state.locations.length * 0.002,
      lng: 121.4690 + state.locations.length * 0.002,
      speed: 0,
      updatedAt: DateTime.now(),
    );

    if (BackendConfig.useSupabase) {
      try {
        final snapshot = await ref
            .read(supabaseAdminRepositoryProvider)
            .confirmDispatchPlan(
              plan: plan,
              location: location,
              shouldBindDriver: driver.boundVehicleId == null,
            );
        state = state.copyWith(
          vehicles: snapshot.vehicles,
          drivers: snapshot.drivers,
          dispatchDemands: snapshot.dispatchDemands,
          dispatchPlans: snapshot.dispatchPlans,
          locations: snapshot.locations,
          selectedVehicleId: plan.vehicleId,
        );
        return const AdminActionResult(success: true, message: '调度方案已确认并生效');
      } catch (_) {
        return const AdminActionResult(success: false, message: '调度方案确认失败');
      }
    }

    state = state.copyWith(
      vehicles: nextVehicles,
      drivers: nextDrivers,
      dispatchDemands: nextDemands,
      dispatchPlans: nextPlans,
      locations: [
        location,
        ...state.locations.where((item) => item.vehicleId != plan.vehicleId),
      ],
      selectedVehicleId: plan.vehicleId,
    );
    return const AdminActionResult(success: true, message: '调度方案已确认并生效');
  }

  AdminActionResult _validateVehicleBinding(
    String? driverId,
    String? vehicleId,
  ) {
    if (vehicleId == null) {
      return const AdminActionResult(success: true, message: '');
    }
    if (state.vehicleById(vehicleId) == null) {
      return const AdminActionResult(success: false, message: '绑定车辆不存在');
    }
    final alreadyBound = state.drivers.any(
      (driver) => driver.id != driverId && driver.boundVehicleId == vehicleId,
    );
    if (alreadyBound) {
      return const AdminActionResult(success: false, message: '车辆已绑定其他司机');
    }
    return const AdminActionResult(success: true, message: '');
  }

  void _stopLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  List<_VehicleDriverPair> _availableVehicleDriverPairs() {
    return state.vehicles
        .where((vehicle) => vehicle.status == VehicleStatus.idle)
        .map((vehicle) {
          final driver = state.driverForVehicle(vehicle.id);
          if (driver == null) {
            return null;
          }
          return _VehicleDriverPair(vehicle: vehicle, driver: driver);
        })
        .whereType<_VehicleDriverPair>()
        .toList();
  }

  DispatchPlanModel _buildDispatchPlan({
    required DispatchDemandModel demand,
    required VehicleModel vehicle,
    required AdminDriverModel driver,
    required bool isAiGenerated,
  }) {
    return DispatchPlanModel(
      id: 'dispatch-${isAiGenerated ? 'ai' : 'manual'}-${DateTime.now().microsecondsSinceEpoch}-${demand.id}',
      demandId: demand.id,
      routeName: demand.routeName,
      vehicleId: vehicle.id,
      driverId: driver.id,
      passengerCount: demand.passengerCount,
      departureTime: demand.departureTime,
      loadRate: demand.passengerCount / vehicle.seatCount,
      isAiGenerated: isAiGenerated,
      isConfirmed: false,
    );
  }

  Future<void> _loadSupabaseSnapshot() async {
    try {
      final snapshot = await ref
          .read(supabaseAdminRepositoryProvider)
          .fetchSnapshot();
      state = state.copyWith(
        vehicles: snapshot.vehicles,
        drivers: snapshot.drivers,
        locations: snapshot.locations,
        dispatchDemands: snapshot.dispatchDemands,
        dispatchPlans: snapshot.dispatchPlans,
        selectedVehicleId: snapshot.locations.firstOrNull?.vehicleId,
      );
    } catch (_) {
      // Keep Mock state visible if Supabase is unreachable.
    }
  }

  Future<void> _persistAddVehicle(VehicleModel vehicle) async {
    try {
      await ref
          .read(supabaseAdminRepositoryProvider)
          .addVehicle(
            plateNo: vehicle.plateNo,
            model: vehicle.model,
            seatCount: vehicle.seatCount,
            status: vehicle.status,
          );
      await _loadSupabaseSnapshot();
    } catch (_) {}
  }

  Future<void> _persistUpdateVehicle(VehicleModel vehicle) async {
    try {
      await ref.read(supabaseAdminRepositoryProvider).updateVehicle(vehicle);
      await _loadSupabaseSnapshot();
    } catch (_) {}
  }

  Future<void> _persistDeleteVehicle(String vehicleId) async {
    try {
      await ref.read(supabaseAdminRepositoryProvider).deleteVehicle(vehicleId);
      await _loadSupabaseSnapshot();
    } catch (_) {}
  }

  Future<void> _persistAddDriver(AdminDriverModel driver) async {
    try {
      await ref
          .read(supabaseAdminRepositoryProvider)
          .addDriver(
            name: driver.name,
            phone: driver.phone,
            licenseNo: driver.licenseNo,
            boundVehicleId: driver.boundVehicleId,
          );
      await _loadSupabaseSnapshot();
    } catch (_) {}
  }

  Future<void> _persistUpdateDriver(AdminDriverModel driver) async {
    try {
      await ref.read(supabaseAdminRepositoryProvider).updateDriver(driver);
      await _loadSupabaseSnapshot();
    } catch (_) {}
  }

  Future<void> _persistDeleteDriver(String driverId) async {
    try {
      await ref.read(supabaseAdminRepositoryProvider).deleteDriver(driverId);
      await _loadSupabaseSnapshot();
    } catch (_) {}
  }

  Future<void> _persistVehicleLocations(
    List<VehicleLocationModel> locations,
  ) async {
    try {
      await ref
          .read(supabaseAdminRepositoryProvider)
          .insertVehicleLocations(locations);
    } catch (_) {}
  }
}

class _VehicleDriverPair {
  const _VehicleDriverPair({required this.vehicle, required this.driver});

  final VehicleModel vehicle;
  final AdminDriverModel driver;
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
