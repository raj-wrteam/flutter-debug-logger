import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../debug_logger.dart';
import '../filters/filter_state.dart';
import '../filters/filters_screen.dart';
import '../models/log_entry.dart';
import '../models/log_session.dart';
import '../shared/app_colors.dart';
import '../shared/custom_app_bar.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text.dart';
import '../shared/log_empty_state.dart';
import 'widgets/log_date_header.dart';
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

final class _DateHeaderItem extends _DisplayItem {
  _DateHeaderItem(this.date, this.entryCount);
  final DateTime date;
  final int entryCount;
}

final class _EntryItem extends _DisplayItem {
  _EntryItem(this.entry, this.sessionNumber);
  final LogEntry entry;
  final int sessionNumber;
}

enum _GroupMode { session, date }

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
  final Set<String> _collapsedDates = {};
  String _query = '';
  _GroupMode _groupMode = _GroupMode.session;
  bool _selectMode = false;
  final Set<String> _selectedEntryIds = {};

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

  String _dateKey(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)}';
  }

  List<_DisplayItem> _buildDisplayItems() {
    final allSessions = DebugLogger.store.sessions;
    final items = <_DisplayItem>[];

    if (_groupMode == _GroupMode.session) {
      final sessions = _sessions;
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
    } else {
      final Map<DateTime, List<LogEntry>> grouped = {};
      for (final session in _sessions) {
        for (final e in session.entries) {
          if (_entryPassesFilter(e) && _entryMatchesSearch(e)) {
            final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
            grouped.putIfAbsent(date, () => []).add(e);
          }
        }
      }

      final sortedDates = grouped.keys.toList()
        ..sort((a, b) => FilterState.instance.latestFirst ? b.compareTo(a) : a.compareTo(b));

      for (final date in sortedDates) {
        final entries = grouped[date]!;
        entries.sort((a, b) => FilterState.instance.latestFirst
            ? b.timestamp.compareTo(a.timestamp)
            : a.timestamp.compareTo(b.timestamp));
        items.add(_DateHeaderItem(date, entries.length));
        if (_collapsedDates.contains(_dateKey(date))) continue;
        for (final e in entries) {
          final sessionIndex = allSessions.indexWhere((s) => s.id == e.sessionId);
          final sessionNumber = sessionIndex >= 0 ? sessionIndex + 1 : 0;
          items.add(_EntryItem(e, sessionNumber));
        }
      }
      return items;
    }
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

  // ── Action helpers ───────────────────────────────────────────────────────────

  void _extractSession(LogSession session, int sessionNumber) {
    final entries = session.entries.where(_entryPassesFilter).where(_entryMatchesSearch).toList();
    if (entries.isEmpty) return;
    final text = DebugLogger.serializeEntriesToText(entries, title: 'Session #$sessionNumber Logs');
    DebugLogger.shareText(text, fileName: 'session_${sessionNumber}_logs.txt', subject: 'Session #$sessionNumber Logs');
  }

  void _selectSession(LogSession session) {
    final entries = session.entries.where(_entryPassesFilter).where(_entryMatchesSearch).toList();
    setState(() {
      _selectMode = true;
      _selectedEntryIds.clear();
      _selectedEntryIds.addAll(entries.map((e) => e.id));
    });
  }

  void _deleteSession(LogSession session, int sessionNumber) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete Session #$sessionNumber?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      DebugLogger.store.deleteSession(session.id);
    }
  }

  void _extractDate(DateTime date) {
    final entries = _sessions
        .expand((s) => s.entries)
        .where((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day) == date)
        .where(_entryPassesFilter)
        .where(_entryMatchesSearch)
        .toList();
    if (entries.isEmpty) return;
    final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final text = DebugLogger.serializeEntriesToText(entries, title: 'Logs for $formattedDate');
    DebugLogger.shareText(text, fileName: 'logs_$formattedDate.txt', subject: 'Logs for $formattedDate');
  }

  void _selectDate(DateTime date) {
    final entries = _sessions
        .expand((s) => s.entries)
        .where((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day) == date)
        .where(_entryPassesFilter)
        .where(_entryMatchesSearch)
        .toList();
    setState(() {
      _selectMode = true;
      _selectedEntryIds.clear();
      _selectedEntryIds.addAll(entries.map((e) => e.id));
    });
  }

  void _deleteDate(DateTime date) async {
    final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Logs by Date'),
        content: Text('Are you sure you want to delete all logs for $formattedDate?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      DebugLogger.store.deleteEntriesForDate(date);
    }
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
      appBar: CustomAppBar(
        title: title,
        actions: [
          IconButton(
            icon: Icon(
              _groupMode == _GroupMode.session
                  ? Icons.calendar_today_rounded
                  : Icons.view_headline_rounded,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _groupMode = _groupMode == _GroupMode.session
                    ? _GroupMode.date
                    : _GroupMode.session;
              });
            },
          ),
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
      bottomNavigationBar: _buildBottomActionBar(),
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
                            child: CustomText(
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
                    onExtract: () => _extractSession(session, sessionNumber),
                    onSelect: () => _selectSession(session),
                    onDelete: () => _deleteSession(session, sessionNumber),
                  ),
                _DateHeaderItem(:final date, :final entryCount) =>
                  LogDateHeader(
                    date: date,
                    entryCount: entryCount,
                    isCollapsed: _collapsedDates.contains(_dateKey(date)),
                    onToggle: () => setState(() {
                      final key = _dateKey(date);
                      if (_collapsedDates.contains(key)) {
                        _collapsedDates.remove(key);
                      } else {
                        _collapsedDates.add(key);
                      }
                    }),
                    onExtract: () => _extractDate(date),
                    onSelect: () => _selectDate(date),
                    onDelete: () => _deleteDate(date),
                  ),
                _EntryItem(:final entry, :final sessionNumber) => LogEntryRow(
                    entry: entry,
                    sessionNumber: sessionNumber,
                    query: _query,
                    isSelected: _selectMode ? _selectedEntryIds.contains(entry.id) : null,
                    onSelectedChanged: _selectMode
                        ? (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedEntryIds.add(entry.id);
                              } else {
                                _selectedEntryIds.remove(entry.id);
                              }
                            });
                          }
                        : null,
                  ),
              };
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomActionBar() {
    if (!_selectMode) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            CustomText(
              '${_selectedEntryIds.length} selected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectMode = false;
                  _selectedEntryIds.clear();
                });
              },
              child: const CustomText(
                'Cancel',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            CustomButton(
              onPressed: _selectedEntryIds.isEmpty
                  ? null
                  : () {
                      final entries = _sessions
                          .expand((s) => s.entries)
                          .where((e) => _selectedEntryIds.contains(e.id))
                          .toList();
                      final text = DebugLogger.serializeEntriesToText(entries, title: 'Selected Logs');
                      DebugLogger.shareText(text, fileName: 'selected_logs.txt', subject: 'Selected Logs');
                    },
              label: 'Extract',
              fontSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
            const SizedBox(width: 8),
            CustomButton(
              onPressed: _selectedEntryIds.isEmpty
                  ? null
                  : () async {
                      final confirmed = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Delete Selected Logs'),
                          content: Text('Are you sure you want to delete ${_selectedEntryIds.length} selected log entries?'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        DebugLogger.store.deleteEntries(_selectedEntryIds);
                        setState(() {
                          _selectMode = false;
                          _selectedEntryIds.clear();
                        });
                      }
                    },
              label: 'Delete',
              fontSize: 12,
              backgroundColor: Colors.redAccent.withAlpha(40),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}
