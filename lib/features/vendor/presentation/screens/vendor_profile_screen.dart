import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
// Add these imports
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/mini_map_preview.dart';
import '../../../../core/di/injection_container.dart';
import '../cubit/vendor_profile_cubit.dart';
import '../../data/models/store_model.dart';
import '../../../shop/data/models/product_model.dart';
import '../../../shop/data/models/review_model.dart';
import '../../../shop/presentation/screens/product_details_screen.dart';
import 'package:hiraajsahm/features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/services/follow_service.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/routes/routes.dart';

/// Vendor Profile Screen - Shows store details and products
class VendorProfileScreen extends StatelessWidget {
  final int vendorId;

  const VendorProfileScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          sl<VendorProfileCubit>()..loadVendorProfile(vendorId),
      child: _VendorProfileView(vendorId: vendorId),
    );
  }
}

class _VendorProfileView extends StatefulWidget {
  final int vendorId;

  const _VendorProfileView({required this.vendorId});

  @override
  State<_VendorProfileView> createState() => _VendorProfileViewState();
}

class _VendorProfileViewState extends State<_VendorProfileView> {
  bool _isFollowing = false;
  bool _isLoadingFollow = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    final isFollowing = await FollowService().isFollowing(widget.vendorId);
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
      });
    }
  }

  Future<void> _toggleFollow() async {
    setState(() {
      _isLoadingFollow = true;
    });

    try {
      final isNowFollowing = await FollowService().toggleFollow(
        widget.vendorId,
      );
      if (mounted) {
        setState(() {
          _isFollowing = isNowFollowing;
          _isLoadingFollow = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowing ? 'تم متابعة السوق بنجاح' : 'تم إلغاء متابعة السوق',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: _isFollowing ? AppColors.success : Colors.grey,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: BlocConsumer<VendorProfileCubit, VendorProfileState>(
        listener: (context, state) {
          if (state is VendorProfileUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        builder: (context, state) {
          // Helper to get the latest available data state (Optimistic)
          final data = _getLoadedData(state);

          if (data != null) {
            return RefreshIndicator(
              onRefresh: () => context
                  .read<VendorProfileCubit>()
                  .loadVendorProfile(widget.vendorId),
              color: AppColors.primary,
              child: _buildContent(context, data, isDark, isTablet),
            );
          }

          if (state is VendorProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is VendorProfileError && state.message.isNotEmpty) {
            return _buildErrorWidget(context, state.message);
          }

          // Fallback if somehow both data and loading are null
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: AppColors.error),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () {
              context.read<VendorProfileCubit>().loadVendorProfile(
                widget.vendorId,
              );
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  VendorProfileLoaded? _getLoadedData(VendorProfileState state) {
    if (state is VendorProfileLoaded) {
      _lastLoadedState = state;
      return state;
    }
    // Return the cached state during updates so the screen doesn't go blank
    if (state is VendorProfileUpdating || state is VendorProfileUpdateSuccess) {
      return _lastLoadedState;
    }
    return null;
  }

  VendorProfileLoaded? _lastLoadedState;

  Widget _buildContent(
    BuildContext context,
    VendorProfileLoaded state,
    bool isDark,
    bool isTablet,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          context.read<VendorProfileCubit>().loadMoreProducts(widget.vendorId);
        }
        return false;
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Store Header with Banner
          _buildSliverAppBar(context, state.store, isDark),

          // Store Info Card
          SliverToBoxAdapter(
            child: FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildStoreInfoCard(state.store, isDark),
            ),
          ),

          // ---- NEW: STORE LINK SECTION ----
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 400),
              child: _buildStoreLinkSection(state.store, isDark),
            ),
          ),
          // --------------------------------

          // Products Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 12.h),
              child: Text(
                'اعلانات السوق',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // Products Grid
          state.products.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyProducts(isDark))
              : SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTablet ? 3 : 2,
                      childAspectRatio: isTablet ? 0.8 : 0.65,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return FadeInUp(
                        delay: Duration(milliseconds: 50 * (index % 6)),
                        duration: const Duration(milliseconds: 400),
                        child: _buildProductCard(
                          context,
                          state.products[index],
                          isDark,
                          storeOverride: state.store,
                        ),
                      );
                    }, childCount: state.products.length),
                  ),
                ),

          // Loading More Indicator
          if (state.hasMoreProducts)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20.h),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),

          // Store Reviews Section
          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 400),
              child: _buildReviewsSection(context, state, isDark),
            ),
          ),

          // Bottom Spacing
          SliverToBoxAdapter(child: SizedBox(height: 32.h)),
        ],
      ),
    );
  }

  // ---- NEW: WIDGET TO DISPLAY AND SHARE LINK ----
  Widget _buildStoreLinkSection(StoreModel store, bool isDark) {
    // Attempt to construct the URL if the model doesn't explicitly have it
    // Dokan standard: https://site.com/store/slug
    // Fallback logic in case StoreModel doesn't have `storeUrl` or `slug` yet
    String slug = store.storeSlug ?? '';
    if (slug.isEmpty && store.storeUrl != null) {
      slug = store.storeUrl!
          .split('/')
          .lastWhere((element) => element.isNotEmpty, orElse: () => '');
    }

    // Construct valid URL
    final String storeUrl =
        store.storeUrl ?? 'https://hiraajsahm.com/store/$slug/';

    // Only show if we have a valid slug or URL
    if (storeUrl.endsWith('/store//')) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: Colors.blue, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'رابط السوق',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            storeUrl,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(storeUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('زيارة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    textStyle: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Share.share('تفضل بزيارة سوقي على هراج سهم: \n$storeUrl');
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('مشاركة'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    textStyle: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ----------------------------------------------

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'gold':
        return const Color(0xFFFFD700); // Gold
      case 'silver':
        return const Color(0xFFC0C0C0); // Silver
      case 'bronze':
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.transparent;
    }
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    StoreModel store,
    bool isDark,
  ) {
    // 1. Check if the current user is the owner of this store
    final authState = context.read<AuthCubit>().state;
    bool isSelf = false;

    if (authState is AuthAuthenticated) {
      // Compare logged-in user ID with the vendor ID passed to the screen
      isSelf = authState.user.id == widget.vendorId;
    }

    return SliverAppBar(
      expandedHeight: 220.h,
      pinned: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
      leading: isSelf
          ? null // No back button for own profile (usually in dashboard)
          : IconButton(
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
      actions: [
        if (isSelf)
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.white),
            ),
            onPressed: () {
              AppRouter.navigateTo(
                context,
                Routes.vendorEditProfile,
                arguments: widget.vendorId,
              );
            },
          ),
        SizedBox(width: 8.w),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Image
            if (store.banner != null && store.banner!.isNotEmpty)
              Image.network(
                store.banner!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultBanner(),
              )
            else
              _buildDefaultBanner(),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),

            // Store Avatar & Name
            Positioned(
              bottom: 20.h,
              left: 20.w,
              right: 20.w,
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 74.w, // Increased for border
                    height: 74.w,
                    padding: EdgeInsets.all(
                      _getTierColor(store.vendorTier) != Colors.transparent
                          ? 3.w
                          : 0,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          _getTierColor(store.vendorTier) != Colors.transparent
                          ? Border.all(
                              color: _getTierColor(store.vendorTier),
                              width: 2.w,
                            )
                          : Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child:
                            store.gravatar != null && store.gravatar!.isNotEmpty
                            ? Image.network(
                                store.gravatar!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildDefaultAvatar(store),
                              )
                            : _buildDefaultAvatar(store),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),

                  // Store Name & Rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                store.displayName,
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (store.isVerified) ...[
                              SizedBox(width: 8.w),
                              Icon(
                                Icons.verified_rounded,
                                color: Colors.blue,
                                size: 20.sp,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            if (store.rating != null && store.rating! > 0)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: AppColors.secondary,
                                      size: 14.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      store.rating!.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '(${store.ratingCount ?? 0})',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),

                            // 2. Only show Follow Button if NOT self
                            if (!isSelf)
                              GestureDetector(
                                onTap: _isLoadingFollow ? null : _toggleFollow,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 6.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isFollowing
                                        ? Colors.white.withOpacity(0.2)
                                        : AppColors.secondary,
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: _isFollowing
                                        ? Border.all(color: Colors.white)
                                        : null,
                                  ),
                                  child: _isLoadingFollow
                                      ? SizedBox(
                                          width: 16.w,
                                          height: 16.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          children: [
                                            Icon(
                                              _isFollowing
                                                  ? Icons.check
                                                  : Icons.add,
                                              color: Colors.white,
                                              size: 16.sp,
                                            ),
                                            SizedBox(width: 6.w),
                                            Text(
                                              _isFollowing ? 'متابع' : 'متابعة',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Icon(Icons.store_rounded, size: 64.sp, color: Colors.white38),
      ),
    );
  }

  Widget _buildDefaultAvatar(StoreModel store) {
    return Container(
      color: AppColors.primary,
      child: Center(
        child: Text(
          store.displayName.isNotEmpty
              ? store.displayName[0].toUpperCase()
              : 'S',
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreInfoCard(StoreModel store, bool isDark) {
    // Check if we are viewing the logged-in user's profile
    final authState = context.read<AuthCubit>().state;
    String? phone = store.phone;
    String? address = store.address?.fullAddress;
    String? email = store.email;

    if (authState is AuthAuthenticated &&
        authState.user.isVendor &&
        authState.user.id == store.id) {
      // Fallback to user data if store data is empty
      if (phone.isEmpty) phone = authState.user.vendorInfo?.phone ?? '';
      if (address == null || address.isEmpty) {
        address = authState.user.vendorInfo?.address?.fullAddress;
      }
      if (email.isEmpty) email = authState.user.email;
    }

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Biography
          if (store.biography != null && store.biography!.isNotEmpty) ...[
            Text(
              'عن السوق',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              store.biography!,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark
                    ? AppColors.textLightSecondary
                    : AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),
            Divider(color: Colors.grey.withOpacity(0.2)),
            SizedBox(height: 16.h),
          ],

          // Phone
          if (phone.isNotEmpty)
            _buildInfoRow(Icons.phone_outlined, phone, isDark),

          // Address
          if (address != null && address.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildInfoRow(Icons.location_on_outlined, address, isDark),
          ],

          // Email (if shown)
          if (store.showEmail && email.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildInfoRow(Icons.email_outlined, email, isDark),
          ],

          // Location Coordinates
          if (store.location != null && store.location!.isNotEmpty) ...[
            SizedBox(height: 16.h),
            MiniMapPreview(
              latLong: store.location,
              isDark: isDark,
              label: 'موقع السوق',
            ),
          ],

          // Social Links
          if (store.social != null) ...[
            SizedBox(height: 16.h),
            Divider(color: Colors.grey.withOpacity(0.2)),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (store.social?.facebook != null &&
                    store.social!.facebook!.isNotEmpty)
                  _buildSocialIcon(
                    Icons.facebook_rounded,
                    store.social!.facebook!,
                    Colors.blue[800]!,
                  ),
                if (store.social?.instagram != null &&
                    store.social!.instagram!.isNotEmpty)
                  _buildSocialIcon(
                    Icons.camera_alt_rounded,
                    store.social!.instagram!,
                    Colors.purple,
                  ),
                if (store.social?.twitter != null &&
                    store.social!.twitter!.isNotEmpty)
                  _buildSocialIcon(
                    Icons.alternate_email_rounded,
                    store.social!.twitter!,
                    Colors.black,
                  ),
                if (store.social?.youtube != null &&
                    store.social!.youtube!.isNotEmpty)
                  _buildSocialIcon(
                    Icons.play_circle_filled_rounded,
                    store.social!.youtube!,
                    Colors.red,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, String url, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      child: InkWell(
        onTap: () {
          // TODO: Implement URL launcher if needed,
          // though for now we just show them
        },
        child: Icon(icon, size: 28.sp, color: color),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: AppColors.primary),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProducts(bool isDark) {
    return Container(
      padding: EdgeInsets.all(40.w),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد اعلانات حالياً',
            style: TextStyle(
              fontSize: 16.sp,
              color: isDark
                  ? AppColors.textLightSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    ProductModel product,
    bool isDark, {
    StoreModel? storeOverride,
  }) {
    return GestureDetector(
      onTap: () {
        // Inject store data if provided (to fix missing tier/info issues from API)
        ProductModel finalProduct = product;
        if (storeOverride != null) {
          // print(); // DEBUG
          finalProduct = product.copyWith(
            vendorTier: storeOverride.vendorTier,
            vendorName: storeOverride.displayName,
            vendorAvatar: storeOverride.gravatar,
            isVendorVerified: storeOverride.isVerified,
            vendorRating: storeOverride.rating,
            vendorRatingCount: storeOverride.ratingCount,
            vendorAddress: storeOverride.address?.fullAddress,
            vendorLocation: storeOverride.location,
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: finalProduct),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              child: AspectRatio(
                aspectRatio: 1,
                child: product.images.isNotEmpty
                    ? Image.network(
                        product.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                      )
                    : _buildPlaceholderImage(),
              ),
            ),

            // Product Info
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${product.price} ر.س',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40.sp,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildReviewsSection(
    BuildContext context,
    VendorProfileLoaded state,
    bool isDark,
  ) {
    final reviews = state.reviews;

    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التقييمات (${reviews.length})',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              // Only allow customers to review, and only if not self
              if (!_isSelf())
                TextButton.icon(
                  onPressed: () => _showAddReviewDialog(context),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('أضف تقييمك'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          if (reviews.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Column(
                  children: [
                    Icon(
                      Icons.star_outline_rounded,
                      size: 48.sp,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'لا توجد تقييمات لهذا المتجر بعد.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return _buildReviewCard(review, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review, bool isDark) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.reviewer,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              Row(
                children: List.generate(5, (starIndex) {
                  return Icon(
                    starIndex < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 14.sp,
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            review.dateCreated,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8.h),
          Text(
            review.review.replaceAll(RegExp(r'<[^>]*>'), ''),
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark
                  ? AppColors.textLight.withOpacity(0.9)
                  : AppColors.textPrimary.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelf() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id == widget.vendorId;
    }
    return false;
  }

  void _showAddReviewDialog(BuildContext context) {
    final reviewController = TextEditingController();
    int rating = 5;
    final cubit = context.read<VendorProfileCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: const Text('ما هو تقييمك للمتجر؟'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () {
                          setState(() {
                            rating = index + 1;
                          });
                        },
                        icon: Icon(
                          index < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 32.sp,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 16.h),
                  CustomTextField(
                    controller: reviewController,
                    hint: 'اكتب تجربتك مع المتجر هنا...',
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (reviewController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء كتابة تعليق')),
                      );
                      return;
                    }
                    cubit.submitStoreReview(
                      vendorId: widget.vendorId,
                      rating: rating,
                      comment: reviewController.text.trim(),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('إرسال التقييم'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
