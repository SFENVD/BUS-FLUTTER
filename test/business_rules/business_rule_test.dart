import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus_app/core/models/admin_driver_model.dart';
import 'package:school_bus_app/core/models/app_mode.dart';
import 'package:school_bus_app/core/models/dispatch_model.dart';
import 'package:school_bus_app/core/models/vehicle_location_model.dart';
import 'package:school_bus_app/core/models/vehicle_model.dart';
import 'package:school_bus_app/features/admin/data/mock_admin_repository.dart';
import 'package:school_bus_app/features/admin/providers/admin_provider.dart';
import 'package:school_bus_app/features/auth/data/auth_repository.dart';
import 'package:school_bus_app/features/auth/data/mock_auth_repository.dart';
import 'package:school_bus_app/features/passenger/booking/providers/passenger_booking_provider.dart';

void main() {
  group('business rule negative tests', () {
    test('role entrance mismatch cannot login', () async {
      final repository = MockAuthRepository();

      await expectLater(
        repository.login(
          phone: '13800000001',
          password: '123456',
          mode: AppMode.driver,
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            contains('当前入口'),
          ),
        ),
      );
    });

    test('duplicate booking for the same trip is blocked', () async {
      final container = _container();
      final controller = container.read(passengerBookingProvider.notifier);

      final first = await controller.createBooking(
        userId: 'u-passenger-001',
        tripId: 'trip-001',
        seatNo: 19,
      );
      final second = await controller.createBooking(
        userId: 'u-passenger-001',
        tripId: 'trip-001',
        seatNo: 20,
      );

      expect(first.success, isTrue);
      expect(second.success, isFalse);
      expect(second.message, '你已预约该车次，请勿重复预约');
    });

    test('completed or cancelled bookings cannot be cancelled again', () async {
      final container = _container();
      final controller = container.read(passengerBookingProvider.notifier);

      final completed = await controller.cancelBooking('booking-legacy-001');
      final cancelled = await controller.cancelBooking('booking-legacy-002');

      expect(completed.success, isFalse);
      expect(completed.message, '只有待发车预约可以取消');
      expect(cancelled.success, isFalse);
      expect(cancelled.message, '只有待发车预约可以取消');
    });

    test('running vehicle cannot be deleted', () {
      final container = _container();
      final result = container
          .read(adminProvider.notifier)
          .deleteVehicle('bus-001');

      expect(result.success, isFalse);
      expect(result.message, '运行中车辆不可删除');
    });

    test('driver vehicle binding conflict is blocked', () {
      final container = _container();
      final result = container
          .read(adminProvider.notifier)
          .addDriver(
            name: '测试司机',
            phone: '13800008888',
            licenseNo: 'A1-TEST-8888',
            boundVehicleId: 'bus-002',
          );

      expect(result.success, isFalse);
      expect(result.message, '车辆已绑定其他司机');
    });

    test('manual dispatch with insufficient seats is blocked', () async {
      final container = ProviderContainer(
        overrides: [
          mockAdminRepositoryProvider.overrideWithValue(
            _InsufficientSeatAdminRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container
          .read(adminProvider.notifier)
          .createManualDispatchPlan(
            demandId: 'demand-large',
            vehicleId: 'bus-small',
            driverId: 'driver-small',
          );

      expect(result.success, isFalse);
      expect(result.message, '车辆座位数不足');
    });

    test('AI dispatch reports failure when no vehicle is available', () async {
      final container = ProviderContainer(
        overrides: [
          mockAdminRepositoryProvider.overrideWithValue(
            _NoAvailableVehicleAdminRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container
          .read(adminProvider.notifier)
          .generateAiDispatchPlans();

      expect(result.success, isFalse);
      expect(result.message, '没有可用于调度的空闲车辆和司机');
    });
  });
}

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

class _InsufficientSeatAdminRepository extends MockAdminRepository {
  @override
  List<VehicleModel> fetchVehicles() {
    return const [
      VehicleModel(
        id: 'bus-small',
        plateNo: '校A·0099',
        model: '测试小巴',
        seatCount: 10,
        status: VehicleStatus.idle,
      ),
    ];
  }

  @override
  List<AdminDriverModel> fetchDrivers() {
    return const [
      AdminDriverModel(
        id: 'driver-small',
        name: '小巴司机',
        phone: '13800007777',
        licenseNo: 'A1-TEST-7777',
        boundVehicleId: 'bus-small',
      ),
    ];
  }

  @override
  List<VehicleLocationModel> fetchLocations() {
    return const [];
  }

  @override
  List<DispatchDemandModel> fetchDispatchDemands() {
    return [
      DispatchDemandModel(
        id: 'demand-large',
        routeName: '大客流测试线',
        origin: '南门',
        destination: '教学楼',
        passengerCount: 36,
        departureTime: DateTime.now().add(const Duration(hours: 2)),
        status: DispatchDemandStatus.pending,
      ),
    ];
  }
}

class _NoAvailableVehicleAdminRepository extends MockAdminRepository {
  @override
  List<VehicleModel> fetchVehicles() {
    return const [];
  }

  @override
  List<AdminDriverModel> fetchDrivers() {
    return const [];
  }

  @override
  List<VehicleLocationModel> fetchLocations() {
    return const [];
  }

  @override
  List<DispatchDemandModel> fetchDispatchDemands() {
    return [
      DispatchDemandModel(
        id: 'demand-no-vehicle',
        routeName: '无车调度测试线',
        origin: '图书馆',
        destination: '科技园',
        passengerCount: 20,
        departureTime: DateTime.now().add(const Duration(hours: 2)),
        status: DispatchDemandStatus.pending,
      ),
    ];
  }
}
