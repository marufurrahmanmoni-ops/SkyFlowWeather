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
    Duration? maxStale,
    void Function()? onRevalidated,
  }) {
    final key = '$keyPrefix${cacheKey(url, query)}';
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = _load(url, key, query, maxAge, headers, forceRefresh, persist, maxStale, onRevalidated);
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
    bool persist, [
    Duration? maxStale,
    void Function()? onRevalidated,
  ]) async {
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
    // Stale-while-revalidate: show the saved copy at once and refresh it in
    // the background; [onRevalidated] fires once the new copy is saved.
    if (!forceRefresh &&
        persist &&
        maxStale != null &&
        cached != null &&
        now.difference(cached.fetchedAt) < maxStale) {
      final refresh = _revalidating.putIfAbsent(
        key,
        () => _network(url, key, query, headers, persist, awaitSave: true)
            .whenComplete(() => _revalidating.remove(key)),
      );
      unawaited(refresh.then((_) => onRevalidated?.call(), onError: (Object _) {}));
      return FetchResult(cached.body, cached.fetchedAt);
    }
    try {
      return await _network(url, key, query, headers, persist);
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

  final Map<String, Future<FetchResult<String>>> _revalidating = {};

  Future<FetchResult<String>> _network(
    String url,
    String key,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool persist, {
    bool awaitSave = false,
  }) async {
    final response = await _dio.get<String>(
      url,
      queryParameters: query,
      options: Options(responseType: ResponseType.plain, headers: headers),
    );
    final body = response.data ?? '';
    if (persist) {
      final save = _db.putCached(key, body).catchError((_) {});
      if (awaitSave) {
        await save;
      } else {
        unawaited(save);
      }
    }
    return FetchResult(body, DateTime.now());
  }

  Future<FetchResult<Object?>> getJson(
    String url, {
    Map<String, dynamic>? query,
    Duration maxAge = const Duration(minutes: 30),
    Map<String, String>? headers,
    bool forceRefresh = false,
    bool persist = true,
    Duration? maxStale,
    void Function()? onRevalidated,
  }) async {
    final r = await getText(url,
        query: query,
        maxAge: maxAge,
        headers: headers,
        forceRefresh: forceRefresh,
        persist: persist,
        maxStale: maxStale,
        onRevalidated: onRevalidated);
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
