import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'debug_logger.dart';
import 'log_level.dart';

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
  final Set<LogLevel> _activeFilters = {...LogLevel.values};

  List<String> _lines = const <String>[];
  bool _loading = true;
  bool _cleared = false;
  bool _latestFirst = false;
  bool _autoScroll = true;
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
    setState(() {
      _lines = lines;
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

  Future<void> _copyVisible() async {
    await _copyText(_visibleLines.join('\n'), 'Copied visible logs');
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
      builder: (_) => const _ShareConfirmSheet(),
    );
    if (ok != true || !mounted) return;

    await _exportLogs();
    await _clear();
  }

  void _toggleLogging() {
    setState(DebugLogger.toggleLogging);
  }

  void _toggleLatestFirst() {
    setState(() => _latestFirst = !_latestFirst);
    _scheduleAutoScroll(force: true);
  }

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
    _scheduleAutoScroll(force: true);
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
          IconButton(
            icon: Icon(
              DebugLogger.loggingActive
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              size: 20,
            ),
            tooltip:
                DebugLogger.loggingActive ? 'Stop logging' : 'Start logging',
            onPressed: _toggleLogging,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            tooltip: 'Copy all logs',
            onPressed: _hasLogs ? _copyAll : null,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_outlined, size: 20),
            tooltip: 'Export logs',
            onPressed: _hasLogs ? _exportLogs : null,
          ),
          PopupMenuButton<_LogAction>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            color: const Color(0xFF1A1A1A),
            onSelected: (action) {
              switch (action) {
                case _LogAction.copyVisible:
                  _copyVisible();
                case _LogAction.shareAndClear:
                  _shareAndClear();
                case _LogAction.clear:
                  _clear();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _LogAction.copyVisible,
                enabled: visibleLines.isNotEmpty,
                child:
                    const _MenuRow(Icons.content_copy_rounded, 'Copy visible'),
              ),
              PopupMenuItem(
                value: _LogAction.shareAndClear,
                enabled: _hasLogs,
                child: const _MenuRow(
                    Icons.delete_sweep_outlined, 'Share & clear'),
              ),
              PopupMenuItem(
                value: _LogAction.clear,
                enabled: _hasLogs,
                child:
                    const _MenuRow(Icons.delete_outline_rounded, 'Clear logs'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            query: _query,
            latestFirst: _latestFirst,
            autoScroll: _autoScroll,
            onChanged: (value) {
              setState(() => _query = value);
              _scheduleAutoScroll();
            },
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
              _scheduleAutoScroll();
            },
            onToggleLatestFirst: _toggleLatestFirst,
            onToggleAutoScroll: _toggleAutoScroll,
          ),
          _FilterBar(
            activeFilters: _activeFilters,
            onToggle: (level) {
              setState(() {
                if (_activeFilters.contains(level)) {
                  if (_activeFilters.length > 1) _activeFilters.remove(level);
                } else {
                  _activeFilters.add(level);
                }
              });
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
      return _EmptyState(text: _cleared ? 'Logs cleared.' : 'No logs yet.');
    }
    if (visibleLines.isEmpty) {
      return const _EmptyState(text: 'No matching logs.');
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

  // -- Filtering/search ------------------------------------------------------

  bool _linePassesFilter(String line) {
    if (_isSeparator(line)) return true;
    if (line.trim().isEmpty) return true;
    final level = LogLevel.fromLine(line);
    if (level == null) return _activeFilters.contains(LogLevel.info);
    return _activeFilters.contains(level);
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

enum _LogAction { copyVisible, shareAndClear, clear }

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.query,
    required this.latestFirst,
    required this.autoScroll,
    required this.onChanged,
    required this.onClear,
    required this.onToggleLatestFirst,
    required this.onToggleAutoScroll,
  });

  final TextEditingController controller;
  final String query;
  final bool latestFirst;
  final bool autoScroll;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onToggleLatestFirst;
  final VoidCallback onToggleAutoScroll;

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
          _ToggleIconButton(
            active: latestFirst,
            icon: Icons.vertical_align_top_rounded,
            tooltip: latestFirst ? 'Showing latest first' : 'Show latest first',
            onPressed: onToggleLatestFirst,
          ),
          const SizedBox(width: 4),
          _ToggleIconButton(
            active: autoScroll,
            icon: Icons.low_priority_rounded,
            tooltip:
                autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
            onPressed: onToggleAutoScroll,
          ),
        ],
      ),
    );
  }
}

class _ToggleIconButton extends StatelessWidget {
  const _ToggleIconButton({
    required this.active,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool active;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 19),
      color: active ? Colors.orangeAccent : Colors.white38,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeFilters,
    required this.onToggle,
  });

  final Set<LogLevel> activeFilters;
  final void Function(LogLevel) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          const Text(
            'Filter:',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: LogLevel.values.map((level) {
                  final active = activeFilters.contains(level);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _LevelChip(
                      level: level,
                      active: active,
                      onTap: () => onToggle(level),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.level,
    required this.active,
    required this.onTap,
  });

  final LogLevel level;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = level.chipColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:
              active ? chipColor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? chipColor : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          level.label,
          style: TextStyle(
            color: active ? chipColor : Colors.white30,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.article_outlined,
            color: Colors.white12,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareConfirmSheet extends StatelessWidget {
  const _ShareConfirmSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(
            Icons.delete_sweep_outlined,
            color: Colors.orangeAccent,
            size: 36,
          ),
          const SizedBox(height: 16),
          const Text(
            'Share & Clear Logs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The log file will be shared, then permanently '
            'deleted from this device. Use export if you want to keep it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Share & Clear',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
