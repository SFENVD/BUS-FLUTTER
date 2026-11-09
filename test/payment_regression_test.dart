import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus_app/core/models/app_notification_model.dart';
import 'package:school_bus_app/core/models/booking_model.dart';
import 'package:school_bus_app/core/models/payment_model.dart';
import 'package:school_bus_app/core/providers/notification_provider.dart';
import 'package:school_bus_app/features/passenger/booking/providers/passenger_booking_provider.dart';

void main() {
  testWidgets(
    'concurrent payment attempts create one charge and notification',
    (tester) async {
      final container = _container();
      final controller = container.read(passengerBookingProvider.notifier);
      final booking = await _createBooking(controller);

      final first = controller.payBooking(
        bookingId: booking.id,
        method: PaymentMethod.wechat,
      );
      final duplicate = await controller.payBooking(
        bookingId: booking.id,
        method: PaymentMethod.alipay,
      );

      expect(duplicate.success, isFalse);
      expect(duplicate.message, contains('正在支付'));
      expect(container.read(passengerBookingProvider).payments, hasLength(1));

      await tester.pump(const Duration(milliseconds: 600));
      expect((await first).success, isTrue);
      final state = container.read(passengerBookingProvider);
      final paidBooking = _booking(state, booking.id);
      expect(paidBooking.status, BookingStatus.pending);
      expect(paidBooking.paymentStatus, BookingPaymentStatus.paid);
      expect(paidBooking.paymentMethod, PaymentMethod.wechat);
      expect(state.payments, hasLength(1));
      expect(state.payments.single.status, PaymentStatus.paid);
      expect(state.payments.single.method, PaymentMethod.wechat);
      expect(_paymentNotifications(container), hasLength(1));

      final replay = await controller.payBooking(
        bookingId: booking.id,
        method: PaymentMethod.alipay,
      );
      expect(replay.success, isFalse);
      expect(container.read(passengerBookingProvider).payments, hasLength(1));
      expect(_paymentNotifications(container), hasLength(1));
    },
  );

  testWidgets('paid cancellation refunds payment and releases only its seat', (
    tester,
  ) async {
    final container = _container();
    final controller = container.read(passengerBookingProvider.notifier);
    final initialSeats = container
        .read(passengerBookingProvider)
        .remainingSeatsForTrip('trip-001');
    final booking = await _createBooking(controller);
    final payment = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.wechat,
    );
    await tester.pump(const Duration(milliseconds: 600));
    final paid = await payment;

    final cancelled = await controller.cancelBooking(booking.id);
    expect(cancelled.success, isTrue);
    final state = container.read(passengerBookingProvider);
    expect(_booking(state, booking.id).status, BookingStatus.cancelled);
    expect(
      _booking(state, booking.id).paymentStatus,
      BookingPaymentStatus.refunded,
    );
    expect(state.payments, hasLength(1));
    expect(state.payments.single.id, paid.payment!.id);
    expect(state.payments.single.status, PaymentStatus.refunded);
    expect(state.payments.single.completedAt, isNotNull);
    expect(state.remainingSeatsForTrip('trip-001'), initialSeats);
    expect(state.tripById('trip-001').bookedSeats, 18);

    expect((await controller.cancelBooking(booking.id)).success, isFalse);
    expect(
      container
          .read(passengerBookingProvider)
          .remainingSeatsForTrip('trip-001'),
      initialSeats,
    );
  });

  testWidgets('cancelling in-flight payment terminates it before callback', (
    tester,
  ) async {
    final container = _container();
    final controller = container.read(passengerBookingProvider.notifier);
    final booking = await _createBooking(controller);
    final payment = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.alipay,
    );

    expect((await controller.cancelBooking(booking.id)).success, isTrue);
    var state = container.read(passengerBookingProvider);
    expect(_booking(state, booking.id).status, BookingStatus.cancelled);
    expect(
      _booking(state, booking.id).paymentStatus,
      BookingPaymentStatus.unpaid,
    );
    expect(state.payments.single.status, PaymentStatus.failed);
    expect(state.payments.single.completedAt, isNotNull);

    await tester.pump(const Duration(milliseconds: 600));
    expect((await payment).success, isFalse);
    state = container.read(passengerBookingProvider);
    expect(_booking(state, booking.id).status, BookingStatus.cancelled);
    expect(
      _booking(state, booking.id).paymentStatus,
      BookingPaymentStatus.unpaid,
    );
    expect(state.payments, hasLength(1));
    expect(state.payments.single.status, PaymentStatus.failed);
    expect(_paymentNotifications(container), isEmpty);

    final retry = await controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.wechat,
    );
    expect(retry.success, isFalse);
    expect(container.read(passengerBookingProvider).payments, hasLength(1));
  });

  testWidgets('disposing a payment session prevents delayed state writes', (
    tester,
  ) async {
    final container = ProviderContainer();
    var disposed = false;
    addTearDown(() {
      if (!disposed) container.dispose();
    });
    final controller = container.read(passengerBookingProvider.notifier);
    final booking = await _createBooking(controller);
    final payment = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.wechat,
    );
    container.dispose();
    disposed = true;

    await tester.pump(const Duration(milliseconds: 600));
    expect((await payment).success, isFalse);
  });

  test(
    'only expired attempts recover and settled records remain unchanged',
    () {
      final createdAt = DateTime(2026, 1, 1);
      final recoveredAt = createdAt.add(const Duration(minutes: 1));
      final state = PassengerBookingState(
        trips: const [],
        bookings: [
          _savedBooking(
            'interrupted',
            BookingPaymentStatus.processing,
            createdAt,
          ),
          _savedBooking('recent', BookingPaymentStatus.processing, recoveredAt),
          _savedBooking('settled', BookingPaymentStatus.paid, createdAt),
        ],
        payments: [
          _savedPayment('interrupted', PaymentStatus.processing, createdAt),
          _savedPayment('recent', PaymentStatus.processing, recoveredAt),
          _savedPayment('settled', PaymentStatus.paid, createdAt),
        ],
      );

      expect(
        state.recoverStalledPayments(createdAt.add(const Duration(seconds: 9))),
        same(state),
      );
      final recovered = state.recoverStalledPayments(recoveredAt);
      expect(
        _booking(recovered, 'interrupted').paymentStatus,
        BookingPaymentStatus.unpaid,
      );
      expect(_booking(recovered, 'interrupted').canPay, isTrue);
      expect(
        recovered.paymentForBooking('interrupted')!.status,
        PaymentStatus.failed,
      );
      expect(
        recovered.paymentForBooking('interrupted')!.completedAt,
        recoveredAt,
      );
      expect(
        _booking(recovered, 'settled').paymentStatus,
        BookingPaymentStatus.paid,
      );
      expect(
        recovered.paymentForBooking('settled')!.status,
        PaymentStatus.paid,
      );
      expect(
        _booking(recovered, 'recent').paymentStatus,
        BookingPaymentStatus.processing,
      );
      expect(
        recovered.paymentForBooking('recent')!.status,
        PaymentStatus.processing,
      );
      expect(
        _booking(state, 'interrupted').paymentStatus,
        BookingPaymentStatus.processing,
      );
    },
  );

  testWidgets('expired attempt callback cannot complete a newer retry', (
    tester,
  ) async {
    final container = _container();
    final controller = container.read(passengerBookingProvider.notifier);
    final booking = await _createBooking(controller);
    final oldPayment = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.wechat,
    );
    final attempt = container
        .read(passengerBookingProvider)
        .paymentForBooking(booking.id)!;
    controller.recoverStalledPayments(
      now: attempt.createdAt.add(paymentAttemptTimeout),
    );
    expect(
      container
          .read(passengerBookingProvider)
          .paymentForBooking(booking.id)!
          .status,
      PaymentStatus.failed,
    );
    final retry = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.alipay,
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect((await oldPayment).success, isFalse);
    expect((await retry).success, isTrue);
    final state = container.read(passengerBookingProvider);
    expect(state.payments, hasLength(1));
    expect(state.payments.single.status, PaymentStatus.paid);
    expect(state.payments.single.method, PaymentMethod.alipay);
    expect(_paymentNotifications(container), hasLength(1));
  });
}

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

Future<BookingModel> _createBooking(
  PassengerBookingController controller,
) async {
  final result = await controller.createBooking(
    userId: 'u-passenger-001',
    tripId: 'trip-001',
    seatNo: 19,
  );
  expect(result.success, isTrue);
  return result.booking!;
}

BookingModel _booking(PassengerBookingState state, String id) {
  return state.bookings.singleWhere((booking) => booking.id == id);
}

Iterable<AppNotificationModel> _paymentNotifications(
  ProviderContainer container,
) {
  return container
      .read(notificationProvider)
      .where(
        (notification) => notification.type == AppNotificationType.payment,
      );
}

BookingModel _savedBooking(
  String id,
  BookingPaymentStatus status,
  DateTime createdAt,
) {
  return BookingModel(
    id: id,
    userId: 'u-passenger-001',
    tripId: 'trip-001',
    seatNo: 19,
    status: BookingStatus.pending,
    fare: 3,
    createdAt: createdAt,
    paymentStatus: status,
    paymentMethod: PaymentMethod.wechat,
  );
}

PaymentModel _savedPayment(
  String bookingId,
  PaymentStatus status,
  DateTime createdAt,
) {
  return PaymentModel(
    id: 'payment-$bookingId',
    bookingId: bookingId,
    amount: 3,
    method: PaymentMethod.wechat,
    status: status,
    createdAt: createdAt,
  );
}
