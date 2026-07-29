import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/notification_model.dart';
import '../../../../core/config/app_config.dart';

part 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  static const String storageKey = 'notification_history';
  final Dio _dio;
  Timer? _pollingTimer;

  NotificationsCubit({required Dio dio})
    : _dio = dio,
      super(NotificationsInitial());

  /// Load notifications from local storage
  Future<void> loadNotifications() async {
    emit(NotificationsLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(storageKey);

      List<NotificationModel> notifications = [];
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        notifications = jsonList
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      }
      try {
        final response = await _dio.get(
          '${AppConfig.baseUrl}/custom/v1/notifications/inbox',
        );
        final remote = (response.data as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  NotificationModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        final merged = <String, NotificationModel>{
          for (final item in notifications) item.id: item,
          for (final item in remote) item.id: item,
        };
        notifications = merged.values.toList();
      } catch (_) {
        // Push history remains usable offline or before the PHP update deploys.
      }
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _save(notifications);
      emit(NotificationsLoaded(notifications: notifications));
      _startPolling();
    } catch (e) {
      emit(NotificationsError(message: 'فشل تحميل الإشعارات: $e'));
    }
  }

  void _startPolling() {
    _pollingTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshFromServer(),
    );
  }

  Future<void> _refreshFromServer() async {
    if (state is! NotificationsLoaded) return;
    try {
      final response = await _dio.get(
        '${AppConfig.baseUrl}/custom/v1/notifications/inbox',
      );
      final remote = (response.data as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                NotificationModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      final current = (state as NotificationsLoaded).notifications;
      final merged = <String, NotificationModel>{
        for (final item in current) item.id: item,
        for (final item in remote) item.id: item,
      }.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _save(merged);
      emit(NotificationsLoaded(notifications: merged));
    } catch (_) {}
  }

  /// Add a new notification (called when push notification is received)
  Future<void> addNotification(NotificationModel notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(storageKey);

      List<NotificationModel> notifications = [];
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        notifications = jsonList
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      }

      // Add new notification at the beginning
      notifications.insert(0, notification);

      // Keep only the last 50 notifications
      if (notifications.length > 50) {
        notifications = notifications.sublist(0, 50);
      }

      // Save back to storage
      final jsonList = notifications.map((n) => n.toJson()).toList();
      await prefs.setString(storageKey, json.encode(jsonList));

      emit(NotificationsLoaded(notifications: notifications));
    } catch (e) {
      print('Error adding notification: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    if (state is! NotificationsLoaded) return;

    final currentState = state as NotificationsLoaded;
    final updatedNotifications = currentState.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    emit(NotificationsLoaded(notifications: updatedNotifications));

    // Save to storage
    final prefs = await SharedPreferences.getInstance();
    final jsonList = updatedNotifications.map((n) => n.toJson()).toList();
    await prefs.setString(storageKey, json.encode(jsonList));
    try {
      await _dio.post(
        '${AppConfig.baseUrl}/custom/v1/notifications/read',
        data: {'id': notificationId},
      );
    } catch (_) {}
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (state is! NotificationsLoaded) return;

    final currentState = state as NotificationsLoaded;
    final updatedNotifications = currentState.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();

    emit(NotificationsLoaded(notifications: updatedNotifications));

    // Save to storage
    final prefs = await SharedPreferences.getInstance();
    final jsonList = updatedNotifications.map((n) => n.toJson()).toList();
    await prefs.setString(storageKey, json.encode(jsonList));
    try {
      await _dio.post(
        '${AppConfig.baseUrl}/custom/v1/notifications/read',
        data: {'all': true},
      );
    } catch (_) {}
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    emit(const NotificationsLoaded(notifications: []));
    try {
      await _dio.post(
        '${AppConfig.baseUrl}/custom/v1/notifications/read',
        data: {'clear': true},
      );
    } catch (_) {}
  }

  /// Get unread count
  int get unreadCount {
    if (state is NotificationsLoaded) {
      return (state as NotificationsLoaded).notifications
          .where((n) => !n.isRead)
          .length;
    }
    return 0;
  }

  Future<void> _save(List<NotificationModel> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = notifications.take(100).map((n) => n.toJson()).toList();
    await prefs.setString(storageKey, json.encode(jsonList));
  }

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    return super.close();
  }
}
