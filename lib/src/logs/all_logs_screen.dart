import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../debug_logger.dart';
import '../filters/filter_state.dart';
import '../filters/filters_screen.dart';
import '../models/log_entry.dart';
import '../models/log_session.dart';
import '../shared/app_colors.dart';
import '../shared/log_empty_state.dart';
import 'widgets/log_entry_row.dart';
import 'widgets/log_search_bar.dart';
import 'widgets/log_session_header.dart';

// ── Display item sealed class ──────────────────────────────────────────────────

sealed class _DisplayItem {}

final class _SessionHeaderItem extends _DisplayItem {
  _SessionHeaderItem(this.session, this.sessionNumber);
  final LogSession session;
  final int sessionNumber;
}

final class _EntryItem extends _DisplayItem {
  _EntryItem(this.entry, this.sessionNumber);
  final LogEntry entry;
  final int sessionNumber;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AllLogsScreen extends StatefulWidget {
  const AllLogsScreen({super.key, this.sessionId});

  /// When set, only logs from this session are shown.
  final String? sessionId;

  @override
  State<AllLogsScreen> createState() => _AllLogsScreenState();
}

class _AllLogsScreenState extends State<AllLogsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _collapsedSessions = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data helpers ─────────────────────────────────────────────────────────────

  List<LogSession> get _sessions {
    if (widget.sessionId == null) return DebugLogger.store.sessions;
    return DebugLogger.store.sessions
        .where((s) => s.id == widget.sessionId)
        .toList();
  }

  bool _entryPassesFilter(LogEntry e) {
    final fs = FilterState.instance;
    return fs.activeLevels.contains(e.level) && fs.activeTags.contains(e.tag);
  }

  bool _entryMatchesSearch(LogEntry e) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    return e.message.toLowerCase().contains(q.toLowerCase());
  }

  List<_DisplayItem> _buildDisplayItems() {
    final allSessions = DebugLogger.store.sessions;
    final sessions = _sessions;
    final items = <_DisplayItem>[];

    for (final session in sessions) {
      final sessionNumber = allSessions.indexOf(session) + 1;
      items.add(_SessionHeaderItem(session, sessionNumber));
      if (_collapsedSessions.contains(session.id)) continue;
      final entries = session.entries
          .where(_entryPassesFilter)
          .where(_entryMatchesSearch)
          .toList();
      final ordered = FilterState.instance.latestFirst
          ? entries.reversed.toList()
          : entries;
      for (final e in ordered) {
        items.add(_EntryItem(e, sessionNumber));
      }
    }
    return FilterState.instance.latestFirst
        ? _reverseSessionBlocks(items)
        : items;
  }

  List<_DisplayItem> _reverseSessionBlocks(List<_DisplayItem> items) {
    final blocks = <List<_DisplayItem>>[];
    List<_DisplayItem>? current;
    for (final item in items) {
      if (item is _SessionHeaderItem) {
        if (current != null) blocks.add(current);
        current = [item];
      } else {
        current?.add(item);
      }
    }
    if (current != null) blocks.add(current);
    return blocks.reversed.expand((b) => b).toList();
  }

  int get _totalEntries =>
      _sessions.fold(0, (sum, s) => sum + s.entries.length);

  int get _visibleEntries =>
      _buildDisplayItems().whereType<_EntryItem>().length;

  bool get _hasAnyFiltersActive {
    final fs = FilterState.instance;
    return !fs.allLevelsActive || !fs.allTagsActive || _query.isNotEmpty;
  }

  String _buildFilterSummary() {
    final levels =
        FilterState.instance.activeLevels.map((l) => l.label).join(', ');
    return 'Showing $_visibleEntries/$_totalEntries · $levels';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    String title = 'All Logs';
    if (widget.sessionId != null) {
      final idx = DebugLogger.store.sessions
          .indexWhere((s) => s.id == widget.sessionId);
      if (idx >= 0) title = 'Session #${idx + 1}';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded, size: 20),
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const FiltersScreen()),
                ),
              ),
              ListenableBuilder(
                listenable: FilterState.instance,
                builder: (_, __) => FilterState.instance.activeFilterCount > 0
                    ? Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          LogSearchBar(
            controller: _searchController,
            query: _query,
            onChanged: (v) {
              setState(() => _query = v);
            },
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
          ListenableBuilder(
            listenable: FilterState.instance,
            builder: (_, __) => _hasAnyFiltersActive
                ? GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const FiltersScreen()),
                    ),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _buildFilterSummary(),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 14, color: Colors.white24),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListenableBuilder(
      listenable: Listenable.merge([DebugLogger.store, FilterState.instance]),
      builder: (context, _) {
        if (_sessions.isEmpty) {
          return const LogEmptyState(text: 'No logs yet.');
        }
        final hasFiltered = _sessions
            .expand((s) => s.entries)
            .any((e) => _entryPassesFilter(e) && _entryMatchesSearch(e));
        if (!hasFiltered) {
          return const LogEmptyState(text: 'No matching logs.');
        }
        final items = _buildDisplayItems();
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return switch (item) {
                _SessionHeaderItem(:final session, :final sessionNumber) =>
                  LogSessionHeader(
                    session: session,
                    sessionNumber: sessionNumber,
                    isCollapsed: _collapsedSessions.contains(session.id),
                    onToggle: () => setState(() {
                      if (_collapsedSessions.contains(session.id)) {
                        _collapsedSessions.remove(session.id);
                      } else {
                        _collapsedSessions.add(session.id);
                      }
                    }),
                  ),
                _EntryItem(:final entry, :final sessionNumber) => LogEntryRow(
                    entry: entry,
                    sessionNumber: sessionNumber,
                    query: _query,
                  ),
              };
            },
          ),
        );
      },
    );
  }
}
