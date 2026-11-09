import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification_model.dart';
import '../persistence/demo_persistence.dart';

final notificationProvider =
    NotifierProvider<NotificationController, List<AppNotificationModel>>(
      NotificationController.new,
    );

class NotificationController extends Notifier<List<AppNotificationModel>> {
  List<AppNotificationModel> Function()? _restore;

  @override
  List<AppNotificationModel> build() {
    final store = ref.read(demoPersistenceProvider);
    List<AppNotificationModel> restore() {
      final data = store.read('notifications');
      return restoreDemoData(
        <AppNotificationModel>[],
        () => [
          for (final value in (data?['items'] as List? ?? []).take(200))
            AppNotificationModel(
              id: (value as Map)['id'] as String,
              title: value['title'] as String,
              message: value['message'] as String,
              type: AppNotificationType.values.byName(value['type'] as String),
              createdAt: DateTime.parse(value['createdAt'] as String),
              isRead: value['isRead'] as bool,
            ),
        ],
      );
    }

    _restore = restore;

    listenSelf((previous, next) {
      store.write('notifications', {
        'items': [
          for (final item in next.take(200))
            {
              'id': item.id,
              'title': item.title,
              'message': item.message,
              'type': item.type.name,
              'createdAt': item.createdAt.toIso8601String(),
              'isRead': item.isRead,
            },
        ],
      });
    });
    final subscription = store.changes.listen((key) {
      if (key == 'notifications' || key == '*') state = restore();
    });
    ref.onDispose(subscription.cancel);
    return restore();
  }

  int get unreadCount {
    return state.where((notification) => !notification.isRead).length;
  }

  void push({
    required String title,
    required String message,
    required AppNotificationType type,
  }) {
    state = _restore!();
    final notification = AppNotificationModel(
      id: 'notification-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
    );
    state = [notification, ...state.take(199)];
  }

  void markAllRead() {
    state = _restore!();
    state = [
      for (final notification in state) notification.copyWith(isRead: true),
    ];
  }
}
