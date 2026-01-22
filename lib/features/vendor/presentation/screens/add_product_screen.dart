import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../cubit/add_product_cubit.dart';
import '../cubit/vendor_dashboard_cubit.dart';
import '../../../shop/data/models/category_model.dart';

/// Add Product Screen - For Vendors
import '../../../shop/data/models/product_model.dart';

class AddProductScreen extends StatefulWidget {
  final ProductModel? productToEdit;
  const AddProductScreen({super.key, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regularPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController(); // Added

  final List<File> _selectedImages = [];
  File? _selectedVideo;
  int? _selectedCategoryId;
  String _selectedCategoryName = 'اختر القسم';

  List<CategoryModel> _categories = []; // Dynamic categories

  late AddProductCubit _addProductCubit;

  @override
  void initState() {
    super.initState();
    _addProductCubit = di.sl<AddProductCubit>();
    _addProductCubit.loadCategories();

    // Reset cubit to initial state
    _addProductCubit.reset();

    // Pre-fill if editing
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
      _regularPriceController.text =
          p.regularPrice; // Use regularPrice directly
      _salePriceController.text = p.salePrice;
      _stockController.text = '1'; // Default, as stock might not be in model
      // Note: ProductModel might need update to include stock_quantity if we want to pre-fill it accurately
      _descriptionController.text = p.description;

      // Set category if possible
      if (p.categories.isNotEmpty) {
        // Logic to find category ID? ProductModel usually has category IDs or names.
        // Assuming first category.
        // We'll leave it for user to select if we can't map it easily from basic ProductModel
      }

      _locationController.text = p.productLocation ?? ''; // Added
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regularPriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _locationController.dispose(); // Added
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                widget.productToEdit != null
                    ? 'تعديل المنتج'
                    : 'إضافة منتج جديد',
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('المعرض (صور متعددة)'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == ImageSource.gallery) {
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles.map((e) => File(e.path)));
        });
      }
    } else {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('تسجيل فيديو'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    final pickedFile = await picker.pickVideo(
      source: result,
      maxDuration: const Duration(minutes: 2),
    );

    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
      });
    }
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
    });
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        constraints: BoxConstraints(maxHeight: 0.5.sh),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر القسم',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            if (_categories.isEmpty)
              Padding(
                padding: EdgeInsets.all(20.h),
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return ListTile(
                      title: Text(category.name),
                      trailing: _selectedCategoryId == category.id
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category.id;
                          _selectedCategoryName = category.name;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _submitProduct() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار القسم'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (widget.productToEdit == null && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة صورة واحدة على الأقل'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (widget.productToEdit != null) {
      _addProductCubit.updateProduct(
        productId: widget.productToEdit!.id,
        name: _nameController.text.trim(),
        price: _regularPriceController.text.trim(),
        salePrice: _salePriceController.text.trim(),
        categoryId: _selectedCategoryId!,
        stockQuantity: int.tryParse(_stockController.text.trim()) ?? 1,
        description: _descriptionController.text.trim(),
        newImages: _selectedImages, // Only passing new images
        address: _locationController.text.trim(), // Changed
      );
    } else {
      _addProductCubit.uploadProduct(
        name: _nameController.text.trim(),
        price: _regularPriceController.text.trim(),
        salePrice: _salePriceController.text.trim(),
        categoryId: _selectedCategoryId!,
        stockQuantity: int.tryParse(_stockController.text.trim()) ?? 1,
        description: _descriptionController.text.trim(),
        images: _selectedImages,
        address: _locationController.text.trim(), // Changed
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _addProductCubit,
      child: BlocListener<AddProductCubit, AddProductState>(
        listener: (context, state) {
          if (state is AddProductCategoriesLoaded) {
            setState(() {
              _categories = state.categories;
            });
          } else if (state is AddProductSuccess) {
            // Refresh dashboard items count
            context.read<VendorDashboardCubit>().loadDashboard();
            _showSuccessDialog(context);
          } else if (state is AddProductError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
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
              'إضافة منتج',
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
                  // Image Picker
                  FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: _buildImagePicker(isDark),
                  ),
                  SizedBox(height: 16.h),

                  // Video Picker
                  FadeInUp(
                    delay: const Duration(milliseconds: 50),
                    duration: const Duration(milliseconds: 300),
                    child: _buildVideoPicker(isDark),
                  ),
                  SizedBox(height: 24.h),

                  // Product Name
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    duration: const Duration(milliseconds: 300),
                    child: _buildTextField(
                      controller: _nameController,
                      label: 'اسم المنتج',
                      hint: 'مثال: ناقة عمر 3 سنوات',
                      icon: Icons.inventory_2_outlined,
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Prices (Regular & Sale)
                  FadeInUp(
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 300),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _regularPriceController,
                            label: 'السعر',
                            hint: '15000',
                            icon: Icons.attach_money_rounded,
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: _buildTextField(
                            controller: _salePriceController,
                            label: 'سعر التخفيض',
                            hint: 'اختياري',
                            icon: Icons.percent_rounded,
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                            isRequired: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Category Selector
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 300),
                    child: _buildCategorySelector(isDark),
                  ),
                  SizedBox(height: 16.h),

                  // Stock Quantity
                  FadeInUp(
                    delay: const Duration(milliseconds: 250),
                    duration: const Duration(milliseconds: 300),
                    child: _buildTextField(
                      controller: _stockController,
                      label: 'الكمية المتاحة',
                      hint: 'مثال: 1',
                      icon: Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Description
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    duration: const Duration(milliseconds: 300),
                    child: _buildTextField(
                      controller: _descriptionController,
                      label: 'الوصف',
                      hint: 'اكتب وصفاً تفصيلياً للمنتج...',
                      icon: Icons.description_outlined,
                      maxLines: 4,
                      isDark: isDark,
                      isRequired: false,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Product Location (New Field)
                  FadeInUp(
                    delay: const Duration(milliseconds: 325),
                    duration: const Duration(milliseconds: 300),
                    child: _buildTextField(
                      controller: _locationController,
                      label: 'عنوان المنتج (مطلوب)',
                      hint: 'مثال: الرياض، حي الملقا',
                      icon: Icons.location_on_outlined,
                      isDark: isDark,
                      isRequired: true,
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Submit Button
                  FadeInUp(
                    delay: const Duration(milliseconds: 350),
                    duration: const Duration(milliseconds: 300),
                    child: BlocBuilder<AddProductCubit, AddProductState>(
                      builder: (context, state) {
                        final isLoading = state is AddProductUploading;

                        return Container(
                          width: double.infinity,
                          height: 56.h,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submitProduct,
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
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_rounded, size: 24.sp),
                                      SizedBox(width: 12.w),
                                      Text(
                                        'نشر المنتج',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 120.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length + 1,
              separatorBuilder: (context, index) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                if (index == _selectedImages.length) {
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100.w,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Icon(
                        Icons.add_a_photo_rounded,
                        color: AppColors.primary,
                        size: 32.sp,
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    Container(
                      width: 120.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppColors.border),
                        image: DecorationImage(
                          image: FileImage(_selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4.h,
                      right: 4.w,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 200.h,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.border,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 64.sp,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'اضغط لإضافة صور للمنتج',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'يمكنك اختيار أكثر من صورة',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'فيديو المنتج (اختياري)',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        if (_selectedVideo != null)
          Container(
            height: 120.h,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        size: 40.sp,
                        color: AppColors.success,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'فيديو محدد',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _selectedVideo!.path.split('/').last,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _removeVideo,
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              height: 100.h,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_call_outlined,
                      size: 32.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'إضافة فيديو (اختياري)',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'هذا الحقل مطلوب';
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: isDark ? AppColors.cardDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    return GestureDetector(
      onTap: _showCategoryPicker,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.category_outlined, color: AppColors.primary),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                _selectedCategoryName,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: _selectedCategoryId != null
                      ? (isDark ? AppColors.textLight : AppColors.textPrimary)
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
              'تم نشر المنتج بنجاح!',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            Text(
              'سيظهر منتجك في المتجر بعد المراجعة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: const Text('حسناً'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
