import '../log_level.dart';

class LogEntry {
  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    required this.sessionId,
    this.stackTrace,
    this.metadata = const {},
  });

  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final LogTag tag;
  final String message;
  final String sessionId;
  final String? stackTrace;
  final Map<String, dynamic> metadata;

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['ts'] as String),
      level: LogLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      tag: LogTag.values.firstWhere(
        (t) => t.name == json['tag'],
        orElse: () => LogTag.unknown,
      ),
      message: json['msg'] as String,
      sessionId: json['sessionId'] as String,
      stackTrace: json['stack'] as String?,
      metadata: Map<String, dynamic>.from(
        (json['meta'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': timestamp.toIso8601String(),
        'level': level.name,
        'tag': tag.name,
        'msg': message,
        'sessionId': sessionId,
        if (stackTrace != null) 'stack': stackTrace,
        if (metadata.isNotEmpty) 'meta': metadata,
      };

  /// Metadata keys used internally to recover full/raw text (e.g. for copy
  /// actions) that duplicate what's already shown via [fullMessage] or a
  /// dedicated copy button — kept out of any general metadata listing.
  static const Set<String> _internalMetadataKeys = {
    'curl',
    'fullMessage',
    'requestBody',
    'responseBody',
  };

  /// [metadata] with internal-only keys removed — use this wherever metadata
  /// is displayed or exported generically.
  Map<String, dynamic> get visibleMetadata => Map<String, dynamic>.fromEntries(
      metadata.entries.where((e) => !_internalMetadataKeys.contains(e.key)));

  /// The untruncated message, when [message] was shortened for display
  /// (e.g. a request/response body cut down to `maxBodyChars`). Falls back
  /// to [message] when nothing was truncated.
  String get fullMessage => (metadata['fullMessage'] as String?) ?? message;

  String formatAsText({required int sessionNumber}) {
    final buf = StringBuffer();
    buf.writeln('Time:    ${_formatTimestamp(timestamp)}');
    buf.writeln('Level:   ${level.label.toUpperCase()}');
    buf.writeln('Tag:     ${tag.label}');
    buf.writeln('Session: #$sessionNumber');
    buf.writeln('Message: $fullMessage');
    if (visibleMetadata.isNotEmpty) {
      final metaStr = visibleMetadata.entries
          .map((e) => '${e.key}=${e.value}')
          .join('  ');
      buf.writeln('Meta:    $metaStr');
    }
    if (stackTrace != null) {
      buf.writeln('Stack:');
      for (final line in stackTrace!.split('\n').where((l) => l.isNotEmpty)) {
        buf.writeln('  $line');
      }
    }
    return buf.toString().trimRight();
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
