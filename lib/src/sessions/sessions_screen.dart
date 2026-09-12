import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../debug_logger.dart';
import '../logs/all_logs_screen.dart';
import '../models/log_session.dart';
import '../shared/app_colors.dart';
import '../shared/custom_app_bar.dart';
import '../shared/custom_button.dart';
import '../shared/custom_text.dart';
import '../shared/log_empty_state.dart';
import '../shared/debug_scope.dart';

// ── Display item sealed class ─────────────────────────────────────────────────

sealed class _DisplayItem {}

final class _DateGroupItem extends _DisplayItem {
  _DateGroupItem(this.date, this.sessions);
  final DateTime date;
  final List<LogSession> sessions;
}

final class _SessionItem extends _DisplayItem {
  _SessionItem(this.session, this.sessionNumber);
  final LogSession session;
  final int sessionNumber;
}

enum _GroupMode { flat, date }

// ── Screen ────────────────────────────────────────────────────────────────────

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _selectMode = false;
  final Set<String> _selectedSessionIds = {};
  final Set<String> _collapsedDates = {};
  _GroupMode _groupMode = _GroupMode.flat;

  // ── Selection helpers ─────────────────────────────────────────────────────

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedSessionIds.clear();
    });
  }

  void _toggleSession(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  void _selectAll(List<LogSession> sessions) {
    setState(() {
      _selectedSessionIds.addAll(sessions.map((s) => s.id));
    });
  }

  void _selectDateGroup(List<LogSession> sessions) {
    setState(() {
      _selectMode = true;
      _selectedSessionIds.addAll(sessions.map((s) => s.id));
    });
  }

  void _deselectAll() {
    setState(() => _selectedSessionIds.clear());
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _deleteSelected() async {
    if (_selectedSessionIds.isEmpty) return;
    final count = _selectedSessionIds.length;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Sessions'),
        content: Text(
          'Delete $count session${count > 1 ? 's' : ''} and all their log entries?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final id in _selectedSessionIds.toList()) {
        DebugLogger.store.deleteSession(id);
      }
      setState(() {
        _selectMode = false;
        _selectedSessionIds.clear();
      });
    }
  }

  Future<void> _deleteDateGroup(
    DateTime date,
    List<LogSession> sessions,
  ) async {
    final label = _formatDateLabel(date);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Sessions'),
        content: Text(
          'Delete all ${sessions.length} session${sessions.length > 1 ? 's' : ''} from $label?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final s in sessions) {
        DebugLogger.store.deleteSession(s.id);
      }
    }
  }

  Future<void> _extractSelected() async {
    if (_selectedSessionIds.isEmpty) return;
    final sessions = DebugLogger.store.sessions
        .where((s) => _selectedSessionIds.contains(s.id))
        .toList();
    final allEntries = sessions.expand((s) => s.entries).toList();
    if (allEntries.isEmpty) return;
    final text = DebugLogger.serializeEntriesToText(
      allEntries,
      title:
          '${sessions.length} Session${sessions.length > 1 ? 's' : ''} — Exported Logs',
    );
    DebugLogger.shareText(
      text,
      fileName: 'sessions_export.txt',
      subject: 'Exported Sessions',
    );
  }

  void _extractDateGroup(DateTime date, List<LogSession> sessions) {
    final allEntries = sessions.expand((s) => s.entries).toList();
    if (allEntries.isEmpty) return;
    final label = _formatDateLabel(date);
    final text = DebugLogger.serializeEntriesToText(
      allEntries,
      title: 'Sessions from $label',
    );
    DebugLogger.shareText(
      text,
      fileName: 'sessions_$label.txt',
      subject: 'Sessions from $label',
    );
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  List<_DisplayItem> _buildDisplayItems(List<LogSession> sessions) {
    final allSessions = DebugLogger.store.sessions;

    if (_groupMode == _GroupMode.flat) {
      return sessions
          .map((s) => _SessionItem(s, allSessions.indexOf(s) + 1))
          .toList();
    }

    // Date grouping
    final Map<DateTime, List<LogSession>> grouped = {};
    for (final s in sessions) {
      final date = DateTime(
        s.startTime.year,
        s.startTime.month,
        s.startTime.day,
      );
      grouped.putIfAbsent(date, () => []).add(s);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // latest first

    final items = <_DisplayItem>[];
    for (final date in sortedDates) {
      final dateSessions = grouped[date]!;
      items.add(_DateGroupItem(date, dateSessions));
      if (_collapsedDates.contains(_dateKey(date))) continue;
      for (final s in dateSessions) {
        items.add(_SessionItem(s, allSessions.indexOf(s) + 1));
      }
    }
    return items;
  }

  static String _formatDateLabel(DateTime dt) {
    const months = [
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
      'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DebugSurface(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Sessions',
          actions: [
            IconButton(
              icon: Icon(
                _groupMode == _GroupMode.flat
                    ? Icons.calendar_today_rounded
                    : Icons.view_headline_rounded,
                size: 20,
              ),
              tooltip: _groupMode == _GroupMode.flat
                  ? 'Group by date'
                  : 'Flat list',
              onPressed: () => setState(() {
                _groupMode = _groupMode == _GroupMode.flat
                    ? _GroupMode.date
                    : _GroupMode.flat;
              }),
            ),
            IconButton(
              icon: Icon(
                _selectMode ? Icons.close_rounded : Icons.checklist_rounded,
                size: 20,
              ),
              onPressed: _toggleSelectMode,
            ),
          ],
        ),
        bottomNavigationBar: _selectMode ? _buildBottomBar() : null,
        body: ListenableBuilder(
          listenable: DebugLogger.store,
          builder: (context, _) {
            final sessions = DebugLogger.store.sessions.reversed.toList();
            if (sessions.isEmpty) {
              return const LogEmptyState(text: 'No sessions yet.');
            }
            final items = _buildDisplayItems(sessions);
            return Column(
              children: [
                if (_selectMode)
                  _SelectionToolbar(
                    selectedCount: _selectedSessionIds.length,
                    totalCount: sessions.length,
                    allSelected: _selectedSessionIds.length == sessions.length,
                    onSelectAll: () => _selectAll(sessions),
                    onDeselectAll: _deselectAll,
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return switch (item) {
                        _DateGroupItem(:final date, :final sessions) =>
                          _DateGroupHeader(
                            date: date,
                            sessionCount: sessions.length,
                            entryCount: sessions.fold(
                              0,
                              (sum, s) => sum + s.entries.length,
                            ),
                            isCollapsed: _collapsedDates.contains(
                              _dateKey(date),
                            ),
                            onToggle: () => setState(() {
                              final key = _dateKey(date);
                              if (_collapsedDates.contains(key)) {
                                _collapsedDates.remove(key);
                              } else {
                                _collapsedDates.add(key);
                              }
                            }),
                            onExtract: () => _extractDateGroup(date, sessions),
                            onSelect: () => _selectDateGroup(sessions),
                            onDelete: () => _deleteDateGroup(date, sessions),
                          ),
                        _SessionItem(:final session, :final sessionNumber) =>
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: 8,
                              left: _groupMode == _GroupMode.date ? 8 : 0,
                            ),
                            child: _SessionCard(
                              session: session,
                              sessionNumber: sessionNumber,
                              selectMode: _selectMode,
                              isSelected: _selectedSessionIds.contains(
                                session.id,
                              ),
                              onTap: _selectMode
                                  ? () => _toggleSession(session.id)
                                  : () => Navigator.push(
                                      context,
                                      debugPageRoute(
                                        AllLogsScreen(sessionId: session.id),
                                      ),
                                    ),
                            ),
                          ),
                      };
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final count = _selectedSessionIds.length;
    final hasSelection = count > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: CustomButton(
                onPressed: hasSelection ? _extractSelected : null,
                icon: Icons.ios_share_outlined,
                label: 'Extract',
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                onPressed: hasSelection ? _deleteSelected : null,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                fontSize: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selection toolbar ─────────────────────────────────────────────────────────

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  final int selectedCount;
  final int totalCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.elevated,
      child: Row(
        children: [
          CustomText(
            '$selectedCount / $totalCount selected',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: allSelected ? onDeselectAll : onSelectAll,
            child: CustomText(
              allSelected ? 'Deselect All' : 'Select All',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date group header ─────────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({
    required this.date,
    required this.sessionCount,
    required this.entryCount,
    required this.isCollapsed,
    required this.onToggle,
    this.onExtract,
    this.onSelect,
    this.onDelete,
  });

  final DateTime date;
  final int sessionCount;
  final int entryCount;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final VoidCallback? onExtract;
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;

  bool get _hasActions =>
      onExtract != null || onSelect != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    _SessionsScreenState._formatDateLabel(date),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 3),
                  CustomText(
                    '$sessionCount session${sessionCount > 1 ? 's' : ''}  ·  $entryCount entries',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isCollapsed
                  ? Icons.keyboard_arrow_right_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.white38,
            ),
            if (_hasActions) ...[
              const SizedBox(width: 4),
              _ActionMenu(
                onExtract: onExtract,
                onSelect: onSelect,
                onDelete: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Compact action menu ───────────────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({this.onExtract, this.onSelect, this.onDelete});

  final VoidCallback? onExtract;
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert_rounded,
          size: 16,
          color: Colors.white38,
        ),
        iconSize: 16,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 140),
        position: PopupMenuPosition.under,
        color: AppColors.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white10),
        ),
        onSelected: (value) {
          switch (value) {
            case 'extract':
              onExtract?.call();
            case 'select':
              onSelect?.call();
            case 'delete':
              onDelete?.call();
          }
        },
        itemBuilder: (context) => [
          if (onExtract != null)
            const PopupMenuItem(
              value: 'extract',
              height: 36,
              child: Row(
                children: [
                  Icon(
                    Icons.ios_share_outlined,
                    size: 14,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 10),
                  CustomText(
                    'Extract',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
          if (onSelect != null)
            const PopupMenuItem(
              value: 'select',
              height: 36,
              child: Row(
                children: [
                  Icon(
                    Icons.check_box_outlined,
                    size: 14,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 10),
                  CustomText(
                    'Select All',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
          if (onDelete != null)
            const PopupMenuItem(
              value: 'delete',
              height: 36,
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  SizedBox(width: 10),
                  CustomText(
                    'Delete',
                    style: TextStyle(fontSize: 13, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.sessionNumber,
    required this.selectMode,
    required this.isSelected,
    required this.onTap,
  });

  final LogSession session;
  final int sessionNumber;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orangeAccent.withAlpha(15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.orangeAccent.withAlpha(80)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            if (selectMode) ...[
              Icon(
                isSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: isSelected ? Colors.orangeAccent : Colors.white24,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent.withAlpha(60)),
              ),
              child: Center(
                child: CustomText(
                  '#$sessionNumber',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    _formatHeader(session.startTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  CustomText(
                    '${session.entries.length} entries',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            if (!selectMode)
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  static String _formatHeader(DateTime dt) {
    const months = [
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
      'Dec',
    ];
    String p(int n) => n.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  ·  ${p(dt.hour)}:${p(dt.minute)}';
  }
}
