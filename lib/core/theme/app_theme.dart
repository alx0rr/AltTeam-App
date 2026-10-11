import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.accentPrimary,
      brightness: brightness,
    ).copyWith(
      primary: p.accentPrimary,
      onPrimary: p.onAccent,
      surface: p.surfaceElevated,
      onSurface: p.textPrimary,
      error: p.error,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: p.surfaceElevated,
      surfaceContainerLow: p.surfaceElevated,
      surfaceContainer: p.surfaceElevated,
      surfaceContainerHigh: p.surfaceElevated,
      surfaceContainerHighest: p.surfaceElevated,
    );

    final popupShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: p.glassBorder),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bgGradient.first,
      canvasColor: p.surfaceElevated,
      dividerColor: p.glassBorder,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accentPrimary,
        selectionColor: p.accentPrimary.withValues(alpha: 0.30),
        selectionHandleColor: p.accentPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accentPrimary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceElevated,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: popupShape,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: p.textSecondary, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceElevated,
        modalBackgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: popupShape,
        textStyle: TextStyle(color: p.textPrimary),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }
}