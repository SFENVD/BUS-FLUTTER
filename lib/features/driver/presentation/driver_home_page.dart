import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/driver_task_model.dart';
import '../../../core/models/location_update.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_mode_switcher.dart';
import '../tasks/providers/driver_task_provider.dart';

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final driverState = ref.watch(driverTaskProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('司机端工作台'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text(user.name)),
          ),
          IconButton(
            tooltip: '退出登录',
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
              context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DriverSummary(state: driverState),
                  const SizedBox(height: 18),
                  const AppModeSwitcher(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (!isWide) {
                        return Column(
                          children: [
                            _StatsPanel(state: driverState),
                            const SizedBox(height: 12),
                            _LocationPanel(state: driverState),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _StatsPanel(state: driverState)),
                          const SizedBox(width: 12),
                          Expanded(child: _LocationPanel(state: driverState)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    title: '今日派车任务',
                    subtitle: '查看路线、发车时间、乘客名单和上车点，发车后自动开启位置共享。',
                  ),
                  const SizedBox(height: 12),
                  _TaskList(tasks: driverState.tasks),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverSummary extends StatelessWidget {
  const _DriverSummary({required this.state});

  final DriverTaskState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.tertiary],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '司机端',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已接入派车任务、乘客名单、统计看板和 5 秒位置上报。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryMetric(
                label: '待发车任务',
                value: '${state.pendingTaskCount}',
              ),
              _SummaryMetric(
                label: '今日乘客',
                value: '${state.todayPassengerCount}',
              ),
              _SummaryMetric(
                label: '位置状态',
                value: state.activeTask == null ? '未开启' : '共享中',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends ConsumerWidget {
  const _StatsPanel({required this.state});

  final DriverTaskState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = state.selectedStats;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: '统计看板', subtitle: '日/周/月维度展示行驶里程、服务人次和准点率。'),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              showSelectedIcon: false,
              selected: {state.selectedStatsPeriod},
              segments: state.stats.map((item) {
                return ButtonSegment<String>(
                  value: item.period,
                  label: Text(item.period),
                );
              }).toList(),
              onSelectionChanged: (selection) {
                ref
                    .read(driverTaskProvider.notifier)
                    .selectStatsPeriod(selection.first);
              },
            ),
            const SizedBox(height: 18),
            _StatsRow(label: '完成车次', value: '${stats.totalTrips} 趟'),
            _StatsRow(label: '服务人次', value: '${stats.totalPassengers} 人'),
            _StatsRow(
              label: '行驶里程',
              value: '${stats.totalDistance.toStringAsFixed(1)} km',
            ),
            const SizedBox(height: 12),
            Text('准点率 ${(stats.onTimeRate * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: stats.onTimeRate),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _LocationPanel extends ConsumerWidget {
  const _LocationPanel({required this.state});

  final DriverTaskState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = state.latestLocation;
    final activeTask = state.activeTask;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: '实时位置共享',
              subtitle: activeTask == null
                  ? '点击任务卡片开始任务后开启位置上报。'
                  : '${activeTask.tripNo} 正在共享位置，每 5 秒上报一次。',
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: activeTask == null
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: latest == null
                  ? const Text('暂无位置上报')
                  : _LocationSummary(update: latest),
            ),
            const SizedBox(height: 12),
            Text('上报次数：${state.locationUpdates.length}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('simulate_location_report'),
                    onPressed: activeTask == null
                        ? null
                        : () {
                            ref
                                .read(driverTaskProvider.notifier)
                                .simulateNextLocationReport();
                          },
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('模拟上报一次'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('complete_active_task'),
                    onPressed: activeTask == null
                        ? null
                        : () => _completeTask(context, ref),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('到站完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _completeTask(BuildContext context, WidgetRef ref) {
    final result = ref.read(driverTaskProvider.notifier).completeActiveTask();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({required this.update});

  final LocationUpdate update;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          update.vehicleId,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text('纬度：${update.lat.toStringAsFixed(5)}'),
        Text('经度：${update.lng.toStringAsFixed(5)}'),
        Text('速度：${update.speed.toStringAsFixed(0)} km/h'),
        Text(
          '时间：${_formatTime(update.timestamp)}',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<DriverTaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tasks.map((task) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TaskCard(task: task),
        );
      }).toList(),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final DriverTaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${task.routeName} · ${task.tripNo}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text('${task.origin} → ${task.destination}'),
                    ],
                  ),
                ),
                Chip(label: Text(task.status.label)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.schedule_outlined,
                  label: _formatDateTime(task.departureTime),
                ),
                _InfoChip(
                  icon: Icons.directions_bus_outlined,
                  label: task.plateNo,
                ),
                _InfoChip(
                  icon: Icons.groups_outlined,
                  label: '${task.passengers.length} 名乘客',
                ),
                _InfoChip(
                  icon: Icons.route_outlined,
                  label: '${task.distanceKm.toStringAsFixed(1)} km',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('乘客名单与上车点'),
              children: task.passengers.map((passenger) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${passenger.seatNo}')),
                  title: Text(
                    '${passenger.name} · 尾号 ${passenger.phoneSuffix}',
                  ),
                  subtitle: Text(passenger.pickupPoint),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _TaskAction(task: task),
          ],
        ),
      ),
    );
  }
}

class _TaskAction extends ConsumerWidget {
  const _TaskAction({required this.task});

  final DriverTaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverTaskProvider);
    final isActive = state.activeTaskId == task.id;

    if (task.status == DriverTaskStatus.completed) {
      return const FilledButton(onPressed: null, child: Text('任务已完成'));
    }

    if (isActive) {
      return FilledButton.icon(
        key: Key('finish_task_${task.id}'),
        onPressed: () {
          final result = ref
              .read(driverTaskProvider.notifier)
              .completeActiveTask();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.message)));
        },
        icon: const Icon(Icons.flag_outlined),
        label: const Text('到站完成'),
      );
    }

    return FilledButton.icon(
      key: Key('start_task_${task.id}'),
      onPressed: state.activeTaskId == null
          ? () {
              final result = ref
                  .read(driverTaskProvider.notifier)
                  .startTask(task.id);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(result.message)));
            }
          : null,
      icon: const Icon(Icons.play_arrow_outlined),
      label: const Text('开始任务并共享位置'),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

String _formatTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.hour)}:${twoDigits(value.minute)}:'
      '${twoDigits(value.second)}';
}
