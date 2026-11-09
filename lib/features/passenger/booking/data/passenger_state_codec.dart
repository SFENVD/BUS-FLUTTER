import '../../../../core/models/booking_model.dart';
import '../../../../core/models/payment_model.dart';
import '../../../../core/models/trip_model.dart';
import '../providers/passenger_booking_provider.dart';

Map<String, Object?> encodePassengerState(PassengerBookingState state) {
  return {
    'version': 1,
    'trips': [
      for (final trip in state.trips)
        {
          'id': trip.id,
          'routeName': trip.routeName,
          'origin': trip.origin,
          'destination': trip.destination,
          'vehicleId': trip.vehicleId,
          'driverId': trip.driverId,
          'departureTime': trip.departureTime.toIso8601String(),
          'totalSeats': trip.totalSeats,
          'bookedSeats': trip.bookedSeats,
          'fare': trip.fare,
          'status': trip.status.name,
        },
    ],
    'bookings': [
      for (final booking in state.bookings)
        {
          'id': booking.id,
          'userId': booking.userId,
          'tripId': booking.tripId,
          'seatNo': booking.seatNo,
          'status': booking.status.name,
          'fare': booking.fare,
          'createdAt': booking.createdAt.toIso8601String(),
          'cancelledAt': booking.cancelledAt?.toIso8601String(),
          'creditPenalty': booking.creditPenalty,
          'paymentStatus': booking.paymentStatus.name,
          'paymentMethod': booking.paymentMethod?.name,
        },
    ],
    'payments': [
      for (final payment in state.payments)
        {
          'id': payment.id,
          'bookingId': payment.bookingId,
          'amount': payment.amount,
          'method': payment.method.name,
          'status': payment.status.name,
          'createdAt': payment.createdAt.toIso8601String(),
          'completedAt': payment.completedAt?.toIso8601String(),
        },
    ],
  };
}

PassengerBookingState decodePassengerState(Map<String, Object?> data) {
  if (data['version'] != 1) {
    throw const FormatException('Unsupported passenger snapshot version');
  }
  final state = PassengerBookingState(
    trips: [
      for (final value in data['trips'] as List)
        _decodeTrip(Map<String, Object?>.from(value as Map)),
    ],
    bookings: [
      for (final value in data['bookings'] as List)
        _decodeBooking(Map<String, Object?>.from(value as Map)),
    ],
    payments: [
      for (final value in data['payments'] as List)
        _decodePayment(Map<String, Object?>.from(value as Map)),
    ],
  );
  _validateState(state);
  return state;
}

TripModel _decodeTrip(Map<String, Object?> value) {
  return TripModel(
    id: value['id'] as String,
    routeName: value['routeName'] as String,
    origin: value['origin'] as String,
    destination: value['destination'] as String,
    vehicleId: value['vehicleId'] as String,
    driverId: value['driverId'] as String,
    departureTime: DateTime.parse(value['departureTime'] as String),
    totalSeats: value['totalSeats'] as int,
    bookedSeats: value['bookedSeats'] as int,
    fare: (value['fare'] as num).toDouble(),
    status: TripStatus.values.byName(value['status'] as String),
  );
}

BookingModel _decodeBooking(Map<String, Object?> value) {
  return BookingModel(
    id: value['id'] as String,
    userId: value['userId'] as String,
    tripId: value['tripId'] as String,
    seatNo: value['seatNo'] as int,
    status: BookingStatus.values.byName(value['status'] as String),
    fare: (value['fare'] as num).toDouble(),
    createdAt: DateTime.parse(value['createdAt'] as String),
    cancelledAt: _optionalDate(value['cancelledAt']),
    creditPenalty: value['creditPenalty'] as int,
    paymentStatus: BookingPaymentStatus.values.byName(
      value['paymentStatus'] as String,
    ),
    paymentMethod: value['paymentMethod'] == null
        ? null
        : PaymentMethod.values.byName(value['paymentMethod'] as String),
  );
}

PaymentModel _decodePayment(Map<String, Object?> value) {
  return PaymentModel(
    id: value['id'] as String,
    bookingId: value['bookingId'] as String,
    amount: (value['amount'] as num).toDouble(),
    method: PaymentMethod.values.byName(value['method'] as String),
    status: PaymentStatus.values.byName(value['status'] as String),
    createdAt: DateTime.parse(value['createdAt'] as String),
    completedAt: _optionalDate(value['completedAt']),
  );
}

DateTime? _optionalDate(Object? value) {
  return value == null ? null : DateTime.parse(value as String);
}

void _validateState(PassengerBookingState state) {
  final trips = {for (final trip in state.trips) trip.id: trip};
  final bookings = {for (final booking in state.bookings) booking.id: booking};
  final paymentIds = <String>{};
  final paymentBookings = <String>{};
  final seats = <(String, int)>{};
  final passengers = <(String, String)>{};
  if (trips.length != state.trips.length ||
      bookings.length != state.bookings.length) {
    throw const FormatException('Duplicate passenger snapshot identifiers');
  }
  for (final trip in state.trips) {
    if (trip.totalSeats <= 0 ||
        trip.bookedSeats < 0 ||
        trip.bookedSeats > trip.totalSeats ||
        !trip.fare.isFinite ||
        trip.fare < 0) {
      throw const FormatException('Invalid saved trip');
    }
  }
  for (final booking in state.bookings) {
    final trip = trips[booking.tripId];
    if (trip == null ||
        booking.seatNo < 1 ||
        booking.seatNo > trip.totalSeats ||
        !booking.fare.isFinite ||
        booking.fare < 0 ||
        booking.creditPenalty < 0) {
      throw const FormatException('Invalid saved booking');
    }
    if (booking.isActive &&
        (booking.seatNo <= trip.bookedSeats ||
            !seats.add((booking.tripId, booking.seatNo)) ||
            !passengers.add((booking.tripId, booking.userId)))) {
      throw const FormatException('Conflicting saved booking');
    }
  }
  for (final payment in state.payments) {
    if (!bookings.containsKey(payment.bookingId) ||
        !paymentIds.add(payment.id) ||
        !paymentBookings.add(payment.bookingId) ||
        !payment.amount.isFinite ||
        payment.amount < 0) {
      throw const FormatException('Invalid saved payment');
    }
  }
  for (final booking in state.bookings) {
    if (booking.paymentStatus == BookingPaymentStatus.processing &&
        state.paymentForBooking(booking.id)?.status !=
            PaymentStatus.processing) {
      throw const FormatException('Missing saved payment attempt');
    }
  }
}
