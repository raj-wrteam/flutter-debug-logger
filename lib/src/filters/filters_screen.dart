import 'package:flutter/material.dart';
import '../log_level.dart';
import '../shared/app_colors.dart';
import '../shared/custom_app_bar.dart';
import '../shared/custom_divider.dart';
import '../shared/custom_chip.dart';
import '../shared/custom_text_button.dart';
import '../shared/custom_section_header.dart';
import '../shared/debug_theme.dart';
import 'filter_state.dart';

class FiltersScreen extends StatelessWidget {
  const FiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DebugTheme.theme,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Filters & Tags',
          actions: [
            CustomTextButton(
              onPressed: FilterState.instance.selectAllTags,
              label: 'All',
              textColor: Colors.orangeAccent,
            ),
            CustomTextButton(
              onPressed: FilterState.instance.deselectAllTags,
              label: 'None',
              textColor: Colors.white38,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListenableBuilder(
          listenable: FilterState.instance,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('LOG LEVELS'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LogLevel.values
                      .map((level) => _FilterChip(
                            label: level.label,
                            selected: FilterState.instance.activeLevels
                                .contains(level),
                            color: level.chipColor,
                            onTap: () =>
                                FilterState.instance.toggleLevel(level),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                const CustomDivider(),
                const SizedBox(height: 20),
                const _SectionLabel('LOG TYPES'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    LogTag.curl,
                    LogTag.request,
                    LogTag.response,
                    LogTag.body,
                    LogTag.apiError,
                    LogTag.responseError,
                    LogTag.flutterError,
                    LogTag.appError,
                    LogTag.printLog,
                    LogTag.stackTrace,
                    LogTag.separator,
                    LogTag.logger,
                    LogTag.unknown,
                  ]
                      .map((tag) => _FilterChip(
                            label: tag.label,
                            selected:
                                FilterState.instance.activeTags.contains(tag),
                            color: tag.color,
                            onTap: () => FilterState.instance.toggleTag(tag),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                const CustomDivider(),
                const SizedBox(height: 20),
                const _SectionLabel('SOCKET LOGS'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LogTag.socketTags
                      .map((tag) => _FilterChip(
                            label: tag.label,
                            selected:
                                FilterState.instance.activeTags.contains(tag),
                            color: tag.color,
                            onTap: () => FilterState.instance.toggleTag(tag),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomSectionHeader(
      text,
      padding: EdgeInsets.zero,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomChip(
      label: label,
      color: color,
      selected: selected,
      onTap: onTap,
      borderRadius: 16.0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      fontSize: 13.0,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      showDot: true,
      textColor: selected ? Colors.white : Colors.white54,
    );
  }
}
