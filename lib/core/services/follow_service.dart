import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../di/injection_container.dart';
import 'notification_service.dart';

/// Service for following/unfollowing vendors
/// Uses OneSignal topics for push notification subscriptions
class FollowService {
  static final FollowService _instance = FollowService._internal();
  factory FollowService() => _instance;
  FollowService._internal();

  // Local storage key prefix for followed vendors
  static const String _followedVendorsKey = 'followed_vendors';

  /// Follow a vendor - subscribes to their OneSignal topic
  Future<void> followVendor(int vendorId) async {
    try {
      await _syncFollow(vendorId, follow: true);
      final topicName = 'vendor_$vendorId';
      await NotificationService().subscribeToTopic(topicName);

      // Save to local storage
      await _addFollowedVendor(vendorId);

      print('✅ Now following vendor: $vendorId');
    } catch (e) {
      print('❌ Error following vendor: $e');
      rethrow;
    }
  }

  /// Unfollow a vendor - unsubscribes from their OneSignal topic
  Future<void> unfollowVendor(int vendorId) async {
    try {
      await _syncFollow(vendorId, follow: false);
      final topicName = 'vendor_$vendorId';
      await NotificationService().unsubscribeFromTopic(topicName);

      // Remove from local storage
      await _removeFollowedVendor(vendorId);

      print('✅ Unfollowed vendor: $vendorId');
    } catch (e) {
      print('❌ Error unfollowing vendor: $e');
      rethrow;
    }
  }

  /// Check if currently following a vendor
  Future<bool> isFollowing(int vendorId) async {
    try {
      final response = await sl<Dio>().get(
        '${AppConfig.followEndpoint}/$vendorId',
      );
      if (response.statusCode == 200 && response.data is Map) {
        final following = response.data['following'] == true;
        if (following) {
          await _addFollowedVendor(vendorId);
        } else {
          await _removeFollowedVendor(vendorId);
        }
        return following;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 &&
          e.response?.statusCode != 403 &&
          e.response?.statusCode != 404) {
        rethrow;
      }
    }
    final followedVendors = await getFollowedVendors();
    return followedVendors.contains(vendorId);
  }

  /// Get list of all followed vendor IDs
  Future<List<int>> getFollowedVendors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> vendorStrings =
          prefs.getStringList(_followedVendorsKey) ?? [];
      return vendorStrings
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toList();
    } catch (e) {
      print('❌ Error getting followed vendors: $e');
      return [];
    }
  }

  /// Add vendor to local followed list
  Future<void> _addFollowedVendor(int vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_followedVendorsKey) ?? [];

    if (!current.contains(vendorId.toString())) {
      current.add(vendorId.toString());
      await prefs.setStringList(_followedVendorsKey, current);
    }
  }

  /// Remove vendor from local followed list
  Future<void> _removeFollowedVendor(int vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_followedVendorsKey) ?? [];

    current.remove(vendorId.toString());
    await prefs.setStringList(_followedVendorsKey, current);
  }

  Future<int> getFollowerCount(int vendorId) async {
    try {
      final response = await sl<Dio>().get(
        '${AppConfig.followEndpoint}/$vendorId',
      );
      return int.tryParse(response.data?['count']?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Toggle follow status
  Future<bool> toggleFollow(int vendorId) async {
    final isCurrentlyFollowing = await isFollowing(vendorId);

    if (isCurrentlyFollowing) {
      await unfollowVendor(vendorId);
      return false;
    } else {
      await followVendor(vendorId);
      return true;
    }
  }

  Future<void> _syncFollow(int vendorId, {required bool follow}) async {
    try {
      await sl<Dio>().post(
        '${AppConfig.followEndpoint}/$vendorId',
        data: {'follow': follow},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw Exception('يرجى تسجيل الدخول لمتابعة البائع');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('خدمة المتابعة غير متاحة على الخادم');
      }
      rethrow;
    }
  }
}
