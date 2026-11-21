import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'grid.dart';
import 'map_viewport.dart';

/// Source of the wind field and current time step for the particles.
abstract class WindFieldProvider {
  GridField? get windField;
  int get windTimeIndex;
}

/// Animated wind particles advected through the gridded wind field.
///
/// Particles live in geographic coordinates, so they stay attached to the
/// map while it is panned or zoomed. Each particle keeps a short trail that
/// fades with age.
class ParticleController extends ChangeNotifier {
  ParticleController({
    required TickerProvider vsync,
    required this.source,
    required this.viewport,
  }) {
    _ticker = vsync.createTicker(_onTick);
  }

  final WindFieldProvider source;
  final ValueListenable<MapViewport?> viewport;
  late final Ticker _ticker;
  final math.Random _rng = math.Random();

  static const int trail = 7;
  static const String speedVar = 'wind_speed_10m';
  static const String dirVar = 'wind_direction_10m';

  int _count = 0;
  Float64List _lat = Float64List(0);
  Float64List _lon = Float64List(0);
  Int32List _age = Int32List(0);
  Int32List _maxAge = Int32List(0);

  /// Screen-space trail points of the last frame: count * trail * 2.
  Float32List _trailXY = Float32List(0);
  Uint8List _trailLen = Uint8List(0);
  int _head = 0;

  bool _enabled = false;
  double density = 1.0;
  Duration _last = Duration.zero;

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    if (value) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
      _count = 0;
      notifyListeners();
    }
  }

  void reset() {
    _count = 0;
  }

  void _ensureCount(MapViewport vp) {
    final target = (vp.size.width * vp.size.height / 320 * density).clamp(150, 2600).toInt();
    if (target == _count) return;
    _count = target;
    _lat = Float64List(target);
    _lon = Float64List(target);
    _age = Int32List(target);
    _maxAge = Int32List(target);
    _trailXY = Float32List(target * trail * 2);
    _trailLen = Uint8List(target);
    for (var i = 0; i < target; i++) {
      _spawn(i, vp, randomAge: true);
    }
  }

  void _spawn(int i, MapViewport vp, {bool randomAge = false}) {
    final p = vp.unproject(Offset(
      _rng.nextDouble() * vp.size.width,
      _rng.nextDouble() * vp.size.height,
    ));
    _lat[i] = p.lat;
    _lon[i] = p.lon;
    _maxAge[i] = 50 + _rng.nextInt(70);
    _age[i] = randomAge ? _rng.nextInt(_maxAge[i]) : 0;
    _trailLen[i] = 0;
  }

  void _onTick(Duration elapsed) {
    // Cap at ~45 fps to save battery.
    if (elapsed - _last < const Duration(milliseconds: 22)) return;
    _last = elapsed;
    final vp = viewport.value;
    final field = source.windField;
    if (vp == null || field == null || field.times.isEmpty || vp.size.isEmpty) {
      if (_count != 0) {
        _count = 0;
        notifyListeners();
      }
      return;
    }
    _ensureCount(vp);
    final t = source.windTimeIndex.clamp(0, field.times.length - 1).toInt();
    _head = (_head + 1) % trail;
    // Pixels moved per frame per m/s; slightly faster when zoomed out.
    final k = 0.30 + 0.02 * (8 - vp.zoom).clamp(0.0, 6.0).toDouble();
    for (var i = 0; i < _count; i++) {
      final o = vp.project(_lat[i], _lon[i]);
      final speedKmh = field.sample(speedVar, t, _lat[i], _lon[i]);
      final dir = field.sampleDirection(dirVar, t, _lat[i], _lon[i]);
      _age[i]++;
      final offscreen = !vp.isVisible(o, margin: 10);
      if (speedKmh.isNaN || dir.isNaN || offscreen || _age[i] > _maxAge[i]) {
        _spawn(i, vp);
        final s = vp.project(_lat[i], _lon[i]);
        final base = (i * trail + _head) * 2;
        _trailXY[base] = s.dx;
        _trailXY[base + 1] = s.dy;
        _trailLen[i] = 1;
        continue;
      }
      final ms = speedKmh / 3.6;
      // Meteorological direction is where the wind comes FROM.
      final rad = dir * math.pi / 180;
      final u = -ms * math.sin(rad);
      final v = -ms * math.cos(rad);
      final nx = o.dx + u * k;
      final ny = o.dy - v * k;
      final g = vp.unproject(Offset(nx, ny));
      _lat[i] = g.lat;
      _lon[i] = g.lon;
      final base = (i * trail + _head) * 2;
      _trailXY[base] = nx;
      _trailXY[base + 1] = ny;
      if (_trailLen[i] < trail) _trailLen[i]++;
    }
    notifyListeners();
  }

  /// Draws trails as line segments batched by age bucket.
  void paint(Canvas canvas, MapViewport? vp) {
    if (_count == 0 || vp == null) return;
    final buckets = List<List<double>>.generate(trail - 1, (_) => <double>[]);
    for (var i = 0; i < _count; i++) {
      final len = _trailLen[i];
      if (len < 2) continue;
      for (var s = 0; s < len - 1; s++) {
        final a = (_head - s + trail) % trail;
        final b = (_head - s - 1 + trail) % trail;
        final ia = (i * trail + a) * 2, ib = (i * trail + b) * 2;
        final ax = _trailXY[ia], ay = _trailXY[ia + 1];
        final bx = _trailXY[ib], by = _trailXY[ib + 1];
        // Skip jumps (e.g. after a respawn or wrap).
        if ((ax - bx).abs() > 40 || (ay - by).abs() > 40) continue;
        buckets[s]
          ..add(bx)
          ..add(by)
          ..add(ax)
          ..add(ay);
      }
    }
    for (var s = 0; s < buckets.length; s++) {
      if (buckets[s].isEmpty) continue;
      final alpha = (0.85 * (1 - s / (trail - 1))).clamp(0.05, 0.85).toDouble();
      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, alpha)
        ..strokeWidth = s == 0 ? 1.6 : 1.3
        ..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(PointMode.lines, Float32List.fromList(buckets[s]), paint);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class ParticlePainter extends CustomPainter {
  ParticlePainter(this.controller) : super(repaint: controller);

  final ParticleController controller;

  @override
  void paint(Canvas canvas, Size size) {
    controller.paint(canvas, controller.viewport.value);
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => oldDelegate.controller != controller;
}
