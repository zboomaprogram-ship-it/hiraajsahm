import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../core/theme/colors.dart';
import '../cubit/auth_cubit.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/location_picker_screen.dart';

class EditUserProfileScreen extends StatefulWidget {
  const EditUserProfileScreen({super.key});

  @override
  State<EditUserProfileScreen> createState() => _EditUserProfileScreenState();
}

class _EditUserProfileScreenState extends State<EditUserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _regionController;
  late TextEditingController _locationController;
  // late TextEditingController _passwordController; // Separated flow usually

  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthCubit>().state;
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _regionController = TextEditingController();
    _locationController = TextEditingController();

    if (state is AuthAuthenticated) {
      final user = state.user;
      final names = user.displayName.split(' ');
      
      _firstNameController.text = user.firstName?.isNotEmpty == true 
          ? user.firstName! 
          : (names.isNotEmpty ? names.first : '');
          
      _lastNameController.text = user.lastName?.isNotEmpty == true 
          ? user.lastName! 
          : (names.length > 1 ? names.sublist(1).join(' ') : '');
          
      _emailController.text = user.email;
      // Phone might not be directly in UserModel root depending heavily on API.
      // But we can check if we have it or user inputs it.
      // Assuming phone/city/etc are not always fully populated in basic user model unless fetched detail.
      // But we will populate what we have.
      _cityController.text = user.city ?? '';
      _regionController.text = user.region ?? '';
      _locationController.text = user.address ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().updateUserMetadata(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        city: _cityController.text,
        region: _regionController.text,
        location: _locationController.text,
        imagePath: _selectedImage?.path,
      );
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        if (result['city'] != null) {
          _cityController.text = result['city'];
        }
        if (result['region'] != null) {
          _regionController.text = result['region'];
        }
        if (result['lat'] != null && result['lng'] != null) {
          _locationController.text = '${result['lat']},${result['lng']}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تعديل الملف الشخصي',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                backgroundColor: state.message!.contains('فشل')
                    ? AppColors.error
                    : AppColors.success,
              ),
            );
            if (!state.message!.contains('فشل')) {
              // Keep strictly on screen or pop? Usually pop if Save is clicked.
              // But let's stay to show success or pop.
              // Navigator.pop(context);
            }
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is! AuthAuthenticated) {
            return const Center(child: Text('Please login first'));
          }

          final user = state.user;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Image Picker
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100.w,
                          height: 100.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _selectedImage != null
                                ? Image.file(
                                    File(_selectedImage!.path),
                                    fit: BoxFit.cover,
                                  )
                                : (user.avatarUrl != null &&
                                          user.avatarUrl!.isNotEmpty
                                      ? Image.network(
                                          user.avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: Colors.grey[300],
                                                child: Icon(
                                                  Icons.person,
                                                  size: 50.sp,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.person,
                                            size: 50.sp,
                                          ),
                                        )),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Fields
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: 'الاسم الأول',
                          icon: Icons.person,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          isDark: isDark,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: 'اسم العائلة',
                          icon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  _buildTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    icon: Icons.email,
                    readOnly: true,
                    isDark: isDark,
                  ),
                  SizedBox(height: 16.h),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    icon: Icons.phone,
                    inputType: TextInputType.phone,
                    isDark: isDark,
                  ),
                  SizedBox(height: 16.h),

                  _buildTextField(
                    controller: _locationController,
                    label: 'العنوان',
                    icon: Icons.location_on,
                    isDark: isDark,
                    onTap: _pickLocation, // Enable tap to open map
                    readOnly:
                        true, // Prevent manual typing if desired, or keep editable
                    suffixIcon: Icons.map, // Visual cue
                  ),
                  SizedBox(height: 16.h),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickLocation,
                          child: AbsorbPointer(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'المدينة',
                              icon: Icons.location_city,
                              isDark: isDark,
                              readOnly: true,
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
                              icon: Icons.map,
                              isDark: isDark,
                              readOnly: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 32.h),

                  CustomButton(text: 'حفظ التغييرات', onPressed: _submit),
                ],
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
    bool readOnly = false,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    IconData? suffixIcon,
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
          readOnly: readOnly,
          validator: validator,
          onTap: onTap,
          style: TextStyle(
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textSecondary),
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: AppColors.primary)
                : null,
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
