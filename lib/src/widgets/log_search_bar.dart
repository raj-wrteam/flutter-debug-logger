import 'package:flutter/material.dart';
import '../log_level.dart';
import 'log_filter_sheet.dart';

class LogSearchBar extends StatelessWidget {
  const LogSearchBar({
    super.key,
    required this.controller,
    required this.query,
    required this.activeFilters,
    required this.onToggleFilter,
    required this.activeTags,
    required this.onToggleTag,
    required this.onSelectAllTags,
    required this.onDeselectAllTags,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final Set<LogLevel> activeFilters;
  final ValueChanged<LogLevel> onToggleFilter;
  final Set<LogTag> activeTags;
  final ValueChanged<LogTag> onToggleTag;
  final VoidCallback onSelectAllTags;
  final VoidCallback onDeselectAllTags;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                cursorColor: Colors.orangeAccent,
                decoration: InputDecoration(
                  hintText: 'Search logs',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          color: Colors.white38,
                          tooltip: 'Clear search',
                          onPressed: onClear,
                        ),
                  filled: true,
                  fillColor: const Color(0xFF202020),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Filter logs',
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.filter_list_rounded,
              size: 19,
              color: (activeFilters.length < LogLevel.values.length ||
                      activeTags.length < LogTag.values.length)
                  ? Colors.orangeAccent
                  : Colors.white38,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1A1A1A),
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setSheetState) {
                      return LogFilterSheet(
                        activeFilters: activeFilters,
                        activeTags: activeTags,
                        onToggleFilter: (level) {
                          onToggleFilter(level);
                          setSheetState(() {});
                        },
                        onToggleTag: (tag) {
                          onToggleTag(tag);
                          setSheetState(() {});
                        },
                        onSelectAllTags: () {
                          onSelectAllTags();
                          setSheetState(() {});
                        },
                        onDeselectAllTags: () {
                          onDeselectAllTags();
                          setSheetState(() {});
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
