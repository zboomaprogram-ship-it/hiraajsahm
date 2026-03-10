import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/location_picker_screen.dart';
import '../../../../core/widgets/mini_map_preview.dart';
import '../../data/models/address_model.dart';
import '../cubit/addresses_cubit.dart';

/// Add/Edit Address Screen
class AddEditAddressScreen extends StatefulWidget {
  final AddressModel? address;

  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();

  String _selectedLabel = 'المنزل';
  bool _isDefault = false;
  String? _selectedLatLong;

  bool get isEditing => widget.address != null;

  final List<String> _labels = ['المنزل', 'العمل', 'أخرى'];

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final addr = widget.address!;
      _fullNameController.text = addr.fullName;
      _phoneController.text = addr.phone;
      _cityController.text = addr.city;
      _streetController.text = addr.street;
      _selectedLabel = addr.label;
      _isDefault = addr.isDefault;
      _selectedLatLong = addr.latLng;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && result is Map) {
      setState(() {
        _cityController.text =
            result['city'] ?? result['address']?.split(',').last ?? '';
        _streetController.text = result['address'] ?? '';
        if (result['lat'] != null && result['lng'] != null) {
          _selectedLatLong = "${result['lat']},${result['lng']}";
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final address = AddressModel(
      id: isEditing
          ? widget.address!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      label: _selectedLabel,
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      city: _cityController.text.trim(),
      street: _streetController.text.trim(),
      latLng: _selectedLatLong,
      isDefault: _isDefault,
    );

    if (isEditing) {
      context.read<AddressesCubit>().updateAddress(address);
    } else {
      context.read<AddressesCubit>().addAddress(address);
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
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
          isEditing ? 'تعديل العنوان' : 'إضافة عنوان جديد',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label selector
              Text(
                'نوع العنوان',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                children: _labels.map((label) {
                  final isSelected = _selectedLabel == label;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedLabel = label),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : isDark
                              ? AppColors.cardDark
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getLabelIcon(label),
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              size: 24.sp,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? AppColors.textLight
                                          : AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 24.h),

              // Full name
              _buildTextField(
                controller: _fullNameController,
                label: 'الاسم الكامل',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
              ),
              SizedBox(height: 16.h),

              // Phone
              _buildTextField(
                controller: _phoneController,
                label: 'رقم الجوال',
                icon: Icons.phone_outlined,
                isDark: isDark,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16.h),

              // City
              _buildTextField(
                controller: _cityController,
                label: 'المدينة',
                icon: Icons.location_city_rounded,
                isDark: isDark,
              ),
              SizedBox(height: 16.h),

              // Street / Address
              GestureDetector(
                onTap: _pickLocation,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _streetController,
                    label: 'العنوان التفصيلي (اضغط لتحديد الموقع)',
                    icon: Icons.map_outlined,
                    isDark: isDark,
                    maxLines: 2,
                  ),
                ),
              ),

              if (_selectedLatLong != null) ...[
                SizedBox(height: 12.h),
                MiniMapPreview(
                  latLong: _selectedLatLong,
                  isDark: isDark,
                  height: 120,
                  onTap: _pickLocation,
                ),
              ],

              SizedBox(height: 20.h),

              // Default toggle
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_outline_rounded,
                      color: AppColors.secondary,
                      size: 24.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'العنوان الافتراضي',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'سيتم استخدامه تلقائياً عند الطلب',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32.h),

              // Save button
              Container(
                width: double.infinity,
                height: 56.h,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'حفظ التعديلات' : 'حفظ العنوان',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: isDark ? AppColors.cardDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.border),
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

  IconData _getLabelIcon(String label) {
    switch (label) {
      case 'المنزل':
        return Icons.home_rounded;
      case 'العمل':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }
}
