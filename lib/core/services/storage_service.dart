import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Secure Storage Service
/// Handles secure storage of sensitive data like tokens
/// and regular storage for non-sensitive preferences
class StorageService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _preferences;

  StorageService({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences preferences,
  }) : _secureStorage = secureStorage,
       _preferences = preferences;

  // ============ SECURE STORAGE (Tokens, Sensitive Data) ============

  /// Save JWT Token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConfig.tokenKey, value: token);
  }

  /// Get JWT Token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConfig.tokenKey);
  }

  /// Delete JWT Token
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: AppConfig.tokenKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Save User ID
  Future<void> saveUserId(int userId) async {
    await _secureStorage.write(
      key: AppConfig.userIdKey,
      value: userId.toString(),
    );
  }

  /// Get User ID
  Future<int?> getUserId() async {
    final id = await _secureStorage.read(key: AppConfig.userIdKey);
    return id != null ? int.tryParse(id) : null;
  }

  /// Save User Email
  Future<void> saveUserEmail(String email) async {
    await _secureStorage.write(key: AppConfig.userEmailKey, value: email);
  }

  /// Get User Email
  Future<String?> getUserEmail() async {
    return await _secureStorage.read(key: AppConfig.userEmailKey);
  }

  /// Save User Display Name
  Future<void> saveUserDisplayName(String displayName) async {
    await _secureStorage.write(
      key: AppConfig.userDisplayNameKey,
      value: displayName,
    );
  }

  /// Get User Display Name
  Future<String?> getUserDisplayName() async {
    return await _secureStorage.read(key: AppConfig.userDisplayNameKey);
  }

  /// Save User Role
  Future<void> saveUserRole(String role) async {
    await _secureStorage.write(key: AppConfig.userRoleKey, value: role);
  }

  /// Get User Role
  Future<String?> getUserRole() async {
    return await _secureStorage.read(key: AppConfig.userRoleKey);
  }

  /// Check if user is vendor
  Future<bool> isVendor() async {
    final role = await getUserRole();
    return role == AppConfig.roleVendor || role == AppConfig.roleAdmin;
  }

  /// Clear all secure storage (Logout)
  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }

  // ============ USER TIER & SUBSCRIPTION ============

  /// Save User Subscription Tier (bronze, silver, gold, zabayeh)
  Future<void> saveUserTier(String tier) async {
    await _secureStorage.write(key: 'user_tier', value: tier);
  }

  /// Get User Subscription Tier
  Future<String?> getUserTier() async {
    return await _secureStorage.read(key: 'user_tier');
  }

  /// Check if user has premium tier (Silver, Gold, or Al-Zabayeh)
  Future<bool> hasPremiumTier() async {
    final tier = await getUserTier();
    return tier == 'silver' || tier == 'gold' || tier == 'zabayeh';
  }

  // ============ VENDOR AD LIMITS ============

  /// Get last ad post date
  String? getLastPostDate() {
    return _preferences.getString('last_post_date');
  }

  /// Get daily post count
  int getDailyPostCount() {
    return _preferences.getInt('daily_post_count') ?? 0;
  }

  /// Increment post count (returns new count)
  Future<int> incrementPostCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = getLastPostDate();

    int count = 0;
    if (lastDate == today) {
      count = getDailyPostCount() + 1;
    } else {
      count = 1;
    }

    await _preferences.setString('last_post_date', today);
    await _preferences.setInt('daily_post_count', count);
    return count;
  }

  /// Reset daily post count
  Future<void> resetDailyPostCount() async {
    await _preferences.remove('daily_post_count');
    await _preferences.remove('last_post_date');
  }

  // ============ SHARED PREFERENCES (Non-Sensitive Data) ============

  /// Save Theme Mode (0: system, 1: light, 2: dark)
  Future<void> saveThemeMode(int mode) async {
    await _preferences.setInt(AppConfig.themeKey, mode);
  }

  /// Get Theme Mode
  int getThemeMode() {
    return _preferences.getInt(AppConfig.themeKey) ?? 0;
  }

  /// Save Locale
  Future<void> saveLocale(String locale) async {
    await _preferences.setString(AppConfig.localeKey, locale);
  }

  /// Get Locale
  String? getLocale() {
    return _preferences.getString(AppConfig.localeKey);
  }

  /// Set Onboarding Complete
  Future<void> setOnboardingComplete() async {
    await _preferences.setBool(AppConfig.onboardingKey, true);
  }

  /// Check Onboarding Complete
  bool isOnboardingComplete() {
    return _preferences.getBool(AppConfig.onboardingKey) ?? false;
  }

  /// Set Registration Pending Status
  /// Used to prevent auto-login if registration/payment is incomplete
  Future<void> setRegistrationPending(bool isPending) async {
    await _preferences.setBool('registration_pending', isPending);
  }

  /// Check if Registration is Pending
  bool isRegistrationPending() {
    return _preferences.getBool('registration_pending') ?? false;
  }

  /// Clear all preferences
  Future<void> clearPreferences() async {
    // Keep locale and theme preferences
    final themeMode = getThemeMode();
    final locale = getLocale();

    await _preferences.clear();

    await saveThemeMode(themeMode);
    if (locale != null) {
      await saveLocale(locale);
    }
  }

  /// Complete logout - clear everything
  Future<void> logout() async {
    await clearSecureStorage();
    await clearPreferences();
  }
}
