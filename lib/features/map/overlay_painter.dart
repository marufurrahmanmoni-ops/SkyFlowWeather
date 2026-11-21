import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/geo.dart';
import '../../core/lru_cache.dart';
import '../../core/units.dart';
import 'grid.dart';
import 'layer_catalog.dart';
import 'map_viewport.dart';
import 'overlay_engine.dart';

/// Draws vector overlays above the map: direction arrows, value labels,
/// isobars and location markers.
class WeatherOverlayPainter extends CustomPainter {
  WeatherOverlayPainter({
    required this.engine,
    required this.viewport,
    required this.units,
    required this.showValues,
    required this.showArrows,
    required this.showIsobars,
    required this.selected,
    required this.myLocation,
  }) : super(repaint: Listenable.merge([engine, viewport]));

  final OverlayEngine engine;
  final ValueNotifier<MapViewport?> viewport;
  final UnitFormatter units;
  final bool showValues;
  final bool showArrows;
  final bool showIsobars;
  final GeoPoint? selected;
  final GeoPoint? myLocation;

  static final LruCache<String, TextPainter> _labels = LruCache(400);

  @override
  void paint(Canvas canvas, Size size) {
    final vp = viewport.value;
    if (vp == null) return;
    final field = engine.field;
    final layer = engine.layer;
    if (field != null && field.times.isNotEmpty && engine.frameTimes.isNotEmpty) {
      final t = engine.fieldTimeIndex;
      if (showIsobars && layer.isobars && field.has('pressure_msl')) {
        _drawIsobars(canvas, vp, field, t);
      }
      if (showArrows && layer.arrowVariable != null && field.has(layer.arrowVariable!)) {
        _drawArrows(canvas, vp, field, t, layer);
      }
      if (showValues) _drawValues(canvas, vp, field, layer);
    }
    final me = myLocation;
    if (me != null) {
      final o = vp.project(me.lat, me.lon);
      canvas.drawCircle(o, 11, Paint()..color = const Color(0x334CC3FF));
      canvas.drawCircle(o, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(o, 4.8, Paint()..color = const Color(0xFF1E88E5));
    }
    final sel = selected;
    if (sel != null) {
      final o = vp.project(sel.lat, sel.lon);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white;
      canvas.drawCircle(o, 9, Paint()..color = const Color(0x55000000));
      canvas.drawCircle(o, 9, ring);
      canvas.drawCircle(o, 3, Paint()..color = Colors.white);
    }
  }

  /// Grid stride so that drawn items are at least [minPx] apart.
  int _stride(MapViewport vp, GridSpec spec, double minPx) {
    final px = spec.step * vp.pixelsPerDegreeLon;
    if (px <= 0) return 1;
    return math.max(1, (minPx / px).ceil());
  }

  void _drawArrows(Canvas canvas, MapViewport vp, GridField field, int t, WeatherLayerDef layer) {
    final spec = field.spec;
    final stride = _stride(vp, spec, 52);
    final dirVar = layer.arrowVariable!;
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    for (var r = 0; r < spec.rows; r += stride) {
      for (var c = 0; c < spec.cols; c += stride) {
        final dir = field.valueAt(dirVar, t, r, c);
        if (dir.isNaN) continue;
        final o = vp.project(spec.latAt(r), spec.lonAt(c));
        if (!vp.isVisible(o)) continue;
        final speed = field.valueAt(layer.variable, t, r, c);
        final len = speed.isNaN ? 14.0 : (9 + math.min(12, speed / 6)).toDouble();
        // Arrow points where the flow goes (direction + 180°).
        final a = (dir + 180) * math.pi / 180;
        final dx = math.sin(a), dy = -math.cos(a);
        final tip = o + Offset(dx, dy) * len / 2;
        final tail = o - Offset(dx, dy) * len / 2;
        final px = -dy, py = dx;
        final path = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - dx * 6 + px * 4, tip.dy - dy * 6 + py * 4)
          ..lineTo(tip.dx - dx * 6 - px * 4, tip.dy - dy * 6 - py * 4)
          ..close();
        canvas.drawLine(tail, tip, shadow);
        canvas.drawPath(path, shadow);
        canvas.drawLine(
            tail,
            tip,
            Paint()
              ..color = fill.color
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round);
        canvas.drawPath(path, fill);
      }
    }
  }

  void _drawValues(Canvas canvas, MapViewport vp, GridField field, WeatherLayerDef layer) {
    final spec = field.spec;
    final stride = _stride(vp, spec, 86);
    // Offset labels half a stride from arrows so they do not overlap.
    final offset = stride > 1 ? stride ~/ 2 : 0;
    for (var r = offset; r < spec.rows; r += stride) {
      for (var c = offset; c < spec.cols; c += stride) {
        final lat = spec.latAt(r), lon = spec.lonAt(c);
        final o = vp.project(lat, lon);
        if (!vp.isVisible(o, margin: -12)) continue;
        final v = engine.valueAt(lat, lon);
        if (v.isNaN) continue;
        if (layer.scale.transparentBelow != null && v < layer.scale.transparentBelow!) continue;
        final text = units.format(layer.quantity, v, withUnit: false);
        final tp = _labels.get(text) ?? _makeLabel(text);
        tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  TextPainter _makeLabel(String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(color: Color(0xCC000000), blurRadius: 3),
            Shadow(color: Color(0x99000000), blurRadius: 1, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _labels.put(text, tp);
    return tp;
  }

  /// Marching-squares isobars every 4 hPa.
  void _drawIsobars(Canvas canvas, MapViewport vp, GridField field, int t) {
    final spec = field.spec;
    final rows = spec.rows, cols = spec.cols;
    double v(int r, int c) => field.valueAt('pressure_msl', t, r, c);
    var minV = double.infinity, maxV = double.negativeInfinity;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x = v(r, c);
        if (x.isNaN) continue;
        minV = math.min(minV, x);
        maxV = math.max(maxV, x);
      }
    }
    if (!minV.isFinite || !maxV.isFinite) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final strong = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final first = (minV / 4).ceil() * 4;
    for (var level = first.toDouble(); level <= maxV; level += 4) {
      final path = Path();
      Offset? labelAt;
      for (var r = 0; r < rows - 1; r++) {
        for (var c = 0; c < cols - 1; c++) {
          final a = v(r, c), b = v(r, c + 1), cc = v(r + 1, c + 1), d = v(r + 1, c);
          if (a.isNaN || b.isNaN || cc.isNaN || d.isNaN) continue;
          var idx = 0;
          if (a >= level) idx |= 8;
          if (b >= level) idx |= 4;
          if (cc >= level) idx |= 2;
          if (d >= level) idx |= 1;
          if (idx == 0 || idx == 15) continue;
          Offset lerp(int r1, int c1, double v1, int r2, int c2, double v2) {
            final f = (level - v1) / ((v2 - v1).abs() < 1e-9 ? 1e-9 : (v2 - v1));
            final lat = spec.latAt(r1) + (spec.latAt(r2) - spec.latAt(r1)) * f;
            final lon = spec.lonAt(c1) + (spec.lonAt(c2) - spec.lonAt(c1)) * f;
            return vp.project(lat, lon);
          }

          final top = lerp(r, c, a, r, c + 1, b);
          final right = lerp(r, c + 1, b, r + 1, c + 1, cc);
          final bottom = lerp(r + 1, c, d, r + 1, c + 1, cc);
          final left = lerp(r, c, a, r + 1, c, d);
          void seg(Offset p1, Offset p2) {
            path
              ..moveTo(p1.dx, p1.dy)
              ..lineTo(p2.dx, p2.dy);
            if (labelAt == null && vp.isVisible(p1, margin: -30)) labelAt = p1;
          }

          switch (idx) {
            case 1:
            case 14:
              seg(left, bottom);
            case 2:
            case 13:
              seg(bottom, right);
            case 3:
            case 12:
              seg(left, right);
            case 4:
            case 11:
              seg(top, right);
            case 5:
              seg(left, top);
              seg(bottom, right);
            case 6:
            case 9:
              seg(top, bottom);
            case 7:
            case 8:
              seg(left, top);
            case 10:
              seg(left, bottom);
              seg(top, right);
          }
        }
      }
      final isMajor = level.round() % 20 == 0;
      canvas.drawPath(path, isMajor ? strong : paint);
      final at = labelAt;
      if (at != null) {
        final text = units.format(Quantity.pressure, level, withUnit: false);
        final tp = _labels.get('p$text') ?? _pressureLabel(text);
        final rect = Rect.fromCenter(center: at, width: tp.width + 8, height: tp.height + 2);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()..color = const Color(0xAA0B1220));
        tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  TextPainter _pressureLabel(String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    _labels.put('p$text', tp);
    return tp;
  }

  @override
  bool shouldRepaint(WeatherOverlayPainter old) =>
      old.engine != engine ||
      old.showValues != showValues ||
      old.showArrows != showArrows ||
      old.showIsobars != showIsobars ||
      old.selected != selected ||
      old.myLocation != myLocation ||
      old.units != units;
}
