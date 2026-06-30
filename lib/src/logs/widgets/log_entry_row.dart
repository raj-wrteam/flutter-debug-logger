import 'package:flutter/material.dart';

import '../../log_level.dart';
import '../../models/log_entry.dart';
import '../../shared/custom_text.dart';
import 'log_entry_detail_sheet.dart';

class LogEntryRow extends StatelessWidget {
  const LogEntryRow({
    super.key,
    required this.entry,
    required this.sessionNumber,
    required this.query,
  });

  final LogEntry entry;
  final int sessionNumber;
  final String query;

  static const _mono =
      TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5);

  String _slug() {
    final meta = entry.metadata;
    switch (entry.tag) {
      case LogTag.request:
        final method = meta['method'] as String?;
        final url = meta['url'] as String?;
        if (method != null && url != null) return '$method ${_pathOnly(url)}';
      case LogTag.response:
        final status = meta['statusCode'];
        final url = meta['url'] as String?;
        final ms = meta['durationMs'];
        if (status != null && url != null) {
          return '$status ${_pathOnly(url)}${ms != null ? '  ${ms}ms' : ''}';
        }
      case LogTag.apiError:
        final status = meta['statusCode'];
        final url = meta['url'] as String?;
        if (url != null)
          return status != null ? '$status ${_pathOnly(url)}' : _pathOnly(url);
      case LogTag.curl:
        final raw = _stripPrefix(entry.message);
        final mMatch = RegExp(r'-X\s+(\w+)').firstMatch(raw);
        final uMatch = RegExp(r"'(https?://[^'?]+)").firstMatch(raw);
        if (mMatch != null && uMatch != null) {
          return '${mMatch.group(1)} ${_pathOnly(uMatch.group(1)!)}';
        }
      default:
        break;
    }
    return _stripPrefix(entry.message);
  }

  static String _pathOnly(String url) {
    try {
      final p = Uri.parse(url).path;
      return p.isEmpty ? url : p;
    } catch (_) {
      return url;
    }
  }

  static String _stripPrefix(String msg) {
    const prefixes = [
      '[Response Error]',
      '[Request Body]',
      '[Response Body]',
      '[Error Body]',
      '[cURL]',
      '[Logger]',
      '[Response]',
      '[Request]',
      '[API Error]',
      '[Flutter Error]',
      '[App Error]',
      '[Print]',
      'EXCEPTION:',
    ];
    for (final p in prefixes) {
      if (msg.startsWith(p)) {
        msg = msg.substring(p.length).trim();
        break;
      }
    }
    return msg.replaceFirst(RegExp(r'^\[[^\]]*\]\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    final t = entry.timestamp;
    String p(int n) => n.toString().padLeft(2, '0');
    final time = '${p(t.hour)}:${p(t.minute)}:${p(t.second)}';

    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => LogEntryDetailSheet(
          entry: entry,
          sessionNumber: sessionNumber,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CustomText(
              time,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            _TagChip(tag: entry.tag),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHighlightedText(
                _slug(),
                _mono.copyWith(color: entry.tag.color),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, TextStyle style) {
    final q = query.trim();
    if (q.isEmpty) {
      return CustomText(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
      );
    }
    final lower = text.toLowerCase();
    final lowerQ = q.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final match = lower.indexOf(lowerQ, start);
      if (match < 0) break;
      if (match > start)
        spans.add(TextSpan(text: text.substring(start, match)));
      spans.add(TextSpan(
        text: text.substring(match, match + q.length),
        style: const TextStyle(
          color: Colors.black,
          backgroundColor: Colors.amberAccent,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = match + q.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return CustomText.rich(
      TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textScaler: TextScaler.noScaling,
    );
  }
}

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
      child: CustomText(
        tag.label,
        style: TextStyle(
          color: tag.color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
