import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/models/booking_model.dart';
import '../../../../core/models/payment_model.dart';
import '../../../../core/models/trip_model.dart';

class SupabasePassengerSnapshot {
  const SupabasePassengerSnapshot({
    required this.trips,
    required this.bookings,
    required this.payments,
  });

  final List<TripModel> trips;
  final List<BookingModel> bookings;
  final List<PaymentModel> payments;
}

class SupabasePassengerRepository {
  const SupabasePassengerRepository(this._client);

  final supabase.SupabaseClient _client;

  Future<SupabasePassengerSnapshot> fetchSnapshot(String userId) async {
    final tripsResult = await _client
        .from('trips')
        .select()
        .order('departure_time');
    final bookingsResult = await _client
        .from('bookings')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final bookings = bookingsResult.map(_bookingFromJson).toList();
    final payments = bookings.isEmpty
        ? <PaymentModel>[]
        : await _fetchPaymentsForBookings(bookings.map((item) => item.id));

    return SupabasePassengerSnapshot(
      trips: tripsResult.map(_tripFromJson).toList(),
      bookings: bookings,
      payments: payments,
    );
  }

  Future<BookingModel> createBooking({
    required String userId,
    required TripModel trip,
    required int seatNo,
  }) async {
    final result = await _client
        .from('bookings')
        .insert({
          'user_id': userId,
          'trip_id': trip.id,
          'seat_no': seatNo,
          'status': BookingStatus.pending.value,
          'fare': trip.fare,
          'payment_status': BookingPaymentStatus.unpaid.value,
          'pickup_point': trip.origin,
        })
        .select()
        .single();

    return _bookingFromJson(result);
  }

  Future<BookingModel> cancelBooking({
    required BookingModel booking,
    required int creditPenalty,
    required int nextCreditScore,
  }) async {
    final nextPaymentStatus = booking.paymentStatus == BookingPaymentStatus.paid
        ? BookingPaymentStatus.refunded
        : booking.paymentStatus;

    final result = await _client
        .from('bookings')
        .update({
          'status': BookingStatus.cancelled.value,
          'cancelled_at': DateTime.now().toIso8601String(),
          'credit_penalty': creditPenalty,
          'payment_status': nextPaymentStatus.value,
        })
        .eq('id', booking.id)
        .select()
        .single();

    await _client
        .from('profiles')
        .update({'credit_score': nextCreditScore})
        .eq('id', booking.userId);

    return _bookingFromJson(result);
  }

  Future<PaymentModel> createProcessingPayment({
    required BookingModel booking,
    required PaymentMethod method,
  }) async {
    final paymentResult = await _client
        .from('payments')
        .insert({
          'booking_id': booking.id,
          'amount': booking.fare,
          'method': method.value,
          'status': PaymentStatus.processing.value,
        })
        .select()
        .single();

    await _client
        .from('bookings')
        .update({
          'payment_status': BookingPaymentStatus.processing.value,
          'payment_method': method.value,
        })
        .eq('id', booking.id);

    return _paymentFromJson(paymentResult);
  }

  Future<(BookingModel, PaymentModel)> completePayment({
    required String bookingId,
    required String paymentId,
    required PaymentMethod method,
  }) async {
    final completedAt = DateTime.now().toIso8601String();
    final paymentResult = await _client
        .from('payments')
        .update({
          'status': PaymentStatus.paid.value,
          'completed_at': completedAt,
        })
        .eq('id', paymentId)
        .select()
        .single();

    final bookingResult = await _client
        .from('bookings')
        .update({
          'payment_status': BookingPaymentStatus.paid.value,
          'payment_method': method.value,
        })
        .eq('id', bookingId)
        .select()
        .single();

    return (_bookingFromJson(bookingResult), _paymentFromJson(paymentResult));
  }

  Future<List<PaymentModel>> _fetchPaymentsForBookings(
    Iterable<String> bookingIds,
  ) async {
    final result = await _client
        .from('payments')
        .select()
        .inFilter('booking_id', bookingIds.toList())
        .order('created_at', ascending: false);

    return result.map(_paymentFromJson).toList();
  }

  TripModel _tripFromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      routeName: json['route_name'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      departureTime: DateTime.parse(json['departure_time'] as String),
      totalSeats: (json['total_seats'] as num?)?.toInt() ?? 0,
      bookedSeats: (json['booked_seats'] as num?)?.toInt() ?? 0,
      fare: (json['fare'] as num?)?.toDouble() ?? 0,
      status: _tripStatusFromValue(json['status'] as String? ?? ''),
    );
  }

  BookingModel _bookingFromJson(Map<String, dynamic> json) {
    final cancelledAt = json['cancelled_at'] as String?;

    return BookingModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      tripId: json['trip_id'] as String? ?? '',
      seatNo: (json['seat_no'] as num?)?.toInt() ?? 0,
      status: _bookingStatusFromValue(json['status'] as String? ?? ''),
      fare: (json['fare'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      cancelledAt: cancelledAt == null ? null : DateTime.parse(cancelledAt),
      creditPenalty: (json['credit_penalty'] as num?)?.toInt() ?? 0,
      paymentStatus: _bookingPaymentStatusFromValue(
        json['payment_status'] as String? ?? '',
      ),
      paymentMethod: _paymentMethodFromValue(json['payment_method'] as String?),
    );
  }

  PaymentModel _paymentFromJson(Map<String, dynamic> json) {
    final completedAt = json['completed_at'] as String?;

    return PaymentModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      method:
          _paymentMethodFromValue(json['method'] as String?) ??
          PaymentMethod.wechat,
      status: _paymentStatusFromValue(json['status'] as String? ?? ''),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: completedAt == null ? null : DateTime.parse(completedAt),
    );
  }

  TripStatus _tripStatusFromValue(String value) {
    return TripStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TripStatus.scheduled,
    );
  }

  BookingStatus _bookingStatusFromValue(String value) {
    return BookingStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BookingStatus.pending,
    );
  }

  BookingPaymentStatus _bookingPaymentStatusFromValue(String value) {
    return BookingPaymentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BookingPaymentStatus.unpaid,
    );
  }

  PaymentMethod? _paymentMethodFromValue(String? value) {
    if (value == null) {
      return null;
    }
    return PaymentMethod.values
        .where((method) => method.value == value)
        .firstOrNull;
  }

  PaymentStatus _paymentStatusFromValue(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PaymentStatus.processing,
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
