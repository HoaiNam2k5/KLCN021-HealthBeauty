import 'package:flutter/material.dart';

/// Bảng màu lấy từ app Kotlin (Color.kt) để giống thiết kế Figma.
class AppColors {
  static const rose = Color(0xFFB76E79);
  static const roseContainer = Color(0xFFFFDADD);
  static const onRoseContainer = Color(0xFF3F0D18);
  static const sage = Color(0xFF5E7F6B);
  static const sageContainer = Color(0xFFD5E8DC);
  static const onSageContainer = Color(0xFF12301F);
  static const cream = Color(0xFFFBF7F5);
  static const surfaceTint = Color(0xFFF3EDEA);
  static const ink = Color(0xFF2B2326);
  static const inkMuted = Color(0xFF7D7275);
  static const outline = Color(0xFFD8CCCF);
  static const danger = Color(0xFFD64545);
  static const warn = Color(0xFFE9A23B);
  static const ok = Color(0xFF4CAF7D);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.rose,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.rose,
      onPrimary: Colors.white,
      primaryContainer: AppColors.roseContainer,
      onPrimaryContainer: AppColors.onRoseContainer,
      secondary: AppColors.sage,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.sageContainer,
      onSecondaryContainer: AppColors.onSageContainer,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
