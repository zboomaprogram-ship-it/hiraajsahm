import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hiraajsahm/features/shop/data/models/service_provider_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/colors.dart';

class ServiceProviderCard extends StatelessWidget {
  final ServiceProviderModel provider;

  const ServiceProviderCard({super.key, required this.provider});

  Future<void> _makeCall() async {
    final Uri url = Uri.parse('tel:${provider.phone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/${provider.phone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 260.w,
      margin: EdgeInsets.only(left: 16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                child: provider.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: provider.imageUrl,
                        height: 140.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              // Role Badge
              Positioned(
                top: 10.h,
                right: 10.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    provider.role,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.name,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                _buildInfoRow(
                  Icons.directions_car_outlined,
                  provider.vehicleDetails,
                  isDark,
                ),
                if (provider.pricePerKilo.isNotEmpty)
                  _buildInfoRow(
                    Icons.payments_outlined,
                    '${provider.pricePerKilo} ر.س / كم',
                    isDark,
                  ),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  provider.city,
                  isDark,
                ),

                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.phone_outlined,
                        label: 'اتصال',
                        color: AppColors.primary,
                        onPressed: _makeCall,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.chat_outlined,
                        label: 'واتساب',
                        color: const Color(0xFF25D366),
                        onPressed: _openWhatsApp,
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

  Widget _buildPlaceholder() {
    return Container(
      height: 140.h,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.person_pin_circle_outlined,
        size: 50.sp,
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: AppColors.primary),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark
                    ? AppColors.textLightSecondary
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14.sp, color: Colors.white),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        elevation: 0,
      ),
    );
  }
}
