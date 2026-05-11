import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/app_notification_model.dart';

class SupabaseNotificationRepository {
  const SupabaseNotificationRepository(this._client);

  final supabase.SupabaseClient _client;

  Future<List<AppNotificationModel>> fetchForUser(String userId) async {
    final result = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return result.map(_notificationFromJson).toList();
  }

  Future<AppNotificationModel> create({
    required String userId,
    required String title,
    required String message,
    required AppNotificationType type,
  }) async {
    final result = await _client
        .from('notifications')
        .insert({
          'user_id': userId,
          'title': title,
          'message': message,
          'type': type.value,
        })
        .select()
        .single();

    return _notificationFromJson(result);
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  AppNotificationModel _notificationFromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: _typeFromValue(json['type'] as String? ?? ''),
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  AppNotificationType _typeFromValue(String value) {
    return AppNotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AppNotificationType.system,
    );
  }
}
