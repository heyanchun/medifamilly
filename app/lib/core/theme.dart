// lib/core/theme.dart
// 亲声药铃全局主题：温暖色调 + 老年友好大字体

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  AppTheme._();

  // 主色调：温暖橙红（传递亲情感）
  static const Color primary = Color(0xFFE8734A);
  static const Color primaryLight = Color(0xFFFFF0EB);
  static const Color primaryDark = Color(0xFFC55A34);

  // 辅助色
  static const Color success = Color(0xFF4CAF72);
  static const Color warning = Color(0xFFFFB347);
  static const Color error = Color(0xFFE53935);

  // 中性色
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E7EB);

  // 字体大小（老年友好：整体放大）
  static double get fontSizeXs  => 12.sp;
  static double get fontSizeSm  => 14.sp;
  static double get fontSizeMd  => 16.sp;
  static double get fontSizeLg  => 18.sp;
  static double get fontSizeXl  => 22.sp;
  static double get fontSizeXxl => 28.sp;
  // 长辈端专用超大字体
  static double get fontSizeElderBody  => 20.sp;
  static double get fontSizeElderTitle => 32.sp;
  static double get fontSizeElderBtn   => 24.sp;

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: surface,
    ),
    fontFamily: 'NotoSansSC',
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: fontSizeLg,
        fontWeight: FontWeight.w600,
        fontFamily: 'NotoSansSC',
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 52.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        textStyle: TextStyle(fontSize: fontSizeMd, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: textHint, fontSize: fontSizeMd),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: divider),
      ),
    ),
  );
}
