import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../cubit/auth_cubit.dart';
import '../../data/models/subscription_pack_model.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../shop/data/models/product_model.dart';

/// Register Screen with Vendor Registration Support
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Vendor Fields
  final _storeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storeUrlController = TextEditingController();
  final _addressController = TextEditingController(); // Added

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isVendor = false;
  bool _acceptTerms = false;
  SubscriptionPackModel? _selectedPack;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _storeNameController.dispose();
    _phoneController.dispose();
    _storeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthRegistrationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم التسجيل بنجاح! يرجى تسجيل الدخول'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            AppRouter.navigateAndReplace(context, Routes.login);
          } else if (state is VendorRegisteredWithPack) {
            // Vendor registered with subscription pack
            final isFreePack = state.packId == 29026 || state.packId == 1;

            if (isFreePack) {
              // Free/Bronze: No checkout needed.
              context.read<AuthCubit>().completeRegistration();
              // Logout to force user to login manually (as requested)
              context.read<AuthCubit>().logout();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('تم التسجيل بنجاح! يرجى تسجيل الدخول'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.login,
                (route) => false,
              );
            } else {
              // Paid: Go to Checkout
              // Create a temporary product to add to cart
              final packProduct = ProductModel(
                id: state.packId,
                name: 'باقة الاشتراك',
                price: '0', // Price will be fetched from product
                regularPrice: '0',
                salePrice: '',
                description: '',
                shortDescription: '',
                images: [],
                categories: [],
                stockStatus: 'instock',
                stockQuantity: 1,
                virtual: true,
              );

              context.read<CartCubit>().clearCart();
              context.read<CartCubit>().addItem(packProduct);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('تم التسجيل بنجاح! أكمل اشتراكك الآن'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );

              // Navigate to Checkout
              // We keep RegisterScreen in stack so if cancelled, they return here (user request)
              Navigator.pushNamed(context, Routes.checkout);
            }
          } else if (state is AuthAuthenticated) {
            // Standard success (no pack selected) - go to main layout
            Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.main,
              (route) => false,
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is VendorSubscriptionLoaded) {
            setState(() {
              // Packs loaded
              if (_selectedPack == null && state.packs.isNotEmpty) {
                // Auto-select Bronze tier (ID 29026) or Free tier
                try {
                  _selectedPack = state.packs.firstWhere(
                    (p) => p.id == 29026 || p.isFree,
                    orElse: () => state.packs.first,
                  );
                } catch (_) {
                  if (state.packs.isNotEmpty) {
                    _selectedPack = state.packs.first;
                  }
                }
              }
            });
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      FadeInDown(
                        duration: const Duration(milliseconds: 500),
                        child: _buildHeader(isDark),
                      ),

                      SizedBox(height: 32.h),

                      // Vendor Toggle
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: _buildVendorToggle(context, isDark),
                      ),

                      SizedBox(height: 24.h),

                      // Basic Fields
                      FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        duration: const Duration(milliseconds: 500),
                        child: _buildBasicFields(isDark),
                      ),

                      // Vendor Fields (Conditional)
                      if (_isVendor) ...[
                        SizedBox(height: 24.h),
                        FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          child: _buildVendorFields(isDark),
                        ),
                        SizedBox(height: 24.h),
                        FadeInUp(
                          delay: const Duration(milliseconds: 100),
                          duration: const Duration(milliseconds: 400),
                          child: _buildSubscriptionPacks(
                            context,
                            state,
                            isDark,
                          ),
                        ),
                      ],

                      SizedBox(height: 24.h),

                      // Terms Checkbox
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        duration: const Duration(milliseconds: 500),
                        child: _buildTermsCheckbox(isDark),
                      ),

                      SizedBox(height: 32.h),

                      // Register Button
                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        duration: const Duration(milliseconds: 500),
                        child: _buildRegisterButton(context, state),
                      ),

                      SizedBox(height: 24.h),

                      // Login Link
                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        duration: const Duration(milliseconds: 500),
                        child: _buildLoginLink(context, isDark),
                      ),

                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إنشاء حساب جديد',
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'انضم إلينا وابدأ رحلتك في عالم التجارة',
          style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildVendorToggle(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: _isVendor
            ? LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.1),
                  AppColors.secondary.withValues(alpha: 0.05),
                ],
              )
            : null,
        color: _isVendor
            ? null
            : (isDark ? AppColors.cardDark : AppColors.card),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: _isVendor ? AppColors.secondary : AppColors.border,
          width: _isVendor ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: _isVendor
                  ? AppColors.secondary.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              _isVendor ? Icons.store_rounded : Icons.person_rounded,
              color: _isVendor ? AppColors.secondary : AppColors.primary,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل تريد التسجيل كبائع؟',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _isVendor ? 'سيتم إنشاء متجرك الخاص' : 'تسجيل كمشتري فقط',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isVendor,
            onChanged: (value) {
              setState(() {
                _isVendor = value;
              });
              if (value) {
                context.read<AuthCubit>().fetchSubscriptionPacks();
              }
            },
            activeThumbColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFields(bool isDark) {
    return Column(
      children: [
        // Name Row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _firstNameController,
                label: 'الاسم الأول',
                hint: 'أدخل اسمك',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'مطلوب';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildTextField(
                controller: _lastNameController,
                label: 'اسم العائلة',
                hint: 'أدخل اسم العائلة',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'مطلوب';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),

        // Email
        _buildTextField(
          controller: _emailController,
          label: 'البريد الإلكتروني',
          hint: 'أدخل بريدك الإلكتروني',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          isDark: isDark,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال البريد الإلكتروني';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'بريد إلكتروني غير صالح';
            }
            return null;
          },
        ),
        SizedBox(height: 20.h),

        // Password
        _buildTextField(
          controller: _passwordController,
          label: 'كلمة المرور',
          hint: 'أدخل كلمة المرور',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          isDark: isDark,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال كلمة المرور';
            }
            if (value.length < 8) {
              return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
            }
            return null;
          },
        ),
        SizedBox(height: 20.h),

        // Confirm Password
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'تأكيد كلمة المرور',
          hint: 'أعد إدخال كلمة المرور',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirmPassword,
          isDark: isDark,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return 'كلمة المرور غير متطابقة';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildVendorFields(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store_rounded,
                color: AppColors.secondary,
                size: 24.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'معلومات المتجر',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Store Name
          _buildTextField(
            controller: _storeNameController,
            label: 'اسم المتجر',
            hint: 'أدخل اسم متجرك',
            icon: Icons.storefront_rounded,
            isDark: isDark,
            validator: (value) {
              if (_isVendor && (value == null || value.isEmpty)) {
                return 'اسم المتجر مطلوب';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),

          // Phone
          _buildTextField(
            controller: _phoneController,
            label: 'رقم الهاتف',
            hint: 'أدخل رقم هاتفك',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            isDark: isDark,
            validator: (value) {
              if (_isVendor && (value == null || value.isEmpty)) {
                return 'رقم الهاتف مطلوب';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),

          // Address (Added)
          _buildTextField(
            controller: _addressController,
            label: 'العنوان',
            hint: 'أدخل عنوان المتجر',
            icon: Icons.location_on_outlined,
            isDark: isDark,
            maxLines: 2,
            validator: (value) {
              if (_isVendor && (value == null || value.isEmpty)) {
                return 'العنوان مطلوب';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),

          // Store URL (Optional)
          _buildTextField(
            controller: _storeUrlController,
            label: 'رابط المتجر (اختياري)',
            hint: 'مثال: my-store',
            icon: Icons.link_rounded,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPacks(
    BuildContext context,
    AuthState state,
    bool isDark,
  ) {
    List<SubscriptionPackModel> packs = [];

    if (state is VendorSubscriptionLoaded) {
      packs = state.packs.where((p) => p.id != 29318).toList(); // Hide Zabayeh
    }

    if (state is VendorSubscriptionLoading) {
      return Container(
        padding: EdgeInsets.all(40.w),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    if (packs.isEmpty) {
      // Show demo packs if none fetched
      packs = [
        const SubscriptionPackModel(
          id: 1,
          title: 'الباقة المجانية',
          description: 'ابدأ مجاناً مع ميزات محدودة',
          price: 0,
          priceFormatted: 'مجاني',
          productLimit: 5,
          billingCycle: 'month',
          billingCycleCount: 1,
          trialDays: 0,
          features: ['5 منتجات', 'دعم أساسي'],
          isFree: true,
        ),
        const SubscriptionPackModel(
          id: 2,
          title: 'الباقة الفضية',
          description: 'مثالية للمتاجر المتوسطة',
          price: 49.99,
          priceFormatted: '\$49.99',
          productLimit: 50,
          billingCycle: 'month',
          billingCycleCount: 1,
          trialDays: 7,
          features: ['50 منتج', 'دعم متقدم', '7 أيام تجربة'],
        ),
        const SubscriptionPackModel(
          id: 3,
          title: 'الباقة الذهبية',
          description: 'للمتاجر الاحترافية',
          price: 99.99,
          priceFormatted: '\$99.99',
          productLimit: -1,
          billingCycle: 'month',
          billingCycleCount: 1,
          trialDays: 14,
          features: ['منتجات غير محدودة', 'دعم VIP', '14 يوم تجربة'],
          isPopular: true,
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر باقة الاشتراك',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 16.h),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: packs.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final pack = packs[index];
            final isSelected = _selectedPack?.id == pack.id;

            return _buildPackCard(pack, isSelected, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildPackCard(
    SubscriptionPackModel pack,
    bool isSelected,
    bool isDark,
  ) {
    Color packColor = AppColors.freePack;
    if (pack.title.toLowerCase().contains('gold') ||
        pack.title.contains('ذهب')) {
      packColor = AppColors.goldPack;
    } else if (pack.title.toLowerCase().contains('silver') ||
        pack.title.contains('فض')) {
      packColor = AppColors.silverPack;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPack = pack;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.border,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Pack Icon
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: packColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    pack.isFree
                        ? Icons.card_giftcard_rounded
                        : Icons.workspace_premium_rounded,
                    color: packColor,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),

                // Pack Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pack.title,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (pack.isPopular) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'الأكثر شعبية',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textOnSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        pack.billingDisplay,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection Indicator
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.secondary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                      : null,
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Features
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: pack.features.map((feature) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    feature,
                    style: TextStyle(fontSize: 11.sp, color: AppColors.primary),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    int maxLines = 1, // Added
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines, // Added
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22.sp),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 24.w,
          height: 24.h,
          child: Checkbox(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() {
                _acceptTerms = value ?? false;
              });
            },
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
              children: [
                const TextSpan(text: 'بالتسجيل، أنت توافق على '),
                TextSpan(
                  text: 'شروط الخدمة',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' و '),
                TextSpan(
                  text: 'سياسة الخصوصية',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(BuildContext context, AuthState state) {
    final isLoading = state is AuthLoading;

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        gradient: _isVendor
            ? AppColors.secondaryGradient
            : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: (_isVendor ? AppColors.secondary : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading || !_acceptTerms
            ? null
            : () {
                if (_formKey.currentState!.validate()) {
                  if (_isVendor) {
                    context.read<AuthCubit>().registerVendor(
                      email: _emailController.text.trim(),
                      password: _passwordController.text,
                      firstName: _firstNameController.text.trim(),
                      lastName: _lastNameController.text.trim(),
                      storeName: _storeNameController.text.trim(),
                      phone: _phoneController.text.trim(),
                      storeUrl: _storeUrlController.text.trim().isNotEmpty
                          ? _storeUrlController.text.trim()
                          : null,
                      address: _addressController.text.trim(),
                      subscriptionPackId: _selectedPack?.id,
                    );
                  } else {
                    context.read<AuthCubit>().registerCustomer(
                      email: _emailController.text.trim(),
                      password: _passwordController.text,
                      firstName: _firstNameController.text.trim(),
                      lastName: _lastNameController.text.trim(),
                    );
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.h,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _isVendor ? 'إنشاء متجري' : 'إنشاء حساب',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildLoginLink(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'لديك حساب بالفعل؟',
          style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
        ),
        TextButton(
          onPressed: () {
            AppRouter.navigateAndReplace(context, Routes.login);
          },
          child: Text(
            'سجل دخولك',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
