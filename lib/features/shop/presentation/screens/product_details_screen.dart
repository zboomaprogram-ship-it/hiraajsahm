import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../data/models/product_model.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../presentation/cubit/product_details_cubit.dart';
import '../../presentation/cubit/qna_cubit.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../widgets/product_qr_card.dart';
import '../widgets/service_providers_slider.dart';
import '../cubit/service_providers_cubit.dart';
import '../../../../core/widgets/mini_map_preview.dart';
import '../../../../features/vendor/presentation/cubit/vendor_profile_cubit.dart';
import 'package:geocoding/geocoding.dart';

/// Product Details Screen
/// Full product view with image slider, info, and action buttons
class ProductDetailsScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final PageController _imageController = PageController();
  int _currentImageIndex = 0;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  String _resolvedLocation = 'جاري التحديد...';

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
    _resolveLocation();
  }

  void _resolveLocation() async {
    final region = widget.product.productRegion;
    final city = widget.product.productCity;

    if (region != null &&
        region.isNotEmpty &&
        city != null &&
        city.isNotEmpty) {
      if (mounted) setState(() => _resolvedLocation = '$city، $region');
      return;
    } else if (region != null && region.isNotEmpty) {
      if (mounted) setState(() => _resolvedLocation = region);
      return;
    } else if (city != null && city.isNotEmpty) {
      if (mounted) setState(() => _resolvedLocation = city);
      return;
    }

    final locText =
        widget.product.productLocation ?? widget.product.vendorAddress;
    if (locText == null || locText.isEmpty) {
      if (mounted) setState(() => _resolvedLocation = 'غير محدد');
      return;
    }

    if (locText.contains(',')) {
      final parts = locText.split(',');
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      if (lat != null && lng != null) {
        try {
          // Set Arabic locale for geocoding
          try {
            await setLocaleIdentifier('ar');
          } catch (_) {
            // Fallback: setLocaleIdentifier may not work on all platforms
          }
          final placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final city =
                place.locality ??
                place.subAdministrativeArea ??
                place.administrativeArea ??
                '';
            final region = place.administrativeArea ?? '';
            final name = [
              city,
              region,
            ].where((e) => e.isNotEmpty).toSet().join('، ');

            if (mounted)
              setState(
                () => _resolvedLocation = name.isNotEmpty
                    ? name
                    : 'محدد على الخريطة',
              );
          } else {
            if (mounted) setState(() => _resolvedLocation = 'محدد على الخريطة');
          }
        } catch (e) {
          if (mounted) setState(() => _resolvedLocation = 'محدد على الخريطة');
        }
      } else {
        if (mounted) setState(() => _resolvedLocation = locText);
      }
    } else {
      if (mounted) setState(() => _resolvedLocation = locText);
    }
  }

  void _initVideoPlayer() {
    final videoUrl = widget.product.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: _videoController!,
              autoPlay: false,
              looping: false,
              aspectRatio: _videoController!.value.aspectRatio,
              placeholder: Container(color: Colors.black),
            );
          });
        });
    }
  }

  @override
  void dispose() {
    _imageController.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = widget.product;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              di.sl<ProductDetailsCubit>()..loadReviews(product.id),
        ),
        BlocProvider(
          create: (context) =>
              di.sl<QnACubit>()..fetchProductQuestions(product.id),
        ),
        BlocProvider(
          create: (context) {
            final cubit = di.sl<VendorProfileCubit>();
            // Enable showLoading: true to show a loader while fetching correct tier/details
            if (product.vendorId != null) {
              cubit.loadVendorProfile(product.vendorId!, showLoading: true);
            }
            return cubit;
          },
        ),
      ],
      child: BlocListener<CartCubit, CartState>(
        listener: (context, state) {
          if (state is CartReplaceConfirmation) {
            _showReplaceCartDialog(context);
          }
        },
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.background,
            body: BlocBuilder<VendorProfileCubit, VendorProfileState>(
              builder: (context, state) {
                if (state is VendorProfileLoading ||
                    state is VendorProfileInitial) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (state is VendorProfileError) {
                  return Center(child: Text(state.message));
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      leading: _buildBackButton(context),
                      title: Text(
                        product.name,
                        style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      ),
                      actions: [
                        _buildActionButton(Icons.share_outlined, () {}),
                        SizedBox(width: 16.w),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          height: 300.h,
                          child: _buildImageSlider(product),
                        ),
                      ),
                    ),

                    // 1. Text Details (Info & Description)
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            _buildProductInfo(context, product, isDark),
                            _buildDescription(product, isDark),
                          ],
                        ),
                      ),
                    ),

                    // Video Player (if available)
                    if (product.videoUrl != null &&
                        product.videoUrl!.isNotEmpty)
                      SliverToBoxAdapter(
                        child: FadeInUp(
                          delay: const Duration(milliseconds: 150),
                          duration: const Duration(milliseconds: 300),
                          child: _buildVideoPlayer(isDark),
                        ),
                      ),

                    // 2. Images Slider

                    // // 3. Contact Actions (Call/Message)
                    // SliverToBoxAdapter(
                    //   child: FadeInUp(
                    //     delay: const Duration(milliseconds: 150),
                    //     duration: const Duration(milliseconds: 400),
                    //     child: _buildContactButtons(context, product),
                    //   ),
                    // ),

                    // 4. Vendor Info
                    if (product.vendorName != null)
                      SliverToBoxAdapter(
                        child: FadeInUp(
                          delay: const Duration(milliseconds: 200),
                          duration: const Duration(milliseconds: 400),
                          child: Column(
                            children: [
                              BlocBuilder<
                                VendorProfileCubit,
                                VendorProfileState
                              >(
                                builder: (context, state) {
                                  ProductModel displayProduct = product;
                                  if (state is VendorProfileLoaded &&
                                      state.store.id == product.vendorId) {
                                    // Merge fresh store data into product
                                    displayProduct = product.copyWith(
                                      vendorTier: state.store.vendorTier,
                                      vendorName: state.store.displayName,
                                      vendorAvatar: state.store.gravatar,
                                      isVendorVerified: state.store.isVerified,
                                      vendorRating: state.store.rating,
                                      vendorRatingCount:
                                          state.store.ratingCount,
                                      vendorAddress:
                                          state.store.address?.fullAddress,
                                      vendorLocation: state.store.location,
                                    );
                                  }
                                  return _buildVendorCard(
                                    displayProduct,
                                    isDark,
                                  );
                                },
                              ),
                              SizedBox(height: 12.h),
                              BlocBuilder<
                                VendorProfileCubit,
                                VendorProfileState
                              >(
                                builder: (context, vendorState) {
                                  String? location =
                                      product.vendorLocation ??
                                      product.productLocation;

                                  if (location == null || location.isEmpty) {
                                    if (vendorState is VendorProfileLoaded) {
                                      location = vendorState.store.location;
                                    }
                                  }

                                  if (location != null && location.isNotEmpty) {
                                    // Make sure it's valid lat/lng before showing map
                                    final parts = location.split(',');
                                    if (parts.length == 2 &&
                                        double.tryParse(parts[0].trim()) !=
                                            null &&
                                        double.tryParse(parts[1].trim()) !=
                                            null) {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20.w,
                                        ),
                                        child: Column(
                                          children: [
                                            MiniMapPreview(
                                              latLong: location,
                                              isDark: isDark,
                                              label: 'الموقع على الخريطة',
                                              height: 180,
                                            ),
                                            SizedBox(height: 12.h),
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              ProductQRCard(product: product),
                              SizedBox(height: 20.h),
                              _buildReviewsSection(context, isDark),
                            ],
                          ),
                        ),
                      ),
                    if (product.vendorName == null)
                      SliverToBoxAdapter(
                        child: FadeInUp(
                          delay: const Duration(milliseconds: 200),
                          duration: const Duration(milliseconds: 400),
                          child: _buildReviewsSection(context, isDark),
                        ),
                      ),

                    // 5. Q&A Section (New)
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        delay: const Duration(milliseconds: 250),
                        duration: const Duration(milliseconds: 400),
                        child: _buildQnASection(context, isDark),
                      ),
                    ),

                    // 5. Service Providers (Inspection & Delivery)
                    SliverToBoxAdapter(
                      child: FadeInUp(
                        delay: const Duration(milliseconds: 250),
                        duration: const Duration(milliseconds: 400),
                        child: _buildServiceProvidersSection(context, isDark),
                      ),
                    ),

                    // Bottom Spacing
                    SliverToBoxAdapter(child: SizedBox(height: 100.h)),
                  ],
                );
              },
            ),
            bottomNavigationBar: _buildBottomNavBar(context, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, bool isDark) {
    final vendorState = context.watch<VendorProfileCubit>().state;
    if (vendorState is VendorProfileLoading ||
        vendorState is VendorProfileInitial) {
      return const SizedBox.shrink();
    }

    // 1. Check if product is locked (sold)
    // 1. Check if product is locked (Under Review)
    // Note: We no longer block the action bar for locked products,
    // as the user wants them to be addable to the cart.

    // 2. Check if current user is the vendor (Owner)
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated &&
        authState.user.id == widget.product.vendorId) {
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            height: 56.h,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.warning),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  color: AppColors.warning,
                  size: 24.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'هذا اعلان الخاص',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Standard Action Bar (Add to Cart / Request)
    return _buildActionBar(context, isDark);
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20.sp),
      ),
    );
  }

  Widget _buildImageSlider(ProductModel product) {
    final images = product.images.isNotEmpty ? product.images : ['placeholder'];

    return Stack(
      children: [
        PageView.builder(
          controller: _imageController,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemCount: images.length,
          itemBuilder: (context, index) {
            if (images[index] == 'placeholder') {
              return Container(
                color: AppColors.surface,
                child: Center(
                  child: Icon(
                    Icons.pets,
                    size: 80.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }
            return CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.surface,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.surface,
                child: Icon(
                  Icons.broken_image,
                  size: 60.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          },
        ),

        // Image Indicator
        if (images.length > 1)
          Positioned(
            bottom: 20.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  width: _currentImageIndex == index ? 24.w : 8.w,
                  height: 8.w,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: _currentImageIndex == index
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
            ),
          ),

        // Under Inspection Banner (Out of Stock)
        if (widget.product.stockStatus == 'outofstock' ||
            widget.product.stockQuantity == 0)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'قيد المعاينة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductInfo(
    BuildContext context,
    ProductModel product,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.hasDiscount) ...[
                    Text(
                      '${product.regularPrice} ر.س',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    SizedBox(height: 4.h),
                  ],
                  Text(
                    '${product.price} ر.س',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              if (product.hasDiscount)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${product.discountPercentage.toStringAsFixed(0)}% خصم',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),

          // Product Name
          Text(
            product.name,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),

          // Stock Status
          Row(
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: product.isInStock
                      ? AppColors.success
                      : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                product.isInStock ? 'متوفر' : 'غير متوفر',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: product.isInStock
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Address (Location)
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: AppColors.textSecondary,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  _resolvedLocation,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Attributes
          if (product.attributes.isNotEmpty) ...[
            // ... existing attribute code
            SizedBox(height: 20.h),
            _buildAttributes(product, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildAttributes(ProductModel product, bool isDark) {
    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children: product.attributes.map((attr) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attr.name,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                attr.options.join(', '),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescription(ProductModel product, bool isDark) {
    if (product.description.isEmpty) return const SizedBox.shrink();

    // Strip HTML tags for simple display
    final plainText = product.description
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();

    if (plainText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(20.w),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الوصف',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            plainText,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_outline,
                color: AppColors.primary,
                size: 24.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'فيديو الاعلان',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  _chewieController != null &&
                      _videoController!.value.isInitialized
                  ? Chewie(controller: _chewieController!)
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildVendorCard(ProductModel product, bool isDark) {
    // print(); // DEBUG
    final tierColor = _getTierColor(product.vendorTier);
    final hasTier = tierColor != Colors.transparent;

    return GestureDetector(
      onTap: () {
        // Navigate to vendor profile if vendorId is available
        if (product.vendorId != null) {
          AppRouter.navigateTo(
            context,
            Routes.storeDetails,
            arguments: product.vendorId,
          );
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Vendor Avatar
            Container(
              width: 54.w, // Slightly larger for border
              height: 54.w,
              padding: EdgeInsets.all(hasTier ? 2.w : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: hasTier
                    ? Border.all(color: tierColor, width: 2.w)
                    : Border.all(
                        color: Colors.white,
                        width: 3,
                      ), // Match Profile Default
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, // Match Profile
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child:
                      product.vendorAvatar != null &&
                          product.vendorAvatar!.isNotEmpty
                      ? Image.network(
                          product.vendorAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.store_rounded,
                            color: AppColors.primary,
                            size: 28.sp,
                          ),
                        )
                      : Icon(
                          Icons.store_rounded,
                          color: AppColors.primary,
                          size: 28.sp,
                        ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          product.vendorName ?? 'السوق',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.isVendorVerified) ...[
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.blue,
                          size: 16.sp,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  // Vendor Rating
                  if (product.vendorRating != null &&
                      product.vendorRating! > 0) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          product.vendorRating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          '(${product.vendorRatingCount})',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                  ],
                  Text(
                    'عرض السوق',
                    style: TextStyle(fontSize: 13.sp, color: AppColors.primary),
                  ),
                  if (_resolvedLocation != 'غير محدد' &&
                      _resolvedLocation != 'جاري التحديد...') ...[
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14.sp,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            _resolvedLocation,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, bool isDark) {
    return BlocBuilder<VendorProfileCubit, VendorProfileState>(
      builder: (context, state) {
        // Dynamic product with vendor data injection
        ProductModel product = widget.product;
        if (state is VendorProfileLoaded &&
            state.store.id == widget.product.vendorId) {
          product = widget.product.copyWith(vendorTier: state.store.vendorTier);
        }

        final price = double.tryParse(product.price) ?? 0;
        // Use dynamic deposit percentage based on tier (Silver/Gold=10%, Bronze=1%)
        final depositPercentage = product.depositPercentage;
        final deposit = price * depositPercentage;
        final isOutOfStock =
            product.stockStatus == 'outofstock' || product.stockQuantity == 0;

        final cartState = context.watch<CartCubit>().state;
        bool isInCart = false;
        if (cartState is CartLoaded) {
          isInCart = cartState.items.any(
            (item) => item.product.id == product.id,
          );
        }
        final isButtonDisabled = isOutOfStock || isInCart;

        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Inspection Button (Dynamic Percentage)
                Expanded(
                  child: ElevatedButton(
                    onPressed: isButtonDisabled
                        ? null
                        : () {
                            context.read<CartCubit>().addItem(
                              product,
                              isDeposit: true,
                            );
                            _showAddToCartSnackBar(
                              context,
                              isDeposit: true,
                              depositPercentageOverride: depositPercentage,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      disabledBackgroundColor: AppColors.textSecondary
                          .withOpacity(0.3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isInCart
                              ? 'مضاف للسلة'
                              : 'معاينة (${(depositPercentage * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isInCart)
                          Text(
                            '${deposit.toStringAsFixed(2)} ر.س',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                // Buy Now Button (100%)
                Expanded(
                  child: ElevatedButton(
                    onPressed: isButtonDisabled
                        ? null
                        : () {
                            context.read<CartCubit>().addItem(
                              product,
                              isDeposit: false,
                            );
                            _showAddToCartSnackBar(
                              context,
                              isDeposit: false,
                              depositPercentageOverride: depositPercentage,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      disabledBackgroundColor: AppColors.textSecondary
                          .withOpacity(0.3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOutOfStock
                              ? 'قيد المعاينة'
                              : (isInCart ? 'مضاف للسلة' : 'شراء الآن'),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isButtonDisabled)
                          Text(
                            'كامل المبلغ',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToCartSnackBar(
    BuildContext context, {
    required bool isDeposit,
    double? depositPercentageOverride,
  }) {
    final depositPercentage =
        depositPercentageOverride ?? widget.product.depositPercentage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isDeposit
              ? 'تم إضافة "معاينة" للسلة (${(depositPercentage * 100).toStringAsFixed(0)}%)'
              : 'تم إضافة الاعلان للسلة (شراء كامل)',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'عرض طلباتي',
          textColor: Colors.white,
          onPressed: () {
            AppRouter.navigateTo(context, Routes.cart);
          },
        ),
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context, bool isDark) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        if (state is ProductDetailsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ProductDetailsError) {
          return Center(child: Text(state.message));
        }
        if (state is ProductDetailsLoaded) {
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
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAddReviewDialog(context),
                      child: const Text('أضف تقييم'),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (reviews.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: Text(
                        'لا توجد تقييمات بعد',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: 16.h),
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12.r),
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
                                    color: isDark
                                        ? AppColors.textLight
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      starIndex < review.rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: Colors.amber,
                                      size: 16.sp,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              review.review.replaceAll(RegExp(r'<[^>]*>'), ''),
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isDark
                                    ? AppColors.textLight.withOpacity(0.8)
                                    : AppColors.textPrimary.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showAddReviewDialog(BuildContext context) {
    final reviewController = TextEditingController();
    int rating = 5;
    // Capture the cubit from the current context which has the provider
    final cubit = context.read<ProductDetailsCubit>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('أضف تقييمك'),
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
                    hint: 'اكتب تعليقك هنا...',
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
                    if (reviewController.text.isNotEmpty) {
                      final authState = context.read<AuthCubit>().state;
                      final reviewerName =
                          (authState is AuthAuthenticated &&
                              authState.user.displayName.isNotEmpty)
                          ? authState.user.displayName
                          : 'زائر';
                      final reviewerEmail = authState is AuthAuthenticated
                          ? authState.user.email
                          : 'guest@example.com';

                      cubit.submitReview(
                        productId: widget.product.id,
                        review: reviewController.text,
                        rating: rating,
                        reviewer: reviewerName,
                        reviewerEmail: reviewerEmail,
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إرسال تقييمك بنجاح')),
                      );
                    }
                  },
                  child: const Text('إرسال'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Bottom Sheet for Request Inspection/Transport
  // ============ Q&A SECTION ============

  Widget _buildQnASection(BuildContext context, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أسئلة وأجوبة',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAskQuestionDialog(context),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('اسأل البائع'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          BlocBuilder<QnACubit, QnAState>(
            builder: (context, state) {
              if (state is QnALoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is QnAError) {
                return Center(
                  child: Text(
                    state.message,
                    style: TextStyle(color: AppColors.error),
                  ),
                );
              } else if (state is QnALoaded) {
                if (state.questions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: Text(
                        'لا توجد أسئلة بعد. كن أول من يسأل!',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.questions.length,
                  separatorBuilder: (_, __) => Divider(height: 24.h),
                  itemBuilder: (context, index) {
                    final qna = state.questions[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                'Q',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                qna.question,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textLight
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              qna.date,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        // Answer
                        Container(
                          margin: EdgeInsets.only(right: 32.w),
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12.r),
                              bottomLeft: Radius.circular(12.r),
                              bottomRight: Radius.circular(12.r),
                            ),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.store,
                                    size: 14.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'رد البائع:',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                qna.isAnswered && qna.answer != null
                                    ? qna.answer!
                                    : 'بانتظار الرد...',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: qna.isAnswered
                                      ? (isDark
                                            ? AppColors.textLight
                                            : AppColors.textPrimary)
                                      : AppColors.textSecondary,
                                  fontStyle: qna.isAnswered
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceProvidersSection(BuildContext context, bool isDark) {
    // 1. Get vendor's subscription tier
    final vendorState = context.read<VendorProfileCubit>().state;
    String vendorTier = widget.product.vendorTier;
    if (vendorState is VendorProfileLoaded &&
        vendorState.store.id == widget.product.vendorId) {
      vendorTier = vendorState.store.vendorTier;
    }

    final tier = vendorTier.toLowerCase();
    final isVendorBronzeOrUnsubscribed =
        tier.isEmpty || tier == 'bronze' || tier == 'unsubscribed';

    // 2. Get viewer info
    final authState = context.read<AuthCubit>().state;
    String? userCity;
    bool isProductOwner = false;

    if (authState is AuthAuthenticated) {
      userCity = authState.user.city;

      // Smart check: If userCity looks like raw coordinates (lat,lng),
      // try using the region as a fallback search term if it's a name.
      final coordinatePattern = RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$');
      if (userCity != null && coordinatePattern.hasMatch(userCity!)) {
        final userRegion = authState.user.region;
        if (userRegion != null && !coordinatePattern.hasMatch(userRegion)) {
          userCity = userRegion;
        }
      }

      isProductOwner = authState.user.id == widget.product.vendorId;
    }

    // 3. Fully hide slider if vendor isn't subscribed AND viewer isn't the owner
    if (isVendorBronzeOrUnsubscribed && !isProductOwner) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (context) =>
          di.sl<ServiceProvidersCubit>()
            ..fetchServiceProviders(userCity: userCity),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: ServiceProvidersSlider(
          userCity: userCity,
          isVendorBronzeOrUnsubscribed: isVendorBronzeOrUnsubscribed,
          isProductOwner: isProductOwner,
        ),
      ),
    );
  }

  void _showAskQuestionDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اطرح سؤالاً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'سيظهر سؤالك للبائع وباقي العملاء بعد الرد عليه.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 10.h),
            CustomTextField(
              controller: controller,
              hint: 'اكتب سؤالك هنا...',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<QnACubit>().askQuestion(
                  widget.product.id,
                  controller.text,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال سؤالك بنجاح')),
                );
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void _showReplaceCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استبدال طلباتي'),
        content: const Text(
          'تحتوي طلباتي على اعلان آخر\nهل تريد استبدال محتويات طلباتي بالاعلان الجديد؟',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<CartCubit>().cancelReplace();
              Navigator.pop(context);
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<CartCubit>().confirmReplace();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تحديث طلباتي بنجاح'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text(
              'استبدال',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestBottomSheet extends StatefulWidget {
  final ProductModel product;
  final bool isTransport;

  const _RequestBottomSheet({required this.product, required this.isTransport});

  @override
  State<_RequestBottomSheet> createState() => _RequestBottomSheetState();
}

class _RequestBottomSheetState extends State<_RequestBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    if (_formKey.currentState!.validate()) {
      // TODO: Submit request to API
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isTransport
                ? 'تم إرسال طلب النقل بنجاح'
                : 'تم إرسال طلب المعاينة بنجاح',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.all(20.w),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Title
            Text(
              widget.isTransport ? 'طلب نقل' : 'طلب معاينة',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              widget.product.name,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24.h),

            // Form Fields
            _buildTextField(
              controller: _nameController,
              label: 'الاسم الكامل',
              icon: Icons.person_outlined,
            ),
            SizedBox(height: 16.h),
            _buildTextField(
              controller: _phoneController,
              label: 'رقم الجوال',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16.h),
            _buildTextField(
              controller: _addressController,
              label: widget.isTransport ? 'عنوان التوصيل' : 'موقع المعاينة',
              icon: Icons.location_on_outlined,
            ),
            SizedBox(height: 16.h),
            _buildTextField(
              controller: _notesController,
              label: 'ملاحظات إضافية',
              icon: Icons.notes_outlined,
              maxLines: 3,
              isRequired: false,
            ),
            SizedBox(height: 24.h),

            // Submit Button
            Container(
              width: double.infinity,
              height: 56.h,
              decoration: BoxDecoration(
                gradient: widget.isTransport
                    ? const LinearGradient(
                        colors: [AppColors.accent, AppColors.accentLight],
                      )
                    : const LinearGradient(
                        colors: [AppColors.info, Color(0xFF60A5FA)],
                      ),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'إرسال الطلب',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'هذا الحقل مطلوب';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: isDark ? AppColors.cardDark : AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
