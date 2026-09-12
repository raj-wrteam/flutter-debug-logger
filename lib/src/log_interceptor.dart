import 'dart:convert';

import 'package:dio/dio.dart';

import 'debug_logger.dart';
import 'log_level.dart';

/// Drop-in Dio interceptor — logs all API traffic to the debug store.
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
  final bool generateCurl;

  /// When `true`, logs request bodies after the request line.
  final bool logRequestBody;

  /// When `true`, logs response/error bodies after the response/error line.
  final bool logResponseBody;

  /// Maximum number of characters written for any one body payload.
  final int maxBodyChars;

  /// Header names whose values should be replaced with `<redacted>`.
  final List<String> redactedHeaders;

  /// When `true`, headers specified in [redactedHeaders] will be replaced
  /// with `<redacted>` in the generated cURL command.
  final bool redactHeadersInCurl;

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
    this.redactHeadersInCurl = false,
  });

  String get _prefix => tag != null ? '[$tag]' : '';
  static const _startedAtKey = 'flutter_debug_logger_started_at';

  // ── cURL builder ──────────────────────────────────────────────────────────

  String _buildCurl(RequestOptions options) {
    final method = options.method.toUpperCase();
    final url = options.uri.toString();
    final buf = StringBuffer("curl -X $method '${_escapeSingle(url)}'");

    options.headers.forEach((key, dynamic value) {
      final headerValue = (redactHeadersInCurl && _isRedactedHeader(key))
          ? '<redacted>'
          : '$value';
      buf.write(" -H '${_escapeSingle(key)}: ${_escapeSingle(headerValue)}'");
    });

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
            " -F '${_escapeSingle(file.key)}=@${_escapeSingle(filename)}'",
          );
        }
      } else if (data is Map || data is List) {
        buf.write(" -d '${_escapeSingle(jsonEncode(data))}'");
      } else {
        buf.write(" --data-raw '${_escapeSingle('$data')}'");
      }
    }

    return buf.toString();
  }

  String _escapeSingle(String s) => s.replaceAll("'", r"'\''");

  bool _isRedactedHeader(String key) {
    final lowerKey = key.toLowerCase();
    return redactedHeaders.any((h) => h.toLowerCase() == lowerKey);
  }

  String _bodyToString(dynamic data) {
    if (data == null) return '<empty>';
    if (data is FormData) {
      final fields = data.fields.map((f) => '${f.key}=${f.value}');
      final files = data.files.map((f) {
        final filename = f.value.filename ?? 'file';
        return '${f.key}=@$filename';
      });
      return [...fields, ...files].join(', ');
    } else if (data is List<int>) {
      return '<${data.length} bytes>';
    } else if (data is Map || data is List) {
      return jsonEncode(data);
    } else {
      return '$data';
    }
  }

  String _truncate(String text) {
    if (maxBodyChars <= 0 || text.length <= maxBodyChars) return text;
    final omitted = text.length - maxBodyChars;
    return '${text.substring(0, maxBodyChars)}... (+$omitted chars)';
  }

  int _elapsedMs(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    if (startedAt is! int) return 0;
    return ((DateTime.now().microsecondsSinceEpoch - startedAt) / 1000).round();
  }

  // ── Interceptor overrides ─────────────────────────────────────────────────

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (flutterDebugLoggerEnabled) {
      options.extra[_startedAtKey] = DateTime.now().microsecondsSinceEpoch;

      if (generateCurl) {
        options.extra['_curl'] = _buildCurl(options);
      }

      if (logRequestBody && options.data != null) {
        options.extra['_request_body'] = _truncate(_bodyToString(options.data));
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
      final elapsed = _elapsedMs(response.requestOptions);
      final method = response.requestOptions.method.toUpperCase();
      final curl = response.requestOptions.extra['_curl'] as String?;
      final reqBody = response.requestOptions.extra['_request_body'] as String?;
      final respBody = (logResponseBody && response.data != null)
          ? _truncate(_bodyToString(response.data))
          : null;

      DebugLogger.writeStructured(
        message:
            '[Response]$_prefix ${response.statusCode} $method ${response.requestOptions.uri}'
            '${elapsed > 0 ? ' (${elapsed}ms)' : ''}',
        level: LogLevel.info,
        tag: LogTag.response,
        metadata: {
          'statusCode': response.statusCode,
          'method': method,
          'url': response.requestOptions.uri.toString(),
          if (elapsed > 0) 'durationMs': elapsed,
          if (curl != null) 'curl': curl,
          if (reqBody != null) 'requestBody': reqBody,
          if (respBody != null) 'responseBody': respBody,
        },
      );

      if (response.data case final Map<String, dynamic> data
          when data['error'] == true) {
        DebugLogger.writeStructured(
          message:
              '[Response Error]$_prefix ${response.requestOptions.path} '
              '— ${data['message']} — $data',
          level: LogLevel.error,
          tag: LogTag.responseError,
          metadata: {
            'url': response.requestOptions.path,
            'errorMessage': data['message'],
            if (curl != null) 'curl': curl,
          },
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (flutterDebugLoggerEnabled) {
      final elapsed = _elapsedMs(err.requestOptions);
      final method = err.requestOptions.method.toUpperCase();
      final curl = err.requestOptions.extra['_curl'] as String?;
      final reqBody = err.requestOptions.extra['_request_body'] as String?;
      final respBody = (logResponseBody && err.response?.data != null)
          ? _truncate(_bodyToString(err.response?.data))
          : null;

      DebugLogger.writeStructured(
        message:
            '[API Error]$_prefix ${err.response?.statusCode ?? 0} $method ${err.requestOptions.uri}'
            '${elapsed > 0 ? ' (${elapsed}ms)' : ''}'
            '${err.response?.statusMessage != null ? ' | ${err.response!.statusMessage}' : ''}'
            '${err.error != null ? ' | ${err.error}' : ''}',
        level: LogLevel.error,
        tag: LogTag.apiError,
        metadata: {
          if (err.response?.statusCode != null)
            'statusCode': err.response!.statusCode,
          'method': method,
          'url': err.requestOptions.uri.toString(),
          if (elapsed > 0) 'durationMs': elapsed,
          if (err.response?.statusMessage != null)
            'statusMessage': err.response!.statusMessage,
          if (curl != null) 'curl': curl,
          if (reqBody != null) 'requestBody': reqBody,
          if (respBody != null) 'responseBody': respBody,
        },
        stackTrace: err.stackTrace != StackTrace.empty
            ? err.stackTrace.toString()
            : null,
      );
    }
    handler.reject(err);
  }
}
