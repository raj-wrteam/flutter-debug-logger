import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'log_level.dart';
import 'log_store.dart';
import 'models/log_entry.dart';
import 'models/log_session.dart';

// ---------------------------------------------------------------------------
// Build-time flag:  flutter build apk --dart-define=FLUTTER_DEBUG_LOGGER=true
// In kDebugMode the logger is ALWAYS active regardless of the flag.
// ---------------------------------------------------------------------------
const bool _kFlagEnabled =
    bool.fromEnvironment('FLUTTER_DEBUG_LOGGER', defaultValue: false);

/// Returns true when the logger should be active.
bool get flutterDebugLoggerEnabled => kDebugMode || _kFlagEnabled;

/// Persistent, structured debug logger.
///
/// - Thread-safe for typical Flutter single-isolate usage.
/// - Silently no-ops when [flutterDebugLoggerEnabled] is false.
/// - Captures `print` / `debugPrint` when you install [DebugLogger.capturePrint].
/// - Captures Flutter framework errors via [DebugLogger.captureFlutterErrors].
/// - Captures uncaught async/Dart errors via [DebugLogger.captureUncaughtErrors].
/// - [store] is a [LogStore] (ChangeNotifier) — attach a ListenableBuilder to
///   receive live updates in the log viewer.
class DebugLogger {
  DebugLogger._();

  // ── Public store — viewer attaches ListenableBuilder to this ──────────────
  static final LogStore store = LogStore();

  // ── Internal state ────────────────────────────────────────────────────────
  static File? _logFile;
  static Directory? _logDirectory;
  static bool _initialized = false;
  static bool _loggingActive = true;
  static int _maxLogBytes = 1024 * 1024;
  static int _maxBackupFiles = 2;
  static Future<void> _pendingWrite = Future<void>.value();
  static DebugPrintCallback? _previousDebugPrint;
  static bool _printCaptured = false;
  static String? _currentSessionId;
  static int _idCounter = 0;

  // ── ID generation ─────────────────────────────────────────────────────────

  static String _generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = math.Random().nextInt(0xFFFF);
    return '${ts.toRadixString(16)}-${(_idCounter++).toRadixString(16)}-${rand.toRadixString(16)}';
  }

  // ── Initialization ────────────────────────────────────────────────────────

  /// Call once inside your `main()` or app-init function.
  ///
  /// ```dart
  /// await DebugLogger.init();
  /// ```
  static Future<void> init({
    bool captureFlutter = true,
    bool captureUncaught = true,
    bool startEnabled = true,
    int maxLogBytes = 1024 * 1024,
    int maxBackupFiles = 2,
    String fileName = 'flutter_debug_logs.jsonl',
  }) async {
    if (!flutterDebugLoggerEnabled) return;
    try {
      _maxLogBytes = maxLogBytes;
      _maxBackupFiles = maxBackupFiles.clamp(0, 99).toInt();
      _loggingActive = startEnabled;

      if (_initialized) return;

      _logDirectory = await getApplicationDocumentsDirectory();
      final path = '${_logDirectory!.path}/$fileName';
      _logFile = File(path);
      await _logFile!.create(recursive: true);
      _initialized = true;

      // Replay existing file into store BEFORE starting a new session.
      await _replayFile();

      // Start new session.
      _currentSessionId = _generateId();
      final sessionStart = DateTime.now();
      store.startSession(_currentSessionId!, sessionStart);
      _queueSessionStartFlush(_currentSessionId!, sessionStart);

      capturePrint();
      if (captureFlutter) captureFlutterErrors();
      if (captureUncaught) captureUncaughtErrors();
    } on Exception catch (e) {
      debugPrint('DebugLogger.init failed: $e');
    }
  }

  // ── Writing ───────────────────────────────────────────────────────────────

  /// Appends a timestamped log entry tagged with [level].
  static void write(String line, {LogLevel level = LogLevel.info}) {
    writeStructured(message: line, level: level);
  }

  /// Logs a caught error/exception with an optional stack trace at [LogLevel.error].
  ///
  /// ```dart
  /// try { … } catch (e, st) { DebugLogger.writeError(e, st); }
  /// ```
  static void writeError(
    Object error, [
    StackTrace? stackTrace,
    LogLevel level = LogLevel.error,
  ]) {
    writeStructured(
      message: 'EXCEPTION: $error',
      level: level,
      stackTrace: stackTrace?.toString(),
    );
  }

  // ── Socket logging ───────────────────────────────────────────────────────

  static const int _maxSocketDataChars = 2000;

  /// Formats [data] for a socket log line: JSON-encodes Map/List, otherwise
  /// `toString()`s it, then truncates to [_maxSocketDataChars].
  static String _formatSocketData(dynamic data) {
    if (data == null) return '<empty>';
    final text = (data is Map || data is List) ? jsonEncode(data) : '$data';
    if (text.length <= _maxSocketDataChars) return text;
    final omitted = text.length - _maxSocketDataChars;
    return '${text.substring(0, _maxSocketDataChars)}... (+$omitted chars)';
  }

  /// Logs a socket connection being opened.
  ///
  /// ```dart
  /// DebugLogger.logSocketConnect('wss://example.com/ws');
  /// ```
  static void logSocketConnect(
    String url, {
    Map<String, dynamic> metadata = const {},
  }) {
    writeStructured(
      message: '[Socket Connect] $url',
      level: LogLevel.info,
      tag: LogTag.socketConnect,
      metadata: {'url': url, ...metadata},
    );
  }

  /// Logs a socket connection being closed.
  static void logSocketDisconnect(
    String url, {
    String? reason,
    Map<String, dynamic> metadata = const {},
  }) {
    writeStructured(
      message: '[Socket Disconnect] $url${reason != null ? ' — $reason' : ''}',
      level: LogLevel.medium,
      tag: LogTag.socketDisconnect,
      metadata: {'url': url, if (reason != null) 'reason': reason, ...metadata},
    );
  }

  /// Logs an outgoing socket message.
  ///
  /// [event] is the message/event name (e.g. `'chat.message'`); [data] is
  /// the payload (any type — Map/List are JSON-encoded).
  static void logSocketSend(String event, {dynamic data, String? url}) {
    writeStructured(
      message: '[Socket Send] $event${url != null ? ' → $url' : ''} '
          '${_formatSocketData(data)}',
      level: LogLevel.info,
      tag: LogTag.socketSend,
      metadata: {
        'event': event,
        if (url != null) 'url': url,
        if (data != null) 'data': data,
      },
    );
  }

  /// Logs an incoming socket message.
  static void logSocketReceive(String event, {dynamic data, String? url}) {
    writeStructured(
      message: '[Socket Receive] $event${url != null ? ' ← $url' : ''} '
          '${_formatSocketData(data)}',
      level: LogLevel.info,
      tag: LogTag.socketReceive,
      metadata: {
        'event': event,
        if (url != null) 'url': url,
        if (data != null) 'data': data,
      },
    );
  }

  /// Logs a custom/named socket event that isn't a plain send or receive —
  /// e.g. typing indicators or online/offline presence updates.
  ///
  /// ```dart
  /// DebugLogger.logSocketEvent('typing', data: {'userId': '42'});
  /// DebugLogger.logSocketEvent('presence', data: {'status': 'online'});
  /// ```
  static void logSocketEvent(String eventName, {dynamic data, String? url}) {
    writeStructured(
      message: '[Socket Event] $eventName ${_formatSocketData(data)}',
      level: LogLevel.info,
      tag: LogTag.socketEvent,
      metadata: {
        'event': eventName,
        if (url != null) 'url': url,
        if (data != null) 'data': data,
      },
    );
  }

  /// Logs a socket-level error.
  static void logSocketError(
    Object error, {
    StackTrace? stackTrace,
    String? url,
  }) {
    writeStructured(
      message: '[Socket Error] ${url != null ? '$url — ' : ''}$error',
      level: LogLevel.error,
      tag: LogTag.socketError,
      metadata: {if (url != null) 'url': url},
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Package-internal structured write — used by [FlutterDebugLogInterceptor]
  /// to supply structured [metadata]. External callers use [write]/[writeError].
  static void writeStructured({
    required String message,
    LogLevel level = LogLevel.info,
    LogTag? tag,
    Map<String, dynamic> metadata = const {},
    String? stackTrace,
  }) {
    if (!flutterDebugLoggerEnabled || !_initialized || !_loggingActive) return;
    final resolvedTag = tag ?? LogTag.fromMessage(message);
    final entry = LogEntry(
      id: _generateId(),
      timestamp: DateTime.now(),
      level: level,
      tag: resolvedTag,
      message: message,
      sessionId: _currentSessionId ?? '',
      stackTrace: stackTrace,
      metadata: metadata,
    );
    store.append(entry);
    _queueJsonlFlush(entry);
  }

  // ── JSONL flush ───────────────────────────────────────────────────────────

  static void _queueJsonlFlush(LogEntry entry) {
    _pendingWrite =
        _pendingWrite.then((_) => _flushEntry(entry)).catchError((_) {});
  }

  static Future<void> _flushEntry(LogEntry entry) async {
    final file = _logFile;
    if (file == null) return;
    await file.create(recursive: true);
    final line = '${jsonEncode(store.entryToJson(entry))}\n';
    await _rotateIfNeeded(utf8.encode(line).length);
    await file.writeAsString(line, mode: FileMode.writeOnlyAppend);
  }

  static void _queueSessionStartFlush(String sessionId, DateTime startTime) {
    _pendingWrite = _pendingWrite.then((_) async {
      final file = _logFile;
      if (file == null) return;
      await file.create(recursive: true);
      final line = '${jsonEncode({
            'tag': 'sessionStart',
            'sessionId': sessionId,
            'ts': startTime.toIso8601String()
          })}\n';
      await file.writeAsString(line, mode: FileMode.writeOnlyAppend);
    }).catchError((_) {});
  }

  // ── File replay ───────────────────────────────────────────────────────────

  static Future<void> _replayFile() async {
    final file = _logFile;
    if (file == null || !await file.exists()) return;
    final content = await file.readAsString();
    if (content.trim().isEmpty) return;

    final loadedSessions = <LogSession>[];
    LogSession? current;

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        if (json['tag'] == 'sessionStart') {
          current = LogSession(
            id: json['sessionId'] as String,
            startTime: DateTime.parse(json['ts'] as String),
          );
          loadedSessions.add(current);
        } else {
          // If entries exist before any sessionStart (e.g. after a clear+restart
          // race condition), create an implicit session so they are not lost.
          if (current == null) {
            final ts = json['ts'] != null
                ? DateTime.tryParse(json['ts'] as String) ?? DateTime.now()
                : DateTime.now();
            current = LogSession(
              id: 'recovered-${ts.microsecondsSinceEpoch}',
              startTime: ts,
            );
            loadedSessions.add(current);
          }
          current.addEntry(store.entryFromJson(json));
        }
      } catch (_) {
        // Skip malformed lines silently.
      }
    }

    if (loadedSessions.isNotEmpty) {
      store.loadSessions(loadedSessions);
    }
  }

  // ── Log rotation ──────────────────────────────────────────────────────────

  static Future<void> _rotateIfNeeded(int incomingBytes) async {
    final file = _logFile;
    if (file == null || _maxLogBytes <= 0) return;
    if (!await file.exists()) return;

    final currentBytes = await file.length();
    if (currentBytes == 0 || currentBytes + incomingBytes <= _maxLogBytes) {
      return;
    }

    if (_maxBackupFiles == 0) {
      await file.writeAsString('');
      return;
    }

    final oldest = File('${file.path}.$_maxBackupFiles');
    if (await oldest.exists()) await oldest.delete();

    for (var i = _maxBackupFiles - 1; i >= 1; i--) {
      final source = File('${file.path}.$i');
      if (await source.exists()) {
        await source.rename('${file.path}.${i + 1}');
      }
    }

    await file.rename('${file.path}.1');
    _logFile = File(file.path);
    await _logFile!.create(recursive: true);
  }

  // ── Print capture ─────────────────────────────────────────────────────────

  /// Installs a [debugPrintCallback] that mirrors output to the log store.
  ///
  /// Called automatically by [init]. Safe to call multiple times.
  static void capturePrint() {
    if (!flutterDebugLoggerEnabled || _printCaptured) return;
    _previousDebugPrint = debugPrint;
    _printCaptured = true;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;
      _previousDebugPrint?.call(message, wrapWidth: wrapWidth);
      write('[Print] $message', level: LogLevel.info);
    };
  }

  // ── Flutter error capture ─────────────────────────────────────────────────

  /// Hooks into [FlutterError.onError] to capture widget-tree and framework errors.
  static void captureFlutterErrors() {
    if (!flutterDebugLoggerEnabled) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previous?.call(details);
      final summary = details.exceptionAsString();
      final library = details.library ?? 'unknown library';
      writeStructured(
        message: '[Flutter Error] $library — $summary',
        level: LogLevel.critical,
        tag: LogTag.flutterError,
        stackTrace: details.stack?.toString(),
      );
    };
  }

  // ── Uncaught async / Dart error capture ──────────────────────────────────

  /// Hooks into [PlatformDispatcher.instance.onError] to capture uncaught Dart exceptions.
  static void captureUncaughtErrors() {
    if (!flutterDebugLoggerEnabled) return;
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      writeStructured(
        message: '[App Error] $error',
        level: LogLevel.critical,
        tag: LogTag.appError,
        stackTrace: stack.toString(),
      );
      return previous?.call(error, stack) ?? false;
    };
  }

  // ── Sharing ───────────────────────────────────────────────────────────────

  /// Creates a timestamped human-readable snapshot file and returns it.
  static Future<File?> getShareableLogFile() async {
    if (!flutterDebugLoggerEnabled || !_initialized || _logFile == null) {
      return null;
    }
    try {
      await flush();
      if (store.sessions.isEmpty) return null;
      final dir = _logDirectory ?? await getApplicationDocumentsDirectory();
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final snapshot = File('${dir.path}/debug_snapshot_$ts.txt');
      await snapshot.writeAsString(_serializeToText());
      return snapshot;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Shares the log file via the native share sheet.
  static Future<void> shareLogFile({String? subject}) async {
    if (!flutterDebugLoggerEnabled) return;
    final file = await getShareableLogFile();
    if (file == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: subject ?? 'Debug Logs',
          text: subject ?? 'Debug Logs',
        ),
      );
    } finally {
      await _deleteIfExists(file);
    }
  }

  static String _serializeToText() {
    final buf = StringBuffer();
    var sessionNum = 0;
    for (final session in store.sessions) {
      sessionNum++;
      buf.writeln(session.formatAsText(sessionNum));
      buf.writeln();
    }
    return buf.toString();
  }

  /// Formats a list of log entries as a human-readable text block.
  static String serializeEntriesToText(List<LogEntry> entries,
      {String title = 'Exported Logs'}) {
    final buf = StringBuffer();
    buf.writeln(title);
    buf.writeln('=' * 72);
    buf.writeln();
    for (final entry in entries) {
      final sessionIndex =
          store.sessions.indexWhere((s) => s.id == entry.sessionId);
      final sessionNum = sessionIndex >= 0 ? sessionIndex + 1 : 0;
      buf.writeln(entry.formatAsText(sessionNumber: sessionNum));
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  /// Shares arbitrary text content as a temporary file.
  static Future<void> shareText(String content,
      {required String fileName, String? subject}) async {
    if (!flutterDebugLoggerEnabled || !_initialized) return;
    final dir = _logDirectory ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: subject ?? 'Debug Logs',
          text: subject ?? 'Debug Logs',
        ),
      );
    } finally {
      await _deleteIfExists(file);
    }
  }

  static Future<void> deleteShareableLogFile(File file) async {
    await _deleteIfExists(file);
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Exception catch (_) {}
  }

  // ── Housekeeping ──────────────────────────────────────────────────────────

  /// Wipes the in-memory store and the on-disk log file, then opens a fresh
  /// session so subsequent log calls have a session to attach to.
  static void clearFile() {
    store.clear();
    _currentSessionId = _generateId();
    final sessionStart = DateTime.now();
    store.startSession(_currentSessionId!, sessionStart);
    if (_logFile == null) return;
    _pendingWrite = _pendingWrite.then((_) async {
      final file = _logFile;
      if (file == null) return;
      if (await file.exists()) await file.writeAsString('');
    }).catchError((_) {});
    _queueSessionStartFlush(_currentSessionId!, sessionStart);
  }

  /// Waits for all queued writes and clears the log.
  static Future<void> clearFileAsync() async {
    clearFile();
    await flush();
  }

  /// Waits for all queued writes to reach disk.
  static Future<void> flush() async {
    try {
      await _pendingWrite;
    } on Exception catch (_) {}
  }

  /// Pauses future log writes without deleting existing logs.
  static void stopLogging() {
    if (!flutterDebugLoggerEnabled || !_initialized || !_loggingActive) return;
    write('[Logger] Logging stopped', level: LogLevel.medium);
    _loggingActive = false;
  }

  /// Resumes log writes after [stopLogging].
  static void startLogging() {
    if (!flutterDebugLoggerEnabled || !_initialized || _loggingActive) return;
    _loggingActive = true;
    write('[Logger] Logging started', level: LogLevel.medium);
  }

  /// Toggles future log writes. Returns the new active state.
  static bool toggleLogging() {
    if (loggingActive) {
      stopLogging();
    } else {
      startLogging();
    }
    return loggingActive;
  }

  /// Returns the on-disk size in bytes (0 when unavailable).
  static int get fileSizeBytes {
    try {
      return _logFile?.lengthSync() ?? 0;
    } on Exception catch (_) {
      return 0;
    }
  }

  /// Returns whether new log entries are currently accepted.
  static bool get loggingActive =>
      flutterDebugLoggerEnabled && _initialized && _loggingActive;

  // ── Deprecated ────────────────────────────────────────────────────────────

  @Deprecated('Read DebugLogger.store.sessions directly. '
      'readLogContent() returns the raw .jsonl file which is not human-readable.')
  static Future<String?> readLogContent() async {
    if (!flutterDebugLoggerEnabled || !_initialized || _logFile == null) {
      return null;
    }
    try {
      await flush();
      if (!await _logFile!.exists() || await _logFile!.length() == 0) {
        return null;
      }
      return _logFile!.readAsString();
    } on Exception catch (_) {
      return null;
    }
  }

  @Deprecated('Read DebugLogger.store.sessions directly. '
      'readLogLines() returned raw text lines replaced by structured LogEntry objects.')
  static Future<List<String>> readLogLines() async {
    // ignore: deprecated_member_use_from_same_package
    final content = await readLogContent();
    if (content == null || content.isEmpty) return const <String>[];
    return const LineSplitter().convert(content);
  }
}
