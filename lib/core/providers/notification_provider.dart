import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../config/backend_config.dart';
import '../data/supabase_notification_repository.dart';
import '../models/app_notification_model.dart';
import 'auth_provider.dart';

final supabaseNotificationRepositoryProvider =
    Provider<SupabaseNotificationRepository>((ref) {
      return SupabaseNotificationRepository(Supabase.instance.client);
    });

final notificationProvider =
    NotifierProvider<NotificationController, List<AppNotificationModel>>(
      NotificationController.new,
    );

class NotificationController extends Notifier<List<AppNotificationModel>> {
  @override
  List<AppNotificationModel> build() {
    if (BackendConfig.useSupabase) {
      final userId = ref.watch(authControllerProvider).user?.id;
      if (userId != null) {
        unawaited(_loadNotifications(userId));
      }
    }

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

    if (BackendConfig.useSupabase) {
      final userId = ref.read(authControllerProvider).user?.id;
      if (userId != null) {
        unawaited(
          _persistNotification(
            userId: userId,
            title: title,
            message: message,
            type: type,
          ),
        );
      }
    }
  }

  void markAllRead() {
    state = [
      for (final notification in state) notification.copyWith(isRead: true),
    ];

    if (BackendConfig.useSupabase) {
      final userId = ref.read(authControllerProvider).user?.id;
      if (userId != null) {
        unawaited(_persistMarkAllRead(userId));
      }
    }
  }

  Future<void> _loadNotifications(String userId) async {
    try {
      state = await ref
          .read(supabaseNotificationRepositoryProvider)
          .fetchForUser(userId);
    } catch (_) {
      // Keep local notifications visible if Supabase is unreachable.
    }
  }

  Future<void> _persistNotification({
    required String userId,
    required String title,
    required String message,
    required AppNotificationType type,
  }) async {
    try {
      final notification = await ref
          .read(supabaseNotificationRepositoryProvider)
          .create(userId: userId, title: title, message: message, type: type);
      state = [
        notification,
        ...state.where((item) => !item.id.startsWith('notification-')),
      ];
    } catch (_) {}
  }

  Future<void> _persistMarkAllRead(String userId) async {
    try {
      await ref
          .read(supabaseNotificationRepositoryProvider)
          .markAllRead(userId);
    } catch (_) {}
  }
}
