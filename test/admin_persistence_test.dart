import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus_app/core/models/analytics_model.dart';
import 'package:school_bus_app/core/models/dispatch_model.dart';
import 'package:school_bus_app/core/models/vehicle_model.dart';
import 'package:school_bus_app/core/persistence/demo_persistence.dart';
import 'package:school_bus_app/features/admin/providers/admin_provider.dart';

void main() {
  test(
    'a stale vehicle form cannot revert a newly confirmed dispatch',
    () async {
      final store = _store();
      final first = _container(store);
      final second = _container(store);
      final editor = first.read(adminProvider.notifier);
      final initialVehicle = first.read(adminProvider).vehicleById('bus-002')!;
      final dispatcher = second.read(adminProvider.notifier);
      expect(
        (await dispatcher.createManualDispatchPlan(
          demandId: 'demand-001',
          vehicleId: 'bus-002',
          driverId: 'driver-002',
        )).success,
        isTrue,
      );
      final plan = second.read(adminProvider).pendingDispatchPlans.single;
      expect((await dispatcher.confirmDispatchPlan(plan.id)).success, isTrue);
      final snapshot = store.read('admin');
      final writes = store.writes;

      final result = editor.updateVehicle(
        initialVehicle.copyWith(model: '旧表单的修改'),
        expectedVehicle: initialVehicle,
      );

      expect(result.success, isFalse);
      expect(result.message, '车辆信息已变化，请重新打开编辑');
      final current = first.read(adminProvider).vehicleById('bus-002')!;
      expect(current.status, VehicleStatus.running);
      expect(current.model, initialVehicle.model);
      expect(
        first.read(adminProvider).confirmedDispatchPlans.single.id,
        plan.id,
      );
      expect(store.read('admin'), snapshot);
      expect(store.writes, writes);
    },
  );

  test('a stale driver form cannot replace a newer vehicle binding', () {
    final store = _store();
    final first = _container(store);
    final second = _container(store);
    final editor = first.read(adminProvider.notifier);
    final initialDriver = first.read(adminProvider).driverById('driver-002')!;
    final otherEditor = second.read(adminProvider.notifier);
    expect(
      otherEditor
          .updateDriver(
            initialDriver.copyWith(boundVehicleId: 'bus-004'),
            expectedDriver: initialDriver,
          )
          .success,
      isTrue,
    );
    final snapshot = store.read('admin');
    final writes = store.writes;

    final result = editor.updateDriver(
      initialDriver.copyWith(name: '旧表单的姓名'),
      expectedDriver: initialDriver,
    );

    expect(result.success, isFalse);
    expect(result.message, '司机信息已变化，请重新打开编辑');
    final current = first.read(adminProvider).driverById('driver-002')!;
    expect(current.boundVehicleId, 'bus-004');
    expect(current.name, initialDriver.name);
    expect(store.read('admin'), snapshot);
    expect(store.writes, writes);
  });

  test('editing validates normalized vehicle and driver fields', () {
    final store = _store();
    final container = _container(store);
    final controller = container.read(adminProvider.notifier);
    final before = container.read(adminProvider);
    final vehicle = before.vehicleById('bus-002')!;
    final driver = before.driverById('driver-002')!;
    final writes = store.writes;
    for (final invalid in [
      vehicle.copyWith(plateNo: '  '),
      vehicle.copyWith(model: '  '),
      vehicle.copyWith(seatCount: 0),
    ]) {
      expect(controller.updateVehicle(invalid).success, isFalse);
    }
    for (final invalid in [
      driver.copyWith(name: '  '),
      driver.copyWith(phone: '  '),
      driver.copyWith(licenseNo: '  '),
    ]) {
      expect(controller.updateDriver(invalid).success, isFalse);
    }
    expect(container.read(adminProvider), same(before));
    expect(store.writes, writes);

    expect(
      controller
          .updateVehicle(
            vehicle.copyWith(plateNo: ' 校A·规范车 ', model: ' 新车型 '),
            expectedVehicle: vehicle,
          )
          .success,
      isTrue,
    );
    expect(
      controller
          .updateDriver(
            driver.copyWith(
              name: ' 新姓名 ',
              phone: ' 13800001111 ',
              licenseNo: ' A1-NEW ',
            ),
            expectedDriver: driver,
          )
          .success,
      isTrue,
    );
    expect(
      container.read(adminProvider).vehicleById(vehicle.id)!.plateNo,
      '校A·规范车',
    );
    expect(container.read(adminProvider).vehicleById(vehicle.id)!.model, '新车型');
    expect(container.read(adminProvider).driverById(driver.id)!.name, '新姓名');
    expect(
      container.read(adminProvider).driverById(driver.id)!.phone,
      '13800001111',
    );
    expect(
      container.read(adminProvider).driverById(driver.id)!.licenseNo,
      'A1-NEW',
    );
  });

  test('sequential writes from stale containers preserve both additions', () {
    final store = _store();
    final first = _container(store);
    final second = _container(store);
    final firstController = first.read(adminProvider.notifier);
    final secondController = second.read(adminProvider.notifier);
    expect(
      firstController
          .addVehicle(
            plateNo: '校A·标签页甲',
            model: '甲车',
            seatCount: 30,
            status: VehicleStatus.idle,
          )
          .success,
      isTrue,
    );
    // Memory writes deliberately do not emit storage events to the other tab.
    expect(second.read(adminProvider).vehicles, hasLength(4));

    expect(
      secondController
          .addVehicle(
            plateNo: '校A·标签页乙',
            model: '乙车',
            seatCount: 35,
            status: VehicleStatus.idle,
          )
          .success,
      isTrue,
    );

    final restored = _container(store).read(adminProvider);
    expect(restored.vehicles, hasLength(6));
    expect(
      restored.vehicles.map((vehicle) => vehicle.plateNo),
      containsAll(['校A·标签页甲', '校A·标签页乙']),
    );
  });

  for (final changedResource in ['capacity', 'driver']) {
    test(
      'confirmation refreshes $changedResource before a storage event',
      () async {
        final store = _store();
        final container = _container(store);
        final controller = container.read(adminProvider.notifier);
        expect(
          (await controller.createManualDispatchPlan(
            demandId: 'demand-001',
            vehicleId: 'bus-002',
            driverId: 'driver-002',
          )).success,
          isTrue,
        );
        final plan = container.read(adminProvider).pendingDispatchPlans.single;
        final snapshot = store.read('admin')!;
        if (changedResource == 'capacity') {
          final vehicles = (snapshot['vehicles'] as List)
              .cast<Map<String, Object?>>();
          vehicles.singleWhere(
            (vehicle) => vehicle['id'] == 'bus-002',
          )['seatCount'] = 5;
        } else {
          final drivers = (snapshot['drivers'] as List)
              .cast<Map<String, Object?>>();
          drivers.singleWhere(
            (driver) => driver['id'] == 'driver-002',
          )['boundVehicleId'] = 'bus-004';
        }
        store.write('admin', snapshot);
        final writes = store.writes;

        final result = await controller.confirmDispatchPlan(plan.id);

        expect(result.success, isFalse);
        expect(
          result.message,
          changedResource == 'capacity' ? '车辆座位数不足' : '司机已绑定其他车辆',
        );
        expect(container.read(adminProvider).confirmedDispatchPlans, isEmpty);
        expect(
          container.read(adminProvider).pendingDispatchDemands,
          hasLength(3),
        );
        expect(store.writes, writes);
        expect(store.read('admin'), snapshot);
      },
    );
  }

  test(
    'a new container restores fleet, drivers and confirmed dispatch',
    () async {
      final store = _store();
      final first = _container(store);
      final controller = first.read(adminProvider.notifier);
      final departure = first
          .read(adminProvider)
          .dispatchDemands
          .first
          .departureTime;
      expect(
        controller
            .addVehicle(
              plateNo: '校A·测试持久化',
              model: '测试车辆',
              seatCount: 42,
              status: VehicleStatus.idle,
            )
            .success,
        isTrue,
      );
      final newVehicle = first.read(adminProvider).vehicles.first;
      expect(
        controller
            .addDriver(
              name: '测试司机',
              phone: '13812345678',
              licenseNo: 'A1-PERSISTENCE',
              boundVehicleId: newVehicle.id,
            )
            .success,
        isTrue,
      );
      expect(
        (await controller.createManualDispatchPlan(
          demandId: 'demand-001',
          vehicleId: 'bus-002',
          driverId: 'driver-002',
        )).success,
        isTrue,
      );
      final plan = first.read(adminProvider).pendingDispatchPlans.single;
      controller.selectAnalyticsPeriod(AnalyticsPeriod.month);
      expect((await controller.confirmDispatchPlan(plan.id)).success, isTrue);

      final second = _container(store);
      final restored = second.read(adminProvider);

      expect(restored.vehicleById(newVehicle.id)!.plateNo, '校A·测试持久化');
      expect(
        restored.driverForVehicle(newVehicle.id)!.licenseNo,
        'A1-PERSISTENCE',
      );
      expect(restored.vehicleById('bus-002')!.status, VehicleStatus.running);
      expect(restored.confirmedDispatchPlans.single.id, plan.id);
      expect(
        restored.dispatchDemands.first.status,
        DispatchDemandStatus.assigned,
      );
      expect(restored.dispatchDemands.first.departureTime, departure);
      expect(restored.selectedVehicleId, 'bus-002');
      expect(restored.selectedAnalyticsPeriod, AnalyticsPeriod.month);
      expect(restored.locationForVehicle('bus-002')!.tripNo, plan.id);
      expect(store.read('admin')!.containsKey('locations'), isFalse);
      expect(store.read('admin')!.containsKey('analytics'), isFalse);
    },
  );

  test('initial seeding gives containers identical demand departure times', () {
    final store = _store();
    final first = _container(store).read(adminProvider);
    final second = _container(store).read(adminProvider);

    expect(store.read('admin'), isNotNull);
    expect(
      second.dispatchDemands.map((demand) => demand.departureTime),
      first.dispatchDemands.map((demand) => demand.departureTime),
    );
  });

  test(
    'external dispatch updates business data without echoing local positions',
    () async {
      final receivingStore = _store();
      final receiving = _container(receivingStore);
      final controller = receiving.read(adminProvider.notifier);
      controller.selectVehicle('bus-003');
      controller.selectAnalyticsPeriod(AnalyticsPeriod.week);
      controller.simulateLocationTick();
      final localPosition = receiving
          .read(adminProvider)
          .locationForVehicle('bus-001');

      final sendingStore = _store();
      sendingStore.write('admin', receivingStore.read('admin')!);
      final sending = _container(sendingStore);
      final sender = sending.read(adminProvider.notifier);
      expect(sender.deleteVehicle('bus-004').success, isTrue);
      expect(
        (await sender.createManualDispatchPlan(
          demandId: 'demand-001',
          vehicleId: 'bus-002',
          driverId: 'driver-002',
        )).success,
        isTrue,
      );
      final plan = sending.read(adminProvider).pendingDispatchPlans.single;
      expect((await sender.confirmDispatchPlan(plan.id)).success, isTrue);
      final snapshot = sendingStore.read('admin')!;
      final writes = receivingStore.writes;

      receivingStore.receiveExternal('admin', snapshot);

      final updated = receiving.read(adminProvider);
      expect(updated.vehicleById('bus-004'), isNull);
      expect(updated.confirmedDispatchPlans.single.id, plan.id);
      expect(updated.locationForVehicle('bus-002')!.driverId, 'driver-002');
      expect(updated.locationForVehicle('bus-001'), same(localPosition));
      expect(updated.selectedVehicleId, 'bus-003');
      expect(updated.selectedAnalyticsPeriod, AnalyticsPeriod.week);
      expect(receivingStore.writes, writes + 1);
      expect(receivingStore.read('admin'), snapshot);
    },
  );

  test(
    'position and selection updates cannot overwrite a newer stored fleet',
    () {
      final store = _store();
      final container = _container(store);
      final controller = container.read(adminProvider.notifier);
      final snapshot = store.read('admin')!;
      final rows = (snapshot['vehicles'] as List).cast<Map<String, Object?>>();
      rows.first['model'] = '来自另一个标签页的更新';
      // The storage event may arrive after an already scheduled timer tick.
      store.write('admin', snapshot);
      final writes = store.writes;

      controller.simulateLocationTick();
      controller.selectVehicle('bus-003');
      controller.selectAnalyticsPeriod(AnalyticsPeriod.month);

      expect(store.writes, writes);
      expect(
        (store.read('admin')!['vehicles'] as List).first['model'],
        '来自另一个标签页的更新',
      );
      store.receiveExternal('admin', snapshot);
      expect(
        container.read(adminProvider).vehicleById('bus-001')!.model,
        '来自另一个标签页的更新',
      );
    },
  );

  for (final corrupt in <Map<String, Object?>>[
    {'version': 1, 'vehicles': 'broken'},
    {'version': 999},
  ]) {
    test('invalid snapshot falls back safely: $corrupt', () {
      final store = _store();
      store.write('admin', corrupt);

      final state = _container(store).read(adminProvider);

      expect(state.vehicles, hasLength(4));
      expect(state.drivers, hasLength(3));
      expect(state.dispatchDemands, hasLength(3));
      expect(state.dispatchPlans, isEmpty);
      expect(store.read('admin')!['version'], 1);
      expect(store.read('admin')!['vehicles'], isA<List>());
    });
  }

  test(
    'an invalid external snapshot preserves current local business data',
    () {
      final store = _store();
      final container = _container(store);
      final controller = container.read(adminProvider.notifier);
      controller.addVehicle(
        plateNo: '校A·保留',
        model: '测试车辆',
        seatCount: 20,
        status: VehicleStatus.idle,
      );
      final before = container.read(adminProvider);
      final writes = store.writes;

      store.receiveExternal('admin', {'version': 1, 'drivers': false});

      expect(container.read(adminProvider), same(before));
      expect(store.writes, writes + 1);
    },
  );

  test('invalid duplicated driver bindings fall back to the demo seed', () {
    final store = _store();
    _container(store).read(adminProvider);
    final snapshot = store.read('admin')!;
    final drivers = (snapshot['drivers'] as List).cast<Map<String, Object?>>();
    drivers[1]['boundVehicleId'] = drivers[0]['boundVehicleId'];
    store.write('admin', snapshot);

    final restored = _container(store).read(adminProvider);

    expect(restored.driverById('driver-001')!.boundVehicleId, 'bus-001');
    expect(restored.driverById('driver-002')!.boundVehicleId, 'bus-002');
  });

  test(
    'clearing demo data resets the active controller and reseeds storage',
    () {
      final store = _store();
      final container = _container(store);
      final controller = container.read(adminProvider.notifier);
      expect(controller.deleteVehicle('bus-004').success, isTrue);
      expect(container.read(adminProvider).vehicleById('bus-004'), isNull);

      store.clear();

      expect(container.read(adminProvider).vehicleById('bus-004'), isNotNull);
      expect(container.read(adminProvider).dispatchPlans, isEmpty);
      expect(store.read('admin'), isNotNull);
    },
  );

  test('a disposed container no longer consumes external events', () {
    final store = _store();
    final container = ProviderContainer(
      overrides: [demoPersistenceProvider.overrideWithValue(store)],
    );
    container.read(adminProvider);
    final snapshot = store.read('admin')!;
    container.dispose();
    final writes = store.writes;

    expect(() => store.receiveExternal('admin', snapshot), returnsNormally);
    expect(store.writes, writes + 1);
  });
}

ProviderContainer _container(DemoPersistence store) {
  final container = ProviderContainer(
    overrides: [demoPersistenceProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

_CountingPersistence _store() {
  final store = _CountingPersistence();
  addTearDown(store.dispose);
  return store;
}

class _CountingPersistence extends MemoryDemoPersistence {
  int writes = 0;

  @override
  void write(String key, Map<String, Object?> value) {
    writes += 1;
    super.write(key, value);
  }
}
