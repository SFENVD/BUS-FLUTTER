import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/driver_task_model.dart';
import '../../../../core/models/location_update.dart';
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

    return initialState;
  }

  void selectStatsPeriod(String period) {
    state = state.copyWith(selectedStatsPeriod: period);
  }

  DriverActionResult startTask(String taskId) {
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
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _appendLocationUpdate();
    });

    return const DriverActionResult(success: true, message: '已发车，位置将每 5 秒上报一次');
  }

  DriverActionResult completeActiveTask() {
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
    final task = state.activeTask;
    if (task == null) {
      return;
    }

    final step = state.locationUpdates
        .where((update) => update.vehicleId == task.vehicleId)
        .length;
    final update = LocationUpdate(
      vehicleId: task.vehicleId,
      lat: 31.2304 + step * 0.0018,
      lng: 121.4737 + step * 0.0012,
      speed: 24 + (step % 5) * 3,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(locationUpdates: [update, ...state.locationUpdates]);
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
