import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Log level enum — used for writing, filtering, and colour-coding log lines.
// ---------------------------------------------------------------------------

/// Severity level for every log entry written by [DebugLogger].
enum LogLevel {
  /// General informational output (print captures, API traffic, etc.).
  info,

  /// Non-critical warnings or noteworthy state changes.
  medium,

  /// Recoverable errors (API errors, caught exceptions, etc.).
  error,

  /// Unrecoverable / fatal errors (Flutter framework errors, uncaught exceptions).
  critical;

  // ── Tag embedded in log lines ─────────────────────────────────────────────

  /// Short uppercase tag written into each log line, e.g. `[INFO]`.
  String get tag => switch (this) {
        LogLevel.info => '[INFO]',
        LogLevel.medium => '[MEDIUM]',
        LogLevel.error => '[ERROR]',
        LogLevel.critical => '[CRITICAL]',
      };

  // ── Display label for filter chips ────────────────────────────────────────

  /// Human-readable label shown in filter chips.
  String get label => switch (this) {
        LogLevel.info => 'Info',
        LogLevel.medium => 'Medium',
        LogLevel.error => 'Error',
        LogLevel.critical => 'Critical',
      };

  // ── Colour coding ─────────────────────────────────────────────────────────

  /// Text colour used in the log viewer for lines at this level.
  Color get color => switch (this) {
        LogLevel.info => const Color(0xFFCFD8DC), // white-ish
        LogLevel.medium => const Color(0xFFFFB74D), // orange
        LogLevel.error => const Color(0xFFEF5350), // red
        LogLevel.critical => const Color(0xFFEF5350), // red (same as error)
      };

  /// Chip accent colour (slightly more vivid than text colour).
  Color get chipColor => switch (this) {
        LogLevel.info => const Color(0xFFB0BEC5),
        LogLevel.medium => const Color(0xFFFF9800),
        LogLevel.error => const Color(0xFFF44336),
        LogLevel.critical => const Color(0xFFD32F2F),
      };

  // ── Reverse lookup: tag string → LogLevel ─────────────────────────────────

  /// Returns the [LogLevel] whose [tag] appears in [line], or `null`.
  static LogLevel? fromLine(String line) {
    for (final level in LogLevel.values) {
      if (line.contains(level.tag)) return level;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Log tag enum — fine-grained tag type for every distinct kind of log line.
// Each case owns its display colour; the viewer uses this instead of hardcoded
// Color() values.
// ---------------------------------------------------------------------------

/// Represents every distinct tag type that can appear in a log line.
///
/// Use [LogTag.fromLine] to identify which tag a line carries, then read
/// [LogTag.color] to obtain the correct display colour — no raw hex needed
/// in the viewer.
enum LogTag {
  /// Session separator line (`====` / `SESSION START`).
  separator,

  /// Outgoing API request — `[Request]`.
  request,

  /// Successful API response — `[Response]`.
  response,

  /// Request/response/error payload line.
  body,

  /// Generated cURL command.
  curl,

  /// Logger lifecycle message.
  logger,

  /// API response that contained an error body — `[Response Error]`.
  responseError,

  /// Network / HTTP failure — `[API Error]`.
  apiError,

  /// Flutter widget-tree / framework error — `[Flutter Error]`.
  flutterError,

  /// Uncaught Dart runtime exception — `[App Error]`.
  appError,

  /// Output from `print()` / `debugPrint()` — `[Print]`.
  printLog,

  /// Stack-trace lines (indented with spaces or `#n` prefix).
  stackTrace,

  /// Default — lines that carry no recognised tag.
  unknown;

  // ── Colour owned by each tag ──────────────────────────────────────────────

  /// The display colour for this tag type in the log viewer.
  Color get color => switch (this) {
        LogTag.separator => const Color(0xFFFFB74D), // amber
        LogTag.request => const Color(0xFF66BB6A), // green
        LogTag.response => const Color(0xFF42A5F5), // blue
        LogTag.body => const Color(0xFFB0BEC5), // cool-grey
        LogTag.curl => const Color(0xFFAB47BC), // purple
        LogTag.logger => const Color(0xFFFFB74D), // amber
        LogTag.responseError => const Color(0xFFFF7043), // deep-orange
        LogTag.apiError => const Color(0xFFEF5350), // red
        LogTag.flutterError => const Color(0xFFEF5350), // red
        LogTag.appError => const Color(0xFFEF5350), // red
        LogTag.printLog => const Color(0xFFB0BEC5), // cool-grey
        LogTag.stackTrace => const Color(0xFFB0BEC5), // cool-grey
        LogTag.unknown => const Color(0xFFCFD8DC), // light grey-blue
      };

  // ── Display label for filter chips ────────────────────────────────────────

  /// Human-readable label shown in filter chips / menu items.
  String get label => switch (this) {
        LogTag.separator => 'Session Separators',
        LogTag.request => 'API Requests',
        LogTag.response => 'API Responses',
        LogTag.body => 'Payload Bodies',
        LogTag.curl => 'cURL Commands',
        LogTag.logger => 'Logger Events',
        LogTag.responseError => 'Response Errors',
        LogTag.apiError => 'API/Network Errors',
        LogTag.flutterError => 'Flutter Errors',
        LogTag.appError => 'App Errors',
        LogTag.printLog => 'Console Prints',
        LogTag.stackTrace => 'Stack Traces',
        LogTag.unknown => 'Other Logs',
      };

  // ── Reverse lookup: message → LogTag ─────────────────────────────────────

  /// Identifies the [LogTag] for a raw [message] string (no timestamp/level prefix).
  ///
  /// Prefer this over [fromLine] when working with structured [LogEntry] data.
  /// Checked in priority order so `[Response Error]` is matched before `[Response]`.
  static LogTag fromMessage(String message) {
    if (message.contains('[Response Error]')) return LogTag.responseError;
    if (message.contains('[Request Body]') ||
        message.contains('[Response Body]') ||
        message.contains('[Error Body]')) return LogTag.body;
    if (message.contains('[cURL]')) return LogTag.curl;
    if (message.contains('[Logger]')) return LogTag.logger;
    if (message.contains('[Response]')) return LogTag.response;
    if (message.contains('[Request]')) return LogTag.request;
    if (message.contains('[API Error]')) return LogTag.apiError;
    if (message.contains('[Flutter Error]')) return LogTag.flutterError;
    if (message.contains('[App Error]')) return LogTag.appError;
    if (message.contains('[Print]')) return LogTag.printLog;
    if (message.trimLeft().startsWith('#') ||
        message.startsWith('    ') ||
        message.startsWith('\t')) return LogTag.stackTrace;
    return LogTag.unknown;
  }

  @Deprecated('Use LogTag.fromMessage() instead. fromLine() expects the old '
      'text-format line with timestamp/level prefix which no longer exists.')
  static LogTag fromLine(String line) {
    if (line.contains('====') || line.contains('SESSION START')) {
      return LogTag.separator;
    }
    if (line.contains('[Response Error]')) return LogTag.responseError;
    if (line.contains('[Request Body]') ||
        line.contains('[Response Body]') ||
        line.contains('[Error Body]')) return LogTag.body;
    if (line.contains('[cURL]')) return LogTag.curl;
    if (line.contains('[Logger]')) return LogTag.logger;
    if (line.contains('[Response]')) return LogTag.response;
    if (line.contains('[Request]')) return LogTag.request;
    if (line.contains('[API Error]')) return LogTag.apiError;
    if (line.contains('[Flutter Error]')) return LogTag.flutterError;
    if (line.contains('[App Error]')) return LogTag.appError;
    if (line.contains('[Print]')) return LogTag.printLog;
    if (line.trimLeft().startsWith('#') ||
        line.startsWith('    ') ||
        line.startsWith('\t')) {
      return LogTag.stackTrace;
    }
    return LogTag.unknown;
  }
}
