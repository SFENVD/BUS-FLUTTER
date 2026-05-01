import 'payment_model.dart';

enum BookingStatus {
  pending('pending', '待发车'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消');

  const BookingStatus(this.value, this.label);

  final String value;
  final String label;
}

enum BookingPaymentStatus {
  unpaid('unpaid', '待支付'),
  processing('processing', '支付中'),
  paid('paid', '已支付'),
  refunded('refunded', '已退款');

  const BookingPaymentStatus(this.value, this.label);

  final String value;
  final String label;
}

class BookingModel {
  const BookingModel({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.seatNo,
    required this.status,
    required this.fare,
    required this.createdAt,
    this.cancelledAt,
    this.creditPenalty = 0,
    this.paymentStatus = BookingPaymentStatus.unpaid,
    this.paymentMethod,
  });

  final String id;
  final String userId;
  final String tripId;
  final int seatNo;
  final BookingStatus status;
  final double fare;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final int creditPenalty;
  final BookingPaymentStatus paymentStatus;
  final PaymentMethod? paymentMethod;

  bool get isActive => status == BookingStatus.pending;
  bool get canPay =>
      status == BookingStatus.pending &&
      paymentStatus == BookingPaymentStatus.unpaid;

  BookingModel copyWith({
    BookingStatus? status,
    DateTime? cancelledAt,
    int? creditPenalty,
    BookingPaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
  }) {
    return BookingModel(
      id: id,
      userId: userId,
      tripId: tripId,
      seatNo: seatNo,
      status: status ?? this.status,
      fare: fare,
      createdAt: createdAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      creditPenalty: creditPenalty ?? this.creditPenalty,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}
