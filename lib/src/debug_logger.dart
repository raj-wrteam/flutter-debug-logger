import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'log_level.dart';

// ---------------------------------------------------------------------------
// Build-time flag:  flutter build apk --dart-define=FLUTTER_DEBUG_LOGGER=true
// In kDebugMode the logger is ALWAYS active regardless of the flag.
// ---------------------------------------------------------------------------
const bool _kFlagEnabled =
    bool.fromEnvironment('FLUTTER_DEBUG_LOGGER', defaultValue: false);

/// Returns true when the logger should be active.
bool get flutterDebugLoggerEnabled => kDebugMode || _kFlagEnabled;

/// Persistent, file-based debug logger.
///
/// - Thread-safe for typical Flutter single-isolate usage.
/// - Silently no-ops when [flutterDebugLoggerEnabled] is false.
/// - Captures `print` / `debugPrint` when you install [DebugLogger.capturePrint].
/// - Captures Flutter framework errors via [DebugLogger.captureFlutterErrors].
/// - Captures uncaught async/Dart errors via [DebugLogger.captureUncaughtErrors].
class DebugLogger {
  DebugLogger._();

  static File? _logFile;
  static Directory? _logDirectory;
  static bool _initialized = false;
  static bool _loggingActive = true;
  static int _maxLogBytes = 1024 * 1024;
  static int _maxBackupFiles = 2;
  static Future<void> _pendingWrite = Future<void>.value();
  static DebugPrintCallback? _previousDebugPrint;
  static bool _printCaptured = false;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Call once inside your `main()` or app-init function.
  ///
  /// ```dart
  /// await DebugLogger.init();
  /// ```
  ///
  /// Pass [captureFlutter] and/or [captureUncaught] to enable automatic
  /// Dart/Flutter error capture.
  static Future<void> init({
    bool captureFlutter = true,
    bool captureUncaught = true,
    bool startEnabled = true,
    int maxLogBytes = 1024 * 1024,
    int maxBackupFiles = 2,
    String fileName = 'flutter_debug_logs.txt',
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

      final now = DateTime.now().toIso8601String();
      _appendRaw(
        '\n${"=" * 64}\n'
        '  SESSION START  $now\n'
        '${"=" * 64}\n\n',
        respectLoggingState: false,
      );

      // Redirect print() calls into the log file
      capturePrint();

      if (captureFlutter) captureFlutterErrors();
      if (captureUncaught) captureUncaughtErrors();
    } on Exception catch (e) {
      debugPrint('DebugLogger.init failed: $e');
    }
  }

  // ── Writing ───────────────────────────────────────────────────────────────

  /// Maximum number of stack-trace lines kept per error entry.
  static const int _kMaxStackLines = 8;

  /// Trims [stack] to at most [_kMaxStackLines] lines.
  ///
  /// If lines are omitted, a trailing `  … (+N more frames)` note is appended
  /// so the reader knows the trace was truncated.
  static String _truncateStack(StackTrace stack) {
    final lines = stack.toString().split('\n');
    if (lines.length <= _kMaxStackLines) return stack.toString();
    final kept = lines.take(_kMaxStackLines).join('\n');
    final omitted = lines.length - _kMaxStackLines;
    return '$kept\n  … (+$omitted more frames)';
  }

  /// Appends a timestamped [line] to the log file tagged with [level].
  ///
  /// Defaults to [LogLevel.info] so all existing call-sites are unaffected.
  static void write(String line, {LogLevel level = LogLevel.info}) {
    if (!flutterDebugLoggerEnabled || !_initialized || !_loggingActive) return;
    final ts = DateTime.now().toIso8601String();
    _appendRaw('[$ts]${level.tag} $line\n');
  }

  /// Convenience method to log a caught error/exception with an optional
  /// stack trace at [LogLevel.error].
  ///
  /// ```dart
  /// try { … } catch (e, st) { DebugLogger.writeError(e, st); }
  /// ```
  static void writeError(
    Object error, [
    StackTrace? stackTrace,
    LogLevel level = LogLevel.error,
  ]) {
    if (!flutterDebugLoggerEnabled || !_initialized || !_loggingActive) return;
    write('EXCEPTION: $error', level: level);
    if (stackTrace != null && stackTrace != StackTrace.empty) {
      final ts = DateTime.now().toIso8601String();
      _appendRaw('[$ts]${level.tag} STACK:\n${_truncateStack(stackTrace)}\n');
    }
    _appendRaw('\n'); // blank line separates log blocks for filter clarity
  }

  /// Low-level append; no timestamp added.
  static void _appendRaw(String text, {bool respectLoggingState = true}) {
    if (!flutterDebugLoggerEnabled || !_initialized || _logFile == null) return;
    if (respectLoggingState && !_loggingActive) return;

    _pendingWrite =
        _pendingWrite.then((_) => _appendRawAsync(text)).catchError((_) {
      // Silently swallow — never crash the host app.
    });
  }

  static Future<void> _appendRawAsync(String text) async {
    final file = _logFile;
    if (file == null) return;
    await file.create(recursive: true);
    await _rotateIfNeeded(utf8.encode(text).length);
    await file.writeAsString(text, mode: FileMode.writeOnlyAppend);
  }

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

  /// Installs a [debugPrintCallback] that mirrors output to the log file.
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

  /// Hooks into [FlutterError.onError] to capture widget-tree and framework
  /// errors (parsing errors, layout overflows, assertion failures, etc.).
  ///
  /// Chains into any previously installed handler so existing tooling
  /// (e.g. Crashlytics) continues to work.
  ///
  /// Called automatically by [init] when [captureFlutter] is `true`.
  static void captureFlutterErrors() {
    if (!flutterDebugLoggerEnabled) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Forward to original handler first (keeps IDE output intact)
      previous?.call(details);

      final summary = details.exceptionAsString();
      final library = details.library ?? 'unknown library';
      write(
        '[Flutter Error] $library — $summary',
        level: LogLevel.critical,
      );
      if (details.stack != null) {
        final ts = DateTime.now().toIso8601String();
        _appendRaw(
          '[$ts]${LogLevel.critical.tag} STACK:\n${_truncateStack(details.stack!)}\n',
        );
      }
      _appendRaw('\n'); // blank line separates log blocks for filter clarity
    };
  }

  // ── Uncaught async / Dart error capture ──────────────────────────────────

  /// Hooks into [PlatformDispatcher.instance.onError] to capture uncaught
  /// Dart exceptions (including async gaps, isolate errors that reach main,
  /// and runtime exceptions not caught by a try/catch).
  ///
  /// Called automatically by [init] when [captureUncaught] is `true`.
  static void captureUncaughtErrors() {
    if (!flutterDebugLoggerEnabled) return;
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      write('[App Error] $error', level: LogLevel.critical);
      final ts = DateTime.now().toIso8601String();
      _appendRaw(
          '[$ts]${LogLevel.critical.tag} STACK:\n${_truncateStack(stack)}\n');
      _appendRaw('\n'); // blank line separates log blocks for filter clarity
      // Return false to let the default handler also process it (shows red screen in debug)
      return previous?.call(error, stack) ?? false;
    };
  }

  // ── Reading ───────────────────────────────────────────────────────────────

  /// Returns the entire log file content, or `null` when empty / unavailable.
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

  /// Returns the current live log file as individual lines.
  static Future<List<String>> readLogLines() async {
    final content = await readLogContent();
    if (content == null || content.isEmpty) return const <String>[];
    return const LineSplitter().convert(content);
  }

  // ── Sharing ───────────────────────────────────────────────────────────────

  /// Creates a timestamped snapshot file and returns it (live file untouched).
  static Future<File?> getShareableLogFile() async {
    if (!flutterDebugLoggerEnabled || !_initialized || _logFile == null) {
      return null;
    }
    try {
      await flush();
      if (!await _logFile!.exists() || await _logFile!.length() == 0) {
        return null;
      }
      final dir = _logDirectory ?? await getApplicationDocumentsDirectory();
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      return _logFile!.copy('${dir.path}/debug_snapshot_$ts.txt');
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

  static Future<void> deleteShareableLogFile(File file) async {
    await _deleteIfExists(file);
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Exception catch (_) {}
  }

  // ── Housekeeping ──────────────────────────────────────────────────────────

  /// Wipes the on-disk log file (keeps the [File] handle open).
  static void clearFile() {
    if (_logFile == null) return;
    _pendingWrite = _pendingWrite.then((_) async {
      final file = _logFile;
      if (file == null) return;
      if (await file.exists()) await file.writeAsString('');
    }).catchError((_) {});
  }

  /// Waits for all queued writes and clears the live log file.
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
}
