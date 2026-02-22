import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/injection_container.dart';
import '../cubit/vendor_profile_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import 'location_picker_screen.dart';
import '../../../../core/widgets/mini_map_preview.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../data/models/store_model.dart';

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
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _biographyController;
  late TextEditingController _locationController;
  late TextEditingController _fbController;
  late TextEditingController _igController;
  late TextEditingController _twitterController;
  late TextEditingController _ytController;

  XFile? _selectedImage;
  XFile? _selectedBanner;
  final ImagePicker _picker = ImagePicker();
  int? _newGravatarId;
  int? _newBannerId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _biographyController = TextEditingController();
    _locationController = TextEditingController();
    _fbController = TextEditingController();
    _igController = TextEditingController();
    _twitterController = TextEditingController();
    _ytController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _biographyController.dispose();
    _locationController.dispose();
    _fbController.dispose();
    _igController.dispose();
    _twitterController.dispose();
    _ytController.dispose();
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

  Future<void> _pickBanner() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _selectedBanner = image;
      });
    }
  }

  Widget _buildDefaultAvatar(StoreModel store) {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Text(
          store.displayName.isNotEmpty
              ? store.displayName[0].toUpperCase()
              : 'S',
          style: TextStyle(
            fontSize: 40.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  void _submitProfile(BuildContext context) async {
    int? finalGravatarId = _newGravatarId;
    int? finalBannerId = _newBannerId;
    final cubit = context.read<VendorProfileCubit>();

    // Upload Gravatar if new
    if (_selectedImage != null) {
      final mediaId = await cubit.uploadMedia(_selectedImage!.path);
      if (mediaId != null) finalGravatarId = mediaId;
    }

    // Upload Banner if new
    if (_selectedBanner != null) {
      final mediaId = await cubit.uploadMedia(_selectedBanner!.path);
      if (mediaId != null) finalBannerId = mediaId;
    }

    cubit.updateVendorProfile(
      vendorId: widget.vendorId,
      storeName: _nameController.text,
      phone: _phoneController.text,
      street: _streetController.text,
      city: _cityController.text,
      state: _stateController.text,
      biography: _biographyController.text,
      location: _locationController.text,
      facebook: _fbController.text,
      instagram: _igController.text,
      twitter: _twitterController.text,
      youtube: _ytController.text,
      gravatarId: finalGravatarId,
      bannerId: finalBannerId,
    );
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
              _streetController.text = state.store.address?.street1 ?? '';
              _cityController.text = state.store.address?.city ?? '';
              _stateController.text = state.store.address?.state ?? '';
              _biographyController.text = state.store.biography ?? '';
              _locationController.text = state.store.location ?? '';
              _fbController.text = state.store.social?.facebook ?? '';
              _igController.text = state.store.social?.instagram ?? '';
              _twitterController.text = state.store.social?.twitter ?? '';
              _ytController.text = state.store.social?.youtube ?? '';
              _newGravatarId = state.store.gravatarId;
              _newBannerId = state.store.bannerId;

              // Address Fallback: If city/state are empty in store, try getting them from UserModel
              if (_cityController.text.isEmpty ||
                  _stateController.text.isEmpty) {
                final authState = context.read<AuthCubit>().state;
                if (authState is AuthAuthenticated) {
                  if (_cityController.text.isEmpty) {
                    _cityController.text = authState.user.city ?? '';
                  }
                  if (_stateController.text.isEmpty) {
                    _stateController.text = authState.user.region ?? '';
                  }
                }
              }
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner Section
                          GestureDetector(
                            onTap: _pickBanner,
                            child: Container(
                              height: 150.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.cardDark
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12.r),
                                image: _selectedBanner != null
                                    ? DecorationImage(
                                        image: FileImage(
                                          File(_selectedBanner!.path),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : (state is VendorProfileLoaded &&
                                              state.store.banner != null &&
                                              state.store.banner!.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                state.store.banner!,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                              ),
                              child:
                                  _selectedBanner == null &&
                                      (state is! VendorProfileLoaded ||
                                          state.store.banner == null ||
                                          state.store.banner!.isEmpty)
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_rounded,
                                          size: 40.sp,
                                          color: AppColors.textSecondary,
                                        ),
                                        SizedBox(height: 8.h),
                                        Text(
                                          'إضافة غلاف المتجر',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Align(
                                      alignment: Alignment.bottomRight,
                                      child: Container(
                                        margin: EdgeInsets.all(8.w),
                                        padding: EdgeInsets.all(8.w),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16.sp,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 24.h),

                          // Profile Image Section
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
                                        : (state is VendorProfileLoaded &&
                                                  state.store.gravatar !=
                                                      null &&
                                                  state
                                                      .store
                                                      .gravatar!
                                                      .isNotEmpty
                                              ? Image.network(
                                                  state.store.gravatar!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _buildDefaultAvatar(
                                                        state.store,
                                                      ),
                                                )
                                              : (state is VendorProfileLoaded
                                                    ? _buildDefaultAvatar(
                                                        state.store,
                                                      )
                                                    : Container(
                                                        color: AppColors.primary
                                                            .withOpacity(0.1),
                                                      ))),
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

                          _buildTextField(
                            controller: _nameController,
                            label: 'اسم السوق',
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
                            controller: _streetController,
                            label: 'الشارع / العنوان',
                            icon: Icons.location_on_rounded,
                            isDark: isDark,
                            maxLines: 2,
                            validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _cityController,
                                  label: 'المدينة',
                                  icon: Icons.location_city_rounded,
                                  isDark: isDark,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: _buildTextField(
                                  controller: _stateController,
                                  label: 'المنطقة',
                                  icon: Icons.map_outlined,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            controller: _biographyController,
                            label: 'وصف السوق (النبذة)',
                            icon: Icons.description_rounded,
                            isDark: isDark,
                            maxLines: 4,
                          ),
                          SizedBox(height: 16.h),
                          MiniMapPreview(
                            latLong: _locationController.text,
                            isDark: isDark,
                            label: 'الموقع الجغرافي',
                            onTap: () async {
                              final result = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LocationPickerScreen(
                                    initialLocation: _locationController.text,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  _locationController.text = result;
                                });
                              }
                            },
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'وسائل التواصل الاجتماعي',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          _buildTextField(
                            controller: _fbController,
                            label: 'رابط فيسبوك',
                            icon: Icons.facebook_rounded,
                            isDark: isDark,
                            hint: 'https://facebook.com/yourstore',
                          ),
                          SizedBox(height: 12.h),
                          _buildTextField(
                            controller: _igController,
                            label: 'رابط إنستغرام',
                            icon: Icons.camera_alt_rounded,
                            isDark: isDark,
                            hint: 'https://instagram.com/yourstore',
                          ),
                          SizedBox(height: 12.h),
                          _buildTextField(
                            controller: _twitterController,
                            label: 'رابط إكس (تويتر سابقاً)',
                            icon: Icons.alternate_email_rounded,
                            isDark: isDark,
                            hint: 'https://x.com/yourstore',
                          ),
                          SizedBox(height: 12.h),
                          _buildTextField(
                            controller: _ytController,
                            label: 'رابط يوتيوب',
                            icon: Icons.play_circle_filled_rounded,
                            isDark: isDark,
                            hint: 'https://youtube.com/@yourstore',
                          ),
                          SizedBox(height: 32.h),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 60.h,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      if (_formKey.currentState!.validate()) {
                                        _submitProfile(context);
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
    String? hint,
    bool readOnly = false,
    VoidCallback? onTap,
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
          readOnly: readOnly,
          onTap: onTap,
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
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
