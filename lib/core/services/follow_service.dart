import 'package:shared_preferences/shared_preferences.dart';
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
      // Subscribe to vendor's OneSignal topic
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
      // Unsubscribe from vendor's OneSignal topic
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

  /// Get follower count for a vendor (placeholder - needs backend API)
  /// TODO: Implement actual API call to get follower count
  Future<int> getFollowerCount(int vendorId) async {
    // This would need a backend endpoint to track followers
    return 0;
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
}
