import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/colors.dart';
import '../../core/routes/routes.dart';
import '../../core/routes/app_router.dart';
import '../../core/services/storage_service.dart';
import '../../core/di/injection_container.dart';
import '../auth/presentation/cubit/auth_cubit.dart';

/// Hiraaj Sahm - Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _animationsComplete = false;
  bool _authCheckComplete = false;
  AuthState? _authState;

  @override
  void initState() {
    super.initState();

    // 1. Set Status Bar to Dark (since background is white)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white bg
        statusBarBrightness: Brightness.light,
      ),
    );

    // 2. Start Auth Check
    context.read<AuthCubit>().checkAuthStatus();

    // 3. Simple Timer for Splash Duration
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _animationsComplete = true;
        });
        _tryNavigate();
      }
    });
  }

  void _onAuthStateChanged(AuthState state) {
    _authState = state;
    if (state is AuthAuthenticated ||
        state is AuthUnauthenticated ||
        state is AuthFailure) {
      _authCheckComplete = true;
      _tryNavigate();
    }
  }

  void _tryNavigate() {
    if (!_animationsComplete || !_authCheckComplete || !mounted) return;

    final storageService = sl<StorageService>();
    final isOnboardingComplete = storageService.isOnboardingComplete();

    if (_authState is AuthAuthenticated) {
      AppRouter.navigateAndRemoveUntil(context, Routes.main);
    } else if (!isOnboardingComplete) {
      AppRouter.navigateAndRemoveUntil(context, Routes.onboarding);
    } else {
      AppRouter.navigateAndRemoveUntil(context, Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) => _onAuthStateChanged(state),
      child: Scaffold(
        backgroundColor: Colors.white, // White Background
        body: Stack(
          children: [
            // 1. CENTER CONTENT (Logo + Text)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  FadeInDown(
                    duration: const Duration(milliseconds: 1000),
                    child: Image.asset(
                      'assets/images/logo2.png',
                      width: 160.w,
                      height: 160.w,
                      fit: BoxFit.contain,
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Title: حراج سهم
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    duration: const Duration(milliseconds: 800),
                    child: Text(
                      'حراج سهم',
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0D47A1), // Dark Blue
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Subtitle: سوق المواشي الأول
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    duration: const Duration(milliseconds: 800),
                    child: Text(
                      'سوق المواشي الأول',
                      style: TextStyle(
                        fontSize: 18.sp,
                        color: const Color(0xFF42A5F5), // Light Blue
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. BOTTOM IMAGE (Grass)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FadeInUp(
                duration: const Duration(milliseconds: 1200),
                child: Image.asset(
                  'assets/images/background.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth, // Stretches to fill width
                ),
              ),
            ),

            // 3. LOADING INDICATOR (Optional, small at bottom)
            Positioned(
              bottom: 30.h,
              left: 0,
              right: 0,
              child: FadeIn(
                delay: const Duration(milliseconds: 1500),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
