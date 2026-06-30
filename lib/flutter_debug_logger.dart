/// flutter_debug_logger
///
/// Usage:
///   1. Wrap your app with [FlutterDebugLogger.wrap] — or add
///      [FlutterDebugLogger.overlay] to your MaterialApp's builder.
///   2. Build with the flag:
///        flutter build apk --release --dart-define=FLUTTER_DEBUG_LOGGER=true
///   3. In debug builds it is ALWAYS active (no flag needed).
library flutter_debug_logger;

export 'src/debug_logger.dart' show DebugLogger, flutterDebugLoggerEnabled;
export 'src/flutter_debug_wrapper.dart' show FlutterDebugLogger;
export 'src/log_interceptor.dart' show FlutterDebugLogInterceptor;
export 'src/log_level.dart' show LogLevel, LogTag;
export 'src/log_store.dart' show LogStore;
export 'src/models/log_entry.dart' show LogEntry;
export 'src/models/log_session.dart' show LogSession;
