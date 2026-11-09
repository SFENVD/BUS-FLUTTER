import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus_app/core/models/admin_driver_model.dart';
import 'package:school_bus_app/core/models/dispatch_model.dart';
import 'package:school_bus_app/core/models/vehicle_location_model.dart';
import 'package:school_bus_app/core/models/vehicle_model.dart';
import 'package:school_bus_app/features/admin/data/mock_admin_repository.dart';
import 'package:school_bus_app/features/admin/providers/admin_provider.dart';

final _start = DateTime.utc(2030, 1, 1, 8);

void main() {
  test(
    'manual dispatch cannot bind a second driver to an occupied vehicle',
    () async {
      final fixture = _AdminFixture();
      final before = fixture.state;

      final result = await fixture.controller.createManualDispatchPlan(
        demandId: 'demand-a',
        vehicleId: 'bus-a',
        driverId: 'driver-b',
      );

      expect(result.success, isFalse);
      expect(result.message, '车辆已绑定其他司机');
      expect(fixture.state, same(before));
    },
  );

  test('manual suggestion binds a free driver only when confirmed', () async {
    final fixture = _AdminFixture();
    final plan = await fixture.plan(vehicleId: 'bus-b', driverId: 'driver-b');

    expect(fixture.state.driverById('driver-b')!.boundVehicleId, isNull);
    expect(fixture.state.vehicleById('bus-b')!.status, VehicleStatus.idle);
    expect(fixture.state.pendingDispatchDemands, hasLength(2));

    final result = await fixture.controller.confirmDispatchPlan(plan.id);

    expect(result.success, isTrue);
    expect(fixture.state.driverById('driver-b')!.boundVehicleId, 'bus-b');
    expect(fixture.state.vehicleById('bus-b')!.status, VehicleStatus.running);
    expect(fixture.state.confirmedDispatchPlans.single.id, plan.id);
    expect(fixture.state.pendingDispatchDemands.single.id, 'demand-b');
    expect(fixture.state.locationForVehicle('bus-b')!.driverId, 'driver-b');
  });

  test(
    'confirmation rejects a capacity reduction after the suggestion',
    () async {
      final fixture = _AdminFixture();
      final plan = await fixture.plan();
      fixture.controller.updateVehicle(
        fixture.state.vehicleById('bus-a')!.copyWith(seatCount: 10),
      );
      final before = fixture.state;

      final result = await fixture.controller.confirmDispatchPlan(plan.id);

      expect(result.success, isFalse);
      expect(result.message, '车辆座位数不足');
      expect(fixture.state, same(before));
    },
  );

  test('confirmation uses the current capacity for load rate', () async {
    final fixture = _AdminFixture();
    final plan = await fixture.plan();
    fixture.controller.updateVehicle(
      fixture.state.vehicleById('bus-a')!.copyWith(seatCount: 50),
    );

    final result = await fixture.controller.confirmDispatchPlan(plan.id);

    expect(result.success, isTrue);
    expect(fixture.state.confirmedDispatchPlans.single.loadRate, 0.4);
  });

  test(
    'confirmation rejects a vehicle newly bound to another driver',
    () async {
      final fixture = _AdminFixture();
      final plan = await fixture.plan();
      expect(
        fixture.controller
            .updateDriver(
              fixture.state
                  .driverById('driver-a')!
                  .copyWith(clearBoundVehicle: true),
            )
            .success,
        isTrue,
      );
      expect(
        fixture.controller
            .updateDriver(
              fixture.state
                  .driverById('driver-b')!
                  .copyWith(boundVehicleId: 'bus-a'),
            )
            .success,
        isTrue,
      );
      final before = fixture.state;

      final result = await fixture.controller.confirmDispatchPlan(plan.id);

      expect(result.success, isFalse);
      expect(result.message, '车辆已绑定其他司机');
      expect(fixture.state, same(before));
    },
  );

  test(
    'confirmation rejects a driver rebound to a different vehicle',
    () async {
      final fixture = _AdminFixture();
      final plan = await fixture.plan();
      expect(
        fixture.controller
            .updateDriver(
              fixture.state
                  .driverById('driver-a')!
                  .copyWith(boundVehicleId: 'bus-b'),
            )
            .success,
        isTrue,
      );
      final before = fixture.state;

      final result = await fixture.controller.confirmDispatchPlan(plan.id);

      expect(result.success, isFalse);
      expect(result.message, '司机已绑定其他车辆');
      expect(fixture.state, same(before));
    },
  );

  test(
    'only the first suggestion sharing a vehicle can be confirmed',
    () async {
      final fixture = _AdminFixture();
      final first = await fixture.plan();
      final second = await fixture.plan(demandId: 'demand-b');
      expect(
        (await fixture.controller.confirmDispatchPlan(first.id)).success,
        isTrue,
      );
      final before = fixture.state;

      final result = await fixture.controller.confirmDispatchPlan(second.id);

      expect(result.success, isFalse);
      expect(fixture.state, same(before));
      expect(fixture.state.confirmedDispatchPlans.single.id, first.id);
      expect(fixture.state.pendingDispatchDemands.single.id, 'demand-b');
    },
  );

  test(
    'only the first suggestion sharing an unbound driver can be confirmed',
    () async {
      final fixture = _AdminFixture();
      fixture.controller.updateDriver(
        fixture.state.driverById('driver-a')!.copyWith(clearBoundVehicle: true),
      );
      final first = await fixture.plan();
      final second = await fixture.plan(
        demandId: 'demand-b',
        vehicleId: 'bus-b',
      );
      expect(
        (await fixture.controller.confirmDispatchPlan(first.id)).success,
        isTrue,
      );
      final before = fixture.state;

      final result = await fixture.controller.confirmDispatchPlan(second.id);

      expect(result.success, isFalse);
      expect(result.message, '司机正在执行其他调度任务');
      expect(fixture.state, same(before));
      expect(fixture.state.vehicleById('bus-b')!.status, VehicleStatus.idle);
    },
  );

  test('a running driver cannot be unbound or rebound through editing', () {
    final fixture = _AdminFixture();
    final before = fixture.state;
    final driver = fixture.state.driverById('driver-c')!;

    for (final changed in [
      driver.copyWith(clearBoundVehicle: true),
      driver.copyWith(boundVehicleId: 'bus-b'),
    ]) {
      final result = fixture.controller.updateDriver(changed);
      expect(result.success, isFalse);
      expect(result.message, '在途司机不可更换绑定车辆');
      expect(fixture.state, same(before));
    }
  });

  test(
    'manual dispatch rejects a driver tracked on another running vehicle',
    () async {
      final fixture = _AdminFixture(
        repository: _DispatchRepository(
          locations: [
            VehicleLocationModel(
              vehicleId: 'bus-c',
              tripNo: 'running-trip',
              driverId: 'driver-b',
              lat: 31.2,
              lng: 121.4,
              speed: 30,
              updatedAt: _start,
            ),
          ],
        ),
      );
      final before = fixture.state;

      final result = await fixture.controller.createManualDispatchPlan(
        demandId: 'demand-a',
        vehicleId: 'bus-b',
        driverId: 'driver-b',
      );

      expect(result.success, isFalse);
      expect(result.message, '司机正在执行其他调度任务');
      expect(fixture.state, same(before));
    },
  );

  test('manual creation and AI generation reject departed demands', () async {
    final fixture = _AdminFixture();
    fixture.now = _start.add(const Duration(hours: 3));
    final before = fixture.state;

    final manual = await fixture.controller.createManualDispatchPlan(
      demandId: 'demand-a',
      vehicleId: 'bus-a',
      driverId: 'driver-a',
    );
    final automatic = await fixture.controller.generateAiDispatchPlans();

    expect(manual.success, isFalse);
    expect(manual.message, '需求已到发车时间，请重新安排');
    expect(automatic.success, isFalse);
    expect(fixture.state, same(before));
  });

  test('a suggestion expires exactly at the departure time', () async {
    final fixture = _AdminFixture();
    final plan = await fixture.plan();
    fixture.now = plan.departureTime;
    final before = fixture.state;

    final result = await fixture.controller.confirmDispatchPlan(plan.id);

    expect(result.success, isFalse);
    expect(result.message, '需求已到发车时间，请重新安排');
    expect(fixture.state, same(before));
  });

  test(
    'a restored stale suggestion cannot reassign an assigned demand',
    () async {
      final source = _AdminFixture();
      final stalePlan = await source.plan();
      final restored = _AdminFixture(
        restore: (initial) => initial.copyWith(
          dispatchPlans: [stalePlan],
          dispatchDemands: initial.dispatchDemands.map((demand) {
            return demand.id == stalePlan.demandId
                ? demand.copyWith(status: DispatchDemandStatus.assigned)
                : demand;
          }).toList(),
        ),
      );
      final before = restored.state;

      final result = await restored.controller.confirmDispatchPlan(
        stalePlan.id,
      );

      expect(result.success, isFalse);
      expect(result.message, '需求已调度，请勿重复确认');
      expect(restored.state, same(before));
    },
  );

  test(
    'a restored suggestion must still describe the current demand',
    () async {
      final source = _AdminFixture();
      final stalePlan = await source.plan();
      final restored = _AdminFixture(
        repository: _DispatchRepository(
          demands: [_demand('demand-a', passengers: 30)],
        ),
        restore: (initial) => initial.copyWith(dispatchPlans: [stalePlan]),
      );
      final before = restored.state;

      final result = await restored.controller.confirmDispatchPlan(
        stalePlan.id,
      );

      expect(result.success, isFalse);
      expect(result.message, '需求已变更，请重新生成调度方案');
      expect(restored.state, same(before));
    },
  );

  test(
    'AI suggestions use each eligible vehicle and driver at most once',
    () async {
      final fixture = _AdminFixture();
      fixture.controller.updateDriver(
        fixture.state.driverById('driver-b')!.copyWith(boundVehicleId: 'bus-b'),
      );

      final result = await fixture.controller.generateAiDispatchPlans();

      expect(result.success, isTrue);
      final plans = fixture.state.pendingDispatchPlans;
      expect(plans, hasLength(2));
      expect(plans.map((plan) => plan.vehicleId).toSet(), hasLength(2));
      expect(plans.map((plan) => plan.driverId).toSet(), hasLength(2));
      expect(fixture.state.confirmedDispatchPlans, isEmpty);
      expect(fixture.state.pendingDispatchDemands, hasLength(2));
      expect(fixture.state.idleVehicleCount, 2);
    },
  );
}

class _AdminFixture {
  _AdminFixture({
    MockAdminRepository? repository,
    AdminState Function(AdminState)? restore,
  }) {
    container = ProviderContainer(
      overrides: [
        mockAdminRepositoryProvider.overrideWithValue(
          repository ?? _DispatchRepository(),
        ),
        adminClockProvider.overrideWithValue(() => now),
        if (restore != null)
          adminProvider.overrideWith(() => _RestoredAdminController(restore)),
      ],
    );
    addTearDown(container.dispose);
  }

  DateTime now = _start;
  late final ProviderContainer container;
  AdminController get controller => container.read(adminProvider.notifier);
  AdminState get state => container.read(adminProvider);

  Future<DispatchPlanModel> plan({
    String demandId = 'demand-a',
    String vehicleId = 'bus-a',
    String driverId = 'driver-a',
  }) async {
    final result = await controller.createManualDispatchPlan(
      demandId: demandId,
      vehicleId: vehicleId,
      driverId: driverId,
    );
    expect(result.success, isTrue, reason: result.message);
    return state.pendingDispatchPlans.singleWhere(
      (plan) => plan.demandId == demandId,
    );
  }
}

class _RestoredAdminController extends AdminController {
  _RestoredAdminController(this.restore);

  final AdminState Function(AdminState) restore;

  @override
  AdminState build() => restore(super.build());
}

class _DispatchRepository extends MockAdminRepository {
  _DispatchRepository({this.demands, this.locations = const []});

  final List<DispatchDemandModel>? demands;
  final List<VehicleLocationModel> locations;

  @override
  List<VehicleModel> fetchVehicles() => const [
    VehicleModel(
      id: 'bus-a',
      plateNo: '校A·001',
      model: '测试车',
      seatCount: 40,
      status: VehicleStatus.idle,
    ),
    VehicleModel(
      id: 'bus-b',
      plateNo: '校A·002',
      model: '测试车',
      seatCount: 40,
      status: VehicleStatus.idle,
    ),
    VehicleModel(
      id: 'bus-c',
      plateNo: '校A·003',
      model: '测试车',
      seatCount: 40,
      status: VehicleStatus.running,
    ),
  ];

  @override
  List<AdminDriverModel> fetchDrivers() => const [
    AdminDriverModel(
      id: 'driver-a',
      name: '甲',
      phone: '13800000011',
      licenseNo: 'A1-01',
      boundVehicleId: 'bus-a',
    ),
    AdminDriverModel(
      id: 'driver-b',
      name: '乙',
      phone: '13800000012',
      licenseNo: 'A1-02',
    ),
    AdminDriverModel(
      id: 'driver-c',
      name: '丙',
      phone: '13800000013',
      licenseNo: 'A1-03',
      boundVehicleId: 'bus-c',
    ),
  ];

  @override
  List<VehicleLocationModel> fetchLocations() => locations;

  @override
  List<DispatchDemandModel> fetchDispatchDemands() =>
      demands ??
      [_demand('demand-a'), _demand('demand-b', passengers: 10, hours: 2)];
}

DispatchDemandModel _demand(String id, {int passengers = 20, int hours = 1}) {
  return DispatchDemandModel(
    id: id,
    routeName: '测试路线',
    origin: '宿舍',
    destination: '教学楼',
    passengerCount: passengers,
    departureTime: _start.add(Duration(hours: hours)),
    status: DispatchDemandStatus.pending,
  );
}
