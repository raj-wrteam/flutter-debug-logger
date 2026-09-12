import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'debug_theme.dart';

/// Guarantees the `package:material_ui` / `package:cupertino_ui` localizations
/// that this package's widgets depend on.
///
/// Host apps still running on `package:flutter/material.dart` provide the
/// *legacy* [MaterialLocalizations] type, which the modern widgets used here
/// cannot see — that mismatch throws "No MaterialLocalizations found" as soon
/// as a debug screen is opened. Only missing delegates are injected, so a
/// migrated host keeps its own (translated) localizations.
class DebugScope extends StatelessWidget {
  const DebugScope({super.key, required this.child});

  final Widget child;

  static const List<LocalizationsDelegate<dynamic>> _delegates =
      <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ];

  @override
  Widget build(BuildContext context) {
    final hasMaterial =
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        ) !=
        null;
    final hasCupertino =
        Localizations.of<CupertinoLocalizations>(
          context,
          CupertinoLocalizations,
        ) !=
        null;
    if (hasMaterial && hasCupertino) return child;

    // Localizations.override merges with the ancestor Localizations, so it
    // needs one to exist; a tree without any gets a fresh en_US scope.
    if (_hasLocalizations(context)) {
      return Localizations.override(
        context: context,
        delegates: _delegates,
        child: child,
      );
    }
    return Localizations(
      locale: const Locale('en', 'US'),
      delegates: _delegates,
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }

  static bool _hasLocalizations(BuildContext context) {
    try {
      Localizations.localeOf(context);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// A [CupertinoPageRoute] whose content is wrapped in a [DebugScope].
Route<T> debugPageRoute<T>(Widget child) =>
    CupertinoPageRoute<T>(builder: (_) => DebugScope(child: child));

/// Root wrapper for every debug screen / sheet: applies [DebugTheme] and the
/// localizations guard in one go.
class DebugSurface extends StatelessWidget {
  const DebugSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DebugScope(
    child: Theme(data: DebugTheme.theme, child: child),
  );
}
