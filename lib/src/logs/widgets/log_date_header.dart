import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';
import '../../shared/custom_text.dart';

class LogDateHeader extends StatelessWidget {
  const LogDateHeader({
    super.key,
    required this.date,
    required this.entryCount,
    required this.isCollapsed,
    required this.onToggle,
    this.onExtract,
    this.onSelect,
    this.onDelete,
  });

  final DateTime date;
  final int entryCount;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final VoidCallback? onExtract;
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;

  bool get _hasActions =>
      onExtract != null || onSelect != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    _formatDate(date),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 3),
                  CustomText(
                    '$entryCount entries',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isCollapsed
                  ? Icons.keyboard_arrow_right_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.white38,
            ),
            if (_hasActions) ...[
              const SizedBox(width: 4),
              _ActionMenu(
                onExtract: onExtract,
                onSelect: onSelect,
                onDelete: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    return '$month $day, ${dt.year}';
  }
}

// ── Shared compact action menu ────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({this.onExtract, this.onSelect, this.onDelete});

  final VoidCallback? onExtract;
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert_rounded,
          size: 16,
          color: Colors.white38,
        ),
        iconSize: 16,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 140),
        position: PopupMenuPosition.under,
        color: AppColors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white10),
        ),
        onSelected: (value) {
          switch (value) {
            case 'extract':
              onExtract?.call();
            case 'select':
              onSelect?.call();
            case 'delete':
              onDelete?.call();
          }
        },
        itemBuilder: (context) => [
          if (onExtract != null)
            const PopupMenuItem(
              value: 'extract',
              height: 36,
              child: Row(
                children: [
                  Icon(
                    Icons.ios_share_outlined,
                    size: 14,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 10),
                  CustomText(
                    'Extract',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
          if (onSelect != null)
            const PopupMenuItem(
              value: 'select',
              height: 36,
              child: Row(
                children: [
                  Icon(
                    Icons.check_box_outlined,
                    size: 14,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 10),
                  CustomText(
                    'Select All',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
          if (onDelete != null)
            const PopupMenuItem(
              value: 'delete',
              height: 36,
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  SizedBox(width: 10),
                  CustomText(
                    'Delete',
                    style: TextStyle(fontSize: 13, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
