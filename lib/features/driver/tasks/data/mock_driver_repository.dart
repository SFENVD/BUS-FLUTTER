import '../../../../core/models/driver_task_model.dart';

class MockDriverRepository {
  List<DriverTaskModel> fetchTasks() {
    final now = DateTime.now();

    return [
      DriverTaskModel(
        id: 'task-001',
        tripNo: 'D-20260501-01',
        routeName: '大学城早班线',
        origin: '南门学生公寓',
        destination: '综合教学楼',
        vehicleId: 'bus-001',
        plateNo: '校A·1028',
        departureTime: now.add(const Duration(minutes: 35)),
        distanceKm: 8.6,
        status: DriverTaskStatus.pending,
        passengers: const [
          PassengerPickup(
            name: '张同学',
            phoneSuffix: '0001',
            pickupPoint: '南门学生公寓',
            seatNo: 5,
          ),
          PassengerPickup(
            name: '陈同学',
            phoneSuffix: '0132',
            pickupPoint: '一食堂站',
            seatNo: 9,
          ),
          PassengerPickup(
            name: '赵同学',
            phoneSuffix: '0228',
            pickupPoint: '图书馆广场',
            seatNo: 12,
          ),
        ],
      ),
      DriverTaskModel(
        id: 'task-002',
        tripNo: 'D-20260501-02',
        routeName: '科技园通勤线',
        origin: '图书馆广场',
        destination: '科技园东门',
        vehicleId: 'bus-001',
        plateNo: '校A·1028',
        departureTime: now.add(const Duration(hours: 2, minutes: 10)),
        distanceKm: 12.4,
        status: DriverTaskStatus.pending,
        passengers: const [
          PassengerPickup(
            name: '李老师',
            phoneSuffix: '1620',
            pickupPoint: '图书馆广场',
            seatNo: 2,
          ),
          PassengerPickup(
            name: '王同学',
            phoneSuffix: '3340',
            pickupPoint: '西门站',
            seatNo: 17,
          ),
          PassengerPickup(
            name: '刘同学',
            phoneSuffix: '2186',
            pickupPoint: '工程楼',
            seatNo: 21,
          ),
          PassengerPickup(
            name: '许同学',
            phoneSuffix: '9081',
            pickupPoint: '工程楼',
            seatNo: 22,
          ),
        ],
      ),
      DriverTaskModel(
        id: 'task-003',
        tripNo: 'D-20260501-03',
        routeName: '晚间返校线',
        origin: '附属医院站',
        destination: '北区宿舍',
        vehicleId: 'bus-001',
        plateNo: '校A·1028',
        departureTime: now.add(const Duration(hours: 7, minutes: 5)),
        distanceKm: 15.8,
        status: DriverTaskStatus.pending,
        passengers: const [
          PassengerPickup(
            name: '周同学',
            phoneSuffix: '5510',
            pickupPoint: '附属医院站',
            seatNo: 6,
          ),
          PassengerPickup(
            name: '吴同学',
            phoneSuffix: '4423',
            pickupPoint: '市民中心站',
            seatNo: 7,
          ),
        ],
      ),
    ];
  }

  List<DriverStats> fetchStats() {
    return const [
      DriverStats(
        period: '日',
        totalTrips: 4,
        totalPassengers: 38,
        totalDistance: 42.6,
        onTimeRate: 0.98,
      ),
      DriverStats(
        period: '周',
        totalTrips: 24,
        totalPassengers: 236,
        totalDistance: 286.4,
        onTimeRate: 0.96,
      ),
      DriverStats(
        period: '月',
        totalTrips: 98,
        totalPassengers: 1034,
        totalDistance: 1198.5,
        onTimeRate: 0.95,
      ),
    ];
  }
}
