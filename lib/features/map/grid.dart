import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/geo.dart';
import '../../core/lru_cache.dart';
import '../../data/net/http.dart';
import '../../data/sources/interfaces.dart';

/// A regular lat/lon sampling grid aligned to multiples of [step], so that
/// panning reuses already-downloaded points.
class GridSpec {
  const GridSpec({
    required this.step,
    required this.north,
    required this.west,
    required this.rows,
    required this.cols,
  });

  final double step;
  final double north;
  final double west;
  final int rows;
  final int cols;

  double get south => north - (rows - 1) * step;
  double get east => west + (cols - 1) * step;
  int get count => rows * cols;

  double latAt(int r) => north - r * step;
  double lonAt(int c) => west + c * step;

  static const List<double> _steps = [
    0.1, 0.125, 0.2, 0.25, 0.4, 0.5, 0.75, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7.5, 10, 15,
  ];

  /// Builds a grid covering [view] with about [targetCols] columns, capped
  /// at [maxPoints] points.
  static GridSpec forView(GeoBounds view, int targetCols, {int maxPoints = 260}) {
    final span = math.max(0.2, view.east - view.west);
    var stepIndex = 0;
    final raw = span / targetCols;
    while (stepIndex < _steps.length - 1 && _steps[stepIndex] < raw) {
      stepIndex++;
    }
    while (true) {
      final step = _steps[stepIndex];
      final west = (view.west / step).floor() * step;
      final east = (view.east / step).ceil() * step;
      final north = math.min(84.0, (view.north / step).ceil() * step);
      final south = math.max(-84.0, (view.south / step).floor() * step);
      final cols = math.max(2, ((east - west) / step).round() + 1);
      final rows = math.max(2, ((north - south) / step).round() + 1);
      final clampedWest = math.max(-180.0, west);
      final clampedCols = math.min(cols, ((180.0 - clampedWest) / step).floor() + 1);
      if (rows * clampedCols <= maxPoints || stepIndex == _steps.length - 1) {
        return GridSpec(
          step: step,
          north: north,
          west: clampedWest,
          rows: rows,
          cols: math.max(2, clampedCols),
        );
      }
      stepIndex++;
    }
  }

  bool sameAs(GridSpec other) =>
      other.step == step &&
      other.north == north &&
      other.west == west &&
      other.rows == rows &&
      other.cols == cols;

  /// True if this grid fully contains [other] at the same step.
  bool covers(GridSpec other) =>
      other.step == step &&
      other.north <= north + 1e-9 &&
      other.south >= south - 1e-9 &&
      other.west >= west - 1e-9 &&
      other.east <= east + 1e-9;
}

/// Gridded hourly values: `data[variable][t * rows * cols + r * cols + c]`,
/// NaN where the provider has no value.
class GridField {
  GridField({
    required this.spec,
    required this.times,
    required this.data,
    required this.fetchedAt,
  });

  final GridSpec spec;
  final List<int> times;
  final Map<String, Float32List> data;
  final DateTime fetchedAt;

  int get frameSize => spec.rows * spec.cols;

  bool has(String variable) => data.containsKey(variable);

  /// Index of the time step nearest to [unixSeconds].
  int timeIndex(int unixSeconds) {
    if (times.isEmpty) return 0;
    var best = 0;
    var bestDiff = (times[0] - unixSeconds).abs();
    for (var i = 1; i < times.length; i++) {
      final d = (times[i] - unixSeconds).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }

  double valueAt(String variable, int t, int r, int c) {
    final arr = data[variable];
    if (arr == null) return double.nan;
    final i = t * frameSize + r * spec.cols + c;
    if (i < 0 || i >= arr.length) return double.nan;
    return arr[i];
  }

  /// Bilinear sample at a location, ignoring missing neighbours.
  double sample(String variable, int t, double lat, double lon) {
    final arr = data[variable];
    if (arr == null) return double.nan;
    final fr = (spec.north - lat) / spec.step;
    final fc = (lon - spec.west) / spec.step;
    if (fr < 0 || fc < 0 || fr > spec.rows - 1 || fc > spec.cols - 1) return double.nan;
    final r0 = fr.floor().clamp(0, spec.rows - 1).toInt();
    final c0 = fc.floor().clamp(0, spec.cols - 1).toInt();
    final r1 = math.min(r0 + 1, spec.rows - 1);
    final c1 = math.min(c0 + 1, spec.cols - 1);
    final dr = fr - r0, dc = fc - c0;
    final base = t * frameSize;
    var sum = 0.0, wsum = 0.0;
    void add(int r, int c, double w) {
      final v = arr[base + r * spec.cols + c];
      if (!v.isNaN && w > 0) {
        sum += v * w;
        wsum += w;
      }
    }

    add(r0, c0, (1 - dr) * (1 - dc));
    add(r0, c1, (1 - dr) * dc);
    add(r1, c0, dr * (1 - dc));
    add(r1, c1, dr * dc);
    if (wsum < 1e-6) return double.nan;
    return sum / wsum;
  }

  /// Bilinear sample of a direction field via unit vectors (handles 359°→1°).
  double sampleDirection(String variable, int t, double lat, double lon) {
    final arr = data[variable];
    if (arr == null) return double.nan;
    final fr = (spec.north - lat) / spec.step;
    final fc = (lon - spec.west) / spec.step;
    if (fr < 0 || fc < 0 || fr > spec.rows - 1 || fc > spec.cols - 1) return double.nan;
    final r0 = fr.floor().clamp(0, spec.rows - 1).toInt();
    final c0 = fc.floor().clamp(0, spec.cols - 1).toInt();
    final r1 = math.min(r0 + 1, spec.rows - 1);
    final c1 = math.min(c0 + 1, spec.cols - 1);
    final dr = fr - r0, dc = fc - c0;
    final base = t * frameSize;
    var sx = 0.0, sy = 0.0, wsum = 0.0;
    void add(int r, int c, double w) {
      final v = arr[base + r * spec.cols + c];
      if (!v.isNaN && w > 0) {
        final rad = v * math.pi / 180;
        sx += math.sin(rad) * w;
        sy += math.cos(rad) * w;
        wsum += w;
      }
    }

    add(r0, c0, (1 - dr) * (1 - dc));
    add(r0, c1, (1 - dr) * dc);
    add(r1, c0, dr * (1 - dc));
    add(r1, c1, dr * dc);
    if (wsum < 1e-6) return double.nan;
    final deg = math.atan2(sx, sy) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  /// Copy of one frame (optionally summed from frame 0 for accumulations).
  Float32List frame(String variable, int t, {bool accumulateFrom = false, int from = 0}) {
    final out = Float32List(frameSize);
    final arr = data[variable];
    if (arr == null) {
      out.fillRange(0, frameSize, double.nan);
      return out;
    }
    if (!accumulateFrom) {
      out.setRange(0, frameSize, arr, t * frameSize);
      return out;
    }
    for (var i = 0; i < frameSize; i++) {
      var s = 0.0;
      var any = false;
      for (var k = from; k <= t; k++) {
        final v = arr[k * frameSize + i];
        if (!v.isNaN) {
          s += v;
          any = true;
        }
      }
      out[i] = any ? s : double.nan;
    }
    return out;
  }

  bool hasAnyValue(String variable) {
    final arr = data[variable];
    if (arr == null) return false;
    for (final v in arr) {
      if (!v.isNaN) return true;
    }
    return false;
  }
}

/// Downloads and caches grid point series, staying inside the free
/// Open-Meteo limits (each point counts as one API call).
class GridRepository {
  GridRepository(this._source);

  final GridSource _source;
  final LruCache<String, PointSeries> _cache = LruCache(6000);
  final List<(DateTime, int)> _recent = [];

  /// Points requested in the last minute.
  int get _pointsLastMinute {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    _recent.removeWhere((e) => e.$1.isBefore(cutoff));
    return _recent.fold(0, (a, e) => a + e.$2);
  }

  static const int _perMinuteBudget = 450;
  static const int _batchSize = 90;

  String _key(GridRequest req, double lat, double lon) {
    final hourBucket = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 3600000;
    return '${req.key}|$hourBucket|${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}';
  }

  /// Loads all points of [spec]. [onThrottle] is called while waiting for
  /// the per-minute budget.
  Future<GridField> load(
    GridSpec spec,
    GridRequest request, {
    void Function(bool waiting)? onThrottle,
    bool Function()? isCancelled,
  }) async {
    final missing = <int>[];
    final series = List<PointSeries?>.filled(spec.count, null);
    for (var r = 0; r < spec.rows; r++) {
      for (var c = 0; c < spec.cols; c++) {
        final i = r * spec.cols + c;
        final cached = _cache.get(_key(request, spec.latAt(r), spec.lonAt(c)));
        if (cached != null) {
          series[i] = cached;
        } else {
          missing.add(i);
        }
      }
    }

    // Batches are requested in parallel (still inside the per-minute budget)
    // instead of one after another.
    final pending = <Future<void>>[];
    for (var b = 0; b < missing.length; b += _batchSize) {
      if (isCancelled?.call() ?? false) {
        throw const ApiException(ApiErrorKind.unknown, message: 'cancelled');
      }
      final batch = missing.sublist(b, math.min(b + _batchSize, missing.length));
      while (_pointsLastMinute + batch.length > _perMinuteBudget) {
        onThrottle?.call(true);
        await Future<void>.delayed(const Duration(seconds: 3));
        if (isCancelled?.call() ?? false) {
          throw const ApiException(ApiErrorKind.unknown, message: 'cancelled');
        }
      }
      onThrottle?.call(false);
      _recent.add((DateTime.now(), batch.length));
      final points = [
        for (final i in batch) GeoPoint(spec.latAt(i ~/ spec.cols), spec.lonAt(i % spec.cols)),
      ];
      pending.add(_source.fetch(request, points).then((result) {
        for (var k = 0; k < batch.length; k++) {
          final s = k < result.length ? result[k] : null;
          if (s == null) continue;
          series[batch[k]] = s;
          _cache.put(_key(request, points[k].lat, points[k].lon), s);
        }
      }));
    }
    await Future.wait(pending);

    // Assemble on a common hourly time axis.
    var start = 1 << 62;
    var end = 0;
    for (final s in series) {
      if (s == null || s.length == 0) continue;
      start = math.min(start, s.startTime);
      end = math.max(end, s.startTime + (s.length - 1) * 3600);
    }
    if (end == 0) {
      return GridField(spec: spec, times: const [], data: const {}, fetchedAt: DateTime.now());
    }
    final nTimes = ((end - start) ~/ 3600) + 1;
    final times = [for (var t = 0; t < nTimes; t++) start + t * 3600];
    final frame = spec.count;
    final data = <String, Float32List>{};
    for (final v in request.variables) {
      final arr = Float32List(nTimes * frame)..fillRange(0, nTimes * frame, double.nan);
      for (var i = 0; i < frame; i++) {
        final s = series[i];
        final src = s?.data[v];
        if (s == null || src == null) continue;
        final offset = (s.startTime - start) ~/ 3600;
        for (var t = 0; t < src.length; t++) {
          final tt = t + offset;
          if (tt >= 0 && tt < nTimes) arr[tt * frame + i] = src[t];
        }
      }
      data[v] = arr;
    }
    return GridField(spec: spec, times: times, data: data, fetchedAt: DateTime.now());
  }

  void clear() => _cache.clear();
}
