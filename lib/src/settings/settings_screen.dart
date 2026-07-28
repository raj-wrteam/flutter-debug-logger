import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../debug_logger.dart';
import '../filters/filter_state.dart';
import '../shared/app_colors.dart';
import '../shared/custom_app_bar.dart';
import '../shared/custom_text.dart';
import '../shared/custom_divider.dart';
import '../shared/custom_section_header.dart';
import '../shared/custom_text_button.dart';
import '../shared/debug_theme.dart';
import '../shared/log_share_confirm_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _snack(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: CustomText(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _copyAll() async {
    final text = DebugLogger.store.sessions
        .asMap()
        .entries
        .map((e) => e.value.formatAsText(e.key + 1))
        .join('\n\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    await _snack('Copied all logs');
  }

  Future<void> _copyFiltered() async {
    final fs = FilterState.instance;
    final buf = StringBuffer();
    var si = 0;
    for (final session in DebugLogger.store.sessions) {
      si++;
      for (final entry in session.entries) {
        if (fs.activeLevels.contains(entry.level) &&
            fs.activeTags.contains(entry.tag)) {
          buf.writeln(entry.formatAsText(sessionNumber: si));
          buf.writeln();
        }
      }
    }
    final text = buf.toString().trimRight();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    await _snack('Copied filtered logs');
  }

  Future<void> _exportLogs() async {
    final file = await DebugLogger.getShareableLogFile();
    if (file == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Debug Logs'),
      );
    } finally {
      await DebugLogger.deleteShareableLogFile(file);
    }
  }

  Future<void> _shareAndClear() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Theme(
        data: DebugTheme.theme,
        child: const LogShareConfirmSheet(),
      ),
    );
    if (ok != true || !mounted) return;
    await _exportLogs();
    await DebugLogger.clearFileAsync();
    if (mounted) setState(() {});
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Theme(
        data: DebugTheme.theme,
        child: AlertDialog(
          backgroundColor: AppColors.elevated,
          title: const CustomText(
            'Clear all logs?',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: const CustomText(
            'This will permanently delete all log entries.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            CustomTextButton(
              onPressed: () => Navigator.pop(context, false),
              label: 'Cancel',
              textColor: Colors.white38,
            ),
            CustomTextButton(
              onPressed: () => Navigator.pop(context, true),
              label: 'Clear',
              textColor: const Color(0xFFEF5350),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await DebugLogger.clearFileAsync();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DebugTheme.theme,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const CustomAppBar(
          title: 'Settings & Actions',
        ),
        body: ListenableBuilder(
          listenable: FilterState.instance,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const _SectionHeader('DISPLAY'),
              SwitchListTile(
                tileColor: AppColors.background,
                title: const CustomText('Latest first',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                value: FilterState.instance.latestFirst,
                onChanged: (_) => FilterState.instance.toggleLatestFirst(),
                activeThumbColor: Colors.orangeAccent,
                inactiveTrackColor: Colors.white12,
              ),
              const CustomDivider(indent: 16, endIndent: 16),
              const _SectionHeader('FLOATING BUBBLE'),
              SwitchListTile(
                tileColor: AppColors.background,
                title: const CustomText('Reduce opacity when idle',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const CustomText('Dim the bubble after inactivity',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                value: FilterState.instance.reduceBubbleOpacityWhenIdle,
                onChanged: (v) =>
                    FilterState.instance.setReduceBubbleOpacityWhenIdle(v),
                activeThumbColor: Colors.orangeAccent,
                inactiveTrackColor: Colors.white12,
              ),
              if (FilterState.instance.reduceBubbleOpacityWhenIdle) ...[
                ListTile(
                  tileColor: AppColors.background,
                  title: const CustomText('Idle timeout',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: DropdownButton<int>(
                    value: FilterState.instance.bubbleIdleTimeoutSeconds,
                    dropdownColor: AppColors.elevated,
                    style: const TextStyle(
                        color: Colors.orangeAccent, fontSize: 14),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 seconds')),
                      DropdownMenuItem(value: 3, child: Text('3 seconds')),
                      DropdownMenuItem(value: 5, child: Text('5 seconds')),
                      DropdownMenuItem(value: 10, child: Text('10 seconds')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        FilterState.instance.setBubbleIdleTimeoutSeconds(v);
                      }
                    },
                  ),
                ),
                ListTile(
                  tileColor: AppColors.background,
                  title: const CustomText('Idle opacity',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: DropdownButton<double>(
                    value: FilterState.instance.bubbleIdleOpacity,
                    dropdownColor: AppColors.elevated,
                    style: const TextStyle(
                        color: Colors.orangeAccent, fontSize: 14),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 0.15, child: Text('15%')),
                      DropdownMenuItem(value: 0.3, child: Text('30%')),
                      DropdownMenuItem(value: 0.5, child: Text('50%')),
                      DropdownMenuItem(value: 0.7, child: Text('70%')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        FilterState.instance.setBubbleIdleOpacity(v);
                      }
                    },
                  ),
                ),
              ],
              const CustomDivider(indent: 16, endIndent: 16),
              const _SectionHeader('SOCKET LOGGING'),
              SwitchListTile(
                tileColor: AppColors.background,
                title: const CustomText('Record socket logs',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                value: DebugLogger.socketLoggingEnabled,
                onChanged: (v) {
                  DebugLogger.setSocketLoggingEnabled(v);
                  setState(() {});
                },
                activeThumbColor: Colors.orangeAccent,
                inactiveTrackColor: Colors.white12,
              ),
              const CustomDivider(indent: 16, endIndent: 16),
              const _SectionHeader('EXPORT'),
              _ActionTile(
                icon: Icons.ios_share_outlined,
                label: 'Export logs',
                onTap: _exportLogs,
              ),
              _ActionTile(
                icon: Icons.copy_all_outlined,
                label: 'Copy all logs',
                onTap: _copyAll,
              ),
              _ActionTile(
                icon: Icons.content_copy_rounded,
                label: 'Copy filtered logs',
                onTap: _copyFiltered,
              ),
              _ActionTile(
                icon: Icons.delete_sweep_outlined,
                label: 'Share & clear',
                onTap: _shareAndClear,
              ),
              const CustomDivider(indent: 16, endIndent: 16),
              const _SectionHeader('DANGER ZONE'),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Clear all logs',
                onTap: _clear,
                color: const Color(0xFFEF5350),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomSectionHeader(text);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return ListTile(
      tileColor: AppColors.background,
      leading: Icon(icon, color: c, size: 20),
      title: CustomText(label, style: TextStyle(color: c, fontSize: 14)),
      onTap: onTap,
    );
  }
}
