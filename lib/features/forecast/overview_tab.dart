import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/forecast.dart';
import '../../data/models/place.dart';
import '../../data/sources/rain_nowcast.dart';
import '../../services/home_widget_service.dart';
import '../air/air_quality_screen.dart';
import '../../services/moon.dart';
import '../../state/providers.dart';
import '../common/weather_icon.dart';
import '../common/widgets.dart';
import '../settings/sources_screen.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.place});

  final Place place;

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(forceRefreshIdsProvider).add(place.id);
    ref.invalidate(forecastProvider(place));
    try {
      await ref.read(forecastProvider(place).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(forecastProvider(place));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(forecastProvider(place))),
      data: (bundle) => RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: _OverviewList(bundle: bundle, place: place),
      ),
    );
  }
}

class _OverviewList extends ConsumerWidget {
  const _OverviewList({required this.bundle, required this.place});

  final ForecastBundle bundle;
  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final units = ref.watch(unitsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final f = bundle.forecast;
    final now = DateTime.now();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    final h = f.hourly;
    final hi = h.indexFor(nowSec);
    final localNow = TimeFmt.atLocation(nowSec, f.utcOffsetSeconds);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        if (f.stale)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassPanel(
              color: AppColors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: AppColors.amber),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.showingCached(fmt.full(f.fetchedAt)))),
                ],
              ),
            ),
          ),
        _CurrentHero(f: f, units: units, strings: s, hourIndex: hi),
        const SizedBox(height: 12),
        _NowcastCard(place: place),
        _DetailsGrid(bundle: bundle, units: units, strings: s, hourIndex: hi, fmt: fmt),
        const SizedBox(height: 12),
        SectionCard(
          title: s.next24h,
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
          child: _HourStrip(f: f, start: hi, count: 24, units: units, fmt: fmt, strings: s),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: s.hourlyForecast,
          child: _HourlyTable(f: f, start: hi, units: units, fmt: fmt, strings: s),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: s.dailyForecast,
          child: _DailyList(f: f, from: 0, to: 7, units: units, fmt: fmt, strings: s, localNow: localNow),
        ),
        if (f.daily.length > 7) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: s.extendedForecast,
            child: _DailyList(
                f: f, from: 7, to: f.daily.length, units: units, fmt: fmt, strings: s, localNow: localNow),
          ),
        ],
        const SizedBox(height: 12),
        _SunMoonCard(bundle: bundle, fmt: fmt, strings: s),
        if (bundle.airQuality != null) ...[
          const SizedBox(height: 12),
          _AirQualityCard(aq: bundle.airQuality!, units: units, strings: s, place: place),
        ],
        if (bundle.hasMarine) ...[
          const SizedBox(height: 12),
          _MarineCard(marine: bundle.marine!, units: units, strings: s),
        ],
        const SizedBox(height: 8),
        SourceLine(
          text:
              '${s.lastUpdated(fmt.weekdayHm(f.fetchedAt))} · ${s.attributionText} · ${f.timezoneAbbreviation ?? f.timezone}',
          stale: f.stale,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SourcesScreen()),
          ),
        ),
      ],
    );
  }
}

class _CurrentHero extends StatelessWidget {
  const _CurrentHero({required this.f, required this.units, required this.strings, required this.hourIndex});

  final OmResponse f;
  final UnitFormatter units;
  final AppStrings strings;
  final int hourIndex;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final c = f.current;
    final code = c['weather_code']?.round();
    final isDay = (c['is_day'] ?? 1) >= 1;
    final hi = f.daily.at('temperature_2m_max', 0);
    final lo = f.daily.at('temperature_2m_min', 0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDay
              ? const [Color(0xFF173A66), Color(0xFF0F2342)]
              : const [Color(0xFF151F3D), Color(0xFF0B1226)],
        ),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  units.format(Quantity.temperature, c['temperature_2m']),
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                Text(
                  code == null ? '' : s.weatherCode(code),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.feelsLike} ${units.format(Quantity.temperature, c['apparent_temperature'])}'
                  '  ·  ↑${units.format(Quantity.temperature, hi)}  ↓${units.format(Quantity.temperature, lo)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          WeatherIcon(code: code, isDay: isDay, size: 96),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({
    required this.bundle,
    required this.units,
    required this.strings,
    required this.hourIndex,
    required this.fmt,
  });

  final ForecastBundle bundle;
  final UnitFormatter units;
  final AppStrings strings;
  final int hourIndex;
  final TimeFmt fmt;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final f = bundle.forecast;
    final c = f.current;
    final dir = c['wind_direction_10m'];
    final uv = c['uv_index'] ?? f.hourly.at('uv_index', hourIndex);
    final rainChance = f.hourly.at('precipitation_probability', hourIndex);
    final todayRain = f.daily.at('precipitation_sum', 0);
    final dew = c['dew_point_2m'] ??
        ((c['temperature_2m'] != null && c['relative_humidity_2m'] != null)
            ? dewPointFrom(c['temperature_2m']!, c['relative_humidity_2m']!)
            : null);
    final items = <_Detail>[
      _Detail(
        Icons.air,
        s.wind,
        units.format(Quantity.speed, c['wind_speed_10m']),
        dir == null ? null : '${compassLabel(dir)} · ${dir.round()}°',
        rotation: dir == null ? null : (dir + 180) * math.pi / 180,
      ),
      _Detail(Icons.storm, s.gusts, units.format(Quantity.speed, c['wind_gusts_10m']), null),
      _Detail(Icons.water_drop, s.humidity, units.format(Quantity.percent, c['relative_humidity_2m']), null),
      _Detail(Icons.compress, s.pressure, units.format(Quantity.pressure, c['pressure_msl']), null),
      _Detail(Icons.umbrella, s.rainProbability, units.format(Quantity.percent, rainChance), null),
      _Detail(Icons.grain, s.precipitation, units.format(Quantity.precipAmount, c['precipitation']),
          '${s.today}: ${units.format(Quantity.precipAmount, todayRain)}'),
      _Detail(Icons.cloud, s.cloudCover, units.format(Quantity.percent, c['cloud_cover']), null),
      _Detail(Icons.visibility, s.visibility, units.format(Quantity.distance, c['visibility']), null),
      _Detail(Icons.thermostat, s.dewPoint, units.format(Quantity.temperature, dew), null),
      _Detail(Icons.wb_sunny, s.uvIndex, units.format(Quantity.indexValue, uv),
          uv == null ? null : s.uvCategory(_uvIndex(uv))),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 520 ? 3 : 2;
      final w = (constraints.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final d in items)
            SizedBox(
              width: w,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: d.rotation ?? 0,
                        child: Icon(d.rotation == null ? d.icon : Icons.navigation,
                            color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.label,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(d.value,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            if (d.extra != null)
                              Text(d.extra!,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

int _uvIndex(double uv) {
  if (uv < 3) return 0;
  if (uv < 6) return 1;
  if (uv < 8) return 2;
  if (uv < 11) return 3;
  return 4;
}

int aqiCategoryIndex(double aqi) {
  if (aqi <= 50) return 0;
  if (aqi <= 100) return 1;
  if (aqi <= 150) return 2;
  if (aqi <= 200) return 3;
  if (aqi <= 300) return 4;
  return 5;
}

const aqiColors = [
  Color(0xFF00C853),
  Color(0xFFFFD600),
  Color(0xFFFF7E00),
  Color(0xFFFF1744),
  Color(0xFF8F3F97),
  Color(0xFF7E0023),
];

class _Detail {
  const _Detail(this.icon, this.label, this.value, this.extra, {this.rotation});
  final IconData icon;
  final String label;
  final String value;
  final String? extra;
  final double? rotation;
}

class _HourStrip extends StatelessWidget {
  const _HourStrip({
    required this.f,
    required this.start,
    required this.count,
    required this.units,
    required this.fmt,
    required this.strings,
  });

  final OmResponse f;
  final int start;
  final int count;
  final UnitFormatter units;
  final TimeFmt fmt;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final h = f.hourly;
    final end = math.min(h.length, start + count);
    return SizedBox(
      height: 118,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: math.max(0, end - start),
        itemBuilder: (context, k) {
          final i = start + k;
          final t = TimeFmt.atLocation(h.time[i], f.utcOffsetSeconds);
          final pop = h.at('precipitation_probability', i);
          return SizedBox(
            width: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(k == 0 ? strings.now : fmt.hour(t),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: k == 0 ? FontWeight.w700 : FontWeight.w500,
                        color: k == 0 ? AppColors.accent : AppColors.textSecondary)),
                WeatherIcon(
                  code: h.at('weather_code', i)?.round(),
                  isDay: (h.at('is_day', i) ?? 1) >= 1,
                  size: 30,
                ),
                Text(units.format(Quantity.temperature, h.at('temperature_2m', i)),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  pop == null || pop < 5 ? ' ' : units.format(Quantity.percent, pop),
                  style: const TextStyle(fontSize: 11, color: AppColors.accent),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HourlyTable extends StatefulWidget {
  const _HourlyTable({
    required this.f,
    required this.start,
    required this.units,
    required this.fmt,
    required this.strings,
  });

  final OmResponse f;
  final int start;
  final UnitFormatter units;
  final TimeFmt fmt;
  final AppStrings strings;

  @override
  State<_HourlyTable> createState() => _HourlyTableState();
}

class _HourlyTableState extends State<_HourlyTable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    final h = f.hourly;
    final u = widget.units;
    final total = math.max(0, math.min(h.length - widget.start, 72));
    final shown = _expanded ? total : math.min(total, 12);
    final nowLocal = TimeFmt.atLocation(DateTime.now().millisecondsSinceEpoch ~/ 1000, f.utcOffsetSeconds);
    return Column(
      children: [
        for (var k = 0; k < shown; k++)
          Builder(builder: (context) {
            final i = widget.start + k;
            final t = TimeFmt.atLocation(h.time[i], f.utcOffsetSeconds);
            final dir = h.at('wind_direction_10m', i);
            final newDay = k > 0 && t.hour == 0;
            return Column(
              children: [
                if (newDay)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(children: [
                      Text(
                        widget.fmt.relativeDay(t, nowLocal,
                            today: widget.strings.today, tomorrow: widget.strings.tomorrow),
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Divider()),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 58,
                        child: Text(widget.fmt.hm(t),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                      ),
                      WeatherIcon(
                        code: h.at('weather_code', i)?.round(),
                        isDay: (h.at('is_day', i) ?? 1) >= 1,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(u.format(Quantity.temperature, h.at('temperature_2m', i)),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Text(
                          '${u.format(Quantity.precipAmount, h.at('precipitation', i))} · ${u.format(Quantity.percent, h.at('precipitation_probability', i))}',
                          style: const TextStyle(fontSize: 12, color: AppColors.accent),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (dir != null)
                        Transform.rotate(
                          angle: (dir + 180) * math.pi / 180,
                          child: const Icon(Icons.navigation, size: 14, color: AppColors.textSecondary),
                        ),
                      const SizedBox(width: 4),
                      Text(u.format(Quantity.speed, h.at('wind_speed_10m', i)),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            );
          }),
        if (total > 12)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_expanded ? widget.strings.close : widget.strings.hourlyForecast),
          ),
      ],
    );
  }
}

class _DailyList extends StatelessWidget {
  const _DailyList({
    required this.f,
    required this.from,
    required this.to,
    required this.units,
    required this.fmt,
    required this.strings,
    required this.localNow,
  });

  final OmResponse f;
  final int from;
  final int to;
  final UnitFormatter units;
  final TimeFmt fmt;
  final AppStrings strings;
  final DateTime localNow;

  @override
  Widget build(BuildContext context) {
    final d = f.daily;
    final end = math.min(to, d.length);
    if (end <= from) return Text(strings.noData);
    var minAll = double.infinity, maxAll = double.negativeInfinity;
    for (var i = from; i < end; i++) {
      final lo = d.at('temperature_2m_min', i), hi = d.at('temperature_2m_max', i);
      if (lo != null) minAll = math.min(minAll, lo);
      if (hi != null) maxAll = math.max(maxAll, hi);
    }
    if (!minAll.isFinite || !maxAll.isFinite) return Text(strings.noData);
    return Column(
      children: [
        for (var i = from; i < end; i++)
          Builder(builder: (context) {
            final t = TimeFmt.atLocation(d.time[i], f.utcOffsetSeconds);
            final lo = d.at('temperature_2m_min', i);
            final hi = d.at('temperature_2m_max', i);
            final pop = d.at('precipitation_probability_max', i);
            final sum = d.at('precipitation_sum', i);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmt.relativeDay(t, localNow, today: strings.today, tomorrow: strings.tomorrow),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(fmt.dayMonth(t),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  WeatherIcon(code: d.at('weather_code', i)?.round(), size: 28),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 52,
                    child: Text(
                      pop == null || pop < 10
                          ? ''
                          : '${units.format(Quantity.percent, pop)}\n${units.format(Quantity.precipAmount, sum)}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.accent, height: 1.2),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(units.format(Quantity.temperature, lo),
                        textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RangeBar(
                      min: minAll,
                      max: maxAll,
                      lo: lo ?? minAll,
                      hi: hi ?? maxAll,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(units.format(Quantity.temperature, hi),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.min, required this.max, required this.lo, required this.hi});

  final double min, max, lo, hi;

  @override
  Widget build(BuildContext context) {
    final span = (max - min).abs() < 0.1 ? 1.0 : max - min;
    final a = ((lo - min) / span).clamp(0.0, 1.0).toDouble();
    final b = ((hi - min) / span).clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(builder: (context, c) {
      return SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Positioned(
              left: c.maxWidth * a,
              width: math.max(6.0, c.maxWidth * (b - a)),
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(colors: [Color(0xFF4CC3FF), Color(0xFFFFB547)]),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SunMoonCard extends StatelessWidget {
  const _SunMoonCard({required this.bundle, required this.fmt, required this.strings});

  final ForecastBundle bundle;
  final TimeFmt fmt;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final f = bundle.forecast;
    final d = f.daily;
    String timeOf(double? unix) =>
        unix == null ? '–' : fmt.hm(TimeFmt.atLocation(unix.round(), f.utcOffsetSeconds));
    final daylight = d.at('daylight_duration', 0);
    final astro = bundle.astronomy;
    final moonrise = astro?.daily.at('moonrise', 0);
    final moonset = astro?.daily.at('moonset', 0);
    final phase = MoonPhase.at(DateTime.now().toUtc());

    Widget item(IconData icon, String label, String value) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: AppColors.amber),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return SectionCard(
      title: s.sunAndMoon,
      child: Column(
        children: [
          Row(
            children: [
              item(Icons.wb_twilight, s.sunrise, timeOf(d.at('sunrise', 0))),
              item(Icons.bedtime_outlined, s.sunset, timeOf(d.at('sunset', 0))),
              item(Icons.schedule, s.daylight, daylight == null ? '–' : fmt.duration(daylight.round())),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CustomPaint(painter: _MoonPainter(phase)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.moonPhaseName(phase.index), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${s.illumination}: ${(phase.illumination * 100).round()}%',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${s.moonrise} ${astro == null ? '–' : (moonrise == null ? s.noMoonrise : timeOf(moonrise))}',
                      style: const TextStyle(fontSize: 12.5)),
                  Text('${s.moonset} ${astro == null ? '–' : (moonset == null ? s.noMoonset : timeOf(moonset))}',
                      style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.phase);
  final MoonPhase phase;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2A3446));
    // Terminator ellipse: width follows the phase.
    final k = math.cos(phase.fraction * 2 * math.pi);
    final lit = Path();
    final rect = Rect.fromCircle(center: c, radius: r);
    if (phase.waxing) {
      lit.addArc(rect, -math.pi / 2, math.pi);
    } else {
      lit.addArc(rect, math.pi / 2, math.pi);
    }
    final ellipse = Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r);
    final terminator = Path()..addOval(ellipse);
    final half = Path.combine(
      k > 0 ? PathOperation.difference : PathOperation.union,
      lit,
      terminator,
    );
    canvas.drawPath(half, Paint()..color = const Color(0xFFEFF3FA));
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.phase.fraction != phase.fraction;
}

class _AirQualityCard extends StatelessWidget {
  const _AirQualityCard(
      {required this.aq, required this.units, required this.strings, required this.place});

  final OmResponse aq;
  final Place place;
  final UnitFormatter units;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final us = aq.current['us_aqi'];
    final eu = aq.current['european_aqi'];
    final cat = us == null ? null : aqiCategoryIndex(us);
    String ug(String key) {
      final v = aq.current[key];
      return v == null ? '–' : '${units.number(v)} µg/m³';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AirQualityScreen(place: place)),
      ),
      child: SectionCard(
      title: s.airQuality,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(s.isBengali ? 'বিস্তারিত' : 'Details',
            style: const TextStyle(fontSize: 12.5, color: AppColors.accent)),
        const Icon(Icons.chevron_right, size: 18, color: AppColors.accent),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cat == null ? AppColors.charcoalHigh : aqiColors[cat].withValues(alpha: 0.22),
                  border: Border.all(color: cat == null ? AppColors.stroke : aqiColors[cat], width: 2),
                ),
                child: Text(us == null ? '–' : units.number(us),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat == null ? s.noData : s.aqiCategory(cat),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('US AQI · EU AQI ${eu == null ? '–' : units.number(eu)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text('PM2.5 ${ug('pm2_5')}', style: const TextStyle(fontSize: 12.5)),
              Text('PM10 ${ug('pm10')}', style: const TextStyle(fontSize: 12.5)),
              Text('O₃ ${ug('ozone')}', style: const TextStyle(fontSize: 12.5)),
              Text('NO₂ ${ug('nitrogen_dioxide')}', style: const TextStyle(fontSize: 12.5)),
              Text('SO₂ ${ug('sulphur_dioxide')}', style: const TextStyle(fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('CAMS via Open-Meteo', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
      ),
    );
  }
}

class _MarineCard extends StatelessWidget {
  const _MarineCard({required this.marine, required this.units, required this.strings});

  final OmResponse marine;
  final UnitFormatter units;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final c = marine.current;
    final dir = c['wave_direction'];
    final swellDir = c['swell_wave_direction'];
    Widget cell(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );
    return SectionCard(
      title: s.marine,
      child: Column(
        children: [
          Row(children: [
            cell(s.waveHeight, units.format(Quantity.waveHeight, c['wave_height'])),
            cell(s.wavePeriod, units.format(Quantity.period, c['wave_period'])),
            cell(s.waveDirection, dir == null ? '–' : compassLabel(dir)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            cell(s.swell, units.format(Quantity.waveHeight, c['swell_wave_height'])),
            cell('${s.swell} °', swellDir == null ? '–' : compassLabel(swellDir)),
            cell(s.seaTemperature, units.format(Quantity.temperature, c['sea_surface_temperature'])),
          ]),
        ],
      ),
    );
  }
}

/// Rain in the next two hours in 15-minute steps.
class _NowcastCard extends ConsumerWidget {
  const _NowcastCard({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(placeNowcastProvider(place));
    final n = async.value;
    // Optional extra: stay out of the way while loading or on errors.
    if (n == null) return const SizedBox.shrink();
    final s = S.of(context);
    final units = ref.watch(unitsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final wet = n.rainingNow || n.minutesUntilRain(nowSec) != null;
    const maxMm = 2.0; // 8 mm/h fills the bar
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: s.next2hRain,
        trailing: n.probability == null
            ? null
            : Text('💧 ${units.format(Quantity.percent, n.probability!.toDouble())}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(wet ? Icons.umbrella : Icons.wb_sunny_outlined,
                    color: wet ? AppColors.accent : AppColors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(HomeWidgetService.rainLine(s, n, nowSec),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (n.next2hMm >= RainNowcast.wetThreshold)
                  Text(units.format(Quantity.precipAmount, n.next2hMm),
                      style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < n.stepMm.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 4 + 44 * (n.stepMm[i] / maxMm).clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                color: n.stepMm[i] >= RainNowcast.wetThreshold
                                    ? AppColors.accent
                                    : AppColors.stroke,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              i.isEven
                                  ? fmt.hm(DateTime.fromMillisecondsSinceEpoch(n.stepTimes[i] * 1000))
                                  : '',
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(s.nowcastModelNote, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
