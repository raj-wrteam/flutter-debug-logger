import 'dart:convert';

import 'package:dio/dio.dart';

import 'debug_logger.dart';
import 'log_level.dart';

/// Drop-in Dio interceptor — logs all API traffic to the debug file.
///
/// ```dart
/// // Basic usage — request/response/error logging only:
/// dio.interceptors.add(FlutterDebugLogInterceptor());
///
/// // With cURL generation — each request also logs a ready-to-paste cURL
/// // command that can be run directly in a terminal:
/// dio.interceptors.add(FlutterDebugLogInterceptor(generateCurl: true));
/// ```
///
/// No-ops automatically when [flutterDebugLoggerEnabled] is false.
class FlutterDebugLogInterceptor extends Interceptor {
  /// Optional label included in every log line (e.g. your app name).
  final String? tag;

  /// When `true`, a cURL command equivalent to every outgoing request is
  /// appended to the debug log immediately after the `[Request]` line.
  ///
  /// The command is built from [RequestOptions] and respects:
  /// - All request headers
  /// - JSON bodies (serialised with [jsonEncode], passed as `-d`)
  /// - FormData fields (`-F key=value`)
  /// - FormData file references (`-F key=@filename`)
  /// - Raw string bodies (`--data-raw`)
  final bool generateCurl;

  /// When `true`, logs request bodies after the request line.
  final bool logRequestBody;

  /// When `true`, logs response/error bodies after the response/error line.
  final bool logResponseBody;

  /// Maximum number of characters written for any one body payload.
  final int maxBodyChars;

  /// Header names whose values should be replaced with `<redacted>`.
  final List<String> redactedHeaders;

  const FlutterDebugLogInterceptor({
    this.tag,
    this.generateCurl = false,
    this.logRequestBody = false,
    this.logResponseBody = false,
    this.maxBodyChars = 2000,
    this.redactedHeaders = const <String>[
      'authorization',
      'cookie',
      'set-cookie',
      'x-api-key',
    ],
  });

  String get _prefix => tag != null ? '[$tag]' : '';
  static const _startedAtKey = 'flutter_debug_logger_started_at';

  // ---------------------------------------------------------------------------
  // cURL builder
  // ---------------------------------------------------------------------------

  /// Builds a cURL command string from [options].
  String _buildCurl(RequestOptions options) {
    final method = options.method.toUpperCase();
    final url = options.uri.toString();
    final buf = StringBuffer("curl -X $method '${_escapeSingle(url)}'");

    // Headers
    options.headers.forEach((key, dynamic value) {
      final headerValue = _isRedactedHeader(key) ? '<redacted>' : '$value';
      buf.write(" -H '${_escapeSingle(key)}: ${_escapeSingle(headerValue)}'");
    });

    // Body
    final data = options.data;
    if (data != null) {
      if (data is FormData) {
        for (final field in data.fields) {
          buf.write(
            " -F '${_escapeSingle(field.key)}=${_escapeSingle(field.value)}'",
          );
        }
        for (final file in data.files) {
          final filename = file.value.filename ?? 'file';
          buf.write(
              " -F '${_escapeSingle(file.key)}=@${_escapeSingle(filename)}'");
        }
      } else if (data is Map || data is List) {
        // JSON body — use -d with jsonEncode, not -F
        final json = _escapeSingle(jsonEncode(data));
        buf.write(" -d '$json'");
      } else {
        // Raw string / other
        buf.write(" --data-raw '${_escapeSingle('$data')}'");
      }
    }

    return buf.toString();
  }

  /// Escapes single quotes for safe embedding inside `'…'` shell strings.
  String _escapeSingle(String s) => s.replaceAll("'", r"'\''");

  bool _isRedactedHeader(String key) {
    final lowerKey = key.toLowerCase();
    return redactedHeaders.any((header) => header.toLowerCase() == lowerKey);
  }

  String _formatBody(dynamic data) {
    if (data == null) return '<empty>';

    String text;
    if (data is FormData) {
      final fields = data.fields.map((field) => '${field.key}=${field.value}');
      final files = data.files.map((file) {
        final filename = file.value.filename ?? 'file';
        return '${file.key}=@$filename';
      });
      text = [...fields, ...files].join(', ');
    } else if (data is List<int>) {
      text = '<${data.length} bytes>';
    } else if (data is Map || data is List) {
      text = jsonEncode(data);
    } else {
      text = '$data';
    }

    return _truncate(text);
  }

  String _truncate(String text) {
    if (maxBodyChars <= 0 || text.length <= maxBodyChars) return text;
    final omitted = text.length - maxBodyChars;
    return '${text.substring(0, maxBodyChars)}... (+$omitted chars)';
  }

  String _durationLabel(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    if (startedAt is! int) return '';
    final elapsedMicros = DateTime.now().microsecondsSinceEpoch - startedAt;
    final elapsedMs = elapsedMicros / 1000;
    return ' (${elapsedMs.toStringAsFixed(0)}ms)';
  }

  // ---------------------------------------------------------------------------
  // Interceptor overrides
  // ---------------------------------------------------------------------------

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (flutterDebugLoggerEnabled) {
      options.extra[_startedAtKey] = DateTime.now().microsecondsSinceEpoch;
      final params = options.queryParameters.isEmpty
          ? ''
          : ' params:${options.queryParameters}';
      DebugLogger.write(
        '[Request]$_prefix ${options.method} ${options.uri}$params',
        level: LogLevel.info,
      );

      if (logRequestBody && options.data != null) {
        DebugLogger.write(
          '[Request Body]$_prefix ${_formatBody(options.data)}',
          level: LogLevel.info,
        );
      }

      if (generateCurl) {
        DebugLogger.write(
          '[cURL]$_prefix ${_buildCurl(options)}',
          level: LogLevel.info,
        );
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (flutterDebugLoggerEnabled) {
      DebugLogger.write(
        '[Response]$_prefix ${response.statusCode} '
        '${response.requestOptions.uri}${_durationLabel(response.requestOptions)}',
        level: LogLevel.info,
      );

      if (logResponseBody && response.data != null) {
        DebugLogger.write(
          '[Response Body]$_prefix ${_formatBody(response.data)}',
          level: LogLevel.info,
        );
      }

      // Surface API-level error flags (common pattern: {error: true, message: …})
      if (response.data case final Map<String, dynamic> data
          when data['error'] == true) {
        DebugLogger.write(
          '[Response Error]$_prefix ${response.requestOptions.path} '
          '— ${data['message']} — $data',
          level: LogLevel.error,
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (flutterDebugLoggerEnabled) {
      DebugLogger.write(
        '[API Error]$_prefix ${err.response?.statusCode} '
        '${err.requestOptions.uri}${_durationLabel(err.requestOptions)} '
        '| ${err.response?.statusMessage} | ${err.error}',
        level: LogLevel.error,
      );
      if (logResponseBody && err.response?.data != null) {
        DebugLogger.write(
          '[Error Body]$_prefix ${_formatBody(err.response?.data)}',
          level: LogLevel.error,
        );
      }
      if (err.stackTrace != StackTrace.empty) {
        DebugLogger.write(err.stackTrace.toString(), level: LogLevel.error);
      }
    }
    handler.reject(err);
  }
}
