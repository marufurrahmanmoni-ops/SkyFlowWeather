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

enum CompareVariable { temperature, windSpeed, windDirection, precipitation, cloudCover, pressure }

extension on CompareVariable {
  String get apiName {
    switch (this) {
      case CompareVariable.temperature:
        return 'temperature_2m';
      case CompareVariable.windSpeed:
        return 'wind_speed_10m';
      case CompareVariable.windDirection:
        return 'wind_direction_10m';
      case CompareVariable.precipitation:
        return 'precipitation';
      case CompareVariable.cloudCover:
        return 'cloud_cover';
      case CompareVariable.pressure:
        return 'pressure_msl';
    }
  }

  Quantity get quantity {
    switch (this) {
      case CompareVariable.temperature:
        return Quantity.temperature;
      case CompareVariable.windSpeed:
        return Quantity.speed;
      case CompareVariable.windDirection:
        return Quantity.direction;
      case CompareVariable.precipitation:
        return Quantity.precipRate;
      case CompareVariable.cloudCover:
        return Quantity.percent;
      case CompareVariable.pressure:
        return Quantity.pressure;
    }
  }
}

/// Older Open-Meteo model names that may appear in responses.
const _aliases = {
  'ncep_gfs_seamless': ['gfs_seamless'],
  'dwd_icon_seamless': ['icon_seamless'],
  'cmc_gem_seamless': ['gem_seamless'],
};

class _ModelSeries {
  _ModelSeries(this.model, this.values, this.color);
  final WeatherModel model;
  final List<double?> values;
  final Color color;

  int get lastIndex {
    for (var i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) return i;
    }
    return -1;
  }
}

class ModelComparisonTab extends ConsumerStatefulWidget {
  const ModelComparisonTab({super.key, required this.place});

  final Place place;

  @override
  ConsumerState<ModelComparisonTab> createState() => _ModelComparisonTabState();
}

class _ModelComparisonTabState extends ConsumerState<ModelComparisonTab> {
  CompareVariable _variable = CompareVariable.temperature;
  int _selected = 0;
  final Set<String> _hidden = {};

  String _label(AppStrings s, CompareVariable v) {
    switch (v) {
      case CompareVariable.temperature:
        return s.temperature;
      case CompareVariable.windSpeed:
        return s.wind;
      case CompareVariable.windDirection:
        return s.windDirection;
      case CompareVariable.precipitation:
        return s.precipitation;
      case CompareVariable.cloudCover:
        return s.cloudCover;
      case CompareVariable.pressure:
        return s.pressure;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(modelComparisonProvider(widget.place));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(modelComparisonProvider(widget.place))),
      data: (data) => _build(context, data),
    );
  }

  List<double?>? _find(TimeSeries h, String variable, WeatherModel m) {
    for (final name in [m.id, ...?_aliases[m.id]]) {
      final key = '${variable}_$name';
      if (h.has(key)) return h.series(key);
    }
    return null;
  }

  Widget _build(BuildContext context, OmResponse data) {
    final s = S.of(context);
    final units = ref.watch(unitsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final h = data.hourly;
    final start = h.indexFor(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final count = math.max(2, h.length - start);
    final variable = _variable.apiName;

    final available = <_ModelSeries>[];
    final unavailable = <WeatherModel>[];
    for (var k = 0; k < comparisonModels.length; k++) {
      final m = comparisonModels[k];
      final raw = _find(h, variable, m);
      if (raw == null || raw.length < start + 2) {
        unavailable.add(m);
        continue;
      }
      final values = raw.sublist(start, math.min(raw.length, start + count));
      if (!values.any((v) => v != null)) {
        unavailable.add(m);
        continue;
      }
      available.add(_ModelSeries(m, values, AppColors.series[k % AppColors.series.length]));
    }

    final times = h.time.sublist(start, start + count);
    final geo = ChartGeometry(count: count, hourWidth: 5.5);
    final sel = _selected.clamp(0, count - 1).toInt();
    final dayStarts = <int>[
      for (var i = 0; i < count; i++)
        if (TimeFmt.atLocation(times[i], data.utcOffsetSeconds).hour == 0) i,
    ];
    final q = _variable.quantity;
    double conv(double v) => units.convert(q, v);

    var lo = double.infinity, hi = double.negativeInfinity;
    for (final m in available) {
      if (_hidden.contains(m.model.id)) continue;
      for (final v in m.values) {
        if (v == null) continue;
        lo = math.min(lo, conv(v));
        hi = math.max(hi, conv(v));
      }
    }
    if (!lo.isFinite) {
      lo = 0;
      hi = 1;
    }
    if (_variable == CompareVariable.windDirection) {
      lo = 0;
      hi = 360;
    } else if (_variable == CompareVariable.precipitation ||
        _variable == CompareVariable.windSpeed ||
        _variable == CompareVariable.cloudCover) {
      lo = 0;
      hi = math.max(hi * 1.1, _variable == CompareVariable.cloudCover ? 100.0 : 1.0);
    } else {
      final pad = math.max(1.0, (hi - lo) * 0.08);
      lo -= pad;
      hi += pad;
    }

    final bars = <LineChartBarData>[
      for (final m in available)
        if (!_hidden.contains(m.model.id))
          LineChartBarData(
            spots: spotsOf([for (final v in m.values) v == null ? null : conv(v)]),
            color: _variable == CompareVariable.windDirection ? Colors.transparent : m.color,
            barWidth: _variable == CompareVariable.windDirection ? 0.01 : 1.8,
            isCurved: false,
            dotData: FlDotData(
              show: _variable == CompareVariable.windDirection,
              getDotPainter: (spot, _, _, _) =>
                  FlDotCirclePainter(radius: 1.6, color: m.color, strokeWidth: 0),
            ),
          ),
    ];

    final selTime = TimeFmt.atLocation(times[sel], data.utcOffsetSeconds);
    String fmtValue(double? v) {
      if (v == null) return '–';
      if (_variable == CompareVariable.windDirection) return '${compassLabel(v)} ${v.round()}°';
      return units.format(q, v);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 28),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(s.compareModels, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final v in CompareVariable.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_label(s, v)),
                    selected: v == _variable,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _variable = v),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => setState(() => _selected = geo.indexAt(d.localPosition.dx)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TimeAxis(geo: geo, times: times, utcOffset: data.utcOffsetSeconds, fmt: fmt, labelEvery: 12),
                alignedLineChart(
                  geo: geo,
                  height: 220,
                  dayStarts: dayStarts,
                  selected: sel,
                  minY: lo,
                  maxY: hi,
                  interval: _variable == CompareVariable.windDirection ? 90 : null,
                  leftLabel: (v) => _variable == CompareVariable.windDirection
                      ? compassLabel(v)
                      : units.number(v, decimals: _variable == CompareVariable.precipitation ? 1 : 0),
                  bars: bars,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Text(s.tapChartHint, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SectionCard(
            title: '${s.availableModels} · ${fmt.full(selTime)}',
            child: Column(
              children: [
                for (final m in available)
                  InkWell(
                    onTap: () => setState(() {
                      if (!_hidden.remove(m.model.id)) _hidden.add(m.model.id);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _hidden.contains(m.model.id) ? Colors.transparent : m.color,
                              border: Border.all(color: m.color, width: 2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.model.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (m.lastIndex >= 0 && m.lastIndex < count - 1)
                                  Text(
                                    s.dataUntil(fmt.weekdayHm(
                                        TimeFmt.atLocation(times[m.lastIndex], data.utcOffsetSeconds))),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          Text(fmtValue(sel < m.values.length ? m.values[sel] : null),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                if (unavailable.isNotEmpty) ...[
                  const Divider(height: 18),
                  for (final m in unavailable)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.block, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(m.label, style: const TextStyle(color: AppColors.textMuted)),
                          ),
                          Text(s.modelUnavailable,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (_variable != CompareVariable.windDirection && available.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _DailyComparisonTable(
              series: available,
              times: times,
              utcOffset: data.utcOffsetSeconds,
              variable: _variable,
              units: units,
              fmt: fmt,
              strings: s,
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(s.modelNote, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: SourceLine(text: '${s.lastUpdated(fmt.weekdayHm(data.fetchedAt))} · ${s.attributionText}'),
        ),
      ],
    );
  }
}

/// Daily summary per model with the spread between models.
class _DailyComparisonTable extends StatelessWidget {
  const _DailyComparisonTable({
    required this.series,
    required this.times,
    required this.utcOffset,
    required this.variable,
    required this.units,
    required this.fmt,
    required this.strings,
  });

  final List<_ModelSeries> series;
  final List<int> times;
  final int utcOffset;
  final CompareVariable variable;
  final UnitFormatter units;
  final TimeFmt fmt;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    // Group hour indexes by local calendar day.
    final days = <DateTime, List<int>>{};
    for (var i = 0; i < times.length; i++) {
      final t = TimeFmt.atLocation(times[i], utcOffset);
      days.putIfAbsent(DateTime.utc(t.year, t.month, t.day), () => []).add(i);
    }
    final dayKeys = days.keys.take(6).toList();
    final q = variable == CompareVariable.precipitation ? Quantity.precipAmount : variable.quantity;

    double? summary(_ModelSeries m, List<int> idx) {
      final vals = [for (final i in idx) if (i < m.values.length && m.values[i] != null) m.values[i]!];
      if (vals.length < idx.length * 0.75) return null;
      switch (variable) {
        case CompareVariable.temperature:
        case CompareVariable.windSpeed:
          return vals.reduce(math.max);
        case CompareVariable.precipitation:
          return vals.fold<double>(0.0, (a, b) => a + b);
        case CompareVariable.cloudCover:
        case CompareVariable.pressure:
          return vals.reduce((a, b) => a + b) / vals.length;
        case CompareVariable.windDirection:
          return null;
      }
    }

    final title = switch (variable) {
      CompareVariable.temperature => s.dailyMax,
      CompareVariable.windSpeed => s.dailyMaxWind,
      CompareVariable.precipitation => s.dailyTotal,
      _ => s.dailyMean,
    };

    final rows = <TableRow>[
      TableRow(children: [
        _cell(s.model, header: true),
        for (final d in dayKeys) _cell(fmt.weekday(d), header: true),
      ]),
      for (final m in series)
        TableRow(children: [
          _cell(m.model.label, color: m.color),
          for (final d in dayKeys) _cell(units.format(q, summary(m, days[d]!), withUnit: false)),
        ]),
      TableRow(children: [
        _cell(s.spread, header: true),
        for (final d in dayKeys)
          Builder(builder: (context) {
            final vals = [for (final m in series) summary(m, days[d]!)].whereType<double>().toList();
            if (vals.length < 2) return _cell('–');
            final spread = vals.reduce(math.max) - vals.reduce(math.min);
            final display = (units.convert(q, spread) - (q == Quantity.temperature ? units.convert(q, 0) : 0)).abs();
            return _cell(units.number(display, decimals: q == Quantity.precipAmount ? 1 : 0), header: true);
          }),
      ]),
    ];

    return SectionCard(
      title: '$title (${units.unit(q)})',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: rows,
        ),
      ),
    );
  }

  Widget _cell(String text, {bool header = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: header ? FontWeight.w700 : FontWeight.w500,
            color: color ?? (header ? AppColors.textSecondary : AppColors.textPrimary),
          ),
        ),
      );
}
