import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/colors.dart';
import '../../data/models/address_model.dart';
import '../cubit/addresses_cubit.dart';
import 'add_edit_address_screen.dart';

/// Addresses Screen - Manage saved user addresses
class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

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
          'العناوين المحفوظة',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<AddressesCubit>(),
                  child: const AddEditAddressScreen(),
                ),
              ),
            );
            if (result == true && context.mounted) {
              context.read<AddressesCubit>().loadAddresses();
            }
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
          label: Text(
            'إضافة عنوان',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: BlocBuilder<AddressesCubit, AddressesState>(
        builder: (context, state) {
          if (state is AddressesLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is AddressesError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64.sp,
                    color: AppColors.error,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    state.message,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<AddressesCubit>().loadAddresses(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (state is AddressesLoaded) {
            if (state.addresses.isEmpty) {
              return _buildEmptyState(isDark);
            }
            return _buildAddressList(context, state.addresses, isDark);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Padding(
          padding: EdgeInsets.all(40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off_rounded,
                  size: 56.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'لا توجد عناوين محفوظة',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'أضف عنوانك الأول لتسهيل عملية الطلب',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressList(
    BuildContext context,
    List<AddressModel> addresses,
    bool isDark,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(20.w),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        return FadeInUp(
          delay: Duration(milliseconds: 50 * index),
          duration: const Duration(milliseconds: 400),
          child: _buildAddressCard(context, address, isDark),
        );
      },
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    AddressModel address,
    bool isDark,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: address.isDefault ? AppColors.primary : AppColors.border,
          width: address.isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with label and actions
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: address.isDefault
                  ? AppColors.primary.withOpacity(0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: _getLabelColor(address.label).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getLabelIcon(address.label),
                        size: 16.sp,
                        color: _getLabelColor(address.label),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        address.label,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: _getLabelColor(address.label),
                        ),
                      ),
                    ],
                  ),
                ),
                if (address.isDefault) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'افتراضي',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editAddress(context, address);
                        break;
                      case 'default':
                        context.read<AddressesCubit>().setDefault(address.id);
                        break;
                      case 'delete':
                        _confirmDelete(context, address);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ],
                      ),
                    ),
                    if (!address.isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('تعيين كافتراضي'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
          ),

          // Address details
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      address.fullName,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      address.phone,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        address.fullAddress,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editAddress(BuildContext context, AddressModel address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AddressesCubit>(),
          child: AddEditAddressScreen(address: address),
        ),
      ),
    );
    if (result == true && context.mounted) {
      context.read<AddressesCubit>().loadAddresses();
    }
  }

  void _confirmDelete(BuildContext context, AddressModel address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('حذف العنوان'),
        content: Text('هل أنت متأكد من حذف عنوان "${address.label}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<AddressesCubit>().deleteAddress(address.id);
              Navigator.pop(ctx);
            },
            child: Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Color _getLabelColor(String label) {
    switch (label) {
      case 'المنزل':
        return AppColors.primary;
      case 'العمل':
        return AppColors.accent;
      default:
        return AppColors.secondary;
    }
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
