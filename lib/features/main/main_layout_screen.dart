import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '../../core/theme/colors.dart';
import '../home/views/home_screen.dart';
import '../shop/presentation/screens/shop_screen.dart';
import '../requests/presentation/screens/requests_screen.dart';
import '../requests/presentation/cubit/requests_cubit.dart';
import '../../core/di/injection_container.dart';
import '../profile/presentation/screens/profile_screen.dart';
import '../cart/presentation/cubit/cart_cubit.dart';

/// Main Layout Screen with Bottom Navigation
/// Container for the main app tabs
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavKey = GlobalKey();

  final List<Widget> _screens = [
    const HomeScreen(),
    const ShopScreen(),
    BlocProvider(
      create: (context) => sl<RequestsCubit>(),
      child: const RequestsScreen(),
    ),
    const ProfileScreen(),
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

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<CartCubit, CartState>(
      listener: (context, state) {
        if (state is CartReplaceConfirmation) {
          _showCartReplaceDialog(context, state);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: CurvedNavigationBar(
            key: _bottomNavKey,
            index: _currentIndex,
            height: 70,
            items: [
              Image.asset(
                'assets/icons/home.png',
                width: 26.w,
                height: 26.w,
                color: _currentIndex == 0
                    ? Colors.white
                    : const Color(0xFF1B4965),
              ),
              Image.asset(
                'assets/icons/store.png',
                width: 26.w,
                height: 26.w,
                color: _currentIndex == 1
                    ? Colors.white
                    : const Color(0xFF1B4965),
              ),
              Image.asset(
                'assets/icons/contract.png',
                width: 26.w,
                height: 26.w,
                color: _currentIndex == 2
                    ? Colors.white
                    : const Color(0xFF1B4965),
              ),

              Image.asset(
                'assets/icons/user.png',
                width: 26.w,
                height: 26.w,
                color: _currentIndex == 3
                    ? Colors.white
                    : const Color(0xFF1B4965),
              ),
            ],
            color: isDark ? AppColors.surfaceDark : Colors.white,
            buttonBackgroundColor: const Color(0xFF1B4965),
            backgroundColor: Colors.transparent,
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 300),
            onTap: _onTabTapped,
          ),
        ),
      ),
    );
  }

  void _showCartReplaceDialog(
    BuildContext context,
    CartReplaceConfirmation state,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'استبدال المنتج',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
        ),
        content: Text(
          'سلتك تحتوي على منتج آخر. هل تريد استبداله بـ "${state.pendingProduct.name}"؟',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CartCubit>().cancelReplace();
            },
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CartCubit>().confirmReplace();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم استبدال المنتج في السلة'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: const Text('استبدال'),
          ),
        ],
      ),
    );
  }
}
