import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'debug_logger.dart';
import 'log_level.dart';
import 'models/log_entry.dart';
import 'models/log_session.dart';
import 'widgets/log_entry_row.dart';
import 'widgets/log_menu_row.dart';
import 'widgets/log_empty_state.dart';
import 'widgets/log_search_bar.dart';
import 'widgets/log_session_header.dart';
import 'widgets/log_share_confirm_sheet.dart';

// ── Display item sealed class ─────────────────────────────────────────────────

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

/// Plain, zero-dependency log viewer.
///
/// Reacts live to [DebugLogger.store] via [ListenableBuilder].
/// App bar: logging toggle + copy/clear/share actions.
/// Controls: search and filter by level/tag.
/// Body: colour-coded, expandable log entries grouped by session.
class DebugLogViewerScreen extends StatefulWidget {
  const DebugLogViewerScreen({super.key});

  @override
  State<DebugLogViewerScreen> createState() => _DebugLogViewerScreenState();
}

class _DebugLogViewerScreenState extends State<DebugLogViewerScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  static final Set<LogLevel> _activeFilters = {...LogLevel.values};
  static final Set<LogTag> _activeTags = {...LogTag.values};
  static bool _latestFirst = false;
  static bool _autoScroll = true;

  final Set<String> _collapsedSessions = {};
  final Set<String> _expandedEntries = {}; // IDs of entries currently expanded
  final Set<String> _expandedStacks =
      {}; // IDs of entries with full stack visible

  bool _cleared = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Display items ─────────────────────────────────────────────────────────

  List<_DisplayItem> _buildDisplayItems() {
    final sessions = DebugLogger.store.sessions;
    final items = <_DisplayItem>[];

    for (var si = 0; si < sessions.length; si++) {
      final session = sessions[si];
      final sessionNumber = si + 1;
      items.add(_SessionHeaderItem(session, sessionNumber));

      if (_collapsedSessions.contains(session.id)) continue;

      final entries = session.entries
          .where(_entryPassesFilter)
          .where(_entryMatchesSearch)
          .toList();

      final ordered = _latestFirst ? entries.reversed.toList() : entries;
      for (final entry in ordered) {
        items.add(_EntryItem(entry, sessionNumber));
      }
    }

    return _latestFirst ? _reverseSessionBlocks(items) : items;
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

  // ── Filtering / search ────────────────────────────────────────────────────

  bool _entryPassesFilter(LogEntry entry) {
    if (!_activeFilters.contains(entry.level)) return false;
    return _activeTags.contains(entry.tag);
  }

  bool _entryMatchesSearch(LogEntry entry) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    return entry.message.toLowerCase().contains(q.toLowerCase());
  }

  // ── Aggregate helpers ─────────────────────────────────────────────────────

  bool get _hasLogs => DebugLogger.store.sessions.isNotEmpty && !_cleared;

  int get _totalEntries =>
      DebugLogger.store.sessions.fold(0, (sum, s) => sum + s.entries.length);

  int get _visibleEntries =>
      _buildDisplayItems().whereType<_EntryItem>().length;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _clear() async {
    await DebugLogger.clearFileAsync();
    if (!mounted) return;
    setState(() => _cleared = true);
  }

  Future<void> _copyText(String text, String message) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyAll() async {
    final text = DebugLogger.store.sessions
        .asMap()
        .entries
        .map((e) => e.value.formatAsText(e.key + 1))
        .join('\n\n');
    await _copyText(text, 'Copied all logs');
  }

  Future<void> _copyFiltered() async {
    final items = _buildDisplayItems().whereType<_EntryItem>();
    final text = items
        .map((i) => i.entry.formatAsText(sessionNumber: i.sessionNumber))
        .join('\n\n');
    await _copyText(text, 'Copied filtered logs');
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
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const LogShareConfirmSheet(),
    );
    if (ok != true || !mounted) return;
    await _exportLogs();
    await _clear();
  }

  void _toggleLogging() => setState(DebugLogger.toggleLogging);

  void _selectAllTags() {
    setState(() => _activeTags.addAll(LogTag.values));
    _scheduleAutoScroll();
  }

  void _deselectAllTags() {
    setState(() => _activeTags.clear());
    _scheduleAutoScroll();
  }

  void _toggleLatestFirst() {
    setState(() => _latestFirst = !_latestFirst);
    _scheduleAutoScroll(force: true);
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
    if (_autoScroll) _scheduleAutoScroll(force: true);
  }

  void _scheduleAutoScroll({bool force = false}) {
    if (!_autoScroll && !force) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final target =
          _latestFirst ? position.minScrollExtent : position.maxScrollExtent;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        foregroundColor: Colors.white,
        elevation: 0,
        title: ListenableBuilder(
          listenable: DebugLogger.store,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Debug Logs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                '${_fileSizeLabel()}  |  $_visibleEntries/$_totalEntries entries',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<_LogAction>(
            tooltip: 'Actions',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            color: const Color(0xFF1A1A1A),
            onSelected: (action) {
              switch (action) {
                case _LogAction.toggleLogging:
                  _toggleLogging();
                case _LogAction.toggleLatestFirst:
                  _toggleLatestFirst();
                case _LogAction.toggleAutoScroll:
                  _toggleAutoScroll();
                case _LogAction.copyAll:
                  _copyAll();
                case _LogAction.copyFiltered:
                  _copyFiltered();
                case _LogAction.export:
                  _exportLogs();
                case _LogAction.shareAndClear:
                  _shareAndClear();
                case _LogAction.clear:
                  _clear();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _LogAction.toggleLogging,
                child: LogMenuRow(
                  DebugLogger.loggingActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  DebugLogger.loggingActive ? 'Stop logging' : 'Start logging',
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: _LogAction.toggleLatestFirst,
                child: LogMenuRow(
                  _latestFirst
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  'Latest first',
                  iconColor:
                      _latestFirst ? Colors.orangeAccent : Colors.white38,
                ),
              ),
              PopupMenuItem(
                value: _LogAction.toggleAutoScroll,
                child: LogMenuRow(
                  _autoScroll
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  'Auto-scroll',
                  iconColor: _autoScroll ? Colors.orangeAccent : Colors.white38,
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: _LogAction.copyAll,
                enabled: _hasLogs,
                child:
                    const LogMenuRow(Icons.copy_all_outlined, 'Copy all logs'),
              ),
              PopupMenuItem(
                value: _LogAction.copyFiltered,
                enabled: _hasLogs,
                child: const LogMenuRow(
                    Icons.content_copy_rounded, 'Copy filtered'),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: _LogAction.export,
                enabled: _hasLogs,
                child:
                    const LogMenuRow(Icons.ios_share_outlined, 'Export logs'),
              ),
              PopupMenuItem(
                value: _LogAction.shareAndClear,
                enabled: _hasLogs,
                child: const LogMenuRow(
                    Icons.delete_sweep_outlined, 'Share & clear'),
              ),
              PopupMenuItem(
                value: _LogAction.clear,
                enabled: _hasLogs,
                child: const LogMenuRow(
                    Icons.delete_outline_rounded, 'Clear logs'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          LogSearchBar(
            controller: _searchController,
            query: _query,
            activeFilters: _activeFilters,
            onToggleFilter: (level) {
              setState(() {
                if (_activeFilters.contains(level)) {
                  if (_activeFilters.length > 1) _activeFilters.remove(level);
                } else {
                  _activeFilters.add(level);
                }
              });
              _scheduleAutoScroll();
            },
            activeTags: _activeTags,
            onToggleTag: (tag) {
              setState(() {
                if (_activeTags.contains(tag)) {
                  if (_activeTags.length > 1) _activeTags.remove(tag);
                } else {
                  _activeTags.add(tag);
                }
              });
              _scheduleAutoScroll();
            },
            onSelectAllTags: _selectAllTags,
            onDeselectAllTags: _deselectAllTags,
            onChanged: (value) {
              setState(() => _query = value);
              _scheduleAutoScroll();
            },
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
              _scheduleAutoScroll();
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Entire body is reactive — ListenableBuilder wraps all states so that
    // the "No logs yet" → list transition fires when the store gains entries.
    return ListenableBuilder(
      listenable: DebugLogger.store,
      builder: (context, _) {
        if (!_hasLogs) {
          return LogEmptyState(
              text: _cleared ? 'Logs cleared.' : 'No logs yet.');
        }
        final items = _buildDisplayItems();
        // Check filtered entries across ALL sessions regardless of collapse state
        // so collapsing sessions doesn't trigger "No matching logs".
        final hasFilteredEntries = DebugLogger.store.sessions
            .expand((s) => s.entries)
            .any((e) => _entryPassesFilter(e) && _entryMatchesSearch(e));
        if (!hasFilteredEntries) {
          return const LogEmptyState(text: 'No matching logs.');
        }
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scheduleAutoScroll());
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
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
                    isExpanded: _expandedEntries.contains(entry.id),
                    isStackExpanded: _expandedStacks.contains(entry.id),
                    query: _query,
                    onToggleExpand: () => setState(() {
                      if (_expandedEntries.contains(entry.id)) {
                        _expandedEntries.remove(entry.id);
                      } else {
                        _expandedEntries.add(entry.id);
                      }
                    }),
                    onToggleStack: () => setState(() {
                      if (_expandedStacks.contains(entry.id)) {
                        _expandedStacks.remove(entry.id);
                      } else {
                        _expandedStacks.add(entry.id);
                      }
                    }),
                  ),
              };
            },
          ),
        );
      },
    );
  }

  String _fileSizeLabel() {
    final bytes = DebugLogger.fileSizeBytes;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
}

enum _LogAction {
  toggleLogging,
  toggleLatestFirst,
  toggleAutoScroll,
  copyAll,
  copyFiltered,
  export,
  shareAndClear,
  clear,
}
