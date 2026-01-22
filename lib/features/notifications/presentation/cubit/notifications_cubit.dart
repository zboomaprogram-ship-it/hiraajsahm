import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/notification_model.dart';

part 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  static const String _storageKey = 'notification_history';

  NotificationsCubit() : super(NotificationsInitial());

  /// Load notifications from local storage
  Future<void> loadNotifications() async {
    emit(NotificationsLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        final notifications = jsonList
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        // Sort by timestamp descending (newest first)
        notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        emit(NotificationsLoaded(notifications: notifications));
      } else {
        emit(const NotificationsLoaded(notifications: []));
      }
    } catch (e) {
      emit(NotificationsError(message: 'فشل تحميل الإشعارات: $e'));
    }
  }

  /// Add a new notification (called when push notification is received)
  Future<void> addNotification(NotificationModel notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

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
      await prefs.setString(_storageKey, json.encode(jsonList));

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
    await prefs.setString(_storageKey, json.encode(jsonList));
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
    await prefs.setString(_storageKey, json.encode(jsonList));
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    emit(const NotificationsLoaded(notifications: []));
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
}
