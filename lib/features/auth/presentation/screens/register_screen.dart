import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../cubit/auth_cubit.dart';
import '../../data/models/subscription_pack_model.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../shop/data/models/product_model.dart';
import '../../../../core/widgets/location_picker_screen.dart';

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

  // Registration Fields
  final _storeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storeUrlController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _locationController = TextEditingController();

  String? _lat;
  String? _lng;

  bool _isLoading = false;
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
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _locationController.dispose();
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
              const SnackBar(
                content: Text(
                  'تم إنشاء الحساب بنجاح! يمكنك الآن تسجيل الدخول.',
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            AppRouter.navigateAndReplace(context, Routes.login);
          } else if (state is VendorRegisteredWithPack) {
            final packProduct = ProductModel(
              id: state.packId,
              name: 'باقة الاشتراك',
              price: '0',
              regularPrice: '0',
              salePrice: '',
              description: '',
              shortDescription: '',
              images: [],
              categories: [],
            );
            context.read<CartCubit>().addItem(packProduct, quantity: 1);
            Navigator.pushReplacementNamed(context, Routes.checkout);
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(isDark),
                    // SizedBox(height: 32.h),
                    // _buildVendorToggle(context, isDark),
                    SizedBox(height: 24.h),
                    if (_isVendor) ...[
                      _buildVendorFields(isDark),
                      SizedBox(height: 24.h),
                    ],
                    _buildBasicFields(isDark),
                    SizedBox(height: 24.h),
                    _buildLocationFields(isDark),
                    SizedBox(height: 24.h),
                    _buildTermsCheckbox(isDark),
                    SizedBox(height: 32.h),
                    _buildRegisterButton(context, state),
                    SizedBox(height: 24.h),
                    _buildLoginLink(context, isDark),
                  ],
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

  // Widget _buildVendorToggle(BuildContext context, bool isDark) {
  //   return Container(
  //     padding: EdgeInsets.all(16.w),
  //     decoration: BoxDecoration(
  //       color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
  //       borderRadius: BorderRadius.circular(16.r),
  //       border: Border.all(
  //         color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
  //       ),
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           padding: EdgeInsets.all(10.w),
  //           decoration: BoxDecoration(
  //             color: _isVendor
  //                 ? AppColors.secondary.withOpacity(0.1)
  //                 : AppColors.primary.withOpacity(0.1),
  //             borderRadius: BorderRadius.circular(12.r),
  //           ),
  //           child: Icon(
  //             _isVendor ? Icons.store_rounded : Icons.person_rounded,
  //             color: _isVendor ? AppColors.secondary : AppColors.primary,
  //             size: 24.sp,
  //           ),
  //         ),
  //         SizedBox(width: 12.w),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 'التسجيل كبائع',
  //                 style: TextStyle(
  //                   fontSize: 16.sp,
  //                   fontWeight: FontWeight.bold,
  //                   color: isDark ? AppColors.textLight : AppColors.textPrimary,
  //                 ),
  //               ),
  //               Text(
  //                 'هل ترغب في بيع اعلاناتك معنا؟',
  //                 style: TextStyle(
  //                   fontSize: 12.sp,
  //                   color: AppColors.textSecondary,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         Switch(
  //           value: _isVendor,
  //           onChanged: (value) {
  //             setState(() {
  //               _isVendor = value;
  //             });
  //             if (value) {
  //               context.read<AuthCubit>().fetchSubscriptionPacks();
  //             }
  //           },
  //           activeColor: AppColors.secondary,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildVendorFields(bool isDark) {
    return Column(
      children: [
        _buildTextField(
          controller: _storeNameController,
          label: 'اسم السوق',
          hint: 'أدخل اسم سوقك',
          icon: Icons.storefront_outlined,
          isDark: isDark,
          validator: (value) {
            if (_isVendor && (value == null || value.isEmpty)) {
              return 'الرجاء إدخال اسم السوق';
            }
            return null;
          },
        ),
        SizedBox(height: 20.h),
        _buildTextField(
          controller: _phoneController,
          label: 'رقم الهاتف',
          hint: 'أدخل رقم هاتفك',
          icon: Icons.phone_outlined,
          isDark: isDark,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (_isVendor && (value == null || value.isEmpty)) {
              return 'الرجاء إدخال رقم الهاتف';
            }
            return null;
          },
        ),
      ],
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
    bool readOnly = false, // Added
    VoidCallback? onTap, // Added
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
          readOnly: readOnly, // Added
          onTap: onTap, // Added
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

  Widget _buildLocationFields(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickLocation,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'المدينة',
                    hint: 'أدخل المدينة',
                    icon: Icons.location_city_rounded,
                    isDark: isDark,
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'مطلوب';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: GestureDetector(
                onTap: _pickLocation,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _regionController,
                    label: 'المنطقة',
                    hint: 'أدخل المنطقة',
                    icon: Icons.map_outlined,
                    isDark: isDark,
                    readOnly: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        _buildTextField(
          controller: _locationController,
          label: 'الموقع على الخريطة',
          hint: 'اضغط لتحديد الموقع',
          icon: Icons.location_on_rounded,
          isDark: isDark,
          readOnly: true,
          onTap: _pickLocation,
          validator: (value) {
            if (_lat == null || _lng == null) {
              return 'الرجاء تحديد الموقع على الخريطة';
            }
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && result is Map) {
      setState(() {
        _lat = result['lat'].toString();
        _lng = result['lng'].toString();
        _locationController.text = ' (${_lat}, ${_lng})';

        if (result['city'] != null) {
          _cityController.text = result['city'];
        }
        if (result['region'] != null) {
          _regionController.text = result['region'];
        }
      });
    }
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
                      city: _cityController.text.trim(),
                      region: _regionController.text.trim(),
                      location: _lat != null && _lng != null
                          ? '$_lat,$_lng'
                          : null,
                      subscriptionPackId: _selectedPack?.id,
                    );
                  } else {
                    context.read<AuthCubit>().registerCustomer(
                      email: _emailController.text.trim(),
                      password: _passwordController.text,
                      firstName: _firstNameController.text.trim(),
                      lastName: _lastNameController.text.trim(),
                      city: _cityController.text.trim(),
                      region: _regionController.text.trim(),
                      location: _lat != null && _lng != null
                          ? '$_lat,$_lng'
                          : null,
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
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isVendor ? 'إنشاء سوقي' : 'إنشاء حساب',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
