import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_bus_app/app.dart';
import 'package:school_bus_app/core/models/app_mode.dart';
import 'package:school_bus_app/core/models/driver_task_model.dart';
import 'package:school_bus_app/core/models/location_update.dart';
import 'package:school_bus_app/core/providers/app_mode_provider.dart';
import 'package:school_bus_app/features/driver/tasks/providers/driver_task_provider.dart';

void main() {
  group('司机端登录与工作台展示', () {
    testWidgets('司机端登录成功后显示工作台', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('司机端工作台'), findsOneWidget);
      expect(find.text('统计看板'), findsOneWidget);
      expect(find.text('实时位置共享'), findsOneWidget);
      expect(find.text('今日派车任务'), findsOneWidget);
    });

    testWidgets('司机端工作台显示司机姓名', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('王师傅'), findsOneWidget);
    });

    testWidgets('司机端工作台显示待发车任务数量', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('待发车任务'), findsOneWidget);
    });

    testWidgets('司机端工作台显示今日乘客数量', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('今日乘客'), findsOneWidget);
    });

    testWidgets('司机端工作台初始位置状态为未开启', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('未开启'), findsOneWidget);
      expect(find.text('位置状态'), findsOneWidget);
    });

    testWidgets('司机端工作台显示任务列表中的路线名称', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.textContaining('大学城早班线'), findsWidgets);
      expect(find.textContaining('科技园通勤线'), findsWidgets);
      expect(find.textContaining('晚间返校线'), findsWidgets);
    });

    testWidgets('司机端工作台显示暂无位置上报', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('暂无位置上报'), findsOneWidget);
    });
  });

  group('统计看板', () {
    testWidgets('统计看板默认显示日维度数据', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('完成车次'), findsOneWidget);
      expect(find.text('4 趟'), findsOneWidget);
      expect(find.text('38 人'), findsOneWidget);
      expect(find.text('42.6 km'), findsOneWidget);
    });

    testWidgets('统计看板可切换到周维度', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();

      expect(find.text('24 趟'), findsOneWidget);
      expect(find.text('236 人'), findsOneWidget);
      expect(find.text('286.4 km'), findsOneWidget);
    });

    testWidgets('统计看板可切换到月维度', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();

      expect(find.text('98 趟'), findsOneWidget);
      expect(find.text('1034 人'), findsOneWidget);
      expect(find.text('1198.5 km'), findsOneWidget);
    });

    testWidgets('统计看板显示准点率进度条', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('准点率 98%'), findsOneWidget);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('任务列表展示', () {
    testWidgets('任务卡片显示路线名称和车次号', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.textContaining('大学城早班线 · D-20260501-01'), findsOneWidget);
      expect(find.textContaining('科技园通勤线 · D-20260501-02'), findsOneWidget);
      expect(find.textContaining('晚间返校线 · D-20260501-03'), findsOneWidget);
    });

    testWidgets('任务卡片显示起止站点', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('南门学生公寓 → 综合教学楼'), findsOneWidget);
      expect(find.text('图书馆广场 → 科技园东门'), findsOneWidget);
      expect(find.text('附属医院站 → 北区宿舍'), findsOneWidget);
    });

    testWidgets('任务卡片显示车牌号', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('校A·1028'), findsWidgets);
    });

    testWidgets('任务卡片显示乘客数量', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('3 名乘客'), findsOneWidget);
      expect(find.text('4 名乘客'), findsOneWidget);
      expect(find.text('2 名乘客'), findsOneWidget);
    });

    testWidgets('任务卡片显示行驶里程', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('8.6 km'), findsOneWidget);
      expect(find.text('12.4 km'), findsOneWidget);
      expect(find.text('15.8 km'), findsOneWidget);
    });

    testWidgets('任务卡片显示待发车状态标签', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      expect(find.text('待发车'), findsWidgets);
    });

    testWidgets('任务卡片可展开查看乘客名单', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.scrollUntilVisible(
        find.text('乘客名单与上车点').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('乘客名单与上车点').first);
      await tester.pumpAndSettle();

      expect(find.text('张同学 · 尾号 0001'), findsOneWidget);
      expect(find.text('陈同学 · 尾号 0132'), findsOneWidget);
      expect(find.text('赵同学 · 尾号 0228'), findsOneWidget);
    });

    testWidgets('乘客名单显示上车点和座位号', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.scrollUntilVisible(
        find.text('乘客名单与上车点').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('乘客名单与上车点').first);
      await tester.pumpAndSettle();

      expect(find.text('南门学生公寓'), findsOneWidget);
      expect(find.text('一食堂站'), findsOneWidget);
      expect(find.text('图书馆广场'), findsOneWidget);
    });
  });

  group('开始任务与位置上报', () {
    testWidgets('点击开始任务按钮可启动任务', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      expect(find.text('行程中'), findsOneWidget);

      expect(find.text('共享中'), findsOneWidget);
    });

    testWidgets('开始任务后自动上报一次位置', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      expect(find.text('上报次数：1'), findsOneWidget);
      expect(find.textContaining('纬度：31.23040'), findsOneWidget);
      expect(find.textContaining('经度：121.47370'), findsOneWidget);
    });

    testWidgets('模拟上报按钮可手动触发位置上报', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('simulate_location_report')),
      );
      await tester.tap(find.byKey(const Key('simulate_location_report')));
      await tester.pumpAndSettle();

      expect(find.text('上报次数：2'), findsOneWidget);
    });

    testWidgets('多次模拟上报位置坐标会变化', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('simulate_location_report')),
      );
      await tester.tap(find.byKey(const Key('simulate_location_report')));
      await tester.pumpAndSettle();

      expect(find.textContaining('纬度：31.23220'), findsOneWidget);
      expect(find.textContaining('经度：121.47490'), findsOneWidget);
    });

    testWidgets('开始任务后显示车辆ID', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      expect(find.text('bus-001'), findsOneWidget);
    });

    testWidgets('开始任务后显示速度信息', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      expect(find.textContaining('km/h'), findsOneWidget);
    });
  });

  group('完成任务', () {
    testWidgets('到站完成按钮可结束当前任务', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('complete_active_task')),
      );
      await tester.tap(find.byKey(const Key('complete_active_task')));
      await tester.pumpAndSettle();

      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('未开启'), findsOneWidget);
    });

    testWidgets('完成任务后位置上报停止', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('complete_active_task')),
      );
      await tester.tap(find.byKey(const Key('complete_active_task')));
      await tester.pumpAndSettle();

      final simulateButton = find.byKey(const Key('simulate_location_report'));
      expect(simulateButton, findsOneWidget);
      final button = tester.widget<OutlinedButton>(simulateButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('完成任务后显示提示消息', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('complete_active_task')),
      );
      await tester.tap(find.byKey(const Key('complete_active_task')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('任务已完成'), findsWidgets);
    });
  });

  group('边界情况', () {
    testWidgets('未开始任务时模拟上报按钮不可用', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      final simulateButton = find.byKey(const Key('simulate_location_report'));
      expect(simulateButton, findsOneWidget);

      final button = tester.widget<OutlinedButton>(simulateButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('未开始任务时到站完成按钮不可用', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      final completeButton = find.byKey(const Key('complete_active_task'));
      expect(completeButton, findsOneWidget);

      final button = tester.widget<FilledButton>(completeButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('不能同时开始两个任务', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      final secondTaskButton = find.byKey(const Key('start_task_task-002'));
      expect(secondTaskButton, findsOneWidget);
      final button = tester.widget<FilledButton>(secondTaskButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('已完成任务显示为不可操作状态', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('complete_active_task')),
      );
      await tester.tap(find.byKey(const Key('complete_active_task')));
      await tester.pumpAndSettle();

      expect(find.text('任务已完成'), findsOneWidget);
    });

    testWidgets('完成任务后可以开始另一个任务', (tester) async {
      await _pumpDriverApp(tester);
      await _loginAsDriver(tester);

      await tester.ensureVisible(find.byKey(const Key('start_task_task-001')));
      await tester.tap(find.byKey(const Key('start_task_task-001')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('complete_active_task')),
      );
      await tester.tap(find.byKey(const Key('complete_active_task')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('start_task_task-002')));
      await tester.tap(find.byKey(const Key('start_task_task-002')));
      await tester.pumpAndSettle();

      expect(find.text('行程中'), findsOneWidget);
    });
  });

  group('DriverTaskState 单元测试', () {
    final mockTasks = [
      DriverTaskModel(
        id: 'task-001',
        tripNo: 'T-001',
        routeName: '路线A',
        origin: '起点A',
        destination: '终点A',
        vehicleId: 'bus-001',
        plateNo: '校A·1001',
        departureTime: DateTime.now(),
        distanceKm: 10.0,
        status: DriverTaskStatus.pending,
        passengers: const [
          PassengerPickup(
            name: '乘客1',
            phoneSuffix: '0001',
            pickupPoint: '站点A',
            seatNo: 1,
          ),
          PassengerPickup(
            name: '乘客2',
            phoneSuffix: '0002',
            pickupPoint: '站点B',
            seatNo: 2,
          ),
        ],
      ),
      DriverTaskModel(
        id: 'task-002',
        tripNo: 'T-002',
        routeName: '路线B',
        origin: '起点B',
        destination: '终点B',
        vehicleId: 'bus-001',
        plateNo: '校A·1001',
        departureTime: DateTime.now(),
        distanceKm: 15.0,
        status: DriverTaskStatus.running,
        passengers: const [
          PassengerPickup(
            name: '乘客3',
            phoneSuffix: '0003',
            pickupPoint: '站点C',
            seatNo: 3,
          ),
        ],
      ),
      DriverTaskModel(
        id: 'task-003',
        tripNo: 'T-003',
        routeName: '路线C',
        origin: '起点C',
        destination: '终点C',
        vehicleId: 'bus-002',
        plateNo: '校A·1002',
        departureTime: DateTime.now(),
        distanceKm: 20.0,
        status: DriverTaskStatus.completed,
        passengers: const [],
      ),
    ];

    final mockStats = [
      const DriverStats(
        period: '日',
        totalTrips: 5,
        totalPassengers: 50,
        totalDistance: 100.0,
        onTimeRate: 0.95,
      ),
      const DriverStats(
        period: '周',
        totalTrips: 30,
        totalPassengers: 300,
        totalDistance: 600.0,
        onTimeRate: 0.92,
      ),
    ];

    test('pendingTaskCount 返回待发车任务数量', () {
      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '日',
        locationUpdates: const [],
      );

      expect(state.pendingTaskCount, 1);
    });

    test('todayPassengerCount 返回所有乘客总数', () {
      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '日',
        locationUpdates: const [],
      );

      expect(state.todayPassengerCount, 3);
    });

    test('activeTask 返回当前活动任务', () {
      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '日',
        locationUpdates: const [],
        activeTaskId: 'task-002',
      );

      expect(state.activeTask, isNotNull);
      expect(state.activeTask!.id, 'task-002');
      expect(state.activeTask!.routeName, '路线B');
    });

    test('activeTask 在没有活动任务时返回 null', () {
      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '日',
        locationUpdates: const [],
      );

      expect(state.activeTask, isNull);
    });

    test('selectedStats 返回当前选中的统计数据', () {
      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '周',
        locationUpdates: const [],
      );

      final stats = state.selectedStats;
      expect(stats.period, '周');
      expect(stats.totalTrips, 30);
      expect(stats.totalPassengers, 300);
    });

    test('latestLocation 返回最新的位置上报', () {
      final now = DateTime.now();
      final updates = [
        LocationUpdate(
          vehicleId: 'bus-001',
          lat: 31.2304,
          lng: 121.4737,
          speed: 30.0,
          timestamp: now,
        ),
        LocationUpdate(
          vehicleId: 'bus-001',
          lat: 31.2322,
          lng: 121.4749,
          speed: 35.0,
          timestamp: now.add(const Duration(seconds: 5)),
        ),
      ];

      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '日',
        locationUpdates: updates,
      );

      expect(state.latestLocation, isNotNull);
      expect(state.latestLocation!.lat, 31.2304);
    });

    test('latestLocation 在没有上报时返回 null', () {
      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '日',
        locationUpdates: const [],
      );

      expect(state.latestLocation, isNull);
    });

    test('copyWith 正确更新字段', () {
      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '日',
        locationUpdates: const [],
      );

      final updated = state.copyWith(selectedStatsPeriod: '周');
      expect(updated.selectedStatsPeriod, '周');
      expect(updated.tasks, mockTasks);
    });

    test('copyWith 的 clearActiveTask 参数可清除活动任务', () {
      final state = DriverTaskState(
        tasks: mockTasks,
        stats: mockStats,
        selectedStatsPeriod: '日',
        locationUpdates: const [],
        activeTaskId: 'task-002',
      );

      final updated = state.copyWith(clearActiveTask: true);
      expect(updated.activeTaskId, isNull);
    });
  });

  group('DriverTaskController 单元测试', () {
    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          initialAppModeProvider.overrideWithValue(AppMode.driver),
        ],
      );
    }

    test('startTask 成功启动任务并返回成功消息', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final controller = container.read(driverTaskProvider.notifier);
      final result = controller.startTask('task-001');

      expect(result.success, isTrue);
      expect(result.message, contains('已发车'));

      final state = container.read(driverTaskProvider);
      expect(state.activeTaskId, 'task-001');
    });

    test('重复 startTask 同一任务返回错误', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final controller = container.read(driverTaskProvider.notifier);
      controller.startTask('task-001');
      final result = controller.startTask('task-001');

      expect(result.success, isFalse);
      expect(result.message, contains('已有任务正在位置共享'));
    });

    test('startTask 不存在的任务返回错误', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final controller = container.read(driverTaskProvider.notifier);
      final result = controller.startTask('non-existent-task');

      expect(result.success, isFalse);
      expect(result.message, '任务不存在');
    });

    test('completeActiveTask 成功完成任务', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final controller = container.read(driverTaskProvider.notifier);
      controller.startTask('task-001');
      final result = controller.completeActiveTask();

      expect(result.success, isTrue);
      expect(result.message, '任务已完成，位置共享已停止');

      final state = container.read(driverTaskProvider);
      expect(state.activeTaskId, isNull);
    });

    test('没有活动任务时 completeActiveTask 返回错误', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final controller = container.read(driverTaskProvider.notifier);
      final result = controller.completeActiveTask();

      expect(result.success, isFalse);
      expect(result.message, '当前没有进行中任务');
    });

    test('selectStatsPeriod 正确切换统计周期', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final controller = container.read(driverTaskProvider.notifier);
      controller.selectStatsPeriod('月');

      final state = container.read(driverTaskProvider);
      expect(state.selectedStatsPeriod, '月');
    });

    test('simulateNextLocationReport 增加位置上报次数', () {
      final container = createContainer();
      addTearDown(container.dispose);

      final controller = container.read(driverTaskProvider.notifier);
      controller.startTask('task-001');

      final stateAfterStart = container.read(driverTaskProvider);
      final initialCount = stateAfterStart.locationUpdates.length;

      controller.simulateNextLocationReport();
      final stateAfterSimulate = container.read(driverTaskProvider);

      expect(stateAfterSimulate.locationUpdates.length, initialCount + 1);
    });
  });

  group('DriverTaskModel 单元测试', () {
    test('copyWith 可更新任务状态', () {
      final task = DriverTaskModel(
        id: 'task-001',
        tripNo: 'T-001',
        routeName: '路线A',
        origin: '起点',
        destination: '终点',
        vehicleId: 'bus-001',
        plateNo: '校A·1001',
        departureTime: DateTime.now(),
        distanceKm: 10.0,
        status: DriverTaskStatus.pending,
        passengers: const [],
      );

      final updated = task.copyWith(status: DriverTaskStatus.running);
      expect(updated.status, DriverTaskStatus.running);
      expect(updated.id, 'task-001');
      expect(updated.routeName, '路线A');
    });
  });

  group('DriverTaskStatus 枚举测试', () {
    test('pending 状态值为 pending', () {
      expect(DriverTaskStatus.pending.value, 'pending');
      expect(DriverTaskStatus.pending.label, '待发车');
    });

    test('running 状态值为 running', () {
      expect(DriverTaskStatus.running.value, 'running');
      expect(DriverTaskStatus.running.label, '行程中');
    });

    test('completed 状态值为 completed', () {
      expect(DriverTaskStatus.completed.value, 'completed');
      expect(DriverTaskStatus.completed.label, '已完成');
    });
  });

  group('PassengerPickup 模型测试', () {
    test('PassengerPickup 正确存储乘客信息', () {
      final passenger = const PassengerPickup(
        name: '测试乘客',
        phoneSuffix: '8888',
        pickupPoint: '测试站点',
        seatNo: 15,
      );

      expect(passenger.name, '测试乘客');
      expect(passenger.phoneSuffix, '8888');
      expect(passenger.pickupPoint, '测试站点');
      expect(passenger.seatNo, 15);
    });
  });

  group('LocationUpdate 模型测试', () {
    test('LocationUpdate 正确存储位置信息', () {
      final now = DateTime.now();
      final update = LocationUpdate(
        vehicleId: 'bus-001',
        lat: 31.2304,
        lng: 121.4737,
        speed: 25.0,
        timestamp: now,
      );

      expect(update.vehicleId, 'bus-001');
      expect(update.lat, 31.2304);
      expect(update.lng, 121.4737);
      expect(update.speed, 25.0);
      expect(update.timestamp, now);
    });
  });

  group('DriverStats 模型测试', () {
    test('DriverStats 正确存储统计数据', () {
      final stats = const DriverStats(
        period: '日',
        totalTrips: 10,
        totalPassengers: 100,
        totalDistance: 200.5,
        onTimeRate: 0.96,
      );

      expect(stats.period, '日');
      expect(stats.totalTrips, 10);
      expect(stats.totalPassengers, 100);
      expect(stats.totalDistance, 200.5);
      expect(stats.onTimeRate, 0.96);
    });
  });

  group('DriverActionResult 模型测试', () {
    test('DriverActionResult 正确存储操作结果', () {
      final successResult = const DriverActionResult(
        success: true,
        message: '操作成功',
      );
      final failResult = const DriverActionResult(
        success: false,
        message: '操作失败',
      );

      expect(successResult.success, isTrue);
      expect(successResult.message, '操作成功');
      expect(failResult.success, isFalse);
      expect(failResult.message, '操作失败');
    });
  });
}

Future<void> _pumpDriverApp(WidgetTester tester) async {
  await _pumpApp(tester, AppMode.driver);
}

Future<void> _loginAsDriver(WidgetTester tester) async {
  await _loginWithMockCredential(
    tester,
    mode: AppMode.driver,
    loginTitle: '司机端登录',
  );
}

Future<void> _pumpApp(WidgetTester tester, AppMode mode) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [initialAppModeProvider.overrideWithValue(mode)],
      child: const AppRoot(),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _loginWithMockCredential(
  WidgetTester tester, {
  required AppMode mode,
  required String loginTitle,
}) async {
  expect(find.text('校车管理系统'), findsOneWidget);
  expect(find.text(loginTitle), findsOneWidget);

  await tester.tap(find.byKey(Key('mock_${mode.value}_login')));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('login_submit')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}
