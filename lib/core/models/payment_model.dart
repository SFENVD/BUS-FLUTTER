enum PaymentMethod {
  wechat('wechat', '微信支付'),
  alipay('alipay', '支付宝');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;
}

enum PaymentStatus {
  processing('processing', '支付中'),
  paid('paid', '已支付'),
  failed('failed', '支付失败'),
  refunded('refunded', '已退款');

  const PaymentStatus(this.value, this.label);

  final String value;
  final String label;
}

class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String bookingId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  PaymentModel copyWith({PaymentStatus? status, DateTime? completedAt}) {
    return PaymentModel(
      id: id,
      bookingId: bookingId,
      amount: amount,
      method: method,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
