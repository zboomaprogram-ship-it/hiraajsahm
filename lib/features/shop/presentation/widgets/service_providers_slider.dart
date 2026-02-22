import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/colors.dart';
import '../cubit/service_providers_cubit.dart';
import 'service_provider_card.dart';

class ServiceProvidersSlider extends StatelessWidget {
  final String? userCity;

  const ServiceProvidersSlider({super.key, this.userCity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ServiceProvidersCubit, ServiceProvidersState>(
      builder: (context, state) {
        if (state is ServiceProvidersLoading) {
          return SizedBox(
            height: 280.h,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is ServiceProvidersLoaded) {
          final providers = state.filteredProviders;

          if (providers.isEmpty) {
            if (userCity != null && userCity!.isNotEmpty) {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : Colors
                            .grey[50], // Using a light grey for light mode background
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    'لا يوجد معاين او ناقل في منطقتك',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مقدمي الخدمة (الفحص والنقل)',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (userCity != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          userCity!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 350.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    return ServiceProviderCard(provider: providers[index]);
                  },
                ),
              ),
            ],
          );
        }

        if (state is ServiceProvidersError) {
          // Silent fail or minimal error display for non-critical feature
          return const SizedBox.shrink();
        }

        return const SizedBox.shrink();
      },
    );
  }
}
