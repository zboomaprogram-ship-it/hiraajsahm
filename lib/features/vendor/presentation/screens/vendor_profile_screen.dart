import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
// Add these imports
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/di/injection_container.dart';
import '../cubit/vendor_profile_cubit.dart';
import '../../data/models/store_model.dart';
import '../../../shop/data/models/product_model.dart';
import '../../../shop/presentation/screens/product_details_screen.dart';
import 'package:hiraajsahm/features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/services/follow_service.dart';

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
              _isFollowing
                  ? 'تم متابعة المتجر بنجاح'
                  : 'تم إلغاء متابعة المتجر',
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: BlocBuilder<VendorProfileCubit, VendorProfileState>(
        builder: (context, state) {
          if (state is VendorProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is VendorProfileError) {
            return _buildErrorWidget(context, state.message);
          }

          if (state is VendorProfileLoaded) {
            return _buildContent(context, state, isDark);
          }

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

  Widget _buildContent(
    BuildContext context,
    VendorProfileLoaded state,
    bool isDark,
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
                'منتجات المتجر',
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
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
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
                'رابط المتجر',
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
                    Share.share('تفضل بزيارة متجري على هراج سهم: \n$storeUrl');
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
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
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
                    width: 70.w,
                    height: 70.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                  SizedBox(width: 16.w),

                  // Store Name & Rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.displayName,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
        children: [
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
        ],
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
            'لا توجد منتجات حالياً',
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
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product),
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
}
