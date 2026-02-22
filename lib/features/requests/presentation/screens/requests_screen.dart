import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/routes/routes.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../cubit/requests_cubit.dart';
import '../widgets/request_form_widget.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/config/app_config.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Track selected role
  RequestRole _selectedRole = RequestRole.inspector;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedRole = _tabController.index == 0
            ? RequestRole.inspector
            : RequestRole.transporter;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthCubit>().state;

    // Check if locked
    bool isLocked = true;
    if (authState is AuthAuthenticated) {
      isLocked = !authState.user.isSilverOrGold;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('المعاينة والتوصيل'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Main Content (Blurred/Disabled if locked)
          IgnorePointer(
            ignoring: isLocked, // Disable interaction if locked
            child: Opacity(
              opacity: isLocked ? 0.3 : 1.0, // Face content if locked
              child: _buildRequestForm(context),
            ),
          ),

          // Locked Overlay
          if (isLocked)
            Container(
              color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 50.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'الميزة مقفلة',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Text(
                      'خدمات المعاينة والنقل متاحة فقط لأصحاب العضوية الفضية والذهبية.\nقم بترقية باقتك الآن لتتمكن من إرسال طلبات المعاينة والنقل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),
                  CustomButton(
                    text: 'ترقية الباقة الآن',
                    width: 200.w,
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.vendorSubscription);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthCubit>().state;

    return BlocConsumer<RequestsCubit, RequestsState>(
      listener: (context, state) {
        if (state is RequestsSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال الطلب بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );

          // Update user metadata with the information from the form
          // Note: data is passed in onSubmit, but we don't have it here directly.
          // However, we can use the latest values if we store them or just rely on the form submission.
          // Since the form submission was successful, we can assume the phone is valid.
          // For now, we'll rely on the persistence triggered in onSubmit or similar.
        } else if (state is RequestsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 16.w,
            bottom: 100.h,
          ),
          child: Column(
            children: [
              // Tabs
              Container(
                height: 50.h,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 3.w,
                    ),
                    insets: EdgeInsets.symmetric(horizontal: 16.w),
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                  tabs: const [
                    Tab(text: 'المعاينة'),
                    Tab(text: 'النقل'),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              // Dynamic Form
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: RequestFormWidget(
                  key: ValueKey(_selectedRole),
                  role: _selectedRole,
                  formId: _selectedRole == RequestRole.inspector
                      ? AppConfig.fluentFormInspectorId
                      : AppConfig.fluentFormTransporterId,
                  initialPhone: authState is AuthAuthenticated
                      ? authState.user.phone
                      : null,
                  isLoading: state is RequestsLoading,
                  onSubmit: (data, vehicle, license) {
                    // Update user profile metadata before submitting the form
                    final phone = data['phone'] as String?;
                    if (phone != null && phone.isNotEmpty) {
                      context.read<AuthCubit>().updateUserMetadata(
                        phone: phone,
                        city: data['input_text_1'] as String?,
                        region: data['input_text_2'] as String?,
                      );
                    }

                    context.read<RequestsCubit>().submitRegistration(
                      formId: _selectedRole == RequestRole.inspector
                          ? AppConfig.fluentFormInspectorId
                          : AppConfig.fluentFormTransporterId,
                      data: data,
                      vehicleImage: vehicle,
                      licenseImage: license,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
