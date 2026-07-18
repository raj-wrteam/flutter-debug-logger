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
              " -F '${_escapeSingle(file.key)}=@${_escapeSingle(filename)}'");
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

  /// Logs a body entry, keeping the full untruncated text in metadata
  /// (as `fullMessage`) so copy/export/detail views can recover it even
  /// though [message] shows the `maxBodyChars`-truncated version.
  void _writeBody({
    required String label,
    required dynamic data,
    required LogLevel level,
  }) {
    final raw = _bodyToString(data);
    final truncated = _truncate(raw);
    final displayMessage = '$label$_prefix $truncated';
    DebugLogger.writeStructured(
      message: displayMessage,
      level: level,
      tag: LogTag.body,
      metadata: {
        if (raw != truncated) 'fullMessage': '$label$_prefix $raw',
      },
    );
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

      final params = options.queryParameters.isEmpty
          ? ''
          : ' params:${options.queryParameters}';

      DebugLogger.writeStructured(
        message: '[Request]$_prefix ${options.method} ${options.uri}$params',
        level: LogLevel.info,
        tag: LogTag.request,
        metadata: {
          'method': options.method,
          'url': options.uri.toString(),
          if (options.queryParameters.isNotEmpty)
            'params': options.queryParameters,
        },
      );

      if (logRequestBody && options.data != null) {
        _writeBody(
          label: '[Request Body]',
          data: options.data,
          level: LogLevel.info,
        );
      }

      if (generateCurl) {
        final curl = _buildCurl(options);
        DebugLogger.writeStructured(
          message: '[cURL]$_prefix $curl',
          level: LogLevel.info,
          tag: LogTag.curl,
          metadata: {'curl': curl},
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
      final elapsed = _elapsedMs(response.requestOptions);

      DebugLogger.writeStructured(
        message:
            '[Response]$_prefix ${response.statusCode} ${response.requestOptions.uri}'
            '${elapsed > 0 ? ' (${elapsed}ms)' : ''}',
        level: LogLevel.info,
        tag: LogTag.response,
        metadata: {
          'statusCode': response.statusCode,
          'url': response.requestOptions.uri.toString(),
          if (elapsed > 0) 'durationMs': elapsed,
        },
      );

      if (logResponseBody && response.data != null) {
        _writeBody(
          label: '[Response Body]',
          data: response.data,
          level: LogLevel.info,
        );
      }

      if (response.data case final Map<String, dynamic> data
          when data['error'] == true) {
        DebugLogger.writeStructured(
          message: '[Response Error]$_prefix ${response.requestOptions.path} '
              '— ${data['message']} — $data',
          level: LogLevel.error,
          tag: LogTag.responseError,
          metadata: {
            'url': response.requestOptions.path,
            'errorMessage': data['message'],
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
      DebugLogger.writeStructured(
        message:
            '[API Error]$_prefix ${err.response?.statusCode} ${err.requestOptions.uri}'
            '${elapsed > 0 ? ' (${elapsed}ms)' : ''}'
            ' | ${err.response?.statusMessage} | ${err.error}',
        level: LogLevel.error,
        tag: LogTag.apiError,
        metadata: {
          'statusCode': err.response?.statusCode,
          'url': err.requestOptions.uri.toString(),
          if (elapsed > 0) 'durationMs': elapsed,
          'statusMessage': err.response?.statusMessage,
        },
        stackTrace: err.stackTrace != StackTrace.empty
            ? err.stackTrace.toString()
            : null,
      );

      if (logResponseBody && err.response?.data != null) {
        _writeBody(
          label: '[Error Body]',
          data: err.response?.data,
          level: LogLevel.error,
        );
      }
    }
    handler.reject(err);
  }
}
