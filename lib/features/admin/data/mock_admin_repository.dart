import '../../../core/models/admin_driver_model.dart';
import '../../../core/models/analytics_model.dart';
import '../../../core/models/dispatch_model.dart';
import '../../../core/models/vehicle_location_model.dart';
import '../../../core/models/vehicle_model.dart';

class MockAdminRepository {
  List<VehicleModel> fetchVehicles() {
    return const [
      VehicleModel(
        id: 'bus-001',
        plateNo: '校A·1028',
        model: '宇通 ZK6908',
        seatCount: 45,
        status: VehicleStatus.running,
      ),
      VehicleModel(
        id: 'bus-002',
        plateNo: '校A·2036',
        model: '金龙 XMQ6802',
        seatCount: 38,
        status: VehicleStatus.idle,
      ),
      VehicleModel(
        id: 'bus-003',
        plateNo: '校A·3099',
        model: '中通 LCK6720',
        seatCount: 32,
        status: VehicleStatus.running,
      ),
      VehicleModel(
        id: 'bus-004',
        plateNo: '校A·4017',
        model: '比亚迪 K8',
        seatCount: 28,
        status: VehicleStatus.maintenance,
      ),
    ];
  }

  List<AdminDriverModel> fetchDrivers() {
    return const [
      AdminDriverModel(
        id: 'driver-001',
        name: '王师傅',
        phone: '13800000002',
        licenseNo: 'A1-310101-8891',
        boundVehicleId: 'bus-001',
      ),
      AdminDriverModel(
        id: 'driver-002',
        name: '赵师傅',
        phone: '13800001002',
        licenseNo: 'A1-310101-2710',
        boundVehicleId: 'bus-002',
      ),
      AdminDriverModel(
        id: 'driver-003',
        name: '钱师傅',
        phone: '13800001003',
        licenseNo: 'A1-310101-5532',
        boundVehicleId: 'bus-003',
      ),
    ];
  }

  List<VehicleLocationModel> fetchLocations() {
    final now = DateTime.now();

    return [
      VehicleLocationModel(
        vehicleId: 'bus-001',
        tripNo: 'D-20260501-01',
        driverId: 'driver-001',
        lat: 31.2304,
        lng: 121.4737,
        speed: 32,
        updatedAt: now.subtract(const Duration(seconds: 12)),
      ),
      VehicleLocationModel(
        vehicleId: 'bus-003',
        tripNo: 'D-20260501-03',
        driverId: 'driver-003',
        lat: 31.2378,
        lng: 121.4821,
        speed: 28,
        updatedAt: now.subtract(const Duration(seconds: 21)),
      ),
    ];
  }

  List<DispatchDemandModel> fetchDispatchDemands() {
    final now = DateTime.now();

    return [
      DispatchDemandModel(
        id: 'demand-001',
        routeName: '大学城早班线',
        origin: '南门学生公寓',
        destination: '综合教学楼',
        passengerCount: 36,
        departureTime: now.add(const Duration(hours: 1, minutes: 20)),
        status: DispatchDemandStatus.pending,
      ),
      DispatchDemandModel(
        id: 'demand-002',
        routeName: '科技园通勤线',
        origin: '图书馆广场',
        destination: '科技园东门',
        passengerCount: 28,
        departureTime: now.add(const Duration(hours: 2, minutes: 10)),
        status: DispatchDemandStatus.pending,
      ),
      DispatchDemandModel(
        id: 'demand-003',
        routeName: '晚间返校线',
        origin: '附属医院站',
        destination: '北区宿舍',
        passengerCount: 18,
        departureTime: now.add(const Duration(hours: 6)),
        status: DispatchDemandStatus.pending,
      ),
    ];
  }

  List<AdminAnalyticsSnapshot> fetchAnalytics() {
    return const [
      AdminAnalyticsSnapshot(
        period: AnalyticsPeriod.day,
        totalPassengers: 186,
        totalRevenue: 842,
        vehicleUtilization: 0.72,
        trend: [
          TrendPointModel(label: '08:00', passengers: 42, revenue: 168),
          TrendPointModel(label: '10:00', passengers: 26, revenue: 118),
          TrendPointModel(label: '14:00', passengers: 33, revenue: 151),
          TrendPointModel(label: '17:00', passengers: 55, revenue: 255),
          TrendPointModel(label: '20:00', passengers: 30, revenue: 150),
        ],
        routeRanking: [
          RouteAnalyticsModel(
            routeName: '大学城早班线',
            passengers: 68,
            revenue: 272,
            vehicleUtilization: 0.86,
          ),
          RouteAnalyticsModel(
            routeName: '科技园通勤线',
            passengers: 54,
            revenue: 270,
            vehicleUtilization: 0.78,
          ),
          RouteAnalyticsModel(
            routeName: '晚间返校线',
            passengers: 38,
            revenue: 152,
            vehicleUtilization: 0.64,
          ),
        ],
      ),
      AdminAnalyticsSnapshot(
        period: AnalyticsPeriod.week,
        totalPassengers: 1298,
        totalRevenue: 5964,
        vehicleUtilization: 0.77,
        trend: [
          TrendPointModel(label: '周一', passengers: 188, revenue: 864),
          TrendPointModel(label: '周二', passengers: 171, revenue: 781),
          TrendPointModel(label: '周三', passengers: 196, revenue: 910),
          TrendPointModel(label: '周四', passengers: 209, revenue: 942),
          TrendPointModel(label: '周五', passengers: 246, revenue: 1136),
          TrendPointModel(label: '周六', passengers: 150, revenue: 690),
          TrendPointModel(label: '周日', passengers: 138, revenue: 641),
        ],
        routeRanking: [
          RouteAnalyticsModel(
            routeName: '大学城早班线',
            passengers: 420,
            revenue: 1680,
            vehicleUtilization: 0.88,
          ),
          RouteAnalyticsModel(
            routeName: '科技园通勤线',
            passengers: 392,
            revenue: 1960,
            vehicleUtilization: 0.81,
          ),
          RouteAnalyticsModel(
            routeName: '校区环线',
            passengers: 266,
            revenue: 532,
            vehicleUtilization: 0.70,
          ),
        ],
      ),
      AdminAnalyticsSnapshot(
        period: AnalyticsPeriod.month,
        totalPassengers: 5346,
        totalRevenue: 24860,
        vehicleUtilization: 0.79,
        trend: [
          TrendPointModel(label: '第1周', passengers: 1190, revenue: 5520),
          TrendPointModel(label: '第2周', passengers: 1286, revenue: 5974),
          TrendPointModel(label: '第3周', passengers: 1394, revenue: 6488),
          TrendPointModel(label: '第4周', passengers: 1476, revenue: 6878),
        ],
        routeRanking: [
          RouteAnalyticsModel(
            routeName: '科技园通勤线',
            passengers: 1680,
            revenue: 8400,
            vehicleUtilization: 0.84,
          ),
          RouteAnalyticsModel(
            routeName: '大学城早班线',
            passengers: 1518,
            revenue: 6072,
            vehicleUtilization: 0.82,
          ),
          RouteAnalyticsModel(
            routeName: '晚间返校线',
            passengers: 920,
            revenue: 3680,
            vehicleUtilization: 0.74,
          ),
        ],
      ),
    ];
  }
}
