import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Fixed dark theme for the debug package UI.
///
/// Every screen, dialog, and bottom sheet the package shows wraps itself in
/// this [Theme] so its appearance never depends on the host app's own
/// [ThemeData] — a light host theme (or any future host theme change) can't
/// leak in via [AppBarTheme.titleTextStyle], [Typography], etc.
abstract final class DebugTheme {
  static final ThemeData theme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    cardColor: AppColors.elevated,
    dividerColor: Colors.white12,
    splashColor: Colors.white10,
    highlightColor: Colors.white10,
    colorScheme: const ColorScheme.dark(
      primary: Colors.orangeAccent,
      secondary: Colors.orangeAccent,
      surface: AppColors.elevated,
      error: Color(0xFFEF5350),
    ),
    textTheme: Typography.material2021(
      platform: TargetPlatform.android,
    ).white.apply(bodyColor: Colors.white, displayColor: Colors.white),
    iconTheme: const IconThemeData(color: Colors.white70),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.elevated),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.elevated,
      modalBackgroundColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: AppColors.background,
      textColor: Colors.white70,
      iconColor: Colors.white70,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.orangeAccent
            : Colors.white54,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.orangeAccent.withValues(alpha: 0.5)
            : Colors.white12,
      ),
    ),
  );
}
