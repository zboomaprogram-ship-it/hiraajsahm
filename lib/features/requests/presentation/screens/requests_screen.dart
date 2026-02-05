import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/location_picker_screen.dart'; // Added
import '../cubit/requests_cubit.dart';
import '../../data/models/request_model.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  // Controllers
  final _phoneController = TextEditingController();

  // New Controllers
  final _carrierNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _plateNumberController = TextEditingController();

  // New State variables
  String _transferType = 'internal'; // 'internal' or 'external'
  File? _vehicleImage;
  final ImagePicker _picker = ImagePicker();

  // Track selected request type
  String _selectedRequestType = 'inspection';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Check permission after build
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _checkPermission();
    // });
  }

  void _checkPermission() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      if (!authState.user.isSilverOrGold) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('عفواً'),
            content: const Text(
              'هذه الميزة متاحة فقط للباقة الفضية والذهبية. يرجى ترقية باقتك للاستفادة من هذه الخدمة.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close screen
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedRequestType = _tabController.index == 0
            ? 'inspection'
            : 'delivery';
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _phoneController.dispose();
    _carrierNameController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _vehicleImage = File(image.path);
      });
    }
  }

  // New: Pick Location
  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && result is Map) {
      setState(() {
        _cityController.text =
            result['city'] ?? result['address'].split(',').last;
        _regionController.text = result['region'] ?? '';
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final request = RequestModel(
        livestockType: 'N/A', // Removed from UI
        ownerPrice: '0', // Removed from UI
        pricePerKg: null, // Removed from UI
        address:
            '${_cityController.text} - ${_regionController.text}', // Map City/Region to Address
        phone: _phoneController.text,
        type: _selectedRequestType,
        carrierName: _carrierNameController.text,
        city: _cityController.text,
        region: _regionController.text,
        plateNumber: _plateNumberController.text,
        transferType: _transferType,
        // vehicleImage will be set by Cubit after upload
      );

      context.read<RequestsCubit>().submitRequest(request, _vehicleImage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthCubit>().state;

    // Check if locked
    bool isLocked = true;
    if (authState is AuthAuthenticated) {
      isLocked = !authState.user.isSilverOrGold;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('المعاينة والتوصيل'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Main Content (Blurred/Disabled if locked)
          IgnorePointer(
            ignoring: isLocked, // Disable interaction if locked
            child: Opacity(
              opacity: isLocked ? 0.3 : 1.0, // Face content if locked
              child: _buildRequestForm(context),
            ),
          ),

          // Locked Overlay
          if (isLocked)
            Container(
              color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 50.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'الميزة مقفلة',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w),
                    child: Text(
                      'خدمات المعاينة والنقل متاحة فقط لأصحاب العضوية الفضية والذهبية.\nقم بترقية باقتك الآن لتتمكن من إرسال طلبات المعاينة والنقل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),
                  CustomButton(
                    text: 'ترقية الباقة الآن',
                    width: 200.w,
                    onPressed: () {
                      Navigator.pushNamed(context, '/subscription_screen');
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<RequestsCubit, RequestsState>(
      listener: (context, state) {
        if (state is RequestsSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال الطلب بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          // Clear form fields
          _phoneController.clear();
          _carrierNameController.clear();
          _cityController.clear();
          _regionController.clear();
          _plateNumberController.clear();
          setState(() {
            _vehicleImage = null;
            _transferType = 'internal';
          });
        } else if (state is RequestsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 16.w,
            bottom: 100.h, // Added padding to avoid navbar overlay
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Tabs
                Container(
                  height: 50.h,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.grey[100],
                    borderRadius: BorderRadius.circular(25.r),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary,
                          width: 2.w,
                        ),
                      ),
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                    tabs: const [
                      Tab(text: 'المعاينة'),
                      Tab(text: 'النقل'),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Form Fields
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _carrierNameController,
                        hint: 'اسم الناقل / المعاين',
                        prefixIcon: const Icon(Icons.person),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 16.h),

                      // 2. City & Region (Map Picker)
                      GestureDetector(
                        onTap: _pickLocation,
                        child: AbsorbPointer(
                          child: Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _cityController,
                                  hint: 'المدينة (اضغط للتحديد)',
                                  prefixIcon: const Icon(Icons.location_city),
                                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: CustomTextField(
                                  controller: _regionController,
                                  hint: 'المنطقة',
                                  prefixIcon: const Icon(Icons.map),
                                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      CustomTextField(
                        controller: _plateNumberController,
                        hint: 'رقم اللوحة',
                        prefixIcon: const Icon(Icons.directions_car),
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 16.h),

                      CustomTextField(
                        controller: _phoneController,
                        hint: 'رقم الهاتف',
                        prefixIcon: const Icon(Icons.phone),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 16.h),

                      // Transfer Type Dropdown
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.inputBackDark
                              : AppColors.inputBack,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isDark
                                ? Colors.transparent
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _transferType,
                            isExpanded: true,
                            dropdownColor: isDark
                                ? AppColors.cardDark
                                : Colors.white,
                            items: const [
                              DropdownMenuItem(
                                value: 'internal',
                                child: Text('نقل داخلي'),
                              ),
                              DropdownMenuItem(
                                value: 'external',
                                child: Text('نقل خارجي'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _transferType = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Vehicle Image Picker
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 150.h,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.inputBackDark
                                : AppColors.inputBack,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isDark
                                  ? Colors.transparent
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: _vehicleImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Image.file(
                                    _vehicleImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'صورة المركبة',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 32.h),

                      CustomButton(
                        text: _selectedRequestType == 'inspection'
                            ? 'التقدم للمعاينة'
                            : 'طلب النقل',
                        onPressed: _submit,
                        isLoading: state is RequestsLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
