import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_button.dart';

enum RequestRole { inspector, transporter }

class RequestFormWidget extends StatefulWidget {
  final RequestRole role;
  final int formId;
  final Function(
    Map<String, dynamic> data,
    File? vehicleImage,
    File? licenseImage,
  )
  onSubmit;
  final String? initialPhone;
  final bool isLoading;

  const RequestFormWidget({
    super.key,
    required this.role,
    required this.formId,
    required this.onSubmit,
    this.initialPhone,
    this.isLoading = false,
  });

  @override
  State<RequestFormWidget> createState() => _RequestFormWidgetState();
}

class _RequestFormWidgetState extends State<RequestFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _plateNumberController = TextEditingController();
  late final TextEditingController _mobileController;

  String _transportType = 'internal'; // 'internal' or 'external'
  File? _vehicleImage;
  File? _licenseImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _plateNumberController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isVehicle) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isVehicle) {
          _vehicleImage = File(image.path);
        } else {
          _licenseImage = File(image.path);
        }
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_vehicleImage == null || _licenseImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إرفاق جميع الصور المطلوبة'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      String transportValue = _transportType == 'internal' ? 'داخلي' : 'خارجي';
      final data = {
        'input_text': _nameController.text.trim(),
        'input_text_1': _cityController.text.trim(),
        'input_text_2': _regionController.text.trim(),
        'input_text_3': _plateNumberController.text.trim(),
        'phone': _mobileController.text.trim(),
        'input_radio': transportValue,
      };

      widget.onSubmit(data, _vehicleImage, _licenseImage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInspector = widget.role == RequestRole.inspector;
    final nameLabel = isInspector ? 'اسم المعاين' : 'اسم الناقل';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _nameController,
            label: nameLabel,
            hint: 'أدخل الاسم كاملاً',
            icon: Icons.person_outline,
            isDark: isDark,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _cityController,
                  label: 'المدينة',
                  hint: 'أدخل المدينة',
                  icon: Icons.location_city_outlined,
                  isDark: isDark,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildTextField(
                  controller: _regionController,
                  label: 'المنطقة',
                  hint: 'أدخل المنطقة',
                  icon: Icons.map_outlined,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildTextField(
            controller: _plateNumberController,
            label: 'رقم اللوحة',
            hint: 'أدخل رقم اللوحة (أرقام وحروف)',
            icon: Icons.directions_car_outlined,
            isDark: isDark,
          ),
          SizedBox(height: 16.h),
          _buildTextField(
            controller: _mobileController,
            label: 'رقم الجوال',
            hint: '05xxxxxxxx',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            isDark: isDark,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'مطلوب';
              if (v.trim().length != 10) return 'يجب أن يكون 10 أرقام';
              return null;
            },
          ),
          SizedBox(height: 16.h),
          Text(
            'نوع الانتقال',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textLight : AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              Radio<String>(
                value: 'internal',
                groupValue: _transportType,
                onChanged: (v) => setState(() => _transportType = v!),
                activeColor: AppColors.primary,
              ),
              Text(
                'داخلي',
                style: TextStyle(
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 20.w),
              Radio<String>(
                value: 'external',
                groupValue: _transportType,
                onChanged: (v) => setState(() => _transportType = v!),
                activeColor: AppColors.primary,
              ),
              Text(
                'خارجي',
                style: TextStyle(
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildImagePickerBox(
                  label: 'صورة المركبة',
                  file: _vehicleImage,
                  onTap: () => _pickImage(true),
                  isDark: isDark,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildImagePickerBox(
                  label: 'رخصة القيادة',
                  file: _licenseImage,
                  onTap: () => _pickImage(false),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),
          CustomButton(
            text: 'إرسال طلب التسجيل',
            onPressed: _submit,
            isLoading: widget.isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator:
          validator ?? (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
      style: TextStyle(
        color: isDark ? AppColors.textLight : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? AppColors.textSecondary : AppColors.textPrimary,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark
              ? AppColors.textSecondary.withOpacity(0.5)
              : Colors.grey,
        ),
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
      ),
    );
  }

  Widget _buildImagePickerBox({
    required String label,
    required File? file,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.file(file, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.primary,
                    size: 32.sp,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
