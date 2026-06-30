import 'package:flutter/material.dart';

import '../../debug_logger.dart';
import '../../log_level.dart';
import '../../shared/app_colors.dart';

class LogStatsCards extends StatelessWidget {
  const LogStatsCards({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DebugLogger.store,
      builder: (context, _) {
        final counts = <LogLevel, int>{
          for (final l in LogLevel.values) l: 0,
        };
        for (final s in DebugLogger.store.sessions) {
          for (final e in s.entries) {
            counts[e.level] = (counts[e.level] ?? 0) + 1;
          }
        }
        return Row(
          children: LogLevel.values
              .map((level) => Expanded(
                    child: _StatCard(
                      level: level,
                      count: counts[level] ?? 0,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.level, required this.count});

  final LogLevel level;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: level.chipColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: level.chipColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            level.label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
