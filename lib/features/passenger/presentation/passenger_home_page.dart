import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_mode.dart';
import '../../../core/models/app_notification_model.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_mode_switcher.dart';
import '../booking/providers/passenger_booking_provider.dart';

class PassengerHomePage extends ConsumerStatefulWidget {
  const PassengerHomePage({super.key});

  @override
  ConsumerState<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends ConsumerState<PassengerHomePage> {
  BookingStatus? _bookingFilter;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final bookingState = ref.watch(passengerBookingProvider);
    final notifications = ref.watch(notificationProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userBookings = bookingState.bookingsForUser(
      user.id,
      status: _bookingFilter,
    );
    final pendingCount = bookingState
        .bookingsForUser(user.id, status: BookingStatus.pending)
        .length;
    final availableTripCount = bookingState.trips
        .where(
          (trip) =>
              trip.isBookable &&
              bookingState.remainingSeatsForTrip(trip.id) > 0,
        )
        .length;
    final unpaidCount = bookingState.unpaidBookingCountForUser(user.id);
    final unreadCount = notifications
        .where((notification) => !notification.isRead)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('普通用户端工作台'),
        actions: [
          IconButton(
            tooltip: '通知',
            onPressed: () => _showNotificationSheet(notifications),
            icon: Badge.count(
              count: unreadCount,
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text('${user.name} · 信用分 ${user.creditScore}'),
            ),
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
                  _PassengerSummary(
                    creditScore: user.creditScore,
                    pendingCount: pendingCount,
                    availableTripCount: availableTripCount,
                    unpaidCount: unpaidCount,
                  ),
                  const SizedBox(height: 18),
                  const AppModeSwitcher(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 860;
                      final creditPanel = _CreditPanel(
                        creditScore: user.creditScore,
                        creditRecords: bookingState.creditRecordsForUser(
                          user.id,
                        ),
                        bookingState: bookingState,
                      );
                      final notificationPanel = _NotificationPanel(
                        notifications: notifications,
                        onMarkAllRead: () {
                          ref.read(notificationProvider.notifier).markAllRead();
                        },
                      );

                      if (!isWide) {
                        return Column(
                          children: [
                            creditPanel,
                            const SizedBox(height: 12),
                            notificationPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: creditPanel),
                          const SizedBox(width: 12),
                          Expanded(child: notificationPanel),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    title: '预约车次',
                    subtitle: '选择车次和座位，确认后生成待发车预约订单。',
                  ),
                  const SizedBox(height: 12),
                  _TripList(
                    bookingState: bookingState,
                    userId: user.id,
                    onBookTrip: _showSeatDialog,
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    title: '我的预约',
                    subtitle: '支持查看待发车、已完成、已取消预约，并取消待发车订单。',
                  ),
                  const SizedBox(height: 12),
                  _BookingFilterBar(
                    selectedStatus: _bookingFilter,
                    onChanged: (status) {
                      setState(() {
                        _bookingFilter = status;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _BookingList(
                    bookings: userBookings,
                    bookingState: bookingState,
                    onCancel: _confirmCancelBooking,
                    onPay: _showPaymentDialog,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSeatDialog(TripModel trip) async {
    final state = ref.read(passengerBookingProvider);
    final seats = state.availableSeatsForTrip(trip.id);
    if (seats.isEmpty) {
      _showSnack('该车次已满座');
      return;
    }

    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      return;
    }

    var selectedSeat = seats.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('选择座位 · ${trip.routeName}'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${trip.origin} → ${trip.destination}'),
                      const SizedBox(height: 6),
                      Text('发车时间：${_formatDateTime(trip.departureTime)}'),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: seats.map((seat) {
                          return ChoiceChip(
                            key: Key('seat_${trip.id}_$seat'),
                            label: Text('$seat 座'),
                            selected: selectedSeat == seat,
                            onSelected: (_) {
                              setDialogState(() {
                                selectedSeat = seat;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('暂不预约'),
                ),
                FilledButton(
                  key: const Key('confirm_booking'),
                  onPressed: () async {
                    final result = await ref
                        .read(passengerBookingProvider.notifier)
                        .createBooking(
                          userId: user.id,
                          tripId: trip.id,
                          seatNo: selectedSeat,
                        );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    _showSnack(result.message);
                  },
                  child: Text('确认预约 $selectedSeat 座'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmCancelBooking(BookingModel booking) async {
    final controller = ref.read(passengerBookingProvider.notifier);
    final trip = ref.read(passengerBookingProvider).tripById(booking.tripId);
    final penalty = controller.cancellationPenaltyForTrip(trip);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认取消预约？'),
          content: Text(
            '车次：${trip.routeName}\n'
            '发车：${_formatDateTime(trip.departureTime)}\n'
            '按当前规则将扣减信用分 $penalty 分。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('保留预约'),
            ),
            FilledButton(
              key: const Key('confirm_cancel_booking'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认取消'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final result = await ref
        .read(passengerBookingProvider.notifier)
        .cancelBooking(booking.id);
    _showSnack(result.message);
  }

  Future<void> _showPaymentDialog(BookingModel booking) async {
    final trip = ref.read(passengerBookingProvider).tripById(booking.tripId);
    var selectedMethod = PaymentMethod.wechat;

    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('支付车费'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${trip.routeName} · 座位 ${booking.seatNo}'),
                  const SizedBox(height: 8),
                  Text('应付金额：¥${booking.fare.toStringAsFixed(0)}'),
                  const SizedBox(height: 16),
                  SegmentedButton<PaymentMethod>(
                    showSelectedIcon: false,
                    selected: {selectedMethod},
                    segments: PaymentMethod.values.map((method) {
                      return ButtonSegment<PaymentMethod>(
                        value: method,
                        label: Text(method.label),
                      );
                    }).toList(),
                    onSelectionChanged: (selection) {
                      setDialogState(() {
                        selectedMethod = selection.first;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('暂不支付'),
                ),
                FilledButton(
                  key: const Key('confirm_payment'),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedMethod),
                  child: const Text('确认支付'),
                ),
              ],
            );
          },
        );
      },
    );

    if (method == null) {
      return;
    }

    _showSnack('正在发起${method.label}...');
    final result = await ref
        .read(passengerBookingProvider.notifier)
        .payBooking(bookingId: booking.id, method: method);
    _showSnack(result.message);
  }

  void _showNotificationSheet(List<AppNotificationModel> notifications) {
    ref.read(notificationProvider.notifier).markAllRead();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _NotificationSheet(notifications: notifications);
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PassengerSummary extends StatelessWidget {
  const _PassengerSummary({
    required this.creditScore,
    required this.pendingCount,
    required this.availableTripCount,
    required this.unpaidCount,
  });

  final int creditScore;
  final int pendingCount;
  final int availableTripCount;
  final int unpaidCount;

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
            AppMode.passenger.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'P5 已接入预约、Mock 支付、信用等级和推送通知流程。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryMetric(label: '可预约车次', value: '$availableTripCount'),
              _SummaryMetric(label: '待发车预约', value: '$pendingCount'),
              _SummaryMetric(label: '待支付订单', value: '$unpaidCount'),
              _SummaryMetric(label: '当前信用分', value: '$creditScore'),
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

class _CreditPanel extends StatelessWidget {
  const _CreditPanel({
    required this.creditScore,
    required this.creditRecords,
    required this.bookingState,
  });

  final int creditScore;
  final List<BookingModel> creditRecords;
  final PassengerBookingState bookingState;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grade = _creditGradeForScore(creditScore);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '信用等级',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('${grade.label} · $creditScore/100'),
                    ],
                  ),
                ),
                Chip(label: Text(grade.badge)),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: creditScore / 100),
            const SizedBox(height: 14),
            if (creditRecords.isEmpty)
              Text(
                '暂无失信记录，保持良好乘车习惯。',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              ...creditRecords.take(3).map((record) {
                final trip = bookingState.tripById(record.tripId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${trip.routeName} 取消预约')),
                      Text('-${record.creditPenalty} 分'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.notifications,
    required this.onMarkAllRead,
  });

  final List<AppNotificationModel> notifications;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '推送通知',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('mark_notifications_read'),
                  onPressed: notifications.isEmpty ? null : onMarkAllRead,
                  child: const Text('全部已读'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (notifications.isEmpty)
              Text(
                '预约、支付和信用变化会在这里生成推送通知。',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              ...notifications.take(3).map((notification) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NotificationTile(notification: notification),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({required this.notifications});

  final List<AppNotificationModel> notifications;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '通知中心',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (notifications.isEmpty)
              const Text('暂无通知')
            else
              ...notifications.map((notification) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NotificationTile(notification: notification),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notification.isRead
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.36)
            : colorScheme.primaryContainer.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _notificationIcon(notification.type),
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(notification.message),
              ],
            ),
          ),
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

class _TripList extends StatelessWidget {
  const _TripList({
    required this.bookingState,
    required this.userId,
    required this.onBookTrip,
  });

  final PassengerBookingState bookingState;
  final String userId;
  final ValueChanged<TripModel> onBookTrip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bookingState.trips.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isWide ? 2.05 : 1.55,
          ),
          itemBuilder: (context, index) {
            final trip = bookingState.trips[index];
            return _TripCard(
              trip: trip,
              remainingSeats: bookingState.remainingSeatsForTrip(trip.id),
              alreadyBooked: bookingState.hasActiveBooking(
                userId: userId,
                tripId: trip.id,
              ),
              onBook: () => onBookTrip(trip),
            );
          },
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.remainingSeats,
    required this.alreadyBooked,
    required this.onBook,
  });

  final TripModel trip;
  final int remainingSeats;
  final bool alreadyBooked;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canBook = trip.isBookable && remainingSeats > 0 && !alreadyBooked;

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
                    Icons.directions_bus_filled_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.routeName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text('${trip.origin} → ${trip.destination}'),
                    ],
                  ),
                ),
                Chip(label: Text(trip.status.label)),
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TripInfoChip(
                  icon: Icons.schedule_outlined,
                  label: _formatDateTime(trip.departureTime),
                ),
                _TripInfoChip(
                  icon: Icons.event_seat_outlined,
                  label: '余座 $remainingSeats/${trip.totalSeats}',
                ),
                _TripInfoChip(
                  icon: Icons.payments_outlined,
                  label: '¥${trip.fare.toStringAsFixed(0)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: Key('book_trip_${trip.id}'),
              onPressed: canBook ? onBook : null,
              child: Text(_bookButtonText),
            ),
          ],
        ),
      ),
    );
  }

  String get _bookButtonText {
    if (alreadyBooked) {
      return '已预约该车次';
    }
    if (remainingSeats <= 0) {
      return '已满座';
    }
    if (!trip.isBookable) {
      return '不可预约';
    }
    return '预约选座';
  }
}

class _TripInfoChip extends StatelessWidget {
  const _TripInfoChip({required this.icon, required this.label});

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

class _BookingFilterBar extends StatelessWidget {
  const _BookingFilterBar({
    required this.selectedStatus,
    required this.onChanged,
  });

  final BookingStatus? selectedStatus;
  final ValueChanged<BookingStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('全部'),
          selected: selectedStatus == null,
          onSelected: (_) => onChanged(null),
        ),
        ...BookingStatus.values.map((status) {
          return ChoiceChip(
            label: Text(status.label),
            selected: selectedStatus == status,
            onSelected: (_) => onChanged(status),
          );
        }),
      ],
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    required this.bookingState,
    required this.onCancel,
    required this.onPay,
  });

  final List<BookingModel> bookings;
  final PassengerBookingState bookingState;
  final ValueChanged<BookingModel> onCancel;
  final ValueChanged<BookingModel> onPay;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Icon(
                Icons.inbox_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              const Text('暂无符合条件的预约记录'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: bookings.map((booking) {
        final trip = bookingState.tripById(booking.tripId);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BookingCard(
            booking: booking,
            trip: trip,
            onCancel: () => onCancel(booking),
            onPay: () => onPay(booking),
          ),
        );
      }).toList(),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.trip,
    required this.onCancel,
    required this.onPay,
  });

  final BookingModel booking;
  final TripModel trip;
  final VoidCallback onCancel;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 680;

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.routeName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Chip(label: Text(booking.status.label)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${trip.origin} → ${trip.destination}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TripInfoChip(
                      icon: Icons.schedule_outlined,
                      label: _formatDateTime(trip.departureTime),
                    ),
                    _TripInfoChip(
                      icon: Icons.event_seat_outlined,
                      label: '座位 ${booking.seatNo}',
                    ),
                    _TripInfoChip(
                      icon: Icons.confirmation_number_outlined,
                      label: booking.id,
                    ),
                    _TripInfoChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: booking.paymentStatus.label,
                    ),
                  ],
                ),
                if (booking.status == BookingStatus.cancelled) ...[
                  const SizedBox(height: 10),
                  Text(
                    '已扣减信用分 ${booking.creditPenalty} 分',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ],
              ],
            );

            final actions = _BookingActions(
              booking: booking,
              onPay: onPay,
              onCancel: onCancel,
            );

            if (!isWide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  if (booking.status == BookingStatus.pending) ...[
                    const SizedBox(height: 12),
                    actions,
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookingActions extends StatelessWidget {
  const _BookingActions({
    required this.booking,
    required this.onPay,
    required this.onCancel,
  });

  final BookingModel booking;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (booking.status != BookingStatus.pending) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (booking.canPay)
          FilledButton.icon(
            key: Key('pay_booking_${booking.id}'),
            onPressed: onPay,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('立即支付'),
          )
        else if (booking.paymentStatus == BookingPaymentStatus.processing)
          FilledButton.icon(
            onPressed: null,
            icon: const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: const Text('支付中'),
          ),
        OutlinedButton.icon(
          key: Key('cancel_${booking.id}'),
          onPressed: onCancel,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('取消预约'),
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

_CreditGrade _creditGradeForScore(int score) {
  if (score >= 90) {
    return const _CreditGrade(label: '优秀', badge: '优秀用户');
  }
  if (score >= 80) {
    return const _CreditGrade(label: '良好', badge: '良好');
  }
  if (score >= 60) {
    return const _CreditGrade(label: '一般', badge: '需关注');
  }
  return const _CreditGrade(label: '受限', badge: '受限');
}

IconData _notificationIcon(AppNotificationType type) {
  return switch (type) {
    AppNotificationType.booking => Icons.event_available_outlined,
    AppNotificationType.payment => Icons.payments_outlined,
    AppNotificationType.credit => Icons.verified_user_outlined,
    AppNotificationType.system => Icons.notifications_outlined,
  };
}

class _CreditGrade {
  const _CreditGrade({required this.label, required this.badge});

  final String label;
  final String badge;
}
