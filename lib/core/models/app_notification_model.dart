enum AppNotificationType {
  booking('booking', '预约'),
  payment('payment', '支付'),
  credit('credit', '信用'),
  system('system', '系统');

  const AppNotificationType(this.value, this.label);

  final String value;
  final String label;
}

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      id: id,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
