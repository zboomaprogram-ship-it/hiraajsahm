import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/theme/colors.dart';
import '../../core/routes/routes.dart';
import '../../core/routes/app_router.dart';
import '../../core/services/storage_service.dart';
import '../../core/di/injection_container.dart';

/// Hiraaj Sahm - Onboarding Screen
/// Introduces the livestock marketplace features
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.store_mall_directory_rounded,
      title: 'سوق المواشي الأول',
      subtitle: 'أكبر سوق إلكتروني لبيع وشراء المواشي في المملكة',
      description: 'تصفح الآلاف من الإبل والأغنام والطيور من بائعين موثوقين',
      color: AppColors.primary,
      secondaryColor: AppColors.secondary,
    ),
    // OnboardingPage(
    //   icon: Icons.gavel_rounded,
    //   title: 'مزادات حية وموثقة',
    //   subtitle: 'شارك في مزادات مباشرة على أفضل المواشي',
    //   description: 'نظام مزادات آمن وشفاف مع ضمان حقوق البائع والمشتري',
    //   color: const Color(0xFFD4AF37), // Gold
    //   secondaryColor: AppColors.primary,
    // ),
    OnboardingPage(
      icon: Icons.local_shipping_rounded,
      title: 'خدمات نقل ومعاينة',
      subtitle: 'نوفر لك خدمات النقل والمعاينة قبل الشراء',
      description: 'فريق متخصص لمعاينة المواشي وتوصيلها لباب منزلك',
      color: AppColors.accent,
      secondaryColor: AppColors.secondary,
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _completeOnboarding() async {
    final storageService = sl<StorageService>();
    await storageService.setOnboardingComplete();

    if (!mounted) return;
    AppRouter.navigateAndRemoveUntil(context, Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Row(
                    children: [
                      Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 28.w,
                            height: 28.w,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        'هراج سهم',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  // Skip
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'تخطي',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),

            // Bottom Section
            Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  // Page Indicator
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.border,
                      dotHeight: 8.h,
                      dotWidth: 8.w,
                      expansionFactor: 4,
                      spacing: 8.w,
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Buttons
                  Row(
                    children: [
                      // Back Button (if not first page)
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(0, 56.h),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            child: Text(
                              'السابق',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),

                      if (_currentPage > 0) SizedBox(width: 16.w),

                      // Next/Start Button
                      Expanded(
                        flex: _currentPage == 0 ? 1 : 1,
                        child: Container(
                          height: 56.h,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (_currentPage < _pages.length - 1) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                _completeOnboarding();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: Size(double.infinity, 56.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage < _pages.length - 1
                                      ? 'التالي'
                                      : 'ابدأ الآن',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(
                                  _currentPage < _pages.length - 1
                                      ? Icons.arrow_forward_ios_rounded
                                      : Icons.rocket_launch_rounded,
                                  color: Colors.white,
                                  size: 20.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    return FadeIn(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration Container
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: Container(
                width: 280.w,
                height: 280.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      page.color.withValues(alpha: 0.1),
                      page.secondaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative rings
                    Container(
                      width: 240.w,
                      height: 240.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: page.color.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 200.w,
                      height: 200.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: page.color.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    // Main Icon
                    Container(
                      width: 140.w,
                      height: 140.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [page.color, page.secondaryColor],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: page.color.withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Icon(page.icon, size: 70.sp, color: Colors.white),
                    ),
                    // Floating elements
                    Positioned(
                      top: 40.h,
                      right: 30.w,
                      child: _buildFloatingElement(page.secondaryColor),
                    ),
                    Positioned(
                      bottom: 50.h,
                      left: 20.w,
                      child: _buildFloatingElement(page.color),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 48.h),

            // Title
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              child: Text(
                page.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // Subtitle
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 600),
              child: Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: page.color,
                  height: 1.4,
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // Description
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 600),
              child: Text(
                page.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingElement(Color color) {
    return Container(
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Onboarding Page Data Model
class OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final Color secondaryColor;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.secondaryColor,
  });
}
