import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus_app/core/models/app_mode.dart';
import 'package:school_bus_app/core/models/app_notification_model.dart';
import 'package:school_bus_app/core/models/driver_task_model.dart';
import 'package:school_bus_app/core/persistence/demo_persistence.dart';
import 'package:school_bus_app/core/providers/auth_provider.dart';
import 'package:school_bus_app/core/providers/notification_provider.dart';
import 'package:school_bus_app/features/driver/tasks/providers/driver_task_provider.dart';

void main() {
  test('driver progress and notifications survive a new app container', () {
    final store = MemoryDemoPersistence();
    addTearDown(store.dispose);
    final first = _container(store);
    expect(
      first.read(driverTaskProvider.notifier).startTask('task-001').success,
      isTrue,
    );
    first
        .read(notificationProvider.notifier)
        .push(
          title: '预约已创建',
          message: '测试保存',
          type: AppNotificationType.booking,
        );
    first.read(notificationProvider.notifier).markAllRead();

    final second = _container(store);
    expect(second.read(driverTaskProvider).activeTaskId, 'task-001');
    expect(
      second.read(driverTaskProvider).tasks.first.status,
      DriverTaskStatus.running,
    );
    expect(second.read(driverTaskProvider).locationUpdates, hasLength(1));
    expect(second.read(notificationProvider).single.isRead, isTrue);
  });

  test('external updates refresh driver progress and notification reads', () {
    final store = MemoryDemoPersistence();
    addTearDown(store.dispose);
    final container = _container(store);
    final controller = container.read(driverTaskProvider.notifier);
    controller.startTask('task-001');
    final snapshot = store.read('driver')!;
    snapshot['activeTaskId'] = null;
    ((snapshot['tasks'] as List).first as Map)['status'] = 'completed';
    store.receiveExternal('driver', snapshot);
    expect(container.read(driverTaskProvider).activeTaskId, isNull);
    expect(
      container.read(driverTaskProvider).tasks.first.status,
      DriverTaskStatus.completed,
    );

    container
        .read(notificationProvider.notifier)
        .push(
          title: '支付成功',
          message: '测试同步',
          type: AppNotificationType.payment,
        );
    final notifications = store.read('notifications')!;
    ((notifications['items'] as List).first as Map)['isRead'] = true;
    store.receiveExternal('notifications', notifications);
    expect(container.read(notificationProvider).single.isRead, isTrue);
  });

  test(
    'stale location report cannot revive a task completed in another session',
    () {
      final store = MemoryDemoPersistence();
      addTearDown(store.dispose);
      final first = _container(store);
      final firstController = first.read(driverTaskProvider.notifier);
      expect(firstController.startTask('task-001').success, isTrue);
      final second = _container(store);
      final secondController = second.read(driverTaskProvider.notifier);
      expect(second.read(driverTaskProvider).activeTaskId, 'task-001');

      expect(firstController.completeActiveTask().success, isTrue);
      // Local writes deliberately do not dispatch a storage event to the other
      // container, so its next report must read the completed task from storage.
      expect(second.read(driverTaskProvider).activeTaskId, 'task-001');
      secondController.simulateNextLocationReport();

      final state = second.read(driverTaskProvider);
      expect(state.activeTaskId, isNull);
      expect(state.tasks.first.status, DriverTaskStatus.completed);
      expect(state.locationUpdates, hasLength(1));
      final saved = store.read('driver')!;
      expect(saved['activeTaskId'], isNull);
      expect(((saved['tasks'] as List).first as Map)['status'], 'completed');
    },
  );

  test('stale stats selection preserves another session completed task', () {
    final store = MemoryDemoPersistence();
    addTearDown(store.dispose);
    final first = _container(store);
    final firstController = first.read(driverTaskProvider.notifier);
    firstController.startTask('task-001');
    final second = _container(store);
    final secondController = second.read(driverTaskProvider.notifier);
    expect(second.read(driverTaskProvider).activeTaskId, 'task-001');

    expect(firstController.completeActiveTask().success, isTrue);
    secondController.selectStatsPeriod('周');

    final state = second.read(driverTaskProvider);
    expect(state.selectedStatsPeriod, '周');
    expect(state.activeTaskId, isNull);
    expect(state.tasks.first.status, DriverTaskStatus.completed);
    expect(secondController.startTask('task-001').success, isFalse);
    expect(firstController.completeActiveTask().success, isFalse);
    final saved = store.read('driver')!;
    expect(saved['activeTaskId'], isNull);
    expect(saved['selectedStatsPeriod'], '周');
    expect(((saved['tasks'] as List).first as Map)['status'], 'completed');
  });

  test(
    'stale notification push and mark read preserve both session updates',
    () {
      final store = MemoryDemoPersistence();
      addTearDown(store.dispose);
      final first = _container(store);
      final second = _container(store);
      final firstNotifications = first.read(notificationProvider.notifier);
      final secondNotifications = second.read(notificationProvider.notifier);
      expect(second.read(notificationProvider), isEmpty);

      firstNotifications.push(
        title: '第一条预约',
        message: '来自第一个标签页',
        type: AppNotificationType.booking,
      );
      expect(second.read(notificationProvider), isEmpty);
      secondNotifications.push(
        title: '第二条支付',
        message: '来自第二个标签页',
        type: AppNotificationType.payment,
      );
      expect(second.read(notificationProvider).map((item) => item.title), [
        '第二条支付',
        '第一条预约',
      ]);
      expect(first.read(notificationProvider), hasLength(1));

      firstNotifications.markAllRead();
      final notifications = first.read(notificationProvider);
      expect(notifications.map((item) => item.title), ['第二条支付', '第一条预约']);
      expect(notifications.every((item) => item.isRead), isTrue);
      final savedItems = store.read('notifications')!['items'] as List;
      expect(savedItems, hasLength(2));
      expect(
        savedItems.every((item) => (item as Map)['isRead'] == true),
        isTrue,
      );

      // A later write from the still-stale second session must preserve reads.
      secondNotifications.push(
        title: '第三条提醒',
        message: '保留前两条的已读状态',
        type: AppNotificationType.system,
      );
      final updated = second.read(notificationProvider);
      expect(updated, hasLength(3));
      expect(updated.first.isRead, isFalse);
      expect(updated.skip(1).every((item) => item.isRead), isTrue);
    },
  );

  test('reset restores initial tasks and clears local notifications', () {
    final store = MemoryDemoPersistence();
    addTearDown(store.dispose);
    final container = _container(store);
    container.read(driverTaskProvider.notifier).startTask('task-001');
    container
        .read(notificationProvider.notifier)
        .push(title: '演示通知', message: '重置前', type: AppNotificationType.system);
    store.clear();
    expect(container.read(driverTaskProvider).activeTaskId, isNull);
    expect(container.read(driverTaskProvider).pendingTaskCount, 3);
    expect(container.read(notificationProvider), isEmpty);
  });

  test('corrupt snapshot falls back without blocking startup', () {
    final store = MemoryDemoPersistence();
    addTearDown(store.dispose);
    store.write('driver', {'tasks': 'invalid'});
    store.write('notifications', {'items': 'invalid'});
    final container = _container(store);
    expect(container.read(driverTaskProvider).pendingTaskCount, 3);
    expect(container.read(notificationProvider), isEmpty);
  });

  test('location history is bounded and coordinates keep advancing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(driverTaskProvider.notifier);
    controller.startTask('task-001');
    for (var index = 0; index < 200; index++) {
      controller.simulateNextLocationReport();
    }
    final previous = container.read(driverTaskProvider).latestLocation!.lat;
    controller.simulateNextLocationReport();
    expect(container.read(driverTaskProvider).locationUpdates, hasLength(200));
    expect(
      container.read(driverTaskProvider).latestLocation!.lat,
      greaterThan(previous),
    );
  });

  testWidgets('logout pauses location timer and driver login resumes it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final auth = container.read(authControllerProvider.notifier);
    Future<bool> login() => auth.login(
      phone: '13800000002',
      password: '123456',
      mode: AppMode.driver,
    );

    final firstLogin = login();
    await tester.pump(const Duration(milliseconds: 500));
    expect(await firstLogin, isTrue);
    final controller = container.read(driverTaskProvider.notifier);
    controller.startTask('task-001');
    await tester.pump(const Duration(seconds: 5));
    expect(container.read(driverTaskProvider).locationUpdates, hasLength(2));

    auth.logout();
    await tester.pump(const Duration(seconds: 10));
    expect(container.read(driverTaskProvider).locationUpdates, hasLength(2));

    final secondLogin = login();
    await tester.pump(const Duration(milliseconds: 500));
    expect(await secondLogin, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(container.read(driverTaskProvider).locationUpdates, hasLength(3));
    controller.completeActiveTask();
  });
}

ProviderContainer _container(DemoPersistence store) {
  final container = ProviderContainer(
    overrides: [demoPersistenceProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}
