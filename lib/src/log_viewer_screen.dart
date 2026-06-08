import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'debug_logger.dart';
import 'log_level.dart';
import 'widgets/log_search_bar.dart';
import 'widgets/log_menu_row.dart';
import 'widgets/log_empty_state.dart';
import 'widgets/log_share_confirm_sheet.dart';

/// Plain, zero-dependency log viewer.
///
/// App bar: logging toggle + refresh/copy/clear/share actions.
/// Controls: search, latest-first, and auto-scroll toggles.
/// Body: colour-coded selectable log lines rendered lazily.
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

  List<String> _lines = const <String>[];
  Map<String, int> _sessionNumbers = const <String, int>{};
  bool _loading = true;
  bool _cleared = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final lines = await DebugLogger.readLogLines();
    if (!mounted) return;
    final sessionNumbers = <String, int>{};
    var sessionCount = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('SESSION START')) {
        sessionCount++;
        sessionNumbers[line] = sessionCount;
      }
    }
    setState(() {
      _lines = lines;
      _sessionNumbers = sessionNumbers;
      _loading = false;
      _cleared = false;
    });
    _scheduleAutoScroll();
  }

  bool get _hasLogs => _lines.isNotEmpty && !_cleared;

  List<String> get _visibleLines {
    final filtered = _lines.where(_linePassesFilter).where(_lineMatchesSearch);
    return _latestFirst
        ? filtered.toList().reversed.toList()
        : filtered.toList();
  }

  // -- Actions ---------------------------------------------------------------

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _clear() async {
    await DebugLogger.clearFileAsync();
    if (!mounted) return;
    setState(() {
      _lines = const <String>[];
      _sessionNumbers = const <String, int>{};
      _cleared = true;
    });
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
    await _copyText(_lines.join('\n'), 'Copied all logs');
  }

  Future<void> _copyFiltered() async {
    await _copyText(_visibleLines.join('\n'), 'Copied filtered logs');
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

  void _toggleLogging() {
    setState(DebugLogger.toggleLogging);
  }

  void _selectAllTags() {
    setState(() {
      _activeTags.addAll(LogTag.values);
    });
    _scheduleAutoScroll();
  }

  void _deselectAllTags() {
    setState(() {
      _activeTags.clear();
    });
    _scheduleAutoScroll();
  }

  void _toggleLatestFirst() {
    setState(() => _latestFirst = !_latestFirst);
    _scheduleAutoScroll(force: true);
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
    if (_autoScroll) {
      _scheduleAutoScroll(force: true);
    }
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

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visibleLines = _visibleLines;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug Logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (!_loading)
              Text(
                '${_fileSizeLabel()}  |  ${visibleLines.length}/${_lines.length} lines',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
          ],
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
                case _LogAction.refresh:
                  _refresh();
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
              PopupMenuItem(
                value: _LogAction.refresh,
                child: const LogMenuRow(Icons.refresh_rounded, 'Refresh'),
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
                enabled: visibleLines.isNotEmpty,
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
          Expanded(child: _buildBody(visibleLines)),
        ],
      ),
    );
  }

  Widget _buildBody(List<String> visibleLines) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }
    if (!_hasLogs) {
      return LogEmptyState(text: _cleared ? 'Logs cleared.' : 'No logs yet.');
    }
    if (visibleLines.isEmpty) {
      return const LogEmptyState(text: 'No matching logs.');
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SelectionArea(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          itemCount: visibleLines.length,
          itemBuilder: (context, index) {
            final line = visibleLines[index];
            if (line.contains('SESSION START')) {
              return _buildSessionDivider(line);
            }
            return Text.rich(
              _buildLineSpan(line),
              style: _mono,
              textScaler: TextScaler.noScaling,
            );
          },
        ),
      ),
    );
  }

  String? _parseSessionTimestamp(String line) {
    final pattern = RegExp(r'SESSION START\s+(.+)');
    final match = pattern.firstMatch(line);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }

  String _formatDateTime(DateTime dt) {
    final months = [
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
      'Dec'
    ];
    final year = dt.year;
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');

    final hourNum = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year • $hourNum:$minute:$second $ampm';
  }

  Widget _buildSessionDivider(String line) {
    final timestampStr = _parseSessionTimestamp(line);
    String displayStr = line.trim();
    if (timestampStr != null) {
      final dt = DateTime.tryParse(timestampStr);
      if (dt != null) {
        final formattedDate = _formatDateTime(dt);
        final sessionNum = _sessionNumbers[line];
        if (sessionNum != null) {
          displayStr = 'SESSION #$sessionNum  •  $formattedDate';
        } else {
          displayStr = 'SESSION START  •  $formattedDate';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              color: Colors.white12,
              thickness: 1,
              endIndent: 12,
            ),
          ),
          Text(
            displayStr,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFB74D),
              letterSpacing: 0.8,
            ),
          ),
          const Expanded(
            child: Divider(
              color: Colors.white12,
              thickness: 1,
              indent: 12,
            ),
          ),
        ],
      ),
    );
  }

  // -- Filtering/search ------------------------------------------------------

  bool _linePassesFilter(String line) {
    if (line.trim().isEmpty) return true;
    if (line.contains('====')) return false;
    final level = LogLevel.fromLine(line);
    final levelPasses = level == null
        ? _activeFilters.contains(LogLevel.info)
        : _activeFilters.contains(level);
    if (!levelPasses) return false;

    final tag = LogTag.fromLine(line);
    return _activeTags.contains(tag);
  }

  bool _lineMatchesSearch(String line) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    return line.toLowerCase().contains(q.toLowerCase());
  }

  // -- Colourised log lines --------------------------------------------------

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    height: 1.55,
  );

  TextSpan _buildLineSpan(String line) {
    final style = _mono.copyWith(
      color: _colorFor(line),
      fontWeight: _isSeparator(line) ? FontWeight.w700 : FontWeight.w400,
    );
    final q = _query.trim();
    if (q.isEmpty) return TextSpan(text: line, style: style);

    final lowerLine = line.toLowerCase();
    final lowerQuery = q.toLowerCase();
    final children = <TextSpan>[];
    var start = 0;
    while (true) {
      final match = lowerLine.indexOf(lowerQuery, start);
      if (match < 0) break;
      if (match > start) {
        children.add(TextSpan(text: line.substring(start, match)));
      }
      children.add(
        TextSpan(
          text: line.substring(match, match + q.length),
          style: const TextStyle(
            color: Colors.black,
            backgroundColor: Colors.amberAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = match + q.length;
    }
    if (start < line.length)
      children.add(TextSpan(text: line.substring(start)));
    return TextSpan(style: style, children: children);
  }

  static bool _isSeparator(String line) =>
      LogTag.fromLine(line) == LogTag.separator;

  static Color _colorFor(String line) => LogTag.fromLine(line).color;

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
  refresh,
  copyAll,
  export,
  copyFiltered,
  shareAndClear,
  clear,
}
