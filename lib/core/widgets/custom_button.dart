import 'package:flutter/material.dart';
import '../theme/colors.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double? width;
  final double? height;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width,
    this.height,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = height ?? 56.h;
    final buttonWidth = width ?? double.infinity;

    return isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(buttonWidth, buttonHeight),
              side: BorderSide(color: color ?? AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
            ),
            child: _buildChild(),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color ?? AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: Size(buttonWidth, buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              elevation: 4,
              shadowColor: (color ?? AppColors.primary).withOpacity(0.4),
            ),
            child: _buildChild(),
          );
  }

  Widget _buildChild() {
    if (isLoading) {
      return SizedBox(
        width: 24.w,
        height: 24.w,
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      );
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w900,
        color: isOutlined ? AppColors.primary : Colors.white,
      ),
    );
  }
}
