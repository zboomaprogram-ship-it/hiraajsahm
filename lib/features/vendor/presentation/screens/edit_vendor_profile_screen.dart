import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/injection_container.dart';
import '../cubit/vendor_profile_cubit.dart';

class EditVendorProfileScreen extends StatefulWidget {
  final int vendorId;

  const EditVendorProfileScreen({super.key, required this.vendorId});

  @override
  State<EditVendorProfileScreen> createState() =>
      _EditVendorProfileScreenState();
}

class _EditVendorProfileScreenState extends State<EditVendorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) =>
          sl<VendorProfileCubit>()..loadVendorProfile(widget.vendorId),
      child: BlocConsumer<VendorProfileCubit, VendorProfileState>(
        listener: (context, state) {
          if (state is VendorProfileUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pop(context); // Go back after success
          } else if (state is VendorProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is VendorProfileLoaded) {
            // Populate fields if empty
            if (_nameController.text.isEmpty) {
              _nameController.text = state.store.storeName;
              _phoneController.text = state.store.phone;
              _addressController.text = state.store.address?.street1 ?? '';
            }
          }
        },
        builder: (context, state) {
          // Show loading for initial fetch OR update
          final isLoading =
              state is VendorProfileLoading || state is VendorProfileUpdating;

          return Scaffold(
            appBar: AppBar(
              title: const Text('تعديل الملف الشخصي'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.background,
            body:
                isLoading &&
                    state is! VendorProfileUpdating &&
                    state is! VendorProfileLoaded
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16.w),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'اسم المتجر',
                            icon: Icons.store_rounded,
                            isDark: isDark,
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'رقم الهاتف',
                            icon: Icons.phone_rounded,
                            isDark: isDark,
                            inputType: TextInputType.phone,
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            controller: _addressController,
                            label: 'العنوان',
                            icon: Icons.location_on_rounded,
                            isDark: isDark,
                            maxLines: 2,
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                          SizedBox(height: 32.h),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 50.h,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      if (_formKey.currentState!.validate()) {
                                        context
                                            .read<VendorProfileCubit>()
                                            .updateVendorProfile(
                                              vendorId: widget.vendorId,
                                              storeName: _nameController.text,
                                              phone: _phoneController.text,
                                              address: _addressController.text,
                                            );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: state is VendorProfileUpdating
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
    int maxLines = 1,
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
          maxLines: maxLines,
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
