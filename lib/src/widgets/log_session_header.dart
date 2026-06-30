import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/log_session.dart';

class LogSessionHeader extends StatelessWidget {
  const LogSessionHeader({
    super.key,
    required this.session,
    required this.sessionNumber,
    required this.isCollapsed,
    required this.onToggle,
  });

  final LogSession session;
  final int sessionNumber;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label =
        'SESSION #$sessionNumber  •  ${_formatHeader(session.startTime)}'
        '  •  ${session.entries.length} entries';

    return GestureDetector(
      onTap: onToggle,
      onLongPress: () => _showActionSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFB74D),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isCollapsed
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              size: 14,
              color: const Color(0xFFFFB74D),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SessionActionSheet(
        session: session,
        sessionNumber: sessionNumber,
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
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final hourNum = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, ${dt.year}  •  $hourNum:$minute:$second $ampm';
  }
}

class _SessionActionSheet extends StatelessWidget {
  const _SessionActionSheet({
    required this.session,
    required this.sessionNumber,
  });

  final LogSession session;
  final int sessionNumber;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined,
                  color: Colors.white70, size: 20),
              title: const Text('Copy session',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () async {
                await Clipboard.setData(ClipboardData(
                  text: session.formatAsText(sessionNumber),
                ));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Session copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined,
                  color: Colors.white70, size: 20),
              title: const Text('Export session',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () async {
                Navigator.pop(context);
                await SharePlus.instance.share(ShareParams(
                  text: session.formatAsText(sessionNumber),
                  subject: 'Session #$sessionNumber',
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
