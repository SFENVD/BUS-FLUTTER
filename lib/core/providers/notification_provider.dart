import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification_model.dart';

final notificationProvider =
    NotifierProvider<NotificationController, List<AppNotificationModel>>(
      NotificationController.new,
    );

class NotificationController extends Notifier<List<AppNotificationModel>> {
  @override
  List<AppNotificationModel> build() {
    return const [];
  }

  int get unreadCount {
    return state.where((notification) => !notification.isRead).length;
  }

  void push({
    required String title,
    required String message,
    required AppNotificationType type,
  }) {
    final notification = AppNotificationModel(
      id: 'notification-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
    );
    state = [notification, ...state];
  }

  void markAllRead() {
    state = [
      for (final notification in state) notification.copyWith(isRead: true),
    ];
  }
}
