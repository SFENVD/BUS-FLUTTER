import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_notification_model.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/models/payment_model.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../data/mock_passenger_repository.dart';

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
  @override
  PassengerBookingState build() {
    final repository = ref.read(mockPassengerRepositoryProvider);
    return PassengerBookingState(
      trips: repository.fetchTrips(),
      bookings: repository.fetchBookings(),
      payments: const [],
    );
  }

  BookingActionResult createBooking({
    required String userId,
    required String tripId,
    required int seatNo,
  }) {
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

    final booking = BookingModel(
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

  BookingActionResult cancelBooking(String bookingId) {
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
    final updatedBooking = booking.copyWith(
      status: BookingStatus.cancelled,
      cancelledAt: DateTime.now(),
      creditPenalty: penalty,
      paymentStatus: booking.paymentStatus == BookingPaymentStatus.paid
          ? BookingPaymentStatus.refunded
          : booking.paymentStatus,
    );
    final nextBookings = [...state.bookings];
    nextBookings[index] = updatedBooking;

    state = PassengerBookingState(
      trips: state.trips,
      bookings: nextBookings,
      payments: state.payments,
    );
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
        ...state.payments.where((item) => item.id != payment.id),
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
