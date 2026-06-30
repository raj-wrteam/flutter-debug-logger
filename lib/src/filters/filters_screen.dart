import 'package:flutter/material.dart';
import '../log_level.dart';
import '../shared/app_colors.dart';
import '../shared/custom_app_bar.dart';
import '../shared/custom_text.dart';
import 'filter_state.dart';

class FiltersScreen extends StatelessWidget {
  const FiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Filters & Tags',
        actions: [
          TextButton(
            onPressed: FilterState.instance.selectAllTags,
            child: const CustomText('All',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 14)),
          ),
          TextButton(
            onPressed: FilterState.instance.deselectAllTags,
            child: const CustomText('None',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
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
                          selected:
                              FilterState.instance.activeLevels.contains(level),
                          color: level.chipColor,
                          onTap: () => FilterState.instance.toggleLevel(level),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12, height: 1),
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
              const SizedBox(height: 32),
            ],
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
    return CustomText(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(31) : const Color(0xFF202020),
          border: Border.all(
            color: selected ? color.withAlpha(153) : Colors.white10,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? color : color.withAlpha(102),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            CustomText(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
