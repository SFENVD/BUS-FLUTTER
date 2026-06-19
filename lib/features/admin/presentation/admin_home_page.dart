import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/admin_driver_model.dart';
import '../../../core/models/analytics_model.dart';
import '../../../core/models/dispatch_model.dart';
import '../../../core/models/vehicle_location_model.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_mode_switcher.dart';
import '../providers/admin_provider.dart';

class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final adminState = ref.watch(adminProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('后台管理端工作台'),
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
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdminSummary(state: adminState),
                  const SizedBox(height: 18),
                  const AppModeSwitcher(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 960;
                      if (!isWide) {
                        return Column(
                          children: [
                            _VehiclePanel(state: adminState),
                            const SizedBox(height: 14),
                            _DriverPanel(state: adminState),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _VehiclePanel(state: adminState)),
                          const SizedBox(width: 14),
                          Expanded(child: _DriverPanel(state: adminState)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _DispatchPanel(state: adminState),
                  const SizedBox(height: 28),
                  _TrackingPanel(state: adminState),
                  const SizedBox(height: 28),
                  _AnalyticsPanel(state: adminState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSummary extends StatelessWidget {
  const _AdminSummary({required this.state});

  final AdminState state;

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
            '后台管理端',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '统一管理车辆、司机、车次调度、实时监控和历史数据分析。',
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
                label: '在线车辆',
                value: '${state.runningVehicleCount}',
              ),
              _SummaryMetric(label: '空闲车辆', value: '${state.idleVehicleCount}'),
              _SummaryMetric(
                label: '维修车辆',
                value: '${state.maintenanceVehicleCount}',
              ),
              _SummaryMetric(label: '司机总数', value: '${state.drivers.length}'),
              _SummaryMetric(
                label: '待调度人数',
                value: '${state.pendingDemandPassengerCount}',
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

class _VehiclePanel extends ConsumerWidget {
  const _VehiclePanel({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              title: '车辆管理',
              subtitle: '维护车牌、车型、座位数和车辆状态。',
              buttonLabel: '新增车辆',
              buttonKey: const Key('add_vehicle'),
              onPressed: () => _openVehicleDialog(context, ref),
            ),
            const SizedBox(height: 14),
            ...state.vehicles.map((vehicle) {
              final driver = state.driverForVehicle(vehicle.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VehicleCard(
                  vehicle: vehicle,
                  driver: driver,
                  onEdit: () =>
                      _openVehicleDialog(context, ref, initialVehicle: vehicle),
                  onDelete: () => _deleteVehicle(context, ref, vehicle),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _openVehicleDialog(
    BuildContext context,
    WidgetRef ref, {
    VehicleModel? initialVehicle,
  }) async {
    final data = await showDialog<_VehicleFormData>(
      context: context,
      builder: (dialogContext) {
        return _VehicleDialog(initialVehicle: initialVehicle);
      },
    );
    if (data == null || !context.mounted) {
      return;
    }

    final controller = ref.read(adminProvider.notifier);
    final result = initialVehicle == null
        ? controller.addVehicle(
            plateNo: data.plateNo,
            model: data.model,
            seatCount: data.seatCount,
            status: data.status,
          )
        : controller.updateVehicle(
            initialVehicle.copyWith(
              plateNo: data.plateNo,
              model: data.model,
              seatCount: data.seatCount,
              status: data.status,
            ),
          );
    _showSnack(context, result.message);
  }

  void _deleteVehicle(
    BuildContext context,
    WidgetRef ref,
    VehicleModel vehicle,
  ) {
    final result = ref.read(adminProvider.notifier).deleteVehicle(vehicle.id);
    _showSnack(context, result.message);
  }
}

class _DriverPanel extends ConsumerWidget {
  const _DriverPanel({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              title: '司机管理',
              subtitle: '维护司机资料、驾照信息，并绑定可用车辆。',
              buttonLabel: '新增司机',
              buttonKey: const Key('add_driver'),
              onPressed: () => _openDriverDialog(context, ref),
            ),
            const SizedBox(height: 14),
            ...state.drivers.map((driver) {
              final vehicle = state.vehicleById(driver.boundVehicleId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DriverCard(
                  driver: driver,
                  vehicle: vehicle,
                  onEdit: () =>
                      _openDriverDialog(context, ref, initialDriver: driver),
                  onDelete: () => _deleteDriver(context, ref, driver),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _openDriverDialog(
    BuildContext context,
    WidgetRef ref, {
    AdminDriverModel? initialDriver,
  }) async {
    final data = await showDialog<_DriverFormData>(
      context: context,
      builder: (dialogContext) {
        return _DriverDialog(
          initialDriver: initialDriver,
          vehicles: ref.read(adminProvider).vehicles,
        );
      },
    );
    if (data == null || !context.mounted) {
      return;
    }

    final controller = ref.read(adminProvider.notifier);
    final result = initialDriver == null
        ? controller.addDriver(
            name: data.name,
            phone: data.phone,
            licenseNo: data.licenseNo,
            boundVehicleId: data.boundVehicleId,
          )
        : controller.updateDriver(
            initialDriver.copyWith(
              name: data.name,
              phone: data.phone,
              licenseNo: data.licenseNo,
              boundVehicleId: data.boundVehicleId,
              clearBoundVehicle: data.boundVehicleId == null,
            ),
          );
    _showSnack(context, result.message);
  }

  void _deleteDriver(
    BuildContext context,
    WidgetRef ref,
    AdminDriverModel driver,
  ) {
    final result = ref.read(adminProvider.notifier).deleteDriver(driver.id);
    _showSnack(context, result.message);
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonKey,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              icon: const Icon(Icons.add),
              label: Text(buttonLabel),
            ),
          ],
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

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.driver,
    required this.onEdit,
    required this.onDelete,
  });

  final VehicleModel vehicle;
  final AdminDriverModel? driver;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _AdminItemShell(
      leadingIcon: Icons.directions_bus_outlined,
      title: vehicle.plateNo,
      subtitle: '${vehicle.model} · ${vehicle.seatCount} 座',
      meta: '绑定司机：${driver?.name ?? '未绑定'}',
      chipLabel: vehicle.status.label,
      editKey: Key('edit_vehicle_${vehicle.id}'),
      deleteKey: Key('delete_vehicle_${vehicle.id}'),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminDriverModel driver;
  final VehicleModel? vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final boundVehicle = vehicle;

    return _AdminItemShell(
      leadingIcon: Icons.badge_outlined,
      title: driver.name,
      subtitle: '${driver.phone} · ${driver.licenseNo}',
      meta: '绑定车辆：${boundVehicle?.plateNo ?? '未绑定'}',
      chipLabel: boundVehicle == null ? '未绑定' : boundVehicle.status.label,
      editKey: Key('edit_driver_${driver.id}'),
      deleteKey: Key('delete_driver_${driver.id}'),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _AdminItemShell extends StatelessWidget {
  const _AdminItemShell({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.chipLabel,
    required this.editKey,
    required this.deleteKey,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final String meta;
  final String chipLabel;
  final Key editKey;
  final Key deleteKey;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(leadingIcon, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Chip(label: Text(chipLabel)),
                  ],
                ),
                Text(subtitle),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            key: editKey,
            tooltip: '编辑',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: deleteKey,
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _DispatchPanel extends ConsumerWidget {
  const _DispatchPanel({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    title: '车次调度',
                    subtitle: '汇总预约需求，支持人工分配车辆/司机和 AI 辅助推荐。',
                  ),
                ),
                FilledButton.icon(
                  key: const Key('generate_ai_dispatch'),
                  onPressed: () async {
                    final result = await ref
                        .read(adminProvider.notifier)
                        .generateAiDispatchPlans();
                    if (!context.mounted) {
                      return;
                    }
                    _showSnack(context, result.message);
                  },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('AI 生成方案'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final demands = _DispatchDemandList(state: state);
                final plans = _DispatchPlanList(state: state);

                if (!isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [demands, const SizedBox(height: 14), plans],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: demands),
                    const SizedBox(width: 14),
                    Expanded(child: plans),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DispatchDemandList extends ConsumerWidget {
  const _DispatchDemandList({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '预约需求汇总',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...state.dispatchDemands.map((demand) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DispatchDemandCard(
              demand: demand,
              onManualDispatch: demand.status == DispatchDemandStatus.pending
                  ? () => _openManualDispatchDialog(context, ref, demand)
                  : null,
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openManualDispatchDialog(
    BuildContext context,
    WidgetRef ref,
    DispatchDemandModel demand,
  ) async {
    final data = await showDialog<_ManualDispatchFormData>(
      context: context,
      builder: (dialogContext) {
        return _ManualDispatchDialog(
          demand: demand,
          state: ref.read(adminProvider),
        );
      },
    );
    if (data == null || !context.mounted) {
      return;
    }

    final result = await ref
        .read(adminProvider.notifier)
        .createManualDispatchPlan(
          demandId: demand.id,
          vehicleId: data.vehicleId,
          driverId: data.driverId,
        );
    if (!context.mounted) {
      return;
    }
    _showSnack(context, result.message);
  }
}

class _DispatchDemandCard extends StatelessWidget {
  const _DispatchDemandCard({
    required this.demand,
    required this.onManualDispatch,
  });

  final DispatchDemandModel demand;
  final VoidCallback? onManualDispatch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  demand.routeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Chip(label: Text(demand.status.label)),
            ],
          ),
          Text('${demand.origin} → ${demand.destination}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.groups_outlined,
                label: '${demand.passengerCount} 人',
              ),
              _InfoPill(
                icon: Icons.schedule_outlined,
                label: _formatDateTime(demand.departureTime),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: Key('manual_dispatch_${demand.id}'),
            onPressed: onManualDispatch,
            icon: const Icon(Icons.tune_outlined),
            label: const Text('人工调度'),
          ),
        ],
      ),
    );
  }
}

class _DispatchPlanList extends ConsumerWidget {
  const _DispatchPlanList({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = state.dispatchPlans;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '调度方案',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (plans.isEmpty)
          _EmptyBlock(icon: Icons.route_outlined, text: '暂无调度方案，点击 AI 生成或人工调度。')
        else
          ...plans.map((plan) {
            final vehicle = state.vehicleById(plan.vehicleId);
            final driver = state.driverById(plan.driverId);
            final isFirstPending =
                state.pendingDispatchPlans.firstOrNull?.id == plan.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DispatchPlanCard(
                plan: plan,
                vehicle: vehicle,
                driver: driver,
                confirmKey: isFirstPending
                    ? const Key('confirm_first_dispatch_plan')
                    : Key('confirm_dispatch_plan_${plan.id}'),
                onConfirm: plan.isConfirmed
                    ? null
                    : () async {
                        final result = await ref
                            .read(adminProvider.notifier)
                            .confirmDispatchPlan(plan.id);
                        if (!context.mounted) {
                          return;
                        }
                        _showSnack(context, result.message);
                      },
              ),
            );
          }),
      ],
    );
  }
}

class _DispatchPlanCard extends StatelessWidget {
  const _DispatchPlanCard({
    required this.plan,
    required this.vehicle,
    required this.driver,
    required this.confirmKey,
    required this.onConfirm,
  });

  final DispatchPlanModel plan;
  final VehicleModel? vehicle;
  final AdminDriverModel? driver;
  final Key confirmKey;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: plan.isConfirmed
            ? colorScheme.primaryContainer.withValues(alpha: 0.46)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.routeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Chip(label: Text(plan.isConfirmed ? '已确认' : '待确认')),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(label: '车辆', value: vehicle?.plateNo ?? plan.vehicleId),
          _DetailRow(label: '司机', value: driver?.name ?? plan.driverId),
          _DetailRow(label: '来源', value: plan.isAiGenerated ? 'AI 推荐' : '人工分配'),
          _DetailRow(
            label: '满载率',
            value: '${(plan.loadRate * 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: confirmKey,
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(plan.isConfirmed ? '方案已生效' : '确认生效'),
          ),
        ],
      ),
    );
  }
}

class _TrackingPanel extends ConsumerWidget {
  const _TrackingPanel({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = state.selectedLocation;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SectionTitle(
                    title: '实时位置监控',
                    subtitle: '地图展示在途车辆位置，点击标记查看车辆、司机和速度。',
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('simulate_admin_location_tick'),
                  onPressed: () {
                    ref.read(adminProvider.notifier).simulateLocationTick();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新位置'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                final map = _MockMap(
                  state: state,
                  onSelectVehicle: (vehicleId) {
                    ref.read(adminProvider.notifier).selectVehicle(vehicleId);
                  },
                );
                final detail = _VehicleTrackingDetail(
                  location: location,
                  state: state,
                );

                if (!isWide) {
                  return Column(
                    children: [map, const SizedBox(height: 14), detail],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: map),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: detail),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            const _PassengerEtaPanel(),
          ],
        ),
      ),
    );
  }
}

class _MockMap extends StatelessWidget {
  const _MockMap({required this.state, required this.onSelectVehicle});

  final AdminState state;
  final ValueChanged<String> onSelectVehicle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.secondaryContainer.withValues(alpha: 0.42),
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MapGridPainter(colorScheme.outline)),
          ),
          Positioned(
            left: 24,
            top: 22,
            child: Text(
              'Campus Live Map',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...state.locations.map((location) {
            final vehicle = state.vehicleById(location.vehicleId);
            final isSelected = state.selectedVehicleId == location.vehicleId;
            final left = 90 + (location.lng - 121.47) * 13000;
            final top = 230 - (location.lat - 31.22) * 8000;

            return Positioned(
              left: left.clamp(40, 500).toDouble(),
              top: top.clamp(64, 250).toDouble(),
              child: _VehicleMarker(
                key: Key('map_marker_${location.vehicleId}'),
                label: vehicle?.plateNo ?? location.vehicleId,
                isSelected: isSelected,
                onTap: () => onSelectVehicle(location.vehicleId),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_bus_filled_outlined,
              size: 18,
              color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleTrackingDetail extends StatelessWidget {
  const _VehicleTrackingDetail({required this.location, required this.state});

  final VehicleLocationModel? location;
  final AdminState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedLocation = location;

    if (selectedLocation == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('暂无在途车辆位置'),
      );
    }

    final vehicle = state.vehicleById(selectedLocation.vehicleId);
    final driver = state.driverById(selectedLocation.driverId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicle?.plateNo ?? selectedLocation.vehicleId,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _DetailRow(label: '车次', value: selectedLocation.tripNo),
          _DetailRow(label: '司机', value: driver?.name ?? '未绑定'),
          _DetailRow(
            label: '当前速度',
            value: '${selectedLocation.speed.toStringAsFixed(0)} km/h',
          ),
          _DetailRow(
            label: '坐标',
            value:
                '${selectedLocation.lat.toStringAsFixed(5)}, ${selectedLocation.lng.toStringAsFixed(5)}',
          ),
          _DetailRow(
            label: '更新时间',
            value: _formatTime(selectedLocation.updatedAt),
          ),
        ],
      ),
    );
  }
}

class _PassengerEtaPanel extends StatelessWidget {
  const _PassengerEtaPanel();

  static const _items = [
    _PassengerEtaItem(
      passengerName: '张同学',
      pickupPoint: '南门学生公寓',
      distanceKm: 1.2,
      etaMinutes: 8,
    ),
    _PassengerEtaItem(
      passengerName: '李老师',
      pickupPoint: '图书馆广场',
      distanceKm: 2.6,
      etaMinutes: 14,
    ),
    _PassengerEtaItem(
      passengerName: '周同学',
      pickupPoint: '附属医院站',
      distanceKm: 4.8,
      etaMinutes: 23,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _softPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预约客户 ETA',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '根据车辆位置估算预约客户与上车点的距离和到达时间。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ..._items.map((item) => _PassengerEtaTile(item: item)),
        ],
      ),
    );
  }
}

class _PassengerEtaTile extends StatelessWidget {
  const _PassengerEtaTile({required this.item});

  final _PassengerEtaItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person_outline)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.passengerName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(item.pickupPoint),
              ],
            ),
          ),
          Text(
            '${item.distanceKm.toStringAsFixed(1)} km · 预计 ${item.etaMinutes} 分钟',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PassengerEtaItem {
  const _PassengerEtaItem({
    required this.passengerName,
    required this.pickupPoint,
    required this.distanceKm,
    required this.etaMinutes,
  });

  final String passengerName;
  final String pickupPoint;
  final double distanceKm;
  final int etaMinutes;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _softPanelDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AnalyticsPanel extends ConsumerWidget {
  const _AnalyticsPanel({required this.state});

  final AdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = state.selectedAnalytics;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    title: '历史数据分析',
                    subtitle: '按日/周/月查看出行人次、路线热度、收入和车辆利用率。',
                  ),
                ),
                SegmentedButton<AnalyticsPeriod>(
                  showSelectedIcon: false,
                  selected: {state.selectedAnalyticsPeriod},
                  segments: AnalyticsPeriod.values.map((period) {
                    return ButtonSegment<AnalyticsPeriod>(
                      value: period,
                      label: Text(period.label),
                    );
                  }).toList(),
                  onSelectionChanged: (selection) {
                    ref
                        .read(adminProvider.notifier)
                        .selectAnalyticsPeriod(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AnalyticsMetric(
                  label: '出行人次',
                  value: '${snapshot.totalPassengers}',
                ),
                _AnalyticsMetric(
                  label: '收入',
                  value: '¥${snapshot.totalRevenue.toStringAsFixed(0)}',
                ),
                _AnalyticsMetric(
                  label: '车辆利用率',
                  value:
                      '${(snapshot.vehicleUtilization * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                final trend = _TrendChart(snapshot: snapshot);
                final ranking = _RouteRanking(snapshot: snapshot);

                if (!isWide) {
                  return Column(
                    children: [trend, const SizedBox(height: 14), ranking],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: trend),
                    const SizedBox(width: 14),
                    Expanded(child: ranking),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.snapshot});

  final AdminAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final maxPassengers = snapshot.trend
        .map((point) => point.passengers)
        .fold<int>(1, (max, value) => value > max ? value : max);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _softPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '出行人次趋势',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: snapshot.trend.map((point) {
                final ratio = point.passengers / maxPassengers;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${point.passengers}'),
                        const SizedBox(height: 6),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: ratio.clamp(0.08, 1),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(point.label),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRanking extends StatelessWidget {
  const _RouteRanking({required this.snapshot});

  final AdminAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final maxPassengers = snapshot.routeRanking
        .map((route) => route.passengers)
        .fold<int>(1, (max, value) => value > max ? value : max);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _softPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '路线热度排行',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          ...snapshot.routeRanking.map((route) {
            final ratio = route.passengers / maxPassengers;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          route.routeName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text('${route.passengers} 人'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 4),
                  Text(
                    '收入 ¥${route.revenue.toStringAsFixed(0)} · 利用率 ${(route.vehicleUtilization * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ManualDispatchDialog extends StatefulWidget {
  const _ManualDispatchDialog({required this.demand, required this.state});

  final DispatchDemandModel demand;
  final AdminState state;

  @override
  State<_ManualDispatchDialog> createState() => _ManualDispatchDialogState();
}

class _ManualDispatchDialogState extends State<_ManualDispatchDialog> {
  late String _vehicleId;
  late String _driverId;

  List<VehicleModel> get _availableVehicles {
    return widget.state.vehicles
        .where(
          (vehicle) =>
              vehicle.status == VehicleStatus.idle &&
              vehicle.seatCount >= widget.demand.passengerCount,
        )
        .toList();
  }

  List<AdminDriverModel> get _availableDrivers {
    return widget.state.drivers.where((driver) {
      return driver.boundVehicleId == null ||
          driver.boundVehicleId == _vehicleId;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final firstVehicle = _availableVehicles.firstOrNull;
    _vehicleId = firstVehicle?.id ?? '';
    _driverId = firstVehicle == null
        ? ''
        : widget.state.driverForVehicle(firstVehicle.id)?.id ??
              _availableDrivers.firstOrNull?.id ??
              '';
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _availableVehicles;
    final drivers = _availableDrivers;

    return AlertDialog(
      title: Text('人工调度 · ${widget.demand.routeName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.demand.passengerCount} 人 · ${_formatDateTime(widget.demand.departureTime)}',
            ),
            const SizedBox(height: 14),
            if (vehicles.isEmpty)
              const Text('暂无满足座位数的空闲车辆')
            else ...[
              DropdownButtonFormField<String>(
                key: const Key('manual_vehicle_dropdown'),
                initialValue: _vehicleId,
                decoration: const InputDecoration(labelText: '车辆'),
                items: vehicles.map((vehicle) {
                  return DropdownMenuItem<String>(
                    value: vehicle.id,
                    child: Text('${vehicle.plateNo} · ${vehicle.seatCount} 座'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _vehicleId = value;
                    _driverId =
                        widget.state.driverForVehicle(value)?.id ??
                        _availableDrivers.firstOrNull?.id ??
                        '';
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('manual_driver_dropdown'),
                initialValue: drivers.any((driver) => driver.id == _driverId)
                    ? _driverId
                    : null,
                decoration: const InputDecoration(labelText: '司机'),
                items: drivers.map((driver) {
                  return DropdownMenuItem<String>(
                    value: driver.id,
                    child: Text(driver.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _driverId = value ?? '';
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('save_manual_dispatch'),
          onPressed: _vehicleId.isEmpty || _driverId.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(
                    _ManualDispatchFormData(
                      vehicleId: _vehicleId,
                      driverId: _driverId,
                    ),
                  );
                },
          child: const Text('生成方案'),
        ),
      ],
    );
  }
}

class _VehicleDialog extends StatefulWidget {
  const _VehicleDialog({this.initialVehicle});

  final VehicleModel? initialVehicle;

  @override
  State<_VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<_VehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateController;
  late final TextEditingController _modelController;
  late final TextEditingController _seatController;
  late VehicleStatus _status;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.initialVehicle;
    _plateController = TextEditingController(text: vehicle?.plateNo ?? '');
    _modelController = TextEditingController(text: vehicle?.model ?? '');
    _seatController = TextEditingController(
      text: vehicle?.seatCount.toString() ?? '45',
    );
    _status = vehicle?.status ?? VehicleStatus.idle;
  }

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    _seatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialVehicle == null ? '新增车辆' : '编辑车辆'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('vehicle_plate_field'),
                controller: _plateController,
                decoration: const InputDecoration(labelText: '车牌号'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('vehicle_model_field'),
                controller: _modelController,
                decoration: const InputDecoration(labelText: '车型'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _seatController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: '座位数'),
                validator: (value) {
                  final seats = int.tryParse(value ?? '');
                  if (seats == null || seats <= 0) {
                    return '请输入有效座位数';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VehicleStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '车辆状态'),
                items: VehicleStatus.values.map((status) {
                  return DropdownMenuItem<VehicleStatus>(
                    value: status,
                    child: Text(status.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('save_vehicle'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _VehicleFormData(
                plateNo: _plateController.text,
                model: _modelController.text,
                seatCount: int.parse(_seatController.text),
                status: _status,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _DriverDialog extends StatefulWidget {
  const _DriverDialog({required this.vehicles, this.initialDriver});

  final List<VehicleModel> vehicles;
  final AdminDriverModel? initialDriver;

  @override
  State<_DriverDialog> createState() => _DriverDialogState();
}

class _DriverDialogState extends State<_DriverDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licenseController;
  late String _vehicleSelection;

  @override
  void initState() {
    super.initState();
    final driver = widget.initialDriver;
    _nameController = TextEditingController(text: driver?.name ?? '');
    _phoneController = TextEditingController(text: driver?.phone ?? '');
    _licenseController = TextEditingController(text: driver?.licenseNo ?? '');
    _vehicleSelection = driver?.boundVehicleId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialDriver == null ? '新增司机' : '编辑司机'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('driver_name_field'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: '姓名'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('driver_phone_field'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: const InputDecoration(labelText: '手机号'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('driver_license_field'),
                controller: _licenseController,
                decoration: const InputDecoration(labelText: '驾照编号'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _vehicleSelection,
                decoration: const InputDecoration(labelText: '绑定车辆'),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('未绑定')),
                  ...widget.vehicles.map((vehicle) {
                    return DropdownMenuItem<String>(
                      value: vehicle.id,
                      child: Text(
                        '${vehicle.plateNo} · ${vehicle.status.label}',
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _vehicleSelection = value ?? '';
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('save_driver'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              _DriverFormData(
                name: _nameController.text,
                phone: _phoneController.text,
                licenseNo: _licenseController.text,
                boundVehicleId: _vehicleSelection.isEmpty
                    ? null
                    : _vehicleSelection,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _VehicleFormData {
  const _VehicleFormData({
    required this.plateNo,
    required this.model,
    required this.seatCount,
    required this.status,
  });

  final String plateNo;
  final String model;
  final int seatCount;
  final VehicleStatus status;
}

class _DriverFormData {
  const _DriverFormData({
    required this.name,
    required this.phone,
    required this.licenseNo,
    this.boundVehicleId,
  });

  final String name;
  final String phone;
  final String licenseNo;
  final String? boundVehicleId;
}

class _ManualDispatchFormData {
  const _ManualDispatchFormData({
    required this.vehicleId,
    required this.driverId,
  });

  final String vehicleId;
  final String driverId;
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

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..strokeWidth = 1;

    for (var x = 40.0; x < size.width; x += 72) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 48.0; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final routePaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final route = Path()
      ..moveTo(48, size.height - 72)
      ..quadraticBezierTo(size.width * 0.32, 120, size.width * 0.62, 190)
      ..quadraticBezierTo(size.width * 0.82, 238, size.width - 52, 88);
    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '必填';
  }
  return null;
}

void _showSnack(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

BoxDecoration _softPanelDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  return BoxDecoration(
    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
    borderRadius: BorderRadius.circular(20),
  );
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

extension _IterableFirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
