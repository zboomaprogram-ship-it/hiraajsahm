import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/storage_service.dart';
import '../cubit/checkout_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Checkout Screen - Shipping & Payment
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedPaymentMethod = 'cod';

  final List<_PaymentMethod> _paymentMethods = [
    _PaymentMethod(
      id: 'cod',
      title: 'الدفع عند الاستلام',
      subtitle: 'ادفع نقداً عند استلام الطلب',
      icon: Icons.money_rounded,
    ),
    _PaymentMethod(
      id: 'bacs',
      title: 'تحويل بنكي',
      subtitle: 'تحويل إلى حسابنا البنكي',
      icon: Icons.account_balance_rounded,
    ),
    _PaymentMethod(
      id: 'online',
      title: 'دفع إلكتروني',
      subtitle: 'بطاقة ائتمانية / مدى / Apple Pay',
      icon: Icons.credit_card_rounded,
    ),
  ];

  late CheckoutCubit _checkoutCubit;

  @override
  void initState() {
    super.initState();
    _checkoutCubit = CheckoutCubit(
      cartCubit: context.read<CartCubit>(),
      authCubit: context.read<AuthCubit>(), // Pass AuthCubit
      storageService: sl<StorageService>(),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _placeOrder() {
    // Check if Subscription in Cart
    final cartState = context.read<CartCubit>().state;
    bool isSubscription = false;
    String calculatedPaymentType = 'full';

    if (cartState is CartLoaded) {
      isSubscription = cartState.items.any((item) {
        final id = item.product.id;
        final name = item.product.name;
        return [29026, 29030, 29318].contains(id) || name.contains('باقة');
      });

      // Determine Payment Type from Cart Items (Inspection vs Full)
      if (cartState.items.any((item) => item.isDeposit)) {
        calculatedPaymentType = 'deposit_10';
      }
    }

    if (isSubscription || _formKey.currentState!.validate()) {
      _checkoutCubit.placeOrder(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        paymentMethod: _selectedPaymentMethod,
        paymentType: calculatedPaymentType,
        notes: _notesController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _checkoutCubit,
      child: MultiBlocListener(
        listeners: [
          BlocListener<CheckoutCubit, CheckoutState>(
            listener: (context, state) {
              if (state is CheckoutSuccess) {
                _showSuccessDialog(context, state.orderId);
              } else if (state is CheckoutFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          BlocListener<CartCubit, CartState>(
            listener: (context, state) {
              if (state is CartLoaded) {
                final isVirtual =
                    state.items.isNotEmpty &&
                    state.items.every((i) => i.product.virtual);
                // If virtual product, COD is not allowed, default to online
                // Also force full payment (no deposits)
                if (isVirtual) {
                  if (_selectedPaymentMethod == 'cod') {
                    setState(() => _selectedPaymentMethod = 'online');
                  }
                }
              }
            },
          ),
        ],
        child: PopScope(
          canPop: true,
          onPopInvoked: (didPop) async {
            if (didPop) {
              final storage = sl<StorageService>();
              if (storage.isRegistrationPending()) {
                if (context.mounted) {
                  context.read<AuthCubit>().cancelRegistration();
                }
              }
            }
          },
          child: Scaffold(
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.background,
            appBar: AppBar(
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              title: Text(
                'إتمام الطلب',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              centerTitle: true,
            ),
            body: BlocBuilder<CartCubit, CartState>(
              builder: (context, cartState) {
                bool isVirtual = false;
                if (cartState is CartLoaded) {
                  isVirtual =
                      cartState.items.isNotEmpty &&
                      cartState.items.every((i) => i.product.virtual);
                }

                return Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Summary
                        FadeInUp(
                          duration: const Duration(milliseconds: 300),
                          child: _buildOrderSummary(isDark),
                        ),
                        SizedBox(height: 24.h),

                        // Customer Info (Shipping or Personal)
                        FadeInUp(
                          delay: const Duration(milliseconds: 100),
                          duration: const Duration(milliseconds: 300),
                          child: _buildSectionTitle(
                            isVirtual ? 'معلومات المشتري' : 'معلومات الشحن',
                            isVirtual
                                ? Icons.person_rounded
                                : Icons.local_shipping_rounded,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        FadeInUp(
                          delay: const Duration(milliseconds: 150),
                          duration: const Duration(milliseconds: 300),
                          child: _buildShippingForm(
                            isDark,
                            isVirtual: isVirtual,
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Payment Method
                        FadeInUp(
                          delay: const Duration(milliseconds: 200),
                          duration: const Duration(milliseconds: 300),
                          child: _buildSectionTitle(
                            'طريقة الدفع',
                            Icons.payment_rounded,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        FadeInUp(
                          delay: const Duration(milliseconds: 250),
                          duration: const Duration(milliseconds: 300),
                          child: _buildPaymentMethods(
                            isDark,
                            isVirtual: isVirtual,
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Notes
                        FadeInUp(
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(milliseconds: 300),
                          child: _buildNotesField(isDark),
                        ),
                        SizedBox(height: 32.h),

                        // Place Order Button
                        FadeInUp(
                          delay: const Duration(milliseconds: 350),
                          duration: const Duration(milliseconds: 300),
                          child: BlocBuilder<CheckoutCubit, CheckoutState>(
                            builder: (context, state) {
                              final isLoading = state is CheckoutProcessing;

                              return Container(
                                width: double.infinity,
                                height: 56.h,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _placeOrder,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                  ),
                                  child: isLoading
                                      ? SizedBox(
                                          width: 24.w,
                                          height: 24.w,
                                          child:
                                              const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                        )
                                      : Text(
                                          'تأكيد الطلب',
                                          style: TextStyle(
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 32.h),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(bool isDark) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        if (state is CartLoaded) {
          return Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'عدد المنتجات',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${state.totalItems} منتج',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المجموع الفرعي',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${state.subtotal.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                // SizedBox(height: 12.h),
                // // Saei Fee (Commission) - 10% of subtotal
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     Row(
                //       children: [
                //         Text(
                //           'سعي',
                //           style: TextStyle(
                //             fontSize: 14.sp,
                //             color: AppColors.textSecondary,
                //           ),
                //         ),
                //         SizedBox(width: 4.w),
                //         Icon(
                //           Icons.info_outline,
                //           size: 14.sp,
                //           color: AppColors.textSecondary,
                //         ),
                //       ],
                //     ),
                //     Text(
                //       '${(state.subtotal * 0.10).toStringAsFixed(2)} ر.س',
                //       style: TextStyle(
                //         fontSize: 14.sp,
                //         fontWeight: FontWeight.w600,
                //         color: AppColors.info,
                //       ),
                //     ),
                //   ],
                // ),
                Divider(height: 24.h, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.items.any((i) => i.isDeposit)
                          ? 'المبلغ المستحق الآن (10%)'
                          : 'الإجمالي',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${state.total.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: state.items.any((i) => i.isDeposit)
                            ? AppColors.warning
                            : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                if (state.items.any((i) => i.isDeposit)) ...[
                  SizedBox(height: 8.h),
                  Text(
                    'المتبقي عند الاستلام: ${(state.total * 9).toStringAsFixed(2)} ر.س',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24.sp),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildShippingForm(bool isDark, {bool isVirtual = false}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _firstNameController,
                label: 'الاسم الأول',
                isDark: isDark,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildTextField(
                controller: _lastNameController,
                label: 'اسم العائلة',
                isDark: isDark,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        _buildTextField(
          controller: _phoneController,
          label: 'رقم الجوال',
          keyboardType: TextInputType.phone,
          isDark: isDark,
        ),
        SizedBox(height: 16.h),
        _buildTextField(
          controller: _emailController,
          label: 'البريد الإلكتروني',
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
        ),
        if (!isVirtual) ...[
          SizedBox(height: 16.h),
          _buildTextField(
            controller: _cityController,
            label: 'المدينة',
            isDark: isDark,
          ),
          SizedBox(height: 16.h),
          _buildTextField(
            controller: _addressController,
            label: 'العنوان بالتفصيل',
            maxLines: 2,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isDark ? AppColors.cardDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildPaymentMethods(bool isDark, {bool isVirtual = false}) {
    // Check if any cart item is a deposit option
    final cartState = context.read<CartCubit>().state;
    bool isDeposit = false;
    if (cartState is CartLoaded) {
      isDeposit = cartState.items.any((item) => item.isDeposit);
    }

    final methods = (isVirtual || isDeposit)
        ? _paymentMethods.where((m) => m.id != 'cod').toList()
        : _paymentMethods;

    return Column(
      children: methods.map((method) {
        final isSelected = _selectedPaymentMethod == method.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = method.id;
            });
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    method.icon,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        method.subtitle,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotesField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ملاحظات الطلب (اختياري)',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'أي ملاحظات خاصة بالطلب...',
            filled: true,
            fillColor: isDark ? AppColors.cardDark : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.border),
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
        ),
      ],
    );
  }

  void _showSuccessDialog(BuildContext context, int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 50.sp,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'تم الطلب بنجاح!',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            Text(
              'رقم الطلب: #$orderId',
              style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 8.h),
            Text(
              'سيتم التواصل معك قريباً',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Mark registration as complete
                  await context.read<AuthCubit>().completeRegistration();

                  Navigator.pop(context);
                  // Refresh user data to get updated subscription info
                  await context.read<AuthCubit>().checkAuthStatus();
                  if (context.mounted) {
                    AppRouter.navigateAndRemoveUntil(context, Routes.main);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'العودة للرئيسية',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
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

class _PaymentMethod {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  _PaymentMethod({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
