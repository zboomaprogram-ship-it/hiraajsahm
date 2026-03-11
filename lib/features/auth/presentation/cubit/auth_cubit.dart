import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
// import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/models/user_model.dart';
import '../../data/models/subscription_pack_model.dart';

// ============ AUTH STATES ============
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  final String token;
  final String? message;

  const AuthAuthenticated({
    required this.user,
    required this.token,
    this.message,
  });

  @override
  List<Object?> get props => [user, token, message];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthRegistrationInProgress extends AuthState {
  final bool isVendor;
  final List<SubscriptionPackModel> subscriptionPacks;
  final SubscriptionPackModel? selectedPack;

  const AuthRegistrationInProgress({
    this.isVendor = false,
    this.subscriptionPacks = const [],
    this.selectedPack,
  });

  AuthRegistrationInProgress copyWith({
    bool? isVendor,
    List<SubscriptionPackModel>? subscriptionPacks,
    SubscriptionPackModel? selectedPack,
  }) {
    return AuthRegistrationInProgress(
      isVendor: isVendor ?? this.isVendor,
      subscriptionPacks: subscriptionPacks ?? this.subscriptionPacks,
      selectedPack: selectedPack ?? this.selectedPack,
    );
  }

  @override
  List<Object?> get props => [isVendor, subscriptionPacks, selectedPack];
}

class VendorSubscriptionLoading extends AuthState {
  const VendorSubscriptionLoading();
}

class VendorSubscriptionLoaded extends AuthState {
  final List<SubscriptionPackModel> packs;
  final SubscriptionPackModel? selectedPack;

  const VendorSubscriptionLoaded({required this.packs, this.selectedPack});

  @override
  List<Object?> get props => [packs, selectedPack];
}

class AuthRegistrationSuccess extends AuthState {
  final UserModel user;

  const AuthRegistrationSuccess({required this.user});

  @override
  List<Object?> get props => [user];
}

/// State emitted when vendor registered with a subscription pack
/// UI should add pack to cart and navigate to checkout
class VendorRegisteredWithPack extends AuthState {
  final UserModel user;
  final int packId;

  const VendorRegisteredWithPack({required this.user, required this.packId});

  @override
  List<Object?> get props => [user, packId];
}

// ============ AUTH CUBIT ============
class AuthCubit extends Cubit<AuthState> {
  final AuthRemoteDataSource _authRemoteDataSource;
  final StorageService _storageService;

  UserModel? _currentUser;
  String? _currentToken;
  List<SubscriptionPackModel> _subscriptionPacks = [];

  AuthCubit({
    required AuthRemoteDataSource authRemoteDataSource,
    required StorageService storageService,
  }) : _authRemoteDataSource = authRemoteDataSource,
       _storageService = storageService,
       super(const AuthInitial());

  UserModel? get currentUser => _currentUser;
  String? get currentToken => _currentToken;
  List<SubscriptionPackModel> get subscriptionPacks => _subscriptionPacks;

  bool get isAuthenticated => state is AuthAuthenticated;
  bool get isVendor => _currentUser?.isVendor ?? false;

  /// Check authentication status on app start
  Future<void> checkAuthStatus() async {
    emit(const AuthLoading());
    print('🔐 checkAuthStatus: Starting...');

    try {
      final token = await _storageService.getToken();
      if (token == null || token.isEmpty) {
        print('🔐 checkAuthStatus: No token found');
        emit(const AuthUnauthenticated());
        return;
      }

      print('🔐 checkAuthStatus: Token found, validating...');
      // Validate token
      final result = await _authRemoteDataSource.validateToken();

      result.fold(
        (failure) {
          print('🔐 checkAuthStatus: Token validation failed');
          _clearAuthData();
          emit(const AuthUnauthenticated());
        },
        (isValid) async {
          if (isValid) {
            if (_storageService.isRegistrationPending()) {
              print('🔐 checkAuthStatus: Registration pending, forcing logout');
              await logout();
              return;
            }
            print(
              '🔐 checkAuthStatus: Token valid, fetching fresh user data...',
            );
            // Always fetch fresh user data from WooCommerce API
            final userResult = await _authRemoteDataSource.getCurrentUser();
            userResult.fold(
              (failure) {
                print(
                  '🔐 checkAuthStatus: Failed to fetch user: ${failure.message}',
                );
                // Token is valid but couldn't fetch user, use cached data as fallback
                _loadCachedUser(token);
              },
              (user) {
                print('🔐 checkAuthStatus: Got fresh user data!');
                print(
                  '🔐 checkAuthStatus: role=${user.role}, isVendor=${user.isVendor}',
                );
                print(
                  '🔐 checkAuthStatus: packId=${user.subscriptionPackId}, tier=${user.tier}',
                );
                _currentUser = user;
                _currentToken = token;
                _saveUserData(user); // Save fresh data to cache
                emit(AuthAuthenticated(user: user, token: token));
              },
            );
          } else {
            print('🔐 checkAuthStatus: Token invalid');
            _clearAuthData();
            emit(const AuthUnauthenticated());
          }
        },
      );
    } catch (e) {
      print('🔐 checkAuthStatus: Exception: $e');
      _clearAuthData();
      emit(const AuthUnauthenticated());
    }
  }

  /// Login with username/email and password
  Future<void> login({
    required String username,
    required String password,
  }) async {
    emit(const AuthLoading());

    final result = await _authRemoteDataSource.login(
      username: username,
      password: password,
    );

    await result.fold(
      (failure) {
        emit(AuthFailure(message: failure.message));
      },
      (data) async {
        final token = data['token'] as String;
        await _storageService.saveToken(token);

        // Fetch complete user data
        final userResult = await _authRemoteDataSource.getCurrentUser();

        userResult.fold(
          (failure) {
            // Use basic data from login response
            final user = UserModel(
              id: 0,
              email: data['user_email'] ?? '',
              displayName: data['user_display_name'] ?? '',
              role: 'customer',
            );
            _currentUser = user;
            _currentToken = token;
            _saveUserData(user);
            emit(AuthAuthenticated(user: user, token: token));
          },
          (user) {
            _currentUser = user;
            _currentToken = token;
            _saveUserData(user);
            // Initialize OneSignal for this user
            NotificationService().login(
              user.id.toString(),
              userAuthToken: token,
            );

            // Check for expiration (Downgrade notification)
            if (user.subscriptionStatus == SubscriptionStatus.expired &&
                user.subscriptionPackId != null) {
              emit(
                AuthAuthenticated(
                  user: user,
                  token: token,
                  message: "انتهت صلاحية باقتك. تم إعادتك للباقة البرونزية.",
                ),
              );
            } else {
              emit(AuthAuthenticated(user: user, token: token));
            }
          },
        );
      },
    );
  }

  /// Start registration process
  void startRegistration({bool isVendor = false}) {
    emit(AuthRegistrationInProgress(isVendor: isVendor));
  }

  /// Toggle vendor registration mode
  Future<void> toggleVendorMode(bool isVendor) async {
    if (isVendor && _subscriptionPacks.isEmpty) {
      emit(const VendorSubscriptionLoading());
      await fetchSubscriptionPacks();
    }

    if (state is AuthRegistrationInProgress) {
      emit((state as AuthRegistrationInProgress).copyWith(isVendor: isVendor));
    } else {
      emit(
        AuthRegistrationInProgress(
          isVendor: isVendor,
          subscriptionPacks: _subscriptionPacks,
        ),
      );
    }
  }

  /// Fetch subscription packs for vendor registration
  Future<void> fetchSubscriptionPacks() async {
    emit(const VendorSubscriptionLoading());

    final result = await _authRemoteDataSource.getSubscriptionPacks();

    result.fold(
      (failure) {
        emit(VendorSubscriptionLoaded(packs: const []));
      },
      (packs) {
        _subscriptionPacks = packs;
        emit(VendorSubscriptionLoaded(packs: packs));
      },
    );
  }

  /// Select subscription pack
  void selectSubscriptionPack(SubscriptionPackModel pack) {
    if (state is VendorSubscriptionLoaded) {
      emit(
        VendorSubscriptionLoaded(packs: _subscriptionPacks, selectedPack: pack),
      );
    } else if (state is AuthRegistrationInProgress) {
      emit((state as AuthRegistrationInProgress).copyWith(selectedPack: pack));
    }
  }

  /// Register as customer
  Future<void> registerCustomer({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? city,
    String? region,
    String? location,
  }) async {
    emit(const AuthLoading());

    final result = await _authRemoteDataSource.registerCustomer(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      city: city,
      region: region,
      location: location,
    );

    result.fold(
      (failure) {
        emit(AuthFailure(message: failure.message));
      },
      (user) {
        emit(AuthRegistrationSuccess(user: user));
      },
    );
  }

  /// Register as vendor
  /// Flow: Register -> Auto Login -> Emit state to trigger subscription
  Future<void> registerVendor({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String storeName,
    required String phone,
    String? storeUrl,
    String? address, // Added address
    String? city,
    String? region,
    String? location,
    int? subscriptionPackId,
  }) async {
    emit(const AuthLoading());

    // 1. Register user as vendor
    final result = await _authRemoteDataSource.registerVendor(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      storeName: storeName,
      phone: phone,
      storeUrl: storeUrl,
      address: address, // Pass address
      city: city,
      region: region,
      location: location,
      subscriptionPackId: subscriptionPackId,
    );

    await result.fold(
      (failure) {
        emit(AuthFailure(message: failure.message));
      },
      (user) async {
        // 2. Registration success - Now auto-login
        final loginResult = await _authRemoteDataSource.login(
          username: email,
          password: password,
        );

        await loginResult.fold(
          (loginFailure) {
            // Login failed, but registration succeeded
            emit(AuthRegistrationSuccess(user: user));
          },
          (data) async {
            // 3. Login success - Save token and user data
            final token = data['token'] as String;
            await _storageService.saveToken(token);

            _currentUser = user;
            _currentToken = token;
            await _saveUserData(user);
            await _storageService.setRegistrationPending(true);

            // 4. Check if subscription pack was selected
            if (subscriptionPackId != null) {
              // Emit special state to trigger "Add to Cart" logic in UI
              emit(
                VendorRegisteredWithPack(
                  user: user,
                  packId: subscriptionPackId,
                ),
              );
            } else {
              emit(AuthAuthenticated(user: user, token: token));
            }
          },
        );
      },
    );
  }

  /// Upgrade User to Vendor (Bronze Tier)
  Future<void> upgradeToVendor({
    required String shopName,
    required String phone,
    String? shopLink,
  }) async {
    if (_currentUser == null) return;

    emit(const AuthLoading());

    // 1. Call API to update role and meta
    final result = await _authRemoteDataSource.upgradeToVendor(
      userId: _currentUser!.id,
      shopName: shopName,
      phone: phone,
      shopLink: shopLink,
    );

    result.fold(
      (failure) {
        // Re-emit authenticated state with error message, but keep user logged in
        emit(
          AuthAuthenticated(
            user: _currentUser!,
            token: _currentToken!,
            message: failure.message, // Or separate error handling
          ),
        );
        // Also could emit AuthFailure but that might log them out visually depending on UI.
        // Better to show snackbar via listener on message change.
      },
      (success) async {
        // 2. Update local user model
        final updatedUser = _currentUser!.copyWith(
          role: 'seller', // WP role
          isVendor: true,
          subscriptionPackId: 29026, // Bronze/Free ID
        );

        _currentUser = updatedUser;

        // 3. Update storage
        await _saveUserData(updatedUser);

        // 4. Update Notifications tags if needed
        await NotificationService().updateUserTags(updatedUser);

        // 5. Emit success
        emit(AuthAuthenticated(user: updatedUser, token: _currentToken!));
      },
    );
  }

  /// Update current user metadata (phone, city, region, image, etc.)
  Future<void> updateUserMetadata({
    String? firstName,
    String? lastName,
    String? phone,
    String? city,
    String? region,
    String? location,
    String? imagePath,
  }) async {
    if (_currentUser == null) return;
    emit(const AuthLoading());

    // Upload image first if provided
    if (imagePath != null) {
      final uploadResult = await _authRemoteDataSource.uploadMedia(imagePath);
      uploadResult.fold(
        (l) => print('📸 Profile image upload failed: ${l.message}'),
        (id) => print(
          '📸 Profile image uploaded with ID: $id (Avatar sync pending backend support)',
        ),
      );
    }

    // For standard WP/WC, updating 'avatar_url' isn't direct.
    // If the user wants to update profile image, we usually need to update a meta key that the theme/plugin uses.
    // Let's assume we maintain the other fields for now as requested.

    final result = await _authRemoteDataSource.updateUserMetadata(
      userId: _currentUser!.id,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      city: city,
      region: region,
      location: location,
    );

    result.fold(
      (failure) {
        print('⚠️ Failed to update user metadata: ${failure.message}');
        // Emit failure or just keep previous state with message
        emit(
          AuthAuthenticated(
            user: _currentUser!,
            token: _currentToken ?? '',
            message: 'فشل تديث البيانات: ${failure.message}',
          ),
        );
      },
      (user) {
        _currentUser = user;
        _saveUserData(user);
        emit(
          AuthAuthenticated(
            user: user,
            token: _currentToken ?? '',
            message: 'تم تحديث البيانات بنجاح',
          ),
        );
      },
    );
  }

  /// Complete registration (mark as not pending)
  Future<void> completeRegistration() async {
    await _storageService.setRegistrationPending(false);
  }

  /// Cancel registration (delete user and logout)
  Future<void> cancelRegistration() async {
    if (_currentUser != null) {
      await _authRemoteDataSource.deleteUser(_currentUser!.id);
    }
    await logout();
  }

  /// Delete user account permanently
  Future<void> deleteAccount(int userId) async {
    emit(const AuthLoading());
    final result = await _authRemoteDataSource.deleteUser(userId);
    result.fold(
      (failure) {
        // Re-emit authenticated state on failure
        if (_currentUser != null && _currentToken != null) {
          emit(AuthAuthenticated(
            user: _currentUser!,
            token: _currentToken!,
            message: 'فشل في حذف الحساب: ${failure.message}',
          ));
        } else {
          emit(AuthFailure(message: failure.message));
        }
      },
      (success) async {
        await NotificationService().logout();
        await _clearAuthData();
        emit(const AuthUnauthenticated());
      },
    );
  }

  Future<void> logout() async {
    emit(const AuthLoading());
    // Clear OneSignal user
    await NotificationService().logout();
    await _clearAuthData();
    emit(const AuthUnauthenticated());
  }

  /// Clear all authentication data
  Future<void> _clearAuthData() async {
    _currentUser = null;
    _currentToken = null;
    await _storageService.logout();
  }

  /// Save user data to storage
  Future<void> _saveUserData(UserModel user) async {
    await _storageService.saveUserId(user.id);
    await _storageService.saveUserEmail(user.email);
    await _storageService.saveUserDisplayName(user.displayName);
    await _storageService.saveUserRole(user.role);
    await _storageService.saveUserTier(user.tier.name);
  }

  /// Load cached user data
  Future<void> _loadCachedUser(String token) async {
    final userId = await _storageService.getUserId();
    final email = await _storageService.getUserEmail();
    final displayName = await _storageService.getUserDisplayName();
    final role = await _storageService.getUserRole();
    final tierString = await _storageService.getUserTier();

    // Convert tier string to pack ID for consistency
    int? packId;
    switch (tierString) {
      case 'gold':
        packId = 29030;
        break;
      case 'silver':
        packId = 29028;
        break;
      case 'bronze':
        packId = 29026;
        break;
    }

    if (userId != null && email != null) {
      final user = UserModel(
        id: userId,
        email: email,
        displayName: displayName ?? '',
        role: role ?? 'customer',
        isVendor:
            role == 'seller' ||
            role == 'Vendor' ||
            role == 'vendor' ||
            role == 'administrator',
        subscriptionPackId: packId,
      );
      _currentUser = user;
      _currentToken = token;
      // OneSignal Login
      // OneSignal.login(user.id.toString());
      emit(AuthAuthenticated(user: user, token: token));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  /// Reset to initial state
  void reset() {
    emit(const AuthInitial());
  }
}
