import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:intl/intl.dart'; // Disabled: date formatting not used
import '../../../../core/routes/routes.dart';
import '../../../../core/routes/app_router.dart';
import '../../../auth/data/models/user_model.dart';

/// Subscription Card - Displays user's current plan and expiry
class SubscriptionCard extends StatelessWidget {
  final UserModel user;

  const SubscriptionCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // 1. Determine Color & Title based on Tier
    Color cardColor;
    String planName;
    IconData planIcon;

    switch (user.tier) {
      case UserTier.gold:
        cardColor = const Color(0xFFFFD700);
        planName = "عضوية ذهبية";
        planIcon = Icons.star_rounded;
      case UserTier.silver:
        cardColor = const Color(0xFFC0C0C0);
        planName = "عضوية فضية";
        planIcon = Icons.verified_rounded;
      case UserTier.bronze:
        cardColor = const Color(0xFFCD7F32);
        planName = "عضوية برونزية (مجانية)";
        planIcon = Icons.person_outline_rounded;
    }

    // 2. Format Date (disabled for now)
    String expiryText = "وصول غير محدود";
    // if (user.tier != UserTier.bronze &&
    //     user.subscriptionEndDate != null &&
    //     user.subscriptionEndDate != 'unlimited') {
    //   try {
    //     final date = DateTime.parse(user.subscriptionEndDate!);
    //     expiryText = "تنتهي في: ${DateFormat('yyyy/MM/dd').format(date)}";
    //   } catch (e) {
    //     expiryText = "تنتهي في: ${user.subscriptionEndDate}";
    //   }
    // } else
    if (user.tier == UserTier.bronze) {
      expiryText = "قم بالترقية للحصول على مزايا إضافية";
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardColor, cardColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Circle
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(planIcon, color: Colors.white, size: 28.sp),
          ),
          SizedBox(width: 16.w),

          // Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  expiryText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),

          // Upgrade Button (Only for Bronze/Silver)
          if (user.tier != UserTier.gold)
            TextButton(
              onPressed: () {
                AppRouter.navigateTo(context, Routes.vendorSubscription);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
              child: Text(
                "ترقية",
                style: TextStyle(
                  color: cardColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
