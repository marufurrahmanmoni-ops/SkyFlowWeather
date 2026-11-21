import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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

class MeteogramTab extends ConsumerStatefulWidget {
  const MeteogramTab({super.key, required this.place});

  final Place place;

  @override
  ConsumerState<MeteogramTab> createState() => _MeteogramTabState();
}

class _MeteogramTabState extends ConsumerState<MeteogramTab> {
  int _days = 3;
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(forecastProvider(widget.place));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(forecastProvider(widget.place))),
      data: (bundle) => _build(context, bundle.forecast),
    );
  }

  Widget _build(BuildContext context, OmResponse f) {
    final s = S.of(context);
    final units = ref.watch(unitsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final h = f.hourly;
    final start = h.indexFor(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final count = math.max(2, math.min(_days * 24, h.length - start));
    final times = h.time.sublist(start, start + count);
    List<double?> series(String key, [double? Function(double)? map]) {
      final src = h.series(key).sublist(start, start + count);
      if (map == null) return src;
      return [for (final v in src) v == null ? null : map(v)];
    }

    final sel = _selected.clamp(0, count - 1).toInt();
    final geo = ChartGeometry(count: count, hourWidth: _days == 3 ? 15 : 7.5);
    final dayStarts = <int>[
      for (var i = 0; i < count; i++)
        if (TimeFmt.atLocation(times[i], f.utcOffsetSeconds).hour == 0) i,
    ];

    double conv(Quantity q, double v) => units.convert(q, v);
    final temp = series('temperature_2m', (v) => conv(Quantity.temperature, v));
    final feels = series('apparent_temperature', (v) => conv(Quantity.temperature, v));
    final precip = series('precipitation', (v) => conv(Quantity.precipRate, v));
    final pop = series('precipitation_probability');
    final wind = series('wind_speed_10m', (v) => conv(Quantity.speed, v));
    final gust = series('wind_gusts_10m', (v) => conv(Quantity.speed, v));
    final dir = series('wind_direction_10m');
    final pressure = series('pressure_msl', (v) => conv(Quantity.pressure, v));
    final cloud = series('cloud_cover');
    final cloudLow = series('cloud_cover_low');
    final cloudMid = series('cloud_cover_mid');
    final cloudHigh = series('cloud_cover_high');

    (double, double) range(List<double?> a, [List<double?>? b, double pad = 1.0]) {
      var lo = double.infinity, hi = double.negativeInfinity;
      for (final list in [a, if (b != null) b]) {
        for (final v in list) {
          if (v == null) continue;
          lo = math.min(lo, v);
          hi = math.max(hi, v);
        }
      }
      if (!lo.isFinite) return (0.0, 1.0);
      if (hi - lo < pad) hi = lo + pad;
      return (lo - pad * 0.5, hi + pad * 0.5);
    }

    final (tMin, tMax) = range(temp, feels, 2.0);
    final precipMax = math.max(units.precip == PrecipUnit.mm ? 2.0 : 0.08,
        precip.whereType<double>().fold<double>(0.0, math.max) * 1.2);
    final (_, wMax) = range(wind, gust, 5.0);
    final (pMin, pMax) = range(pressure, null, units.pressureUnit == PressureUnit.hpa ? 4.0 : 0.12);

    String num0(double v) => units.number(v);
    String num1(double v) => units.number(v, decimals: 1);
    String num2(double v) => units.number(v, decimals: 2);

    LineChartBarData line(List<double?> v, Color color,
            {double width = 2, bool curved = true, bool area = false, List<int>? dash}) =>
        LineChartBarData(
          spots: spotsOf(v),
          color: color,
          barWidth: width,
          isCurved: curved,
          preventCurveOverShooting: true,
          dotData: const FlDotData(show: false),
          dashArray: dash,
          belowBarData: area
              ? BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.02)],
                  ),
                )
              : BarAreaData(show: false),
        );

    final i = start + sel;
    final selTime = TimeFmt.atLocation(h.time[i], f.utcOffsetSeconds);
    final selDir = h.at('wind_direction_10m', i);

    Widget label(String text, Color color) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 0, 2),
          child: Row(children: [
            Container(width: 10, height: 3, color: color),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selected hour summary (stays put while charts scroll).
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: GlassPanel(
            color: AppColors.charcoal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(fmt.full(selTime), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(value: 3, label: Text('3d')),
                        ButtonSegment(value: 7, label: Text('7d')),
                      ],
                      selected: {_days},
                      onSelectionChanged: (v) => setState(() => _days = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text('${s.temperature} ${units.format(Quantity.temperature, h.at('temperature_2m', i))}'),
                    Text('${s.feelsLike} ${units.format(Quantity.temperature, h.at('apparent_temperature', i))}'),
                    Text('${s.precipitation} ${units.format(Quantity.precipRate, h.at('precipitation', i))}'),
                    Text('${s.rainProbability} ${units.format(Quantity.percent, h.at('precipitation_probability', i))}'),
                    Text(
                        '${s.wind} ${units.format(Quantity.speed, h.at('wind_speed_10m', i))}${selDir == null ? '' : ' ${compassLabel(selDir)}'}'),
                    Text('${s.gusts} ${units.format(Quantity.speed, h.at('wind_gusts_10m', i))}'),
                    Text('${s.pressure} ${units.format(Quantity.pressure, h.at('pressure_msl', i))}'),
                    Text('${s.cloudCover} ${units.format(Quantity.percent, h.at('cloud_cover', i))}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(s.tapChartHint, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => setState(() => _selected = geo.indexAt(d.localPosition.dx)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TimeAxis(
                      geo: geo,
                      times: times,
                      utcOffset: f.utcOffsetSeconds,
                      fmt: fmt,
                      labelEvery: _days == 3 ? 3 : 6,
                    ),
                    label('${s.temperature} / ${s.feelsLike} (${units.unit(Quantity.temperature)})',
                        AppColors.amber),
                    alignedLineChart(
                      geo: geo,
                      height: 130,
                      dayStarts: dayStarts,
                      selected: sel,
                      minY: tMin,
                      maxY: tMax,
                      leftLabel: num0,
                      bars: [
                        line(feels, AppColors.textSecondary, width: 1.4, dash: const [4, 3]),
                        line(temp, AppColors.amber, width: 2.4, area: true),
                      ],
                    ),
                    label('${s.precipitation} (${units.unit(Quantity.precipRate)}) · ${s.rainProbability} (%)',
                        AppColors.accent),
                    alignedLineChart(
                      geo: geo,
                      height: 100,
                      dayStarts: dayStarts,
                      selected: sel,
                      minY: 0,
                      maxY: precipMax,
                      leftLabel: units.precip == PrecipUnit.mm ? num1 : num2,
                      bars: [
                        LineChartBarData(
                          spots: spotsOf(precip),
                          isStepLineChart: true,
                          lineChartStepData: const LineChartStepData(
                              stepDirection: LineChartStepData.stepDirectionForward),
                          color: AppColors.accent,
                          barWidth: 1,
                          dotData: const FlDotData(show: false),
                          belowBarData:
                              BarAreaData(show: true, color: AppColors.accent.withValues(alpha: 0.55)),
                        ),
                        // Probability scaled onto the precipitation axis.
                        line([for (final p in pop) p == null ? null : p / 100 * precipMax],
                            const Color(0xFF9FD8FF),
                            width: 1.2, dash: const [3, 3]),
                      ],
                    ),
                    label('${s.wind} / ${s.gusts} (${units.unit(Quantity.speed)})', AppColors.success),
                    alignedLineChart(
                      geo: geo,
                      height: 110,
                      dayStarts: dayStarts,
                      selected: sel,
                      minY: 0,
                      maxY: wMax,
                      leftLabel: num0,
                      bars: [
                        line(gust, const Color(0xFFFF8A65), width: 1.4, dash: const [4, 3]),
                        line(wind, AppColors.success, width: 2.2, area: true),
                      ],
                    ),
                    SizedBox(
                      width: geo.width,
                      height: 22,
                      child: CustomPaint(painter: _ArrowRow(geo: geo, directions: dir, every: _days == 3 ? 2 : 4)),
                    ),
                    label('${s.pressure} (${units.unit(Quantity.pressure)})', const Color(0xFFB38CFF)),
                    alignedLineChart(
                      geo: geo,
                      height: 90,
                      dayStarts: dayStarts,
                      selected: sel,
                      minY: pMin,
                      maxY: pMax,
                      leftLabel: units.pressureUnit == PressureUnit.hpa ? num0 : num2,
                      bars: [line(pressure, const Color(0xFFB38CFF), width: 2)],
                    ),
                    label('${s.cloudCover} (%)', const Color(0xFFDDE3EA)),
                    alignedLineChart(
                      geo: geo,
                      height: 90,
                      dayStarts: dayStarts,
                      selected: sel,
                      minY: 0,
                      maxY: 100,
                      interval: 50,
                      leftLabel: num0,
                      bars: [
                        line(cloud, const Color(0xFFDDE3EA), width: 1.8, area: true, curved: false),
                        line(cloudLow, const Color(0xFF8C99AC), width: 1, curved: false),
                        line(cloudMid, const Color(0xFFB9C4D3), width: 1, curved: false, dash: const [2, 2]),
                        line(cloudHigh, const Color(0xFF6EE7F9), width: 1, curved: false, dash: const [6, 3]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrowRow extends CustomPainter {
  _ArrowRow({required this.geo, required this.directions, required this.every});

  final ChartGeometry geo;
  final List<double?> directions;
  final int every;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < directions.length; i += every) {
      final d = directions[i];
      if (d == null) continue;
      final a = (d + 180) * math.pi / 180;
      final c = Offset(geo.xFor(i), size.height / 2);
      final v = Offset(math.sin(a), -math.cos(a)) * 7;
      canvas.drawLine(c - v, c + v, p);
      final head = c + v;
      final back = Offset(math.sin(a), -math.cos(a)) * 4;
      final side = Offset(math.cos(a), math.sin(a)) * 3;
      canvas.drawLine(head, head - back + side, p);
      canvas.drawLine(head, head - back - side, p);
    }
  }

  @override
  bool shouldRepaint(_ArrowRow old) => old.directions != directions || old.every != every;
}
