import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      surface: AppColors.surface,
    ),

    // Cấu hình đồng bộ trọn bộ Font chữ cho cả nhóm gọi nhanh
    textTheme: const TextTheme(
      // 1. Dùng cho Tiêu đề màn hình (My Home, Notification...)
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText, // Hoặc AppColors.textMain theo file MD
      ),
      // 2. Dùng cho Tên thiết bị, Tiêu đề Card (Smart V1 CCTV...)
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600, // Semi-bold
        color: AppColors.darkText,
      ),
      // 3. Dùng cho nội dung thông thường
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.darkText,
      ),
      // 4. Dùng cho chữ chú thích nhỏ (Timestamp, Wi-Fi...)
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Colors.black54, // Hoặc AppColors.textSecondary
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false, // Để tiêu đề lệch trái giống hệt như ảnh mockup mẫu
    ),
  );
}
