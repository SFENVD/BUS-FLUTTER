import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_notification_model.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/models/payment_model.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/persistence/demo_persistence.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../data/mock_passenger_repository.dart';
import '../data/passenger_state_codec.dart';

const paymentAttemptTimeout = Duration(seconds: 10);

final mockPassengerRepositoryProvider = Provider<MockPassengerRepository>((
  ref,
) {
  return MockPassengerRepository();
});

final passengerBookingProvider =
    NotifierProvider<PassengerBookingController, PassengerBookingState>(
      PassengerBookingController.new,
    );

class PassengerBookingState {
  const PassengerBookingState({
    required this.trips,
    required this.bookings,
    required this.payments,
  });

  final List<TripModel> trips;
  final List<BookingModel> bookings;
  final List<PaymentModel> payments;

  List<BookingModel> bookingsForUser(String userId, {BookingStatus? status}) {
    final items = bookings.where((booking) => booking.userId == userId);
    if (status == null) {
      return items.toList();
    }
    return items.where((booking) => booking.status == status).toList();
  }

  TripModel tripById(String tripId) {
    return trips.firstWhere((trip) => trip.id == tripId);
  }

  int remainingSeatsForTrip(String tripId) {
    final trip = tripById(tripId);
    final activeBookings = bookings
        .where((booking) => booking.tripId == tripId && booking.isActive)
        .length;
    return trip.totalSeats - trip.bookedSeats - activeBookings;
  }

  List<int> availableSeatsForTrip(String tripId) {
    final trip = tripById(tripId);
    final occupiedSeats = bookings
        .where((booking) => booking.tripId == tripId && booking.isActive)
        .map((booking) => booking.seatNo)
        .toSet();

    return [
      for (var seat = trip.bookedSeats + 1; seat <= trip.totalSeats; seat++)
        if (!occupiedSeats.contains(seat)) seat,
    ];
  }

  bool hasActiveBooking({required String userId, required String tripId}) {
    return bookings.any(
      (booking) =>
          booking.userId == userId &&
          booking.tripId == tripId &&
          booking.isActive,
    );
  }

  int get activeBookingCount {
    return bookings.where((booking) => booking.isActive).length;
  }

  int unpaidBookingCountForUser(String userId) {
    return bookings
        .where((booking) => booking.userId == userId && booking.canPay)
        .length;
  }

  List<BookingModel> creditRecordsForUser(String userId) {
    return bookings
        .where(
          (booking) =>
              booking.userId == userId &&
              booking.status == BookingStatus.cancelled &&
              booking.creditPenalty > 0,
        )
        .toList();
  }

  PaymentModel? paymentForBooking(String bookingId) {
    return payments
        .where((payment) => payment.bookingId == bookingId)
        .firstOrNull;
  }

  /// Leaves recent attempts alone because another tab may still complete them.
  PassengerBookingState recoverStalledPayments(DateTime recoveredAt) {
    final expiredPayments = payments.where(
      (payment) =>
          payment.status == PaymentStatus.processing &&
          !payment.createdAt.add(paymentAttemptTimeout).isAfter(recoveredAt),
    );
    final expiredIds = expiredPayments.map((payment) => payment.id).toSet();
    if (expiredIds.isEmpty) return this;
    final bookingIds = expiredPayments
        .map((payment) => payment.bookingId)
        .toSet();

    return PassengerBookingState(
      trips: trips,
      bookings: [
        for (final booking in bookings)
          if (booking.paymentStatus == BookingPaymentStatus.processing &&
              bookingIds.contains(booking.id))
            booking.copyWith(paymentStatus: BookingPaymentStatus.unpaid)
          else
            booking,
      ],
      payments: [
        for (final payment in payments)
          if (expiredIds.contains(payment.id))
            payment.copyWith(
              status: PaymentStatus.failed,
              completedAt: recoveredAt,
            )
          else
            payment,
      ],
    );
  }
}

class BookingActionResult {
  const BookingActionResult({
    required this.success,
    required this.message,
    this.booking,
    this.creditPenalty = 0,
    this.payment,
  });

  final bool success;
  final String message;
  final BookingModel? booking;
  final int creditPenalty;
  final PaymentModel? payment;
}

class PassengerBookingController extends Notifier<PassengerBookingState> {
  Timer? _paymentRecoveryTimer;

  @override
  PassengerBookingState build() {
    final persistence = ref.read(demoPersistenceProvider);
    final initialState = _seedState();
    final saved = persistence.read('passenger');
    final restored = saved == null
        ? initialState
        : restoreDemoData(initialState, () => decodePassengerState(saved));
    final current = restored.recoverStalledPayments(DateTime.now());

    listenSelf((previous, next) {
      persistence.write('passenger', encodePassengerState(next));
      _schedulePaymentRecovery(next);
    });
    final subscription = persistence.changes.listen((key) {
      if (key == 'passenger' || key == '*') _refreshFromStorage();
    });
    ref.onDispose(() {
      _paymentRecoveryTimer?.cancel();
      unawaited(subscription.cancel());
    });
    persistence.write('passenger', encodePassengerState(current));
    _schedulePaymentRecovery(current);
    return current;
  }

  PassengerBookingState _seedState() {
    final repository = ref.read(mockPassengerRepositoryProvider);
    return PassengerBookingState(
      trips: repository.fetchTrips(),
      bookings: repository.fetchBookings(),
      payments: const [],
    );
  }

  void _refreshFromStorage() {
    final saved = ref.read(demoPersistenceProvider).read('passenger');
    final restored = saved == null
        ? _seedState()
        : restoreDemoData(state, () => decodePassengerState(saved));
    final next = restored.recoverStalledPayments(DateTime.now());
    if (!identical(next, state)) state = next;
  }

  void _schedulePaymentRecovery(PassengerBookingState current) {
    _paymentRecoveryTimer?.cancel();
    DateTime? deadline;
    for (final payment in current.payments) {
      if (payment.status != PaymentStatus.processing) continue;
      final expiresAt = payment.createdAt.add(paymentAttemptTimeout);
      if (deadline == null || expiresAt.isBefore(deadline)) {
        deadline = expiresAt;
      }
    }
    if (deadline == null) return;
    final expiresAt = deadline;
    final delay = expiresAt.difference(DateTime.now());
    _paymentRecoveryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!ref.mounted) return;
      _refreshFromStorage();
      final now = DateTime.now();
      recoverStalledPayments(now: now.isBefore(expiresAt) ? expiresAt : now);
    });
  }

  void recoverStalledPayments({DateTime? now}) {
    final recovered = state.recoverStalledPayments(now ?? DateTime.now());
    if (!identical(recovered, state)) state = recovered;
  }

  Future<BookingActionResult> createBooking({
    required String userId,
    required String tripId,
    required int seatNo,
  }) async {
    _refreshFromStorage();
    final trip = state.tripById(tripId);
    if (!trip.isBookable) {
      return const BookingActionResult(success: false, message: '该车次暂不可预约');
    }

    if (state.remainingSeatsForTrip(tripId) <= 0) {
      return const BookingActionResult(success: false, message: '该车次已满座');
    }

    if (state.hasActiveBooking(userId: userId, tripId: tripId)) {
      return const BookingActionResult(
        success: false,
        message: '你已预约该车次，请勿重复预约',
      );
    }

    if (!state.availableSeatsForTrip(tripId).contains(seatNo)) {
      return const BookingActionResult(
        success: false,
        message: '该座位已不可选，请重新选择',
      );
    }

    var booking = BookingModel(
      id: 'booking-${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      tripId: tripId,
      seatNo: seatNo,
      status: BookingStatus.pending,
      fare: trip.fare,
      createdAt: DateTime.now(),
    );

    state = PassengerBookingState(
      trips: state.trips,
      bookings: [booking, ...state.bookings],
      payments: state.payments,
    );

    ref
        .read(notificationProvider.notifier)
        .push(
          title: '预约已创建',
          message: '${trip.routeName} 已生成订单，请及时支付车费。',
          type: AppNotificationType.booking,
        );

    return BookingActionResult(
      success: true,
      message: '预约成功，订单已生成',
      booking: booking,
    );
  }

  Future<BookingActionResult> cancelBooking(String bookingId) async {
    _refreshFromStorage();
    final index = state.bookings.indexWhere(
      (booking) => booking.id == bookingId,
    );
    if (index < 0) {
      return const BookingActionResult(success: false, message: '预约记录不存在');
    }

    final booking = state.bookings[index];
    if (booking.status != BookingStatus.pending) {
      return const BookingActionResult(success: false, message: '只有待发车预约可以取消');
    }

    final trip = state.tripById(booking.tripId);
    if (trip.departureTime.isBefore(DateTime.now())) {
      return const BookingActionResult(success: false, message: '车次已发车，无法取消预约');
    }

    final penalty = cancellationPenaltyForTrip(trip);
    final cancelledAt = DateTime.now();
    final updatedBooking = booking.copyWith(
      status: BookingStatus.cancelled,
      cancelledAt: cancelledAt,
      creditPenalty: penalty,
      paymentStatus: switch (booking.paymentStatus) {
        BookingPaymentStatus.paid => BookingPaymentStatus.refunded,
        BookingPaymentStatus.processing => BookingPaymentStatus.unpaid,
        final status => status,
      },
    );
    final payment = state.paymentForBooking(booking.id);
    final updatedPayment = switch (payment?.status) {
      PaymentStatus.paid => payment!.copyWith(
        status: PaymentStatus.refunded,
        completedAt: cancelledAt,
      ),
      PaymentStatus.processing => payment!.copyWith(
        status: PaymentStatus.failed,
        completedAt: cancelledAt,
      ),
      _ => payment,
    };
    _replaceBooking(index, updatedBooking, payment: updatedPayment);
    ref.read(authControllerProvider.notifier).adjustCreditScore(-penalty);
    ref
        .read(notificationProvider.notifier)
        .push(
          title: '预约已取消',
          message: '取消 ${trip.routeName}，信用分扣减 $penalty 分。',
          type: AppNotificationType.credit,
        );

    return BookingActionResult(
      success: true,
      message: '预约已取消，信用分扣减 $penalty 分',
      booking: updatedBooking,
      creditPenalty: penalty,
      payment: updatedPayment,
    );
  }

  int cancellationPenaltyForTrip(TripModel trip) {
    final minutesToDeparture = trip.departureTime
        .difference(DateTime.now())
        .inMinutes;

    if (minutesToDeparture <= 120) {
      return 5;
    }
    return 2;
  }

  Future<BookingActionResult> payBooking({
    required String bookingId,
    required PaymentMethod method,
  }) async {
    _refreshFromStorage();
    final index = state.bookings.indexWhere(
      (booking) => booking.id == bookingId,
    );
    if (index < 0) {
      return const BookingActionResult(success: false, message: '预约记录不存在');
    }

    final booking = state.bookings[index];
    if (booking.status != BookingStatus.pending) {
      return const BookingActionResult(success: false, message: '该预约不可支付');
    }
    if (booking.paymentStatus == BookingPaymentStatus.paid) {
      return const BookingActionResult(success: false, message: '该订单已支付');
    }
    if (booking.paymentStatus == BookingPaymentStatus.processing) {
      return const BookingActionResult(
        success: false,
        message: '该订单正在支付，请勿重复提交',
      );
    }
    if (!booking.canPay) {
      return const BookingActionResult(success: false, message: '该预约不可支付');
    }

    final payment = PaymentModel(
      id: 'payment-${DateTime.now().microsecondsSinceEpoch}',
      bookingId: booking.id,
      amount: booking.fare,
      method: method,
      status: PaymentStatus.processing,
      createdAt: DateTime.now(),
    );
    final processingBooking = booking.copyWith(
      paymentStatus: BookingPaymentStatus.processing,
      paymentMethod: method,
    );
    _replaceBooking(index, processingBooking, payment: payment);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!ref.mounted) {
      return const BookingActionResult(success: false, message: '支付会话已结束');
    }
    _refreshFromStorage();

    final latestIndex = state.bookings.indexWhere(
      (item) => item.id == bookingId,
    );
    if (latestIndex < 0) {
      return const BookingActionResult(success: false, message: '预约记录不存在');
    }

    final latestBooking = state.bookings[latestIndex];
    if (latestBooking.status == BookingStatus.cancelled) {
      return const BookingActionResult(success: false, message: '该预约已取消');
    }
    final latestPayment = state.paymentForBooking(bookingId);
    if (latestBooking.status != BookingStatus.pending ||
        latestBooking.paymentStatus != BookingPaymentStatus.processing ||
        latestPayment?.id != payment.id ||
        latestPayment?.status != PaymentStatus.processing) {
      return const BookingActionResult(
        success: false,
        message: '支付状态已变化，请刷新订单',
      );
    }

    final paidBooking = latestBooking.copyWith(
      paymentStatus: BookingPaymentStatus.paid,
      paymentMethod: method,
    );
    final paidPayment = payment.copyWith(
      status: PaymentStatus.paid,
      completedAt: DateTime.now(),
    );
    _replaceBooking(latestIndex, paidBooking, payment: paidPayment);

    final trip = state.tripById(paidBooking.tripId);
    ref
        .read(notificationProvider.notifier)
        .push(
          title: '支付成功',
          message:
              '${method.label} ¥${paidBooking.fare.toStringAsFixed(0)} 已到账，${trip.routeName} 预约生效。',
          type: AppNotificationType.payment,
        );

    return BookingActionResult(
      success: true,
      message: '支付成功，预约已生效',
      booking: paidBooking,
      payment: paidPayment,
    );
  }

  void _replaceBooking(
    int index,
    BookingModel booking, {
    PaymentModel? payment,
  }) {
    final nextBookings = [...state.bookings];
    nextBookings[index] = booking;

    var nextPayments = state.payments;
    if (payment != null) {
      nextPayments = [
        payment,
        ...state.payments.where((item) => item.bookingId != booking.id),
      ];
    }

    state = PassengerBookingState(
      trips: state.trips,
      bookings: nextBookings,
      payments: nextPayments,
    );
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
