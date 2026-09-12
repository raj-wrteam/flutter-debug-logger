import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'dashboard/dashboard_screen.dart';
import 'debug_logger.dart';
import 'filters/filter_state.dart';
import 'shared/debug_scope.dart';

/// Wraps your app (or any subtree) with a persistent floating debug button.
///
/// ### Option A — wrap the whole app
/// ```dart
/// runApp(FlutterDebugLogger.wrap(child: const MyApp()));
/// ```
///
/// ### Option B — use the MaterialApp builder
/// ```dart
/// MaterialApp(
///   builder: FlutterDebugLogger.overlay,
///   ...
/// )
/// ```
///
/// When [flutterDebugLoggerEnabled] is false the widget is a transparent pass-
/// through, so you can leave it in production builds safely.
class FlutterDebugLogger extends StatelessWidget {
  const FlutterDebugLogger({super.key, required this.child});

  final Widget child;

  /// Convenience factory — identical to `FlutterDebugLogger(child: child)`.
  static Widget wrap({required Widget child}) =>
      FlutterDebugLogger(child: child);

  /// Use this as `MaterialApp(builder: FlutterDebugLogger.overlay)`.
  static Widget overlay(BuildContext context, Widget? child) =>
      FlutterDebugLogger(child: child ?? const SizedBox.shrink());

  @override
  Widget build(BuildContext context) {
    if (!flutterDebugLoggerEnabled) return child;
    return _DebugFabOverlay(child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DebugFabOverlay extends StatefulWidget {
  const _DebugFabOverlay({required this.child});
  final Widget child;

  @override
  State<_DebugFabOverlay> createState() => _DebugFabOverlayState();
}

class _DebugFabOverlayState extends State<_DebugFabOverlay> {
  // FAB starts bottom-right; user can drag it anywhere.
  Offset _position = const Offset(20, 100);
  bool _dragging = false;
  bool _isDebugScreenOpen = false;
  bool _isIdle = false;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    FilterState.instance.addListener(_onFilterStateChanged);
    _resetIdleTimer();
  }

  @override
  void dispose() {
    FilterState.instance.removeListener(_onFilterStateChanged);
    _idleTimer?.cancel();
    super.dispose();
  }

  void _onFilterStateChanged() {
    if (mounted) {
      _resetIdleTimer();
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isIdle) {
      setState(() {
        _isIdle = false;
      });
    }
    final fs = FilterState.instance;
    if (fs.reduceBubbleOpacityWhenIdle) {
      _idleTimer = Timer(Duration(seconds: fs.bubbleIdleTimeoutSeconds), () {
        if (mounted) {
          setState(() {
            _isIdle = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenSize = mq.size;
    final fs = FilterState.instance;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,

          // ── Draggable FAB ──────────────────────────────────────────────────
          if (!_isDebugScreenOpen)
            Positioned(
              right: _position.dx,
              bottom: _position.dy,
              child: Listener(
                onPointerDown: (_) => _resetIdleTimer(),
                child: GestureDetector(
                  onPanStart: (_) {
                    _resetIdleTimer();
                    setState(() => _dragging = true);
                  },
                  onPanUpdate: (d) {
                    _resetIdleTimer();
                    setState(() {
                      _dragging = true;
                      _position = Offset(
                        (_position.dx - d.delta.dx).clamp(
                          8,
                          screenSize.width - 72,
                        ),
                        (_position.dy - d.delta.dy).clamp(
                          8,
                          screenSize.height - 72,
                        ),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    _resetIdleTimer();
                    setState(() => _dragging = false);
                  },
                  onTapDown: (_) => _resetIdleTimer(),
                  onTap: () {
                    _resetIdleTimer();
                    if (_dragging || _isDebugScreenOpen) return;
                    NavigatorState? nav;
                    try {
                      nav = Navigator.of(context, rootNavigator: true);
                    } catch (_) {
                      nav = _findNavigatorState(context);
                    }

                    if (nav != null) {
                      setState(() => _isDebugScreenOpen = true);
                      nav.push(debugPageRoute(const DashboardScreen())).then((
                        _,
                      ) {
                        if (mounted) {
                          setState(() => _isDebugScreenOpen = false);
                          _resetIdleTimer();
                        }
                      });
                    } else {
                      debugPrint(
                        'FlutterDebugLogger: Could not find Navigator in the widget tree.',
                      );
                    }
                  },
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: (_isIdle && fs.reduceBubbleOpacityWhenIdle)
                        ? fs.bubbleIdleOpacity
                        : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: _dragging ? 0.85 : 0.70,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bug_report_outlined,
                        color: Colors.greenAccent,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  NavigatorState? _findNavigatorState(BuildContext context) {
    NavigatorState? navState;
    void visitor(Element element) {
      if (navState != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        navState = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    return navState;
  }
}
