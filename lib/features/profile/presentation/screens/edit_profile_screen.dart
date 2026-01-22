import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/injection_container.dart';
import '../cubit/profile_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();

    // Pre-fill data
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      _firstNameController.text = authState.user.firstName ?? '';
      _lastNameController.text = authState.user.lastName ?? '';
      _emailController.text = authState.user.email;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => sl<ProfileCubit>(),
      child: BlocConsumer<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state is ProfileUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
            // Refresh Auth User Data
            context.read<AuthCubit>().checkAuthStatus();
            Navigator.pop(context);
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is ProfileUpdating;

          return Scaffold(
            appBar: AppBar(
              title: const Text('تعديل البيانات الشخصية'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.background,
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'الاسم الأول',
                      icon: Icons.person_outline,
                      isDark: isDark,
                      validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'الاسم الأخير',
                      icon: Icons.person_outline,
                      isDark: isDark,
                      validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      isDark: isDark,
                      inputType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'مطلوب';
                        if (!val.contains('@')) return 'بريد غير صالح';
                        return null;
                      },
                    ),
                    SizedBox(height: 32.h),
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  context
                                      .read<ProfileCubit>()
                                      .updateUserProfile(
                                        firstName: _firstNameController.text,
                                        lastName: _lastNameController.text,
                                        email: _emailController.text,
                                      );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'حفظ التغييرات',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          validator: validator,
          style: TextStyle(
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textSecondary),
            filled: true,
            fillColor: isDark ? AppColors.cardDark : AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
