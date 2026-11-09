import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/driver_task_model.dart';
import '../../../../core/models/location_update.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/persistence/demo_persistence.dart';
import '../../../../core/providers/auth_provider.dart';
import '../data/driver_state_codec.dart';
import '../data/mock_driver_repository.dart';

final mockDriverRepositoryProvider = Provider<MockDriverRepository>((ref) {
  return MockDriverRepository();
});

final driverTaskProvider =
    NotifierProvider<DriverTaskController, DriverTaskState>(
      DriverTaskController.new,
    );

class DriverTaskState {
  const DriverTaskState({
    required this.tasks,
    required this.stats,
    required this.selectedStatsPeriod,
    required this.locationUpdates,
    this.activeTaskId,
  });

  final List<DriverTaskModel> tasks;
  final List<DriverStats> stats;
  final String selectedStatsPeriod;
  final List<LocationUpdate> locationUpdates;
  final String? activeTaskId;

  DriverTaskModel? get activeTask {
    if (activeTaskId == null) {
      return null;
    }
    return tasks.where((task) => task.id == activeTaskId).firstOrNull;
  }

  DriverStats get selectedStats {
    return stats.firstWhere((item) => item.period == selectedStatsPeriod);
  }

  LocationUpdate? get latestLocation {
    if (locationUpdates.isEmpty) {
      return null;
    }
    return locationUpdates.first;
  }

  int get pendingTaskCount {
    return tasks
        .where((task) => task.status == DriverTaskStatus.pending)
        .length;
  }

  int get todayPassengerCount {
    return tasks.fold<int>(0, (total, task) => total + task.passengers.length);
  }

  DriverTaskState copyWith({
    List<DriverTaskModel>? tasks,
    List<DriverStats>? stats,
    String? selectedStatsPeriod,
    List<LocationUpdate>? locationUpdates,
    String? activeTaskId,
    bool clearActiveTask = false,
  }) {
    return DriverTaskState(
      tasks: tasks ?? this.tasks,
      stats: stats ?? this.stats,
      selectedStatsPeriod: selectedStatsPeriod ?? this.selectedStatsPeriod,
      locationUpdates: locationUpdates ?? this.locationUpdates,
      activeTaskId: clearActiveTask ? null : activeTaskId ?? this.activeTaskId,
    );
  }
}

class DriverActionResult {
  const DriverActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class DriverTaskController extends Notifier<DriverTaskState> {
  Timer? _locationTimer;

  @override
  DriverTaskState build() {
    ref.onDispose(_stopTimer);

    final repository = ref.read(mockDriverRepositoryProvider);
    final initialState = DriverTaskState(
      tasks: repository.fetchTasks(),
      stats: repository.fetchStats(),
      selectedStatsPeriod: '日',
      locationUpdates: const [],
    );

    final store = ref.read(demoPersistenceProvider);
    DriverTaskState restore([DriverTaskState? fallback]) {
      final saved = store.read('driver');
      return saved == null
          ? initialState
          : restoreDemoData(
              fallback ?? initialState,
              () => decodeDriverState(saved, initialState),
            );
    }

    final restored = restore();
    listenSelf((previous, next) {
      store.write('driver', encodeDriverState(next));
    });
    final subscription = store.changes.listen((key) {
      if (key != 'driver' && key != '*') return;
      state = restore(key == '*' ? initialState : state);
      _syncTimerWithSession();
    });
    ref.onDispose(subscription.cancel);
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.user?.id != next.user?.id ||
          previous?.user?.role != next.user?.role) {
        _syncTimerWithSession();
      }
    });
    if (restored.activeTaskId != null &&
        ref.read(authControllerProvider).user?.role == UserRole.driver) {
      _startTimer();
    }
    if (store.read('driver') == null) {
      store.write('driver', encodeDriverState(restored));
    }
    return restored;
  }

  void selectStatsPeriod(String period) {
    _refreshFromStorage();
    state = state.copyWith(selectedStatsPeriod: period);
  }

  DriverActionResult startTask(String taskId) {
    _refreshFromStorage();
    if (state.activeTaskId != null) {
      return const DriverActionResult(
        success: false,
        message: '已有任务正在位置共享，请先结束当前任务',
      );
    }

    final index = state.tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      return const DriverActionResult(success: false, message: '任务不存在');
    }

    final task = state.tasks[index];
    if (task.status == DriverTaskStatus.completed) {
      return const DriverActionResult(success: false, message: '已完成任务不可发车');
    }

    final nextTasks = [...state.tasks];
    nextTasks[index] = task.copyWith(status: DriverTaskStatus.running);
    state = state.copyWith(tasks: nextTasks, activeTaskId: taskId);

    _appendLocationUpdate();
    _startTimer();

    return const DriverActionResult(success: true, message: '已发车，位置将每 5 秒上报一次');
  }

  DriverActionResult completeActiveTask() {
    _refreshFromStorage();
    final taskId = state.activeTaskId;
    if (taskId == null) {
      return const DriverActionResult(success: false, message: '当前没有进行中任务');
    }

    final index = state.tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      _stopTimer();
      state = state.copyWith(clearActiveTask: true);
      return const DriverActionResult(success: false, message: '任务不存在');
    }

    final nextTasks = [...state.tasks];
    nextTasks[index] = nextTasks[index].copyWith(
      status: DriverTaskStatus.completed,
    );
    _stopTimer();
    state = state.copyWith(tasks: nextTasks, clearActiveTask: true);

    return const DriverActionResult(success: true, message: '任务已完成，位置共享已停止');
  }

  void simulateNextLocationReport() {
    if (state.activeTaskId == null) {
      return;
    }
    _appendLocationUpdate();
  }

  void _appendLocationUpdate() {
    _refreshFromStorage();
    final task = state.activeTask;
    if (task == null) {
      _stopTimer();
      return;
    }

    final previous = state.locationUpdates
        .where((update) => update.vehicleId == task.vehicleId)
        .firstOrNull;
    final update = LocationUpdate(
      vehicleId: task.vehicleId,
      lat: previous == null ? 31.2304 : previous.lat + 0.0018,
      lng: previous == null ? 121.4737 : previous.lng + 0.0012,
      speed: previous == null || previous.speed >= 36 ? 24 : previous.speed + 3,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      locationUpdates: [update, ...state.locationUpdates.take(199)],
    );
  }

  void _syncTimerWithSession() {
    if (state.activeTaskId != null &&
        ref.read(authControllerProvider).user?.role == UserRole.driver) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  void _refreshFromStorage() {
    final saved = ref.read(demoPersistenceProvider).read('driver');
    if (saved != null) {
      state = restoreDemoData(state, () => decodeDriverState(saved, state));
    }
  }

  void _startTimer() {
    _stopTimer();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _appendLocationUpdate();
    });
  }

  void _stopTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }
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
