import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus_app/core/models/booking_model.dart';
import 'package:school_bus_app/core/models/payment_model.dart';
import 'package:school_bus_app/core/persistence/demo_persistence.dart';
import 'package:school_bus_app/features/passenger/booking/data/passenger_state_codec.dart';
import 'package:school_bus_app/features/passenger/booking/providers/passenger_booking_provider.dart';

void main() {
  testWidgets('reload retains trips reservations payment and refund records', (
    tester,
  ) async {
    final store = _store();
    final first = _container(store);
    final controller = first.read(passengerBookingProvider.notifier);
    final departure = first
        .read(passengerBookingProvider)
        .tripById('trip-001')
        .departureTime;
    final booking = await _createBooking(controller);
    final payment = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.alipay,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect((await payment).success, isTrue);

    final reloaded = _container(store);
    final paid = reloaded.read(passengerBookingProvider);
    expect(paid.tripById('trip-001').departureTime, departure);
    expect(paid.tripById('trip-001').bookedSeats, 18);
    expect(paid.remainingSeatsForTrip('trip-001'), 26);
    expect(_booking(paid, booking.id).paymentStatus, BookingPaymentStatus.paid);
    expect(paid.payments.single.method, PaymentMethod.alipay);
    expect(paid.payments.single.status, PaymentStatus.paid);
    expect(
      encodePassengerState(paid),
      encodePassengerState(first.read(passengerBookingProvider)),
    );

    expect(
      (await reloaded
              .read(passengerBookingProvider.notifier)
              .cancelBooking(booking.id))
          .success,
      isTrue,
    );
    final refunded = _container(store).read(passengerBookingProvider);
    expect(_booking(refunded, booking.id).status, BookingStatus.cancelled);
    expect(
      _booking(refunded, booking.id).paymentStatus,
      BookingPaymentStatus.refunded,
    );
    expect(_booking(refunded, booking.id).creditPenalty, 5);
    expect(_booking(refunded, booking.id).cancelledAt, isNotNull);
    expect(refunded.payments.single.status, PaymentStatus.refunded);
    expect(refunded.remainingSeatsForTrip('trip-001'), 27);
  });

  test('stale sessions read latest reservations before mutating', () async {
    final store = _store();
    final first = _container(store);
    final second = _container(store);
    final firstController = first.read(passengerBookingProvider.notifier);
    final secondController = second.read(passengerBookingProvider.notifier);
    final firstBooking = await _createBooking(firstController);

    final conflict = await secondController.createBooking(
      userId: 'another-passenger',
      tripId: 'trip-001',
      seatNo: 19,
    );
    expect(conflict.success, isFalse);
    final secondBooking = await secondController.createBooking(
      userId: 'another-passenger',
      tripId: 'trip-001',
      seatNo: 20,
    );
    expect(secondBooking.success, isTrue);

    expect(
      (await firstController.cancelBooking(firstBooking.id)).success,
      isTrue,
    );
    final state = first.read(passengerBookingProvider);
    expect(_booking(state, secondBooking.booking!.id).isActive, isTrue);
    expect(state.remainingSeatsForTrip('trip-001'), 26);
  });

  test(
    'storage events update a live session and reset clears its orders',
    () async {
      final sourceStore = _store();
      final targetStore = _store();
      final source = _container(sourceStore);
      final target = _container(targetStore);
      target.read(passengerBookingProvider);
      final booking = await _createBooking(
        source.read(passengerBookingProvider.notifier),
      );

      targetStore.receiveExternal('passenger', sourceStore.read('passenger')!);
      expect(
        _booking(target.read(passengerBookingProvider), booking.id).isActive,
        isTrue,
      );
      targetStore.clear();
      expect(
        target
            .read(passengerBookingProvider)
            .bookings
            .any((item) => item.id == booking.id),
        isFalse,
      );
      expect(target.read(passengerBookingProvider).payments, isEmpty);
      expect(
        target.read(passengerBookingProvider).remainingSeatsForTrip('trip-001'),
        27,
      );
    },
  );

  testWidgets('external cancellation blocks an in-flight payment callback', (
    tester,
  ) async {
    final sourceStore = _store();
    final targetStore = _store();
    final source = _container(sourceStore);
    final target = _container(targetStore);
    final sourceController = source.read(passengerBookingProvider.notifier);
    final targetController = target.read(passengerBookingProvider.notifier);
    final booking = await _createBooking(sourceController);
    final payment = sourceController.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.wechat,
    );

    targetStore.receiveExternal('passenger', sourceStore.read('passenger')!);
    expect((await targetController.cancelBooking(booking.id)).success, isTrue);
    sourceStore.receiveExternal('passenger', targetStore.read('passenger')!);
    await tester.pump(const Duration(milliseconds: 600));

    expect((await payment).success, isFalse);
    final state = source.read(passengerBookingProvider);
    expect(_booking(state, booking.id).status, BookingStatus.cancelled);
    expect(state.payments.single.status, PaymentStatus.failed);
  });

  testWidgets('reloaded processing payment expires when its owner is gone', (
    tester,
  ) async {
    final store = _store();
    final source = ProviderContainer(
      overrides: [demoPersistenceProvider.overrideWithValue(store)],
    );
    var sourceDisposed = false;
    addTearDown(() {
      if (!sourceDisposed) source.dispose();
    });
    final controller = source.read(passengerBookingProvider.notifier);
    final booking = await _createBooking(controller);
    final payment = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.wechat,
    );
    source.dispose();
    sourceDisposed = true;

    final reloaded = _container(store);
    final processing = reloaded.read(passengerBookingProvider);
    expect(
      _booking(processing, booking.id).paymentStatus,
      BookingPaymentStatus.processing,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect((await payment).success, isFalse);
    await tester.pump(paymentAttemptTimeout);

    final recovered = reloaded.read(passengerBookingProvider);
    expect(
      _booking(recovered, booking.id).paymentStatus,
      BookingPaymentStatus.unpaid,
    );
    expect(recovered.payments.single.status, PaymentStatus.failed);
    expect(recovered.payments.single.completedAt, isNotNull);
    final retry = reloaded
        .read(passengerBookingProvider.notifier)
        .payBooking(bookingId: booking.id, method: PaymentMethod.alipay);
    await tester.pump(const Duration(milliseconds: 600));
    expect((await retry).success, isTrue);
    expect(reloaded.read(passengerBookingProvider).payments, hasLength(1));
  });

  testWidgets('another tab can finish a recent saved payment before timeout', (
    tester,
  ) async {
    final sourceStore = _store();
    final targetStore = _store();
    final source = _container(sourceStore);
    final controller = source.read(passengerBookingProvider.notifier);
    final booking = await _createBooking(controller);
    final payment = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.wechat,
    );
    targetStore.write('passenger', sourceStore.read('passenger')!);
    final target = _container(targetStore);
    expect(
      _booking(target.read(passengerBookingProvider), booking.id).paymentStatus,
      BookingPaymentStatus.processing,
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect((await payment).success, isTrue);
    targetStore.receiveExternal('passenger', sourceStore.read('passenger')!);
    await tester.pump(paymentAttemptTimeout);
    expect(
      _booking(target.read(passengerBookingProvider), booking.id).paymentStatus,
      BookingPaymentStatus.paid,
    );
    expect(
      target.read(passengerBookingProvider).payments.single.status,
      PaymentStatus.paid,
    );
  });

  test('invalid saved state falls back to usable mock data', () async {
    final store = _store();
    store.write('passenger', {'version': 1, 'trips': 'not a list'});
    final container = _container(store);
    final controller = container.read(passengerBookingProvider.notifier);
    expect(container.read(passengerBookingProvider).trips, hasLength(4));
    expect((await _createBooking(controller)).seatNo, 19);
    expect(decodePassengerState(store.read('passenger')!).trips, hasLength(4));
  });

  testWidgets('already expired saved payment recovers on initial load', (
    tester,
  ) async {
    final sourceStore = _store();
    final source = _container(sourceStore);
    final controller = source.read(passengerBookingProvider.notifier);
    final booking = await _createBooking(controller);
    final payment = controller.payBooking(
      bookingId: booking.id,
      method: PaymentMethod.wechat,
    );
    final snapshot = sourceStore.read('passenger')!;
    final payments = snapshot['payments'] as List;
    (payments.single as Map)['createdAt'] = DateTime.now()
        .subtract(const Duration(minutes: 1))
        .toIso8601String();
    final targetStore = _store();
    targetStore.write('passenger', snapshot);
    final target = _container(targetStore);
    final recovered = target.read(passengerBookingProvider);
    expect(
      _booking(recovered, booking.id).paymentStatus,
      BookingPaymentStatus.unpaid,
    );
    expect(recovered.payments.single.status, PaymentStatus.failed);
    await tester.pump(const Duration(milliseconds: 600));
    await payment;
  });
}

MemoryDemoPersistence _store() {
  final store = MemoryDemoPersistence();
  addTearDown(store.dispose);
  return store;
}

ProviderContainer _container(MemoryDemoPersistence store) {
  final container = ProviderContainer(
    overrides: [demoPersistenceProvider.overrideWithValue(store)],
  );
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
