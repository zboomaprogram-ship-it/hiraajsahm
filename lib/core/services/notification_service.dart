import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:dio/dio.dart';
// import '../di/injection_container.dart';
import '../routes/routes.dart';

/// ✅ GLOBAL NAVIGATOR KEY
/// Allows navigation from outside the widget tree (Service -> Screen)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // OneSignal App ID
  static const String _oneSignalAppId = '9f9ed559-2c77-43e5-9c47-473043f2e6d4';

  // API endpoint for saving push subscription ID (optional backup)
  static const String _saveTokenEndpoint =
      'https://hiraajsahm.com/wp-json/custom/v1/save-fcm-token';

  bool _isInitialized = false;

  /// Initialize OneSignal - Call this early in app startup (main.dart)
  Future<void> initializeOneSignal() async {
    if (_isInitialized) {
      print('🔔 NotificationService already initialized');
      return;
    }

    try {
      // Enable verbose logging for debugging (disable in production)
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

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
        // event.preventDefault(); // Uncomment to stop it from showing
        event.notification.display();
      });

      _isInitialized = true;
      print('✅ OneSignal initialized successfully');
    } catch (e) {
      print('❌ OneSignal initialization failed: $e');
    }
  }

  /// Login user to OneSignal (associate device with user ID)
  Future<void> login(String userId, {String? userAuthToken}) async {
    try {
      await OneSignal.login(userId);
      print('✅ OneSignal user logged in: $userId');

      // Optionally save the push subscription ID to your backend
      if (userAuthToken != null) {
        final subscriptionId = OneSignal.User.pushSubscription.id;
        if (subscriptionId != null) {
          await _sendTokenToBackend(subscriptionId, userAuthToken);
        }
      }
    } catch (e) {
      print('❌ OneSignal login failed: $e');
    }
  }

  /// Logout user from OneSignal
  Future<void> logout() async {
    try {
      await OneSignal.logout();
      print('✅ OneSignal user logged out');
    } catch (e) {
      print('❌ OneSignal logout failed: $e');
    }
  }

  /// Handle notification click -> DEEP LINKING LOGIC
  void _onNotificationClicked(OSNotificationClickEvent event) {
    print('🔔 Notification clicked!');
    final data = event.notification.additionalData;
    if (data != null) {
      _handleDeepLinking(data);
    }
  }

  /// Parse data and navigate using Global Key
  void _handleDeepLinking(Map<String, dynamic> data) {
    print('🔗 Deep Linking Data: $data');

    final String? type = data['type']?.toString();
    final String? idStr = data['id']?.toString();
    final int? id = idStr != null ? int.tryParse(idStr) : null;

    if (id == null) {
      print('⚠️ Deep linking failed: ID is null');
      return;
    }

    switch (type) {
      case 'order_vendor':
      case 'order_client':
        print('🚀 Navigating to Order Details: $id');
        navigatorKey.currentState?.pushNamed(
          Routes.orderDetails,
          arguments: id,
        );
        break;

      case 'product':
      case 'qa_vendor':
      case 'qa_client':
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

      default:
        print('⚠️ Unknown notification type: $type');
        // Fallback or generic handling if needed
        break;
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
      final tags = {
        'role': user.role,
        'tier': user.tier.name,
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
