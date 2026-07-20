# flutter_debug_logger

A zero-config, file-based floating debug logger for Flutter apps. It automatically captures console prints, framework errors, and uncaught exceptions, displaying them in a color-coded log viewer opened via a draggable on-screen button.

## Features

- 🐛 **Floating Draggable FAB**: Persistent overlay button to open the log viewer, active only when enabled (acts as a transparent pass-through in production).
- 🎨 **Color-Coded Log Viewer**: Displays logs in readable monospace text color-coded by log level and tag.
- 🔎 **Search & Filter**: Case-insensitive substring search with visual text highlighting, along with filters for specific log levels and tags.
- 🌐 **Dio Interceptor**: Seamless HTTP logging including request headers/params, response payloads, error details, and dynamic cURL command generation.
- 🔌 **Socket Logging**: Manual logging helpers for socket connect/disconnect/send/receive/error events. Off by default, toggle via Settings or code.
- 🧹 **Automatic Log Rotation**: Configuration of max live log file size and automatic rotated backup files to prevent storage bloat.
- 📤 **Export & Share**: Share logs via native share sheet, clear disk logs, or use a "Share & Clear" flow.
- 🔇 **Zero Production Cost**: Automatically disabled in release builds unless explicitly activated via build-time flags.

---

## Quick Start

### 1. Add Dependency

Add `flutter_debug_logger` to your project's `pubspec.yaml`:

```yaml
dependencies:
  flutter_debug_logger:
    path: path/to/flutter_debug_logger # Or use git/pub.dev source
```

### 2. Initialize in `main.dart`

Configure `DebugLogger.init()` and wrap your root widget with `FlutterDebugLogger.wrap()`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_debug_logger/flutter_debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage, print redirection, and error capturing
  await DebugLogger.init();

  runApp(
    FlutterDebugLogger.wrap(
      child: const MyApp(),
    ),
  );
}
```

*Alternative overlay setup via MaterialApp builder:*

```dart
MaterialApp(
  builder: FlutterDebugLogger.overlay,
  home: const HomeScreen(),
)
```

### 3. Usage & Manual Logging

Log messages directly from your code. Use `LogLevel` to categorize message severity:

```dart
import 'package:flutter_debug_logger/flutter_debug_logger.dart';

// Write standard logs (LogLevel.info by default)
DebugLogger.write('User navigated to profile page');
DebugLogger.write('Performance benchmark warning', level: LogLevel.medium);

// Write caught exceptions automatically including stack traces (truncated to 8 lines)
try {
  throw Exception('Failed to query database');
} catch (e, st) {
  DebugLogger.writeError(e, st);
}
```

### 4. Build Configuration

By default, the logger is **always active in debug mode**, and **disabled in release/profile modes** (zero performance overhead). 

To enable the logger in release/profile builds (e.g., for QA or internal testers), compile your application with the compiler flag:

```bash
# Build release APK with logger activated
flutter build apk --release --dart-define=FLUTTER_DEBUG_LOGGER=true
```

---

## Configuration

### DebugLogger.init()
Configure logger options at startup:

```dart
await DebugLogger.init(
  captureFlutter: true,     // Captures Flutter framework/layout errors (Default: true)
  captureUncaught: true,    // Captures uncaught Dart/async exceptions (Default: true)
  startEnabled: true,       // Start logger as active (Default: true)
  socketLoggingEnabled: false, // Records socket events (Default: false — off)
  maxLogBytes: 1024 * 1024, // 1MB log file limit before rotating (Default: 1MB)
  maxBackupFiles: 2,        // Number of backup files to keep (Default: 2, Clamped 0-99)
  fileName: 'custom_logs.txt', // Log file name (Default: 'flutter_debug_logs.txt')
);
```

### Socket Logging

Socket events aren't captured automatically — call these helpers manually from your socket connect/message/error handlers. **Off by default**; no socket log is recorded until enabled.

Enable it via `DebugLogger.init(socketLoggingEnabled: true)`, at runtime with `DebugLogger.setSocketLoggingEnabled(true)`, or by flipping "Record socket logs" in the Settings screen.

```dart
// Check current state
if (DebugLogger.socketLoggingEnabled) { ... }

// Enable/disable at runtime
DebugLogger.setSocketLoggingEnabled(true);

// Connection lifecycle
DebugLogger.logSocketConnect('wss://example.com/ws');
DebugLogger.logSocketDisconnect('wss://example.com/ws', reason: 'timeout');

// Messages (Map/List data is JSON-encoded; other types use toString(), truncated to 2000 chars)
DebugLogger.logSocketSend('chat.message', data: {'text': 'hi'}, url: 'wss://example.com/ws');
DebugLogger.logSocketReceive('chat.message', data: {'text': 'hello'}, url: 'wss://example.com/ws');

// Custom/named events (typing indicators, presence, etc.)
DebugLogger.logSocketEvent('presence', data: {'status': 'online'});

// Errors
try {
  // socket operation
} catch (e, st) {
  DebugLogger.logSocketError(e, stackTrace: st, url: 'wss://example.com/ws');
}
```

Socket logs are filterable in the log viewer via the **Socket Logs** dashboard tile and the **SOCKET LOGS** filter section.

### Dio Network Interceptor
Log HTTP traffic with `FlutterDebugLogInterceptor`. Redacts sensitive headers and formats payloads automatically:

```dart
final dio = Dio();
dio.interceptors.add(
  const FlutterDebugLogInterceptor(
    tag: 'API',                 // Prepends tag to interceptor logs (Default: null)
    generateCurl: true,         // Generates ready-to-paste cURL command (Default: false)
    logRequestBody: true,       // Logs outgoing request bodies (Default: false)
    logResponseBody: true,      // Logs incoming response bodies (Default: false)
    maxBodyChars: 2000,         // Truncation limit for long body payloads (Default: 2000)
    redactedHeaders: [          // List of header keys to redact (Default: authorization, cookie, set-cookie, x-api-key)
      'authorization',
      'x-api-key',
    ],
    redactHeadersInCurl: false, // Set to true to redact sensitive headers in cURL logs (Default: false)
  ),
);
```

---

## Log Viewer UI & Settings

Tap the floating bug icon overlay to open the **Debug Logs** viewer.

### UI Features
- **Search Panel**: Instantly filters log lines by substring. Matches are highlighted in yellow.
- **Filter Sheet**: Tap the filter icon to filter logs by **Log Levels** or **Log Tags**.

### Dropdown Settings
The three-dot action menu in the top-right contains:
- **Start/Stop logging**: Pauses or resumes log file writes on disk (without erasing history).
- **Refresh**: Re-reads the log file from disk.
- **Latest first**: Toggles chronological sorting order.
- **Auto-scroll**: Follows incoming log lines automatically.
- **Copy all logs** / **Copy filtered**: Copies the raw text buffer of either the full logs or the filtered/visible logs to the device clipboard.
- **Export logs**: Shares the current log file snapshot natively.
- **Share & clear**: Shares the log file snapshot and then clears the log contents.
- **Clear logs**: Immediately clears all logs from disk.

---

## API Reference

| Symbol | Description |
|---|---|
| `DebugLogger.init()` | Starts logger, prepares log file, overrides `print`, and hooks error captures. |
| `DebugLogger.write(message, {level})` | Writes a timestamped log line with the specified `LogLevel`. |
| `DebugLogger.writeError(error, [stackTrace, level])` | Logs exception text and automatically truncates stack traces to 8 lines. |
| `DebugLogger.readLogContent()` | Returns the complete log file text as a `String?`. |
| `DebugLogger.readLogLines()` | Returns log file lines as a `List<String>`. |
| `DebugLogger.getShareableLogFile()` | Returns a copy of the live log file for safe sharing. |
| `DebugLogger.shareLogFile({subject})` | Triggers the native share sheet for the logs. |
| `DebugLogger.deleteShareableLogFile(file)` | Deletes a temporary shareable file snapshot. |
| `DebugLogger.clearFile()` | Wipes the live log file asynchronously. |
| `DebugLogger.clearFileAsync()` | Wipes the live log file and awaits completion. |
| `DebugLogger.flush()` | Awaits completion of all queued disk writes. |
| `DebugLogger.startLogging()` | Resumes writing logs to disk. |
| `DebugLogger.stopLogging()` | Pauses writing logs to disk. |
| `DebugLogger.toggleLogging()` | Toggles log active state and returns the new state. |
| `DebugLogger.loggingActive` | `bool` getter indicating if logger is accepting writes. |
| `DebugLogger.fileSizeBytes` | `int` getter returning the current on-disk log file size. |
| `DebugLogger.logSocketConnect(url, {metadata})` | Logs a socket connection being opened. |
| `DebugLogger.logSocketDisconnect(url, {reason, metadata})` | Logs a socket connection being closed. |
| `DebugLogger.logSocketSend(event, {data, url})` | Logs an outgoing socket message. |
| `DebugLogger.logSocketReceive(event, {data, url})` | Logs an incoming socket message. |
| `DebugLogger.logSocketEvent(eventName, {data, url})` | Logs a custom/named socket event (e.g. presence, typing). |
| `DebugLogger.logSocketError(error, {stackTrace, url})` | Logs a socket-level error. |
| `DebugLogger.socketLoggingEnabled` | `bool` getter indicating if socket events are being recorded (Default: `false`). |
| `DebugLogger.setSocketLoggingEnabled(enabled)` | Enables/disables recording of socket log events. |
| `FlutterDebugLogger.wrap({child})` | Widget wrapper displaying the floating button overlay. |
| `FlutterDebugLogger.overlay` | Signature helper to use as MaterialApp's `builder` property. |
| `FlutterDebugLogInterceptor` | Dio interceptor for zero-config HTTP logging. |
| `flutterDebugLoggerEnabled` | `bool` global indicating if the logger environment is active. |
| `LogLevel` | Enum for log severity levels (`info`, `medium`, `error`, `critical`). |
| `LogTag` | Enum for log source/type classification. |
