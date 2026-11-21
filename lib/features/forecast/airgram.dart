import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/forecast.dart';
import '../../data/models/place.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';
import 'chart_kit.dart';

/// Vertical cross-section over time: cloud cover by pressure level,
/// isotherms (0 °C highlighted) and wind arrows.
class AirgramTab extends ConsumerStatefulWidget {
  const AirgramTab({super.key, required this.place});

  final Place place;

  @override
  ConsumerState<AirgramTab> createState() => _AirgramTabState();
}

class _AirgramTabState extends ConsumerState<AirgramTab> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pressureLevelsProvider(widget.place));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(pressureLevelsProvider(widget.place))),
      data: (data) => _build(context, data),
    );
  }

  Widget _build(BuildContext context, OmResponse data) {
    final s = S.of(context);
    final units = ref.watch(unitsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final h = data.hourly;
    if (h.isEmpty) return ErrorView(error: s.noData);
    final start = h.indexFor(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final count = math.max(2, math.min(72, h.length - start));
    final times = h.time.sublist(start, start + count);
    final geo = ChartGeometry(count: count, hourWidth: 16);
    final sel = _selected.clamp(0, count - 1).toInt();
    final levels = airgramLevels.where((l) => h.hasAnyValue('temperature_${l}hPa')).toList();
    if (levels.length < 3) return ErrorView(error: s.noData);

    // Mean geopotential height per level → altitude axis (km).
    final heights = <int, double>{};
    for (final l in levels) {
      final gh = h.series('geopotential_height_${l}hPa').whereType<double>().toList();
      heights[l] = gh.isEmpty ? _standardHeight(l) : gh.reduce((a, b) => a + b) / gh.length;
    }

    final selIndex = start + sel;
    final selTime = TimeFmt.atLocation(h.time[selIndex], data.utcOffsetSeconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: GlassPanel(
            color: AppColors.charcoal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmt.full(selTime), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final l in levels.where((l) => l >= 300))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            '$l hPa · ${units.number(heights[l]! / 1000, decimals: 1)} km',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ),
                        SizedBox(
                          width: 54,
                          child: Text(units.format(Quantity.temperature, h.at('temperature_${l}hPa', selIndex)),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text('☁ ${units.format(Quantity.percent, h.at('cloud_cover_${l}hPa', selIndex))}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          child: Text(units.format(Quantity.speed, h.at('wind_speed_${l}hPa', selIndex)),
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => setState(() => _selected = geo.indexAt(d.localPosition.dx)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TimeAxis(geo: geo, times: times, utcOffset: data.utcOffsetSeconds, fmt: fmt, labelEvery: 3),
                        SizedBox(
                          width: geo.width,
                          height: 360,
                          child: CustomPaint(
                            painter: _AirgramPainter(
                              geo: geo,
                              series: h,
                              start: start,
                              count: count,
                              levels: levels,
                              heights: heights,
                              selected: sel,
                              units: units,
                              freezingLabel: s.freezingLevel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Text(s.airgramNote, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static double _standardHeight(int hPa) {
    // International standard atmosphere approximation (metres).
    return 44330.8 * (1 - math.pow(hPa / 1013.25, 0.190263).toDouble());
  }
}

class _AirgramPainter extends CustomPainter {
  _AirgramPainter({
    required this.geo,
    required this.series,
    required this.start,
    required this.count,
    required this.levels,
    required this.heights,
    required this.selected,
    required this.units,
    required this.freezingLabel,
  });

  final ChartGeometry geo;
  final TimeSeries series;
  final int start;
  final int count;
  final List<int> levels;
  final Map<int, double> heights;
  final int selected;
  final UnitFormatter units;
  final String freezingLabel;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0, bottom = 8.0;
    final plotH = size.height - top - bottom;
    final maxH = heights.values.reduce(math.max);
    final minH = math.min(0.0, heights.values.reduce(math.min));
    double y(double metres) => top + plotH * (1 - (metres - minH) / (maxH - minH));

    // Background and altitude grid.
    canvas.drawRect(
      Rect.fromLTWH(ChartGeometry.leftReserved, top, geo.width - ChartGeometry.leftReserved - ChartGeometry.rightPad, plotH),
      Paint()..color = const Color(0xFF0E2038),
    );
    final grid = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(fontSize: 10, color: AppColors.textSecondary);
    for (var km = 0; km * 1000 <= maxH; km += 2) {
      final yy = y(km * 1000.0);
      canvas.drawLine(Offset(ChartGeometry.leftReserved, yy), Offset(geo.width - ChartGeometry.rightPad, yy), grid);
      final tp = TextPainter(
        text: TextSpan(text: '${units.number(km.toDouble())} km', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, yy - tp.height / 2));
    }

    // Cloud cover cells between level midpoints.
    final sorted = [...levels]..sort((a, b) => heights[a]!.compareTo(heights[b]!));
    for (var k = 0; k < sorted.length; k++) {
      final l = sorted[k];
      final hHere = heights[l]!;
      final lowerEdge = k == 0 ? hHere - 400 : (hHere + heights[sorted[k - 1]]!) / 2;
      final upperEdge = k == sorted.length - 1 ? hHere + 800 : (hHere + heights[sorted[k + 1]]!) / 2;
      for (var i = 0; i < count; i++) {
        final cc = series.at('cloud_cover_${l}hPa', start + i);
        if (cc == null || cc < 3) continue;
        final x0 = geo.xFor(i) - geo.hourWidth / 2;
        final rect = Rect.fromLTRB(
          math.max(ChartGeometry.leftReserved, x0),
          y(upperEdge),
          x0 + geo.hourWidth,
          y(lowerEdge),
        );
        canvas.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: (cc / 100) * 0.85));
      }
    }

    // Isotherms every 5 °C via linear interpolation between levels.
    final iso = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x88FFB547)
      ..strokeWidth = 1;
    final zero = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF4CC3FF)
      ..strokeWidth = 2.2;
    for (var temp = -60; temp <= 40; temp += 5) {
      final path = Path();
      var started = false;
      Offset? labelAt;
      for (var i = 0; i < count; i++) {
        double? found;
        for (var k = 0; k < sorted.length - 1; k++) {
          final a = series.at('temperature_${sorted[k]}hPa', start + i);
          final b = series.at('temperature_${sorted[k + 1]}hPa', start + i);
          if (a == null || b == null) continue;
          if ((a - temp) * (b - temp) <= 0 && (a - b).abs() > 1e-6) {
            final f = (a - temp) / (a - b);
            found = heights[sorted[k]]! + (heights[sorted[k + 1]]! - heights[sorted[k]]!) * f;
            break;
          }
        }
        if (found == null) {
          started = false;
          continue;
        }
        final p = Offset(geo.xFor(i), y(found));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
        if (i == count ~/ 6) labelAt = p;
      }
      canvas.drawPath(path, temp == 0 ? zero : iso);
      if (labelAt != null) {
        final text = temp == 0 ? freezingLabel : units.format(Quantity.temperature, temp.toDouble());
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: 10,
              color: temp == 0 ? AppColors.accent : AppColors.amber,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final r = Rect.fromCenter(center: labelAt, width: tp.width + 6, height: tp.height + 2);
        canvas.drawRect(r, Paint()..color = const Color(0xCC0E2038));
        tp.paint(canvas, labelAt - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Wind arrows every 3 hours at each level.
    final arrow = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final l in sorted) {
      final yy = y(heights[l]!);
      for (var i = 1; i < count; i += 3) {
        final d = series.at('wind_direction_${l}hPa', start + i);
        final sp = series.at('wind_speed_${l}hPa', start + i);
        if (d == null || sp == null) continue;
        final a = (d + 180) * math.pi / 180;
        final double len = 5.0 + math.min(9.0, sp / 15.0);
        final c = Offset(geo.xFor(i), yy);
        final v = Offset(math.sin(a), -math.cos(a)) * len;
        canvas.drawLine(c - v, c + v, arrow);
        final head = c + v;
        final back = Offset(math.sin(a), -math.cos(a)) * 3.5;
        final side = Offset(math.cos(a), math.sin(a)) * 2.5;
        canvas.drawLine(head, head - back + side, arrow);
        canvas.drawLine(head, head - back - side, arrow);
      }
    }

    // Selected hour.
    final xs = geo.xFor(selected);
    canvas.drawLine(
      Offset(xs, top),
      Offset(xs, top + plotH),
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_AirgramPainter old) =>
      old.selected != selected || old.series != series || old.units != units || old.start != start;
}
