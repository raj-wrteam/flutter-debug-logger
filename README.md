# flutter_debug_logger

A zero-config, persistent floating debug logger for Flutter apps.

- 🐛 **Floating draggable FAB** — visible only when the flag is on  
- 📄 **Full-screen log viewer** — colour-coded, selectable monospace text  
- 📤 **Share & clear** — bottom sheet confirmation, then native share  
- 🌐 **Dio interceptor** — auto-logs all API requests / responses / errors  
- 🔎 **Search, copy, export** — find logs, copy visible/all logs, export without clearing
- 🧹 **Log rotation** — configurable max live file size and backup count
- 🔇 **Zero cost in production** — completely silent when the flag is off  

---

## Quick start

### 1. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  flutter_debug_logger:
    path: ../flutter_debug_logger   # or your pub.dev / git path
```

### 2. Initialise in `main.dart`

```dart
import 'package:flutter_debug_logger/flutter_debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DebugLogger.init();           // ← one line
  runApp(FlutterDebugLogger.wrap(     // ← wraps your whole app
    child: const MyApp(),
  ));
}
```

**Alternative — use the `MaterialApp` builder:**

```dart
MaterialApp(
  builder: FlutterDebugLogger.overlay,
  ...
)
```

### 3. Add the Dio interceptor (optional)

```dart
final dio = Dio();
dio.interceptors.add(FlutterDebugLogInterceptor(tag: 'MyApp'));
```

Optional request/response body logging is off by default. Enable it when you
need payloads, with truncation and sensitive header redaction:

```dart
dio.interceptors.add(
  const FlutterDebugLogInterceptor(
    tag: 'MyApp',
    logRequestBody: true,
    logResponseBody: true,
    maxBodyChars: 4000,
  ),
);
```

### 4. Build with the flag

```bash
# Debug builds: logger is ALWAYS on — no flag needed.

# Release build WITH logger enabled:
flutter build apk --release --dart-define=FLUTTER_DEBUG_LOGGER=true

# Release build WITHOUT logger (default / production):
flutter build apk --release
```

Add a Makefile / script alias so testers don't have to remember the flag:

```makefile
build-debug-apk:
    flutter build apk --release --dart-define=FLUTTER_DEBUG_LOGGER=true
```

---

## Manual logging

```dart
DebugLogger.write('[MY_TAG] Something happened');
DebugLogger.stopLogging();  // pauses future writes
DebugLogger.startLogging(); // resumes future writes
```

Configure storage limits at startup:

```dart
await DebugLogger.init(
  maxLogBytes: 1024 * 1024,
  maxBackupFiles: 2,
);
```

---

## API reference

| Symbol | Description |
|---|---|
| `DebugLogger.init()` | Call once at app start. Creates the log file, captures `print`, and configures rotation. |
| `DebugLogger.write(line)` | Appends a timestamped line. |
| `DebugLogger.writeError(error, stackTrace)` | Appends an exception with a truncated stack trace. |
| `DebugLogger.readLogContent()` | Returns full log text as `Future<String?>`. |
| `DebugLogger.readLogLines()` | Returns live log text as individual lines. |
| `DebugLogger.shareLogFile()` | Shares via native share sheet. |
| `DebugLogger.deleteShareableLogFile(file)` | Deletes a snapshot created by `getShareableLogFile()`. |
| `DebugLogger.clearFile()` | Wipes the on-disk log. |
| `DebugLogger.clearFileAsync()` | Wipes the log and waits for queued writes. |
| `DebugLogger.flush()` | Waits for queued asynchronous writes to finish. |
| `DebugLogger.startLogging()` | Resumes future log writes. |
| `DebugLogger.stopLogging()` | Pauses future log writes. |
| `DebugLogger.toggleLogging()` | Toggles logging and returns the new state. |
| `DebugLogger.loggingActive` | Whether new entries are currently accepted. |
| `DebugLogger.fileSizeBytes` | Current log file size. |
| `FlutterDebugLogger.wrap(child:)` | Wraps a widget with the FAB overlay. |
| `FlutterDebugLogger.overlay` | `MaterialApp` builder signature. |
| `FlutterDebugLogInterceptor` | Dio interceptor. |
| `flutterDebugLoggerEnabled` | `bool` — true in debug mode OR when flag is set. |

---

## How the FAB works

The FAB is a semi-transparent draggable bubble (bottom-right by default).  
Drag it anywhere. Tap to open the log viewer.

The viewer includes search, level filters, selectable log text, copy actions,
latest-first display, auto-scroll, export, share-and-clear, and a start/stop
logging toggle.

Primary toolbar actions:

| Icon | Action |
|---|---|
| ▶ / ⏸ | Start or stop future logging |
| ↺ Refresh | Re-reads the log file from disk |
| ⧉ Copy | Copies all logs |
| ↑ Export | Shares logs without clearing |
| ⋮ More | Copy visible, share & clear, or clear logs |

---

## Integrating into eBroker

Replace your old files with these equivalents:

| Old file | Replacement |
|---|---|
| `utils/debug_logger.dart` | `DebugLogger` from this package |
| `utils/debug_log_interceptor.dart` | `FlutterDebugLogInterceptor` |
| `debug_log_viewer_screen.dart` | Built-in viewer (opened by the FAB) |

Remove `AppSettings.enableDebugLogger` checks — the package handles that internally via `flutterDebugLoggerEnabled`.
