import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../debug_logger.dart';
import '../logs/all_logs_screen.dart';
import '../models/log_session.dart';
import '../shared/app_colors.dart';
import '../shared/custom_app_bar.dart';
import '../shared/log_empty_state.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(
        title: 'Sessions',
      ),
      body: ListenableBuilder(
        listenable: DebugLogger.store,
        builder: (context, _) {
          final sessions = DebugLogger.store.sessions.reversed.toList();
          if (sessions.isEmpty) {
            return const LogEmptyState(text: 'No sessions yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final session = sessions[i];
              final index = DebugLogger.store.sessions.indexOf(session) + 1;
              return _SessionCard(session: session, sessionNumber: index);
            },
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.sessionNumber});

  final LogSession session;
  final int sessionNumber;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => AllLogsScreen(sessionId: session.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent.withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  '#$sessionNumber',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatHeader(session.startTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.entries.length} entries',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  static String _formatHeader(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String p(int n) => n.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  ·  ${p(dt.hour)}:${p(dt.minute)}';
  }
}
