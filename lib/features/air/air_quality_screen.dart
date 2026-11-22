import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/forecast.dart';
import '../../data/models/place.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';
import '../forecast/overview_tab.dart' show aqiCategoryIndex, aqiColors;

/// Pollutants shown in detail: Open-Meteo key, US sub-index key, WHO
/// guideline (µg/m³, the shortest averaging time WHO gives), labels.
class Pollutant {
  const Pollutant(this.key, this.subIndexKey, this.symbol, this.nameEn, this.nameBn, this.whoLimit,
      this.aboutEn, this.aboutBn);
  final String key;
  final String subIndexKey;
  final String symbol;
  final String nameEn;
  final String nameBn;
  final double? whoLimit;
  final String aboutEn;
  final String aboutBn;
}

const pollutants = [
  Pollutant('pm2_5', 'us_aqi_pm2_5', 'PM2.5', 'Fine particles', 'অতি সূক্ষ্ম কণা', 15,
      'Smoke, traffic and brick-kiln dust. Small enough to reach the lungs and blood.',
      'ধোঁয়া, যানবাহন ও ইটভাটার ধুলা। ফুসফুস ও রক্তে ঢুকে যেতে পারে।'),
  Pollutant('pm10', 'us_aqi_pm10', 'PM10', 'Coarse particles', 'ধূলিকণা', 45,
      'Road and construction dust, pollen. Irritates nose, throat and eyes.',
      'রাস্তা ও নির্মাণকাজের ধুলা, পরাগরেণু। নাক, গলা ও চোখে জ্বালা করে।'),
  Pollutant('ozone', 'us_aqi_ozone', 'O₃', 'Ozone', 'ওজোন', 100,
      'Forms in sunlight from traffic fumes; highest on hot afternoons.',
      'রোদে যানবাহনের ধোঁয়া থেকে তৈরি হয়; গরম দুপুরে সবচেয়ে বেশি।'),
  Pollutant('nitrogen_dioxide', 'us_aqi_nitrogen_dioxide', 'NO₂', 'Nitrogen dioxide', 'নাইট্রোজেন ডাই-অক্সাইড', 25,
      'Mainly from vehicle engines. Inflames the airways.',
      'মূলত গাড়ির ইঞ্জিন থেকে। শ্বাসনালিতে প্রদাহ করে।'),
  Pollutant('sulphur_dioxide', 'us_aqi_sulphur_dioxide', 'SO₂', 'Sulphur dioxide', 'সালফার ডাই-অক্সাইড', 40,
      'From burning coal and oil (kilns, power plants, ships).',
      'কয়লা ও তেল পোড়ানো থেকে (ইটভাটা, বিদ্যুৎকেন্দ্র, জাহাজ)।'),
  Pollutant('carbon_monoxide', 'us_aqi_carbon_monoxide', 'CO', 'Carbon monoxide', 'কার্বন মনো-অক্সাইড', 4000,
      'From incomplete burning (traffic, cooking fires).',
      'অসম্পূর্ণ দহন থেকে (যানবাহন, রান্নার চুলা)।'),
];

/// Main pollutant: the one with the highest US sub-index.
Pollutant? dominantPollutant(Map<String, double?> current) {
  Pollutant? best;
  double bestValue = -1;
  for (final p in pollutants) {
    final v = current[p.subIndexKey];
    if (v != null && v > bestValue) {
      bestValue = v;
      best = p;
    }
  }
  return best;
}

/// European AQI band 0..5 (good … extremely poor).
int euCategoryIndex(double v) {
  if (v <= 20) return 0;
  if (v <= 40) return 1;
  if (v <= 60) return 2;
  if (v <= 80) return 3;
  if (v <= 100) return 4;
  return 5;
}

class AirQualityScreen extends ConsumerStatefulWidget {
  const AirQualityScreen({super.key, required this.place});
  final Place place;

  @override
  ConsumerState<AirQualityScreen> createState() => _AirQualityScreenState();
}

class _AirQualityScreenState extends ConsumerState<AirQualityScreen> {
  bool _eu = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final async = ref.watch(airQualityDetailProvider(widget.place));
    return Scaffold(
      appBar: AppBar(title: Text('${s.airQuality} · ${widget.place.name}')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorView(error: e, onRetry: () => ref.invalidate(airQualityDetailProvider(widget.place))),
        data: (aq) => RefreshIndicator(
          onRefresh: () => ref.refresh(airQualityDetailProvider(widget.place).future),
          child: _AqBody(aq: aq, eu: _eu, onScale: (v) => setState(() => _eu = v)),
        ),
      ),
    );
  }
}

class _AqBody extends ConsumerWidget {
  const _AqBody({required this.aq, required this.eu, required this.onScale});
  final OmResponse aq;
  final bool eu;
  final ValueChanged<bool> onScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final bn = s.isBengali;
    String t(String en, String b) => bn ? b : en;
    final units = ref.watch(unitsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final c = aq.current;
    final us = c['us_aqi'];
    final euV = c['european_aqi'];
    final value = eu ? euV : us;
    final cat = value == null ? null : (eu ? euCategoryIndex(value) : aqiCategoryIndex(value));
    final color = cat == null ? AppColors.textSecondary : aqiColors[cat];
    final main = dominantPollutant(c);

    // Next 48 hours of the index, from the current hour.
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final start = aq.hourly.isEmpty ? 0 : aq.hourly.indexFor(nowSec).clamp(0, aq.hourly.length - 1);
    final key = eu ? 'european_aqi' : 'us_aqi';
    final hours = <(int, double)>[
      for (var i = start; i < math.min(start + 48, aq.hourly.length); i++)
        if (aq.hourly.at(key, i) != null) (aq.hourly.time[i], aq.hourly.at(key, i)!),
    ];
    // Daily highest index.
    final days = <DateTime, double>{};
    for (var i = 0; i < aq.hourly.length; i++) {
      final v = aq.hourly.at(key, i);
      if (v == null) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(aq.hourly.time[i] * 1000);
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) continue;
      days[day] = math.max(days[day] ?? 0, v);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('US AQI')),
              ButtonSegment(value: true, label: Text('EU AQI')),
            ],
            selected: {eu},
            onSelectionChanged: (v) => onScale(v.first),
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Column(
            children: [
              SizedBox(
                height: 150,
                width: 220,
                child: CustomPaint(
                  painter: _GaugePainter(
                    fraction: value == null ? 0 : (value / (eu ? 120 : 300)).clamp(0.0, 1.0),
                    color: color,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Text(value == null ? '–' : units.number(value),
                            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: color)),
                        Text(eu ? 'EU AQI' : 'US AQI',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                cat == null ? s.noData : (eu ? _euLabel(cat, bn) : s.aqiCategory(cat)),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
              ),
              if (main != null) ...[
                const SizedBox(height: 4),
                Text('${t('Main pollutant', 'প্রধান দূষণকারী')}: ${main.symbol}',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 10),
              _ScaleBar(index: cat),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (cat != null)
          SectionCard(
            title: t('Health advice', 'স্বাস্থ্য পরামর্শ'),
            child: Column(
              children: [
                for (final (icon, text) in _advice(cat, bn))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(icon, color: color),
                    title: Text(text),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SectionCard(
          title: t('Pollutants', 'দূষণকারী উপাদান'),
          child: Column(
            children: [
              for (final p in pollutants) _PollutantRow(p: p, current: c, units: units, bengali: bn),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (hours.isNotEmpty)
          SectionCard(
            title: t('Next 48 hours', 'আগামী ৪৮ ঘণ্টা'),
            child: _HourlyBars(hours: hours, eu: eu, fmt: fmt),
          ),
        const SizedBox(height: 12),
        if (days.isNotEmpty)
          SectionCard(
            title: t('Daily worst', 'দিনের সর্বোচ্চ'),
            child: Row(
              children: [
                for (final e in days.entries.take(5))
                  Expanded(
                    child: Column(
                      children: [
                        Text(fmt.weekday(e.key), style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: aqiColors[eu ? euCategoryIndex(e.value) : aqiCategoryIndex(e.value)]
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(units.number(e.value),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SectionCard(
          title: t('More', 'আরও'),
          child: Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Mini(t('Dust', 'ধুলা'), c['dust'] == null ? '–' : '${units.number(c['dust']!)} µg/m³'),
              _Mini(t('UV index', 'UV সূচক'), c['uv_index'] == null ? '–' : units.number(c['uv_index']!)),
              _Mini(t('Aerosol optical depth', 'বায়ুকণার ঘনত্ব (AOD)'),
                  c['aerosol_optical_depth'] == null ? '–' : c['aerosol_optical_depth']!.toStringAsFixed(2)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t('Forecast by the CAMS model via Open-Meteo (about 11 km grid), not a ground monitor. '
              'Street-level air can be worse near traffic and kilns.',
              'CAMS মডেলের পূর্বাভাস (Open-Meteo-র মাধ্যমে, প্রায় ১১ কিমি গ্রিড), মাটির মনিটর স্টেশন নয়। '
              'যানবাহন ও ইটভাটার কাছে রাস্তার বাতাস আরও খারাপ হতে পারে।'),
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

String _euLabel(int i, bool bn) => bn
    ? const ['ভালো', 'মোটামুটি', 'মাঝারি', 'খারাপ', 'খুব খারাপ', 'চরম খারাপ'][i]
    : const ['Good', 'Fair', 'Moderate', 'Poor', 'Very poor', 'Extremely poor'][i];

List<(IconData, String)> _advice(int cat, bool bn) {
  String t(String en, String b) => bn ? b : en;
  switch (cat) {
    case 0:
      return [
        (Icons.directions_run, t('Great for outdoor activity.', 'বাইরে ব্যায়াম ও চলাফেরার জন্য চমৎকার।')),
        (Icons.window, t('Open windows to air the house.', 'ঘরে বাতাস চলাচলের জন্য জানালা খুলুন।')),
      ];
    case 1:
      return [
        (Icons.directions_walk,
            t('Fine for most people. Unusually sensitive people should limit long, hard exercise outside.',
                'বেশিরভাগ মানুষের জন্য ঠিক আছে। খুব সংবেদনশীলরা বাইরে দীর্ঘ ভারী ব্যায়াম কমান।')),
      ];
    case 2:
      return [
        (Icons.child_care,
            t('Children, older people and those with asthma or heart disease: reduce time outdoors.',
                'শিশু, বয়স্ক এবং হাঁপানি বা হৃদরোগীরা বাইরে কম থাকুন।')),
        (Icons.masks, t('Consider a mask (N95/KN95) outside.', 'বাইরে মাস্ক (N95/KN95) পরার কথা ভাবুন।')),
      ];
    case 3:
      return [
        (Icons.masks, t('Wear an N95/KN95 mask outside.', 'বাইরে N95/KN95 মাস্ক পরুন।')),
        (Icons.do_not_disturb_on_outlined,
            t('Everyone should cut down on outdoor exercise.', 'সবাই বাইরে ব্যায়াম কমান।')),
        (Icons.window, t('Keep windows closed.', 'জানালা বন্ধ রাখুন।')),
      ];
    default:
      return [
        (Icons.home, t('Stay indoors as much as possible.', 'যতটা সম্ভব ঘরের ভেতরে থাকুন।')),
        (Icons.masks, t('Wear an N95/KN95 mask if you must go out.', 'বাইরে যেতে হলে N95/KN95 মাস্ক পরুন।')),
        (Icons.air, t('Use an air purifier if you have one; keep windows shut.',
            'এয়ার পিউরিফায়ার থাকলে চালান; জানালা বন্ধ রাখুন।')),
        (Icons.local_hospital_outlined,
            t('Seek medical help for chest pain or breathlessness.', 'বুকে ব্যথা বা শ্বাসকষ্ট হলে ডাক্তার দেখান।')),
      ];
  }
}

class _PollutantRow extends StatelessWidget {
  const _PollutantRow({required this.p, required this.current, required this.units, required this.bengali});
  final Pollutant p;
  final Map<String, double?> current;
  final UnitFormatter units;
  final bool bengali;

  @override
  Widget build(BuildContext context) {
    final v = current[p.key];
    final sub = current[p.subIndexKey];
    final cat = sub == null ? null : aqiCategoryIndex(sub);
    final color = cat == null ? AppColors.textSecondary : aqiColors[cat];
    final times = (v != null && p.whoLimit != null) ? v / p.whoLimit! : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(p.symbol, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15)),
              ),
              Expanded(
                child: Text(bengali ? p.nameBn : p.nameEn,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ),
              Text(v == null ? '–' : '${units.number(v)} µg/m³',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: sub == null ? 0 : (sub / 300).clamp(0.02, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.stroke,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (sub != null) 'AQI ${units.number(sub)}',
              if (times != null && times >= 1.05)
                bengali
                    ? 'WHO সীমার ${times.toStringAsFixed(1)} গুণ'
                    : '${times.toStringAsFixed(1)}× WHO guideline',
              bengali ? p.aboutBn : p.aboutEn,
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HourlyBars extends StatelessWidget {
  const _HourlyBars({required this.hours, required this.eu, required this.fmt});
  final List<(int, double)> hours;
  final bool eu;
  final TimeFmt fmt;

  @override
  Widget build(BuildContext context) {
    final maxV = hours.fold<double>(eu ? 60 : 150, (m, h) => math.max(m, h.$2));
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < hours.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.8),
                    height: 4 + 86 * (hours[i].$2 / maxV),
                    decoration: BoxDecoration(
                      color: aqiColors[eu ? euCategoryIndex(hours[i].$2) : aqiCategoryIndex(hours[i].$2)],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(
                    height: 18,
                    child: i % 8 == 0
                        ? OverflowBox(
                            maxWidth: 60,
                            child: Text(
                              fmt.hm(DateTime.fromMillisecondsSinceEpoch(hours[i].$1 * 1000)),
                              style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScaleBar extends StatelessWidget {
  const _ScaleBar({required this.index});
  final int? index;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < aqiColors.length; i++)
            Expanded(
              child: Container(
                height: i == index ? 10 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: aqiColors[i].withValues(alpha: i == index ? 1 : 0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.62), radius: size.width * 0.42);
    const startAngle = math.pi * 0.8;
    const sweep = math.pi * 1.4;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = AppColors.stroke;
    canvas.drawArc(rect, startAngle, sweep, false, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, startAngle, sweep * fraction.clamp(0.01, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction || old.color != color;
}

/// Short label used in the widget and elsewhere, e.g. "AQI 152 · Unhealthy".
String aqiShortLine(AppStrings s, double? us, UnitFormatter units) =>
    us == null ? '' : 'AQI ${units.number(us)} · ${s.aqiCategory(aqiCategoryIndex(us))}';
