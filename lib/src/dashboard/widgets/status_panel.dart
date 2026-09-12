import 'package:material_ui/material_ui.dart';

import '../../debug_logger.dart';
import '../../shared/app_colors.dart';
import '../../shared/custom_text.dart';

class StatusPanel extends StatefulWidget {
  const StatusPanel({super.key});

  @override
  State<StatusPanel> createState() => _StatusPanelState();
}

class _StatusPanelState extends State<StatusPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _fileSizeLabel() {
    final bytes = DebugLogger.fileSizeBytes;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  int get _totalEntries =>
      DebugLogger.store.sessions.fold(0, (sum, s) => sum + s.entries.length);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugLogger.store,
      builder: (context, _) {
        final active = DebugLogger.loggingActive;
        final dotColor = active
            ? const Color(0xFF4CAF50)
            : const Color(0xFFFF9800);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor.withValues(
                          alpha: active ? 0.5 + _pulse.value * 0.5 : 1.0,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: dotColor.withAlpha(100),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CustomText(
                    active ? 'ACTIVE' : 'PAUSED',
                    style: TextStyle(
                      color: dotColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(DebugLogger.toggleLogging),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: CustomText(
                        active ? 'Pause logging' : 'Resume logging',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CustomText(
                '${_fileSizeLabel()}  ·  $_totalEntries entries',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
