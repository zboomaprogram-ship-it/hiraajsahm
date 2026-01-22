import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../cubit/requests_cubit.dart';
import '../../data/models/request_model.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _livestockTypeController = TextEditingController();
  final _ownerPriceController = TextEditingController();
  final _pricePerKgController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  // Track selected request type
  String _selectedRequestType = 'inspection';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Check permission after build
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _checkPermission();
    // });
  }

  void _checkPermission() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      if (!authState.user.isSilverOrGold) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('عفواً'),
            content: const Text(
              'هذه الميزة متاحة فقط للباقة الفضية والذهبية. يرجى ترقية باقتك للاستفادة من هذه الخدمة.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close screen
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedRequestType = _tabController.index == 0
            ? 'inspection'
            : 'delivery';
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _livestockTypeController.dispose();
    _ownerPriceController.dispose();
    _pricePerKgController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final request = RequestModel(
        livestockType: _livestockTypeController.text,
        ownerPrice: _ownerPriceController.text,
        pricePerKg: _selectedRequestType == 'delivery'
            ? _pricePerKgController.text
            : null,
        address: _addressController.text,
        phone: _phoneController.text,
        type: _selectedRequestType,
      );

      context.read<RequestsCubit>().submitRequest(request);
    }
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
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        elevation: 0,
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
                      Navigator.pushNamed(context, '/subscription_screen');
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

    return BlocConsumer<RequestsCubit, RequestsState>(
      listener: (context, state) {
        if (state is RequestsSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال الطلب بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          // Clear form fields
          _livestockTypeController.clear();
          _ownerPriceController.clear();
          _pricePerKgController.clear();
          _addressController.clear();
          _phoneController.clear();
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
          padding: EdgeInsets.all(16.w),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Tabs
                Container(
                  height: 50.h,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.grey[100],
                    borderRadius: BorderRadius.circular(25.r),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary,
                          width: 2.w,
                        ),
                      ),
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: TextStyle(
                      fontSize: 14.sp,
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

                // Form Fields
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _livestockTypeController,
                        hint: 'نوع الذبيحة',
                        prefixIcon: const Icon(Icons.pets),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 16.h),

                      CustomTextField(
                        controller: _ownerPriceController,
                        hint: 'السعر المطلوب من المالك',
                        prefixIcon: const Icon(Icons.attach_money),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 16.h),

                      if (_selectedRequestType == 'delivery') ...[
                        CustomTextField(
                          controller: _pricePerKgController,
                          hint: 'السعر للكيلو',
                          prefixIcon: const Icon(Icons.scale),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        SizedBox(height: 16.h),
                      ],

                      CustomTextField(
                        controller: _addressController,
                        hint: 'العنوان',
                        prefixIcon: const Icon(Icons.location_on),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 16.h),

                      CustomTextField(
                        controller: _phoneController,
                        hint: 'رقم الهاتف',
                        prefixIcon: const Icon(Icons.phone),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 32.h),

                      CustomButton(
                        text: _selectedRequestType == 'inspection'
                            ? 'التقدم للمعاينة'
                            : 'طلب النقل',
                        onPressed: _submit,
                        isLoading: state is RequestsLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
