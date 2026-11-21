import 'dart:async';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import '../../core/constants.dart';
import '../../core/l10n/app_strings.dart';

enum ApiErrorKind { network, timeout, rateLimit, server, badRequest, unknown }

/// A data-provider failure, classified so the UI can show a helpful message.
class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this.message});

  final ApiErrorKind kind;
  final int? statusCode;
  final String? message;

  String describe(AppStrings s) {
    switch (kind) {
      case ApiErrorKind.network:
        return s.errNetwork;
      case ApiErrorKind.timeout:
        return s.errTimeout;
      case ApiErrorKind.rateLimit:
        return s.errRateLimit;
      case ApiErrorKind.server:
        return s.errServer;
      case ApiErrorKind.badRequest:
        return message == null ? s.errBadRequest : '${s.errBadRequest}\n$message';
      case ApiErrorKind.unknown:
        return s.errUnknown;
    }
  }

  bool get isOffline => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  @override
  String toString() => 'ApiException($kind, $statusCode, $message)';
}

ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final type = error.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return const ApiException(ApiErrorKind.timeout);
    }
    if (type == DioExceptionType.connectionError) {
      return const ApiException(ApiErrorKind.network);
    }
    if (type == DioExceptionType.badResponse) {
      final code = error.response?.statusCode ?? 0;
      String? reason;
      final data = error.response?.data;
      if (data is Map && data['reason'] is String) reason = data['reason'] as String;
      if (code == 429) {
        return ApiException(ApiErrorKind.rateLimit, statusCode: code, message: reason);
      }
      if (code >= 500) {
        return ApiException(ApiErrorKind.server, statusCode: code, message: reason);
      }
      return ApiException(ApiErrorKind.badRequest, statusCode: code, message: reason);
    }
    if (error.error is SocketException) {
      return const ApiException(ApiErrorKind.network);
    }
    return ApiException(ApiErrorKind.unknown, message: error.message);
  }
  if (error is SocketException) return const ApiException(ApiErrorKind.network);
  if (error is TimeoutException) return const ApiException(ApiErrorKind.timeout);
  return ApiException(ApiErrorKind.unknown, message: error.toString());
}

/// Retries idempotent GET requests on transient failures with backoff.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;
  static const _maxRetries = 2;

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.method.toUpperCase() != 'GET') return false;
    final type = err.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.connectionError) {
      return true;
    }
    if (type == DioExceptionType.badResponse) {
      final code = err.response?.statusCode ?? 0;
      return code == 502 || code == 503 || code == 504;
    }
    return false;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;
    if (attempt >= _maxRetries || !_shouldRetry(err)) {
      handler.next(err);
      return;
    }
    await Future<void>.delayed(Duration(milliseconds: 700 * (1 << attempt)));
    final options = err.requestOptions..extra['retry_attempt'] = attempt + 1;
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

class HttpClientFactory {
  HttpClientFactory._();

  static Dio create() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 12),
      headers: {'User-Agent': AppInfo.userAgent},
    ));
    dio.interceptors.add(_RetryInterceptor(dio));
    return dio;
  }
}

/// Adds the optional Open-Meteo API key to query parameters.
Map<String, dynamic> withOpenMeteoKey(Map<String, dynamic> query) {
  if (Endpoints.openMeteoApiKey.isEmpty) return query;
  return {...query, 'apikey': Endpoints.openMeteoApiKey};
}
