import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../log_level.dart';
import '../models/log_entry.dart';

class LogEntryRow extends StatelessWidget {
  const LogEntryRow({
    super.key,
    required this.entry,
    required this.sessionNumber,
    required this.isExpanded,
    required this.isStackExpanded,
    required this.query,
    required this.onToggleExpand,
    required this.onToggleStack,
  });

  final LogEntry entry;
  final int sessionNumber;
  final bool isExpanded;
  final bool isStackExpanded;
  final String query;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleStack;

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    height: 1.55,
  );

  // ── Slug: smart one-liner for collapsed view ──────────────────────────────

  String _slug() {
    final meta = entry.metadata;

    switch (entry.tag) {
      case LogTag.request:
        final method = meta['method'] as String?;
        final url = meta['url'] as String?;
        if (method != null && url != null) {
          final path = _pathOnly(url);
          return '$method $path';
        }

      case LogTag.response:
        final status = meta['statusCode'];
        final url = meta['url'] as String?;
        final ms = meta['durationMs'];
        if (status != null && url != null) {
          final path = _pathOnly(url);
          return '$status $path${ms != null ? '  ${ms}ms' : ''}';
        }

      case LogTag.apiError:
        final status = meta['statusCode'];
        final url = meta['url'] as String?;
        if (url != null) {
          final path = _pathOnly(url);
          return status != null ? '$status $path' : path;
        }

      case LogTag.responseError:
        final url = meta['url'] as String?;
        final msg = meta['errorMessage'];
        if (url != null) return '$url${msg != null ? ' — $msg' : ''}';

      case LogTag.curl:
        // Pull method + path out of the curl command string
        final raw = _stripKnownPrefix(entry.message);
        final mMatch = RegExp(r'-X\s+(\w+)').firstMatch(raw);
        final uMatch = RegExp(r"'(https?://[^'?]+)").firstMatch(raw);
        if (mMatch != null && uMatch != null) {
          return '${mMatch.group(1)} ${_pathOnly(uMatch.group(1)!)}';
        }

      default:
        break;
    }

    // Fallback: strip known tag prefix from message
    return _stripKnownPrefix(entry.message);
  }

  static String _pathOnly(String url) {
    try {
      final path = Uri.parse(url).path;
      return path.isEmpty ? url : path;
    } catch (_) {
      return url;
    }
  }

  static String _stripKnownPrefix(String message) {
    const prefixes = [
      '[Response Error]', '[Request Body]', '[Response Body]', '[Error Body]',
      '[cURL]', '[Logger]', '[Response]', '[Request]', '[API Error]',
      '[Flutter Error]', '[App Error]', '[Print]', 'EXCEPTION:',
    ];
    String msg = message;
    for (final p in prefixes) {
      if (msg.startsWith(p)) {
        msg = msg.substring(p.length).trim();
        break;
      }
    }
    // Strip optional [interceptorTag] prefix added by FlutterDebugLogInterceptor
    return msg.replaceFirst(RegExp(r'^\[[^\]]*\]\s*'), '');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleExpand,
      onLongPress: () => _showActionSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isExpanded ? const Color(0xFF1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(),
            if (isExpanded) ...[
              const SizedBox(height: 4),
              _buildExpandedBody(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TagChip(tag: entry.tag),
        const SizedBox(width: 6),
        Expanded(
          child: _buildHighlightedText(
            isExpanded ? _stripKnownPrefix(entry.message) : _slug(),
            _mono.copyWith(color: entry.tag.color),
            maxLines: isExpanded ? null : 1,
          ),
        ),
        Icon(
          isExpanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          size: 14,
          color: Colors.white24,
        ),
      ],
    );
  }

  Widget _buildExpandedBody() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledField(
            label: 'Time',
            value: _formatTimestamp(entry.timestamp),
          ),
          _LabeledField(label: 'Session', value: '#$sessionNumber'),
          if (entry.metadata.isNotEmpty)
            _LabeledField(
              label: 'Meta',
              value: entry.metadata.entries
                  .map((e) => '${e.key}=${e.value}')
                  .join('  '),
            ),
          if (entry.stackTrace != null) _buildStackSection(),
        ],
      ),
    );
  }

  Widget _buildStackSection() {
    final lines = entry.stackTrace!
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();
    final visibleLines = isStackExpanded ? lines : lines.take(3).toList();
    final hasMore = lines.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text(
          'Stack:',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        ...visibleLines.map(
          (line) => Text(
            '  $line',
            style: _mono.copyWith(color: const Color(0xFFB0BEC5)),
            textScaler: TextScaler.noScaling,
          ),
        ),
        if (hasMore)
          GestureDetector(
            onTap: onToggleStack,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                isStackExpanded
                    ? 'Show less ▲'
                    : '… ${lines.length - 3} more frames ▼',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHighlightedText(
    String text,
    TextStyle style, {
    int? maxLines,
  }) {
    final q = query.trim();
    if (q.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow:
            maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
        textScaler: TextScaler.noScaling,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = q.toLowerCase();
    final children = <TextSpan>[];
    var start = 0;
    while (true) {
      final match = lowerText.indexOf(lowerQuery, start);
      if (match < 0) break;
      if (match > start) {
        children.add(TextSpan(text: text.substring(start, match)));
      }
      children.add(TextSpan(
        text: text.substring(match, match + q.length),
        style: const TextStyle(
          color: Colors.black,
          backgroundColor: Colors.amberAccent,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = match + q.length;
    }
    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start)));
    }
    return Text.rich(
      TextSpan(style: style, children: children),
      maxLines: maxLines,
      overflow:
          maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
      textScaler: TextScaler.noScaling,
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EntryActionSheet(
        entry: entry,
        sessionNumber: sessionNumber,
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});
  final LogTag tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: tag.color.withAlpha(30),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: tag.color.withAlpha(80), width: 0.5),
      ),
      child: Text(
        tag.label,
        style: TextStyle(
          color: tag.color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        textScaler: TextScaler.noScaling,
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '${label.padRight(8)}: ',
              style: const TextStyle(color: Colors.white38),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryActionSheet extends StatelessWidget {
  const _EntryActionSheet({
    required this.entry,
    required this.sessionNumber,
  });

  final LogEntry entry;
  final int sessionNumber;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy_rounded,
                  color: Colors.white70, size: 20),
              title: const Text('Copy entry',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () async {
                await Clipboard.setData(ClipboardData(
                  text: entry.formatAsText(sessionNumber: sessionNumber),
                ));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Entry copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined,
                  color: Colors.white70, size: 20),
              title: const Text('Export entry',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () async {
                Navigator.pop(context);
                await SharePlus.instance.share(ShareParams(
                  text: entry.formatAsText(sessionNumber: sessionNumber),
                  subject: 'Log Entry',
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
