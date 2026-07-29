import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/routes.dart';
import '../config/app_config.dart';
import '../../features/notifications/data/models/notification_model.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/messages/presentation/message_unread_controller.dart';

/// ✅ GLOBAL NAVIGATOR KEY
/// Allows navigation from outside the widget tree (Service -> Screen)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // OneSignal App ID
  static const String _oneSignalAppId = AppConfig.oneSignalAppId;

  // API endpoint for saving push subscription ID (optional backup)
  static final String _saveTokenEndpoint =
      AppConfig.baseUrl + AppConfig.saveFcmTokenEndpoint;

  bool _isInitialized = false;
  Future<void>? _initialization;

  /// Initialize OneSignal - Call this early in app startup (main.dart)
  Future<void> initializeOneSignal() async {
    if (_isInitialized) return;
    final inProgress = _initialization;
    if (inProgress != null) return inProgress;

    final initialization = _performInitialization();
    _initialization = initialization;
    await initialization;
  }

  Future<void> _performInitialization() async {
    try {
      OneSignal.Debug.setLogLevel(
        AppConfig.enableLogging ? OSLogLevel.warn : OSLogLevel.none,
      );

      // Initialize OneSignal with App ID
      OneSignal.initialize(_oneSignalAppId);

      // Request notification permission
      await OneSignal.Notifications.requestPermission(true);

      // ✅ LISTEN FOR NOTIFICATION CLICKS (Deep Linking)
      OneSignal.Notifications.addClickListener(_onNotificationClicked);

      // Listen for foreground notifications (Optional)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print(
          '🔔 Notification received in foreground: ${event.notification.title}',
        );
        unawaited(_saveNotification(event.notification));
      });

      _isInitialized = true;
      print('✅ OneSignal initialized successfully');
    } catch (e) {
      _initialization = null;
      print('❌ OneSignal initialization failed: $e');
    }
  }

  /// Login user to OneSignal (associate device with user ID)
  Future<void> login(
    String userId, {
    String? userAuthToken,
    dynamic user,
  }) async {
    try {
      // Authentication can finish before the deferred SDK startup. Always
      // initialize first so the external_id is never lost in that race.
      await initializeOneSignal();
      if (!_isInitialized) {
        throw StateError('OneSignal is not initialized');
      }
      await OneSignal.login(userId);
      print('✅ OneSignal user logged in: $userId');

      if (user != null) {
        await updateUserTags(user);
      } else {
        await OneSignal.User.addTagWithKey('user_id', userId);
      }

      // The subscription can be unavailable for a few moments after startup.
      // Observe it briefly instead of silently skipping backend registration.
      if (userAuthToken != null) {
        await _syncSubscriptionWithBackend(userAuthToken);
      }
    } catch (e) {
      print('❌ OneSignal login failed: $e');
    }
  }

  /// Logout user from OneSignal
  Future<void> logout() async {
    try {
      await OneSignal.logout();
      // Local inbox entries belong to the signed-in account. Remove them on
      // logout so a different account on the same device cannot see them.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(NotificationsCubit.storageKey);
      MessageUnreadController.instance.clear();
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await context.read<NotificationsCubit>().clearAll();
      }
      print('✅ OneSignal user logged out');
    } catch (e) {
      print('❌ OneSignal logout failed: $e');
    }
  }

  /// Handle notification click -> DEEP LINKING LOGIC
  void _onNotificationClicked(OSNotificationClickEvent event) {
    print('🔔 Notification clicked!');
    unawaited(_saveNotification(event.notification));
    final data = event.notification.additionalData;
    if (data != null) {
      _handleDeepLinking(data);
    }
  }

  /// Parse data and navigate using Global Key
  void _handleDeepLinking(Map<String, dynamic> data) {
    print('🔗 Deep Linking Data: $data');

    final String? type = data['type']?.toString();
    final String? idStr =
        (data['id'] ??
                data['order_id'] ??
                data['product_id'] ??
                data['conversation_id'])
            ?.toString();
    final int? id = idStr != null ? int.tryParse(idStr) : null;

    switch (type) {
      case 'order_vendor':
      case 'order_client':
        if (id == null) return;
        print('🚀 Navigating to Order Details: $id');
        navigatorKey.currentState?.pushNamed(
          Routes.orderDetails,
          arguments: id,
        );
        break;

      case 'product':
      case 'qa_vendor':
      case 'qa_client':
      case 'review_vendor':
      case 'followed_product':
        if (id == null) return;
        print('🚀 Navigating to Product Details: $id');
        navigatorKey.currentState?.pushNamed(
          Routes.productDetails,
          arguments: id,
        );
        break;

      case 'requests':
        print('🚀 Navigating to Requests Screen');
        navigatorKey.currentState?.pushNamed(Routes.requests);
        break;

      case 'message':
        if (id == null) return;
        navigatorKey.currentState?.pushNamed(
          Routes.chat,
          arguments: {'conversationId': id},
        );
        break;

      default:
        print('⚠️ Unknown notification type: $type');
        // Fallback or generic handling if needed
        break;
    }
  }

  /// Open a notification that was selected from the in-app notification inbox.
  void openNotificationData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;
    _handleDeepLinking(data);
  }

  Future<void> _syncSubscriptionWithBackend(String token) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final subscriptionId = OneSignal.User.pushSubscription.id;
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        await _sendTokenToBackend(subscriptionId, token);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
    print('⚠️ OneSignal subscription ID was not ready');
  }

  Future<void> _saveNotification(OSNotification notification) async {
    try {
      final data = Map<String, dynamic>.from(
        notification.additionalData ?? const <String, dynamic>{},
      );
      final item = NotificationModel(
        id: notification.notificationId,
        title: notification.title ?? 'إشعار جديد',
        body: notification.body ?? '',
        type: _normalizeType(data['type']?.toString()),
        timestamp: DateTime.now(),
        data: data,
      );

      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(NotificationsCubit.storageKey);
      final items = existing == null || existing.isEmpty
          ? <NotificationModel>[]
          : (jsonDecode(existing) as List<dynamic>)
                .map(
                  (entry) => NotificationModel.fromJson(
                    Map<String, dynamic>.from(entry as Map),
                  ),
                )
                .toList();

      if (items.any((entry) => entry.id == item.id)) return;
      items.insert(0, item);
      final trimmed = items.take(100).map((entry) => entry.toJson()).toList();
      await prefs.setString(NotificationsCubit.storageKey, jsonEncode(trimmed));

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await context.read<NotificationsCubit>().loadNotifications();
      }
    } catch (e) {
      print('⚠️ Failed to store notification: $e');
    }
  }

  String _normalizeType(String? type) {
    switch (type) {
      case 'order_vendor':
      case 'order_client':
        return 'order';
      case 'qa_vendor':
      case 'qa_client':
        return 'question';
      case 'review_vendor':
        return 'review';
      case 'followed_product':
        return 'product';
      case 'message':
        return 'message';
      case 'payment':
        return 'payment';
      default:
        return type ?? 'general';
    }
  }

  /// Send subscription ID to backend
  Future<void> _sendTokenToBackend(String id, String token) async {
    try {
      final dio = Dio();
      await dio.post(
        _saveTokenEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'fcm_token': id}, // Backend expects 'fcm_token' key
      );
      print('✅ Push subscription ID sent to backend');
    } catch (e) {
      print('⚠️ Failed to send push ID to backend: $e');
    }
  }

  /// Update User Tags for Targeted Notifications
  Future<void> updateUserTags(dynamic user) async {
    try {
      if (!_isInitialized) return;

      // user corresponds to UserModel, using dynamic to avoid import loop
      final tier = user.tier.toString().split('.').last;
      final tags = {
        'role': user.role,
        'tier': tier,
        'user_id': user.id.toString(),
        if (user.city != null) 'city': user.city!,
      };

      await OneSignal.User.addTags(tags);
      print('🏷️ OneSignal Tags Updated: $tags');
    } catch (e) {
      print('❌ Failed to update OneSignal tags: $e');
    }
  }

  /// Subscribe to a topic (using tags)
  Future<void> subscribeToTopic(String topic) async {
    try {
      // OneSignal doesn't have "topics" like FCM, so we use tags
      // Topic name becomes the key, value is "1" (true)
      await OneSignal.User.addTagWithKey(topic, "1");
      print('✅ Subscribed to topic (tag): $topic');
    } catch (e) {
      print('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic (remove tag)
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await OneSignal.User.removeTag(topic);
      print('✅ Unsubscribed from topic (tag): $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic: $e');
    }
  }
}
