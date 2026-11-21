import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../db/app_database.dart';
import 'http.dart';

class FetchResult<T> {
  const FetchResult(this.data, this.fetchedAt, {this.stale = false});

  final T data;
  final DateTime fetchedAt;

  /// True when a refresh failed and older cached data was returned.
  final bool stale;
}

/// HTTP GET with a persistent cache (SQLite), freshness windows, offline
/// fallback and de-duplication of identical in-flight requests.
class CachedFetcher {
  CachedFetcher(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;
  final Map<String, Future<FetchResult<String>>> _inFlight = {};

  static String cacheKey(String url, Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return url;
    final keys = query.keys.toList()..sort();
    return '$url?${keys.map((k) => '$k=${query[k]}').join('&')}';
  }

  Future<FetchResult<String>> getText(
    String url, {
    Map<String, dynamic>? query,
    Duration maxAge = const Duration(minutes: 30),
    Map<String, String>? headers,
    bool forceRefresh = false,
    bool persist = true,
    String keyPrefix = '',
  }) {
    final key = '$keyPrefix${cacheKey(url, query)}';
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = _load(url, key, query, maxAge, headers, forceRefresh, persist);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  Future<FetchResult<String>> _load(
    String url,
    String key,
    Map<String, dynamic>? query,
    Duration maxAge,
    Map<String, String>? headers,
    bool forceRefresh,
    bool persist,
  ) async {
    CachedBody? cached;
    if (persist) {
      try {
        cached = await _db.cached(key);
      } catch (_) {
        cached = null;
      }
    }
    final now = DateTime.now();
    if (!forceRefresh && cached != null && now.difference(cached.fetchedAt) < maxAge) {
      return FetchResult(cached.body, cached.fetchedAt);
    }
    try {
      final response = await _dio.get<String>(
        url,
        queryParameters: query,
        options: Options(responseType: ResponseType.plain, headers: headers),
      );
      final body = response.data ?? '';
      if (persist) {
        unawaited(_db.putCached(key, body).catchError((_) {}));
      }
      return FetchResult(body, DateTime.now());
    } catch (e) {
      final apiError = toApiException(e);
      // Serve stale data when offline or when the service is struggling.
      if (cached != null &&
          (apiError.isOffline ||
              apiError.kind == ApiErrorKind.server ||
              apiError.kind == ApiErrorKind.rateLimit)) {
        return FetchResult(cached.body, cached.fetchedAt, stale: true);
      }
      throw apiError;
    }
  }

  Future<FetchResult<Object?>> getJson(
    String url, {
    Map<String, dynamic>? query,
    Duration maxAge = const Duration(minutes: 30),
    Map<String, String>? headers,
    bool forceRefresh = false,
    bool persist = true,
  }) async {
    final r = await getText(url,
        query: query,
        maxAge: maxAge,
        headers: headers,
        forceRefresh: forceRefresh,
        persist: persist);
    try {
      return FetchResult<Object?>(jsonDecode(r.data), r.fetchedAt, stale: r.stale);
    } on FormatException catch (e) {
      throw ApiException(ApiErrorKind.unknown, message: 'Invalid JSON: ${e.message}');
    }
  }

  /// Uncached JSON GET (used for high-volume map grid requests).
  Future<Object?> getJsonDirect(String url, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<String>(
        url,
        queryParameters: query,
        options: Options(responseType: ResponseType.plain),
      );
      return jsonDecode(response.data ?? 'null');
    } on FormatException catch (e) {
      throw ApiException(ApiErrorKind.unknown, message: 'Invalid JSON: ${e.message}');
    } catch (e) {
      throw toApiException(e);
    }
  }
}
