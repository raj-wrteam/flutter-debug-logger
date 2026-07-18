import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../log_level.dart';
import '../../models/log_entry.dart';
import '../../shared/app_colors.dart';
import '../../shared/custom_text.dart';
import '../../shared/custom_divider.dart';
import '../../shared/custom_chip.dart';
import '../../shared/custom_button.dart';
import '../../shared/custom_section_header.dart';

class LogEntryDetailSheet extends StatelessWidget {
  const LogEntryDetailSheet({
    super.key,
    required this.entry,
    required this.sessionNumber,
  });

  final LogEntry entry;
  final int sessionNumber;

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 1.6,
    color: Colors.white70,
  );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _LevelBadge(entry.level),
                  const SizedBox(width: 8),
                  _TagBadge(entry.tag),
                  const Spacer(),
                  CustomText(
                    _formatTime(entry.timestamp),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const CustomDivider(),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _MetaRow('Session', '#$sessionNumber'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const _SheetSectionLabel('MESSAGE'),
                      if (entry.tag == LogTag.curl &&
                          entry.metadata['curl'] is String) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(
                              text: entry.metadata['curl'] as String,
                            ));
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: CustomText('cURL command copied'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: const CustomText(
                            'Copy cURL',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: SelectableText(entry.fullMessage, style: _mono),
                  ),
                  if (entry.visibleMetadata.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SheetSectionLabel('METADATA'),
                    const SizedBox(height: 8),
                    ...entry.visibleMetadata.entries.map(
                      (e) => _MetaRow(e.key, '${e.value}'),
                    ),
                  ],
                  if (entry.stackTrace != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const _SheetSectionLabel('STACK TRACE'),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: entry.stackTrace!),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: CustomText('Stack trace copied'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: const CustomText(
                            'Copy',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: SelectableText(
                        entry.stackTrace!,
                        style: _mono.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(
                              text: entry.formatAsText(
                                  sessionNumber: sessionNumber),
                            ));
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: CustomText('Entry copied'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: Icons.copy_rounded,
                          label: 'Copy Entry',
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await SharePlus.instance.share(ShareParams(
                              text: entry.formatAsText(
                                  sessionNumber: sessionNumber),
                              subject: 'Log Entry',
                            ));
                          },
                          icon: Icons.ios_share_outlined,
                          label: 'Export',
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge(this.level);
  final LogLevel level;

  @override
  Widget build(BuildContext context) {
    return CustomChip(
      label: level.label.toUpperCase(),
      color: level.chipColor,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge(this.tag);
  final LogTag tag;

  @override
  Widget build(BuildContext context) {
    return CustomChip(
      label: tag.label,
      color: tag.color,
      textColor: tag.color,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: CustomText.rich(
        TextSpan(
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, height: 1.5),
          children: [
            TextSpan(
              text: '${label.padRight(12)}: ',
              style: const TextStyle(color: Colors.white38),
            ),
            TextSpan(
                text: value, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomSectionHeader(
      text,
      padding: EdgeInsets.zero,
    );
  }
}
