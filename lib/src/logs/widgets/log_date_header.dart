import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
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
            const Spacer(),
            CustomText(
              '$entryCount entries',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isCollapsed
                  ? Icons.keyboard_arrow_right_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.white38,
            ),
            if (onExtract != null || onSelect != null || onDelete != null) ...[
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 16, color: Colors.white38),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 120),
                color: AppColors.elevated,
                surfaceTintColor: Colors.transparent,
                onSelected: (value) {
                  switch (value) {
                    case 'extract':
                      onExtract?.call();
                      break;
                    case 'select':
                      onSelect?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onExtract != null)
                    const PopupMenuItem(
                      value: 'extract',
                      child: Row(
                        children: [
                          Icon(Icons.ios_share_outlined, size: 14, color: Colors.white70),
                          SizedBox(width: 8),
                          CustomText('Extract', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  if (onSelect != null)
                    const PopupMenuItem(
                      value: 'select',
                      child: Row(
                        children: [
                          Icon(Icons.check_box_outlined, size: 14, color: Colors.white70),
                          SizedBox(width: 8),
                          CustomText('Select', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                          SizedBox(width: 8),
                          CustomText('Delete', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                ],
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
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    return '$month $day, ${dt.year}';
  }
}
