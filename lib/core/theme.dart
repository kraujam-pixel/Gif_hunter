import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFF0E0E12);
  static const Color surface = Color(0xFF1A1A22);
  static const Color surfaceHigh = Color(0xFF24242F);
  static const Color accent = Color(0xFFBB86FC);
  static const Color accentAlt = Color(0xFF03DAC6);
  static const Color warning = Color(0xFFFFB74D);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [accent, accentAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Muted tones used for image placeholders and skeletons.
  static const List<Color> placeholders = [
    Color(0xFF3A2A5C),
    Color(0xFF1F4D4A),
    Color(0xFF5C2A44),
    Color(0xFF2A3E5C),
    Color(0xFF4D3A1F),
  ];
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentAlt,
      surface: AppColors.surface,
    ),
    // Platform-native page transitions (iOS keeps its swipe-back). The Zoom
    // transition is used without snapshotting: on Flutter Web the snapshot of
    // the previous page can come back blank, which left the grid tiles empty
    // after returning from the detail screen.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android:
            ZoomPageTransitionsBuilder(allowSnapshotting: false),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows:
            ZoomPageTransitionsBuilder(allowSnapshotting: false),
        TargetPlatform.linux:
            ZoomPageTransitionsBuilder(allowSnapshotting: false),
        TargetPlatform.fuchsia:
            ZoomPageTransitionsBuilder(allowSnapshotting: false),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
