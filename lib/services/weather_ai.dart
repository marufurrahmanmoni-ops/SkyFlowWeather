import 'dart:math' as math;

import '../core/l10n/app_strings.dart';
import '../core/units.dart';
import '../data/models/forecast.dart';
import '../data/models/warnings.dart';
import '../data/sources/rain_nowcast.dart';
import 'radar_analyzer.dart';

/// Everything the on-device analyst looks at. Only [forecast] is required.
class WeatherAiInput {
  const WeatherAiInput({
    required this.placeName,
    required this.forecast,
    required this.nowSec,
    this.airQuality,
    this.nowcast,
    this.models,
    this.modelIds = const [],
    this.national,
    this.warnings = const [],
    this.storms = const [],
    this.radar,
  });

  final String placeName;
  final OmResponse forecast;
  final int nowSec;
  final OmResponse? airQuality;
  final RainNowcast? nowcast;

  /// Open-Meteo multi-model response (hourly `precipitation_<model>`).
  final OmResponse? models;
  final List<String> modelIds;

  /// Rain now/soon in Bangladesh's towns.
  final List<(BdCity, RainNowcast)>? national;
  final List<OfficialWarning> warnings;
  final List<DisasterEvent> storms;
  final RadarAnalysis? radar;
}

class AiSection {
  const AiSection(this.emoji, this.title, this.lines);
  final String emoji;
  final String title;
  final List<String> lines;
}

class AiBriefing {
  const AiBriefing({
    required this.headline,
    required this.sections,
    required this.spoken,
    required this.sources,
    this.confidence,
  });

  final String headline;
  final List<AiSection> sections;

  /// Text to read aloud (headline and the key points).
  final String spoken;
  final List<String> sources;

  /// 2 high, 1 medium, 0 low; null when the models were not available.
  final int? confidence;
}

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// Western digits → Bengali digits.
String toBnDigits(String s) =>
    s.replaceAllMapped(RegExp('[0-9]'), (m) => _bnDigits[int.parse(m[0]!)]);

/// The analyst: turns the data into a short weather bulletin, entirely on
/// the phone (rules written from BMD's own categories, no online AI).
class WeatherAi {
  WeatherAi(this.input, {required this.bengali, required this.units}) : s = AppStrings(bengali ? 'bn' : 'en');

  final WeatherAiInput input;
  final bool bengali;
  final UnitFormatter units;
  final AppStrings s;

  String t(String en, String bn) => bengali ? bn : en;
  String temp(double? v) => units.format(Quantity.temperature, v);
  String pct(num v) => '${v.round()}%';
  String mm(double v) => units.format(Quantity.precipAmount, v);

  OmResponse get f => input.forecast;
  int get offset => f.utcOffsetSeconds;
  DateTime local(int sec) => DateTime.fromMillisecondsSinceEpoch((sec + offset) * 1000, isUtc: true);

  static bool isRain(int? c) => c != null && ((c >= 51 && c <= 67) || (c >= 80 && c <= 82) || c >= 95);
  static bool isThunder(int? c) => c != null && c >= 95;

  /// Part of the day in everyday Bengali/English.
  String partOfDay(int hour) {
    if (hour >= 4 && hour < 6) return t('dawn', 'ভোর');
    if (hour >= 6 && hour < 12) return t('morning', 'সকাল');
    if (hour >= 12 && hour < 15) return t('midday', 'দুপুর');
    if (hour >= 15 && hour < 18) return t('afternoon', 'বিকেল');
    if (hour >= 18 && hour < 20) return t('evening', 'সন্ধ্যা');
    return t('night', 'রাত');
  }

  String clock(int hour) {
    if (!bengali) {
      final h12 = hour % 12 == 0 ? 12 : hour % 12;
      return '$h12 ${hour < 12 ? 'am' : 'pm'}';
    }
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${partOfDay(hour)} $h12টা';
  }

  /// BMD rainfall words for a 24-hour total (mm).
  String rainAmountWord(double total) {
    if (total >= 89) return t('very heavy rain', 'অতি ভারী বৃষ্টি');
    if (total >= 44) return t('heavy rain', 'ভারী বৃষ্টি');
    if (total >= 23) return t('moderately heavy rain', 'মাঝারি ধরনের ভারী বৃষ্টি');
    if (total >= 11) return t('moderate rain', 'মাঝারি বৃষ্টি');
    return t('light rain', 'হালকা বৃষ্টি');
  }

  /// BMD heat-wave scale on the day's maximum (°C).
  String? heatWave(double? max) {
    if (max == null) return null;
    if (max >= 42) return t('very severe heat wave', 'অতি তীব্র তাপপ্রবাহ');
    if (max >= 40) return t('severe heat wave', 'তীব্র তাপপ্রবাহ');
    if (max >= 38) return t('moderate heat wave', 'মাঝারি তাপপ্রবাহ');
    if (max >= 36) return t('mild heat wave', 'মৃদু তাপপ্রবাহ');
    return null;
  }

  /// BMD cold-wave scale on the night's minimum (°C).
  String? coldWave(double? min) {
    if (min == null) return null;
    if (min < 4) return t('very severe cold wave', 'অতি তীব্র শৈত্যপ্রবাহ');
    if (min < 6) return t('severe cold wave', 'তীব্র শৈত্যপ্রবাহ');
    if (min < 8) return t('moderate cold wave', 'মাঝারি শৈত্যপ্রবাহ');
    if (min <= 10) return t('mild cold wave', 'মৃদু শৈত্যপ্রবাহ');
    return null;
  }

  // ------------------------------------------------------------- pieces

  /// Wet spells in the next [hours] hours: (startIndex, endIndex, maxProb, thunder, total).
  List<(int, int, int, bool, double)> wetWindows(int hours) {
    final h = f.hourly;
    if (h.isEmpty) return const [];
    final start = h.indexFor(input.nowSec).clamp(0, h.length - 1);
    final end = math.min(h.length, start + hours);
    final out = <(int, int, int, bool, double)>[];
    int? open;
    var maxP = 0;
    var thunder = false;
    var total = 0.0;
    for (var i = start; i <= end; i++) {
      var wet = false;
      if (i < end) {
        final p = h.at('precipitation_probability', i) ?? 0;
        final r = h.at('precipitation', i) ?? 0;
        final code = h.at('weather_code', i)?.round();
        wet = (p >= 50 && r >= 0.3) || r >= 1.0 || isThunder(code);
        if (wet) {
          open ??= i;
          maxP = math.max(maxP, p.round());
          thunder = thunder || isThunder(code) || ((h.at('cape', i) ?? 0) >= 1500 && r >= 0.5);
          total += r;
        }
      }
      if (!wet && open != null) {
        out.add((open, i - 1, maxP, thunder, total));
        open = null;
        maxP = 0;
        thunder = false;
        total = 0;
      }
    }
    return out;
  }

  String windowText((int, int, int, bool, double) w) {
    final h = f.hourly;
    final a = local(h.time[w.$1]).hour;
    final b = (local(h.time[w.$2]).hour + 1) % 24;
    final what = w.$4
        ? t('thunderstorms with rain', 'বজ্রসহ বৃষ্টি')
        : (w.$5 >= 11 ? rainAmountWord(w.$5) : t('rain', 'বৃষ্টি'));
    final dayWord = local(h.time[w.$1]).day != local(input.nowSec).day ? t('tomorrow ', 'আগামীকাল ') : '';
    return t(
      '$what ${dayWord}from ${clock(a)} to ${clock(b)} (chance ${pct(w.$3)})',
      '$dayWord${clock(a)} থেকে ${clock(b)}-র মধ্যে $what (সম্ভাবনা ${pct(w.$3)})',
    );
  }

  AiSection nowSection() {
    final c = f.current;
    final code = c['weather_code']?.round();
    final cond = code == null ? '' : s.weatherCode(code);
    final dir = c['wind_direction_10m'];
    final lines = <String>[
      t(
        'Now in ${input.placeName}: $cond, ${temp(c['temperature_2m'])} (feels like ${temp(c['apparent_temperature'])}).',
        '${input.placeName}-এ এখন $cond, তাপমাত্রা ${temp(c['temperature_2m'])} (অনুভূত হচ্ছে ${temp(c['apparent_temperature'])})।',
      ),
      t(
        'Humidity ${pct(c['relative_humidity_2m'] ?? 0)}, wind ${units.format(Quantity.speed, c['wind_speed_10m'])}'
            '${dir == null ? '' : ' from the ${directionName(dir, false)}'}.',
        'আর্দ্রতা ${pct(c['relative_humidity_2m'] ?? 0)}, বাতাস ঘণ্টায় ${units.format(Quantity.speed, c['wind_speed_10m'])}'
            '${dir == null ? '' : ', ${directionName(dir, true)} দিক থেকে'}।',
      ),
    ];
    return AiSection('🌡️', t('Right now', 'এখন'), lines);
  }

  AiSection? nextTwoHours() {
    final n = input.nowcast;
    if (n == null) return null;
    final lines = <String>[];
    final stop = n.minutesUntilDry(input.nowSec);
    final start = n.minutesUntilRain(input.nowSec);
    if (n.rainingNow) {
      lines.add(stop == null
          ? t('It is raining and should continue for the next two hours.', 'এখন বৃষ্টি হচ্ছে, আগামী ২ ঘণ্টা চলতে পারে।')
          : t('It is raining; it should ease in about $stop minutes.', 'এখন বৃষ্টি হচ্ছে, প্রায় $stop মিনিট পর থামতে পারে।'));
    } else if (start != null) {
      lines.add(t('Rain likely in about $start minutes.', 'প্রায় $start মিনিট পর বৃষ্টি শুরু হতে পারে।'));
    } else {
      lines.add(t('No rain expected in the next two hours.', 'আগামী ২ ঘণ্টায় বৃষ্টির সম্ভাবনা নেই।'));
    }
    if (n.probability != null) {
      lines.add(t('Rain chance up to ${pct(n.probability!)}.', 'বৃষ্টির সম্ভাবনা সর্বোচ্চ ${pct(n.probability!)}।'));
    }
    if (n.next2hMm >= 0.5) {
      lines.add(t('About ${mm(n.next2hMm)} in total.', 'মোট প্রায় ${mm(n.next2hMm)}।'));
    }
    return AiSection('⏱️', t('Next 2 hours', 'আগামী ২ ঘণ্টা'), lines);
  }

  AiSection todaySection() {
    final windows = wetWindows(18);
    final d = f.daily;
    final lines = <String>[];
    if (windows.isEmpty) {
      lines.add(t('Mostly dry for the rest of today and tonight.', 'আজ বাকি দিন ও রাতে বৃষ্টির তেমন সম্ভাবনা নেই।'));
    } else {
      for (final w in windows.take(2)) {
        lines.add('${windowText(w)}${bengali ? '।' : '.'}');
      }
    }
    lines.add(t(
      'High ${temp(d.at('temperature_2m_max', 0))}, low ${temp(d.at('temperature_2m_min', 0))}.',
      'সর্বোচ্চ তাপমাত্রা ${temp(d.at('temperature_2m_max', 0))}, সর্বনিম্ন ${temp(d.at('temperature_2m_min', 0))}।',
    ));
    final total = d.at('precipitation_sum', 0) ?? 0;
    if (total >= 1) {
      lines.add(t('Total today about ${mm(total)} — ${rainAmountWord(total)}.',
          'আজ মোট প্রায় ${mm(total)} — ${rainAmountWord(total)}।'));
    }
    return AiSection('📅', t('Today & tonight', 'আজ ও আজ রাত'), lines);
  }

  AiSection daysSection() {
    final d = f.daily;
    final lines = <String>[];
    for (var i = 1; i <= 3 && i < d.length; i++) {
      final day = local(d.time[i]);
      final name = bengali
          ? const ['সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'][day.weekday - 1]
          : const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][day.weekday - 1];
      final code = d.at('weather_code', i)?.round();
      final p = d.at('precipitation_probability_max', i);
      final total = d.at('precipitation_sum', i) ?? 0;
      final parts = <String>[
        if (code != null) s.weatherCode(code),
        '${temp(d.at('temperature_2m_max', i))} / ${temp(d.at('temperature_2m_min', i))}',
        if (p != null) t('rain chance ${pct(p)}', 'বৃষ্টির সম্ভাবনা ${pct(p)}'),
        if (total >= 1) '${rainAmountWord(total)} (${mm(total)})',
      ];
      lines.add('$name: ${parts.join(', ')}');
    }
    return AiSection('🗓️', t('Next 3 days', 'আগামী ৩ দিন'), lines);
  }

  List<String> risks() {
    final d = f.daily;
    final out = <String>[];
    final windows = wetWindows(36);
    if (windows.any((w) => w.$4)) {
      out.add(t(
        'Lightning risk: during thunderstorms stay indoors, keep away from open fields, trees, water and metal poles.',
        'বজ্রপাতের ঝুঁকি: ঝড়ের সময় ঘরে থাকুন; খোলা মাঠ, গাছের নিচে, পানি ও ধাতব খুঁটি থেকে দূরে থাকুন।',
      ));
    }
    for (var i = 0; i < 2 && i < d.length; i++) {
      final total = d.at('precipitation_sum', i) ?? 0;
      if (total >= 44) {
        out.add(t(
          '${i == 0 ? 'Today' : 'Tomorrow'}: ${rainAmountWord(total)} (${mm(total)}) — waterlogging and, in hilly areas, landslides are possible.',
          '${i == 0 ? 'আজ' : 'আগামীকাল'} ${rainAmountWord(total)} (${mm(total)}) — জলাবদ্ধতা এবং পাহাড়ি এলাকায় ভূমিধসের ঝুঁকি।',
        ));
        break;
      }
    }
    final gust = d.at('wind_gusts_10m_max', 0);
    if (gust != null && gust >= 50) {
      out.add(t(
        'Gusts up to ${units.format(Quantity.speed, gust)}: secure loose objects; small boats should stay ashore.',
        'ঘণ্টায় ${units.format(Quantity.speed, gust)} পর্যন্ত দমকা হাওয়া: আলগা জিনিস বেঁধে রাখুন; ছোট নৌযান তীরে রাখুন।',
      ));
    }
    final heat = heatWave(d.at('temperature_2m_max', 0));
    if (heat != null) {
      out.add(t(
        '$heat (high ${temp(d.at('temperature_2m_max', 0))}): drink plenty of water, avoid the midday sun.',
        '$heat (সর্বোচ্চ ${temp(d.at('temperature_2m_max', 0))}): প্রচুর পানি পান করুন, দুপুরের রোদ এড়িয়ে চলুন।',
      ));
    }
    final cold = coldWave(d.at('temperature_2m_min', 0));
    if (cold != null) {
      out.add(t('$cold (low ${temp(d.at('temperature_2m_min', 0))}): keep warm, take care of children and the elderly.',
          '$cold (সর্বনিম্ন ${temp(d.at('temperature_2m_min', 0))}): গরম কাপড় পরুন, শিশু ও বয়স্কদের যত্ন নিন।'));
    }
    final h = f.hourly;
    if (!h.isEmpty) {
      final i0 = h.indexFor(input.nowSec).clamp(0, h.length - 1);
      var fog = false;
      for (var i = i0; i < math.min(h.length, i0 + 18); i++) {
        final code = h.at('weather_code', i)?.round();
        final vis = h.at('visibility', i);
        if (code == 45 || code == 48 || (vis != null && vis < 1000)) fog = true;
      }
      if (fog) {
        out.add(t('Fog likely: drive slowly with lights on; river crossings may be delayed.',
            'কুয়াশার সম্ভাবনা: গাড়ি ধীরে ও লাইট জ্বালিয়ে চালান; নৌ চলাচলে দেরি হতে পারে।'));
      }
    }
    final uv = d.at('uv_index_max', 0);
    if (uv != null && uv >= 8) {
      out.add(t('Very high UV (${uv.round()}): shade, hat and sunscreen around midday.',
          'অতি উচ্চ UV (${uv.round()}): দুপুরে ছায়ায় থাকুন, টুপি ও সানস্ক্রিন ব্যবহার করুন।'));
    }
    final aqi = input.airQuality?.current['us_aqi'];
    if (aqi != null && aqi > 150) {
      out.add(t('Unhealthy air (AQI ${aqi.round()}): wear an N95/KN95 mask outside, keep windows closed.',
          'অস্বাস্থ্যকর বাতাস (AQI ${aqi.round()}): বাইরে N95/KN95 মাস্ক পরুন, জানালা বন্ধ রাখুন।'));
    }
    if (windows.isNotEmpty && !windows.any((w) => w.$4)) {
      out.add(t('Carry an umbrella.', 'ছাতা সাথে রাখুন।'));
    }
    return out;
  }

  AiSection? nationalSection() {
    final list = input.national;
    if (list == null || list.isEmpty) return null;
    final now = [for (final (c, n) in list) if (n.rainingNow) c.name(bengali)];
    final soon = [
      for (final (c, n) in list)
        if (!n.rainingNow && n.minutesUntilRain(input.nowSec) != null) c.name(bengali)
    ];
    final lines = <String>[
      if (now.isNotEmpty)
        t('Raining now: ${now.join(', ')}.', 'এখন বৃষ্টি হচ্ছে: ${now.join(', ')}।')
      else
        t('No rain now in the major towns.', 'বড় শহরগুলোতে এখন বৃষ্টি নেই।'),
      if (soon.isNotEmpty) t('Rain within 2 hours: ${soon.join(', ')}.', '২ ঘণ্টার মধ্যে বৃষ্টি: ${soon.join(', ')}।'),
    ];
    return AiSection('🇧🇩', t('Across Bangladesh', 'সারাদেশে'), lines);
  }

  AiSection? radarSection() {
    final r = input.radar;
    if (r == null) return null;
    final last = r.latest;
    final ageH = ((input.nowSec - last.time.millisecondsSinceEpoch ~/ 1000) / 3600).round();
    final lines = <String>[];
    final cover = (last.bdCoverage * 100).round();
    if (cover < 1) {
      lines.add(t('NASA satellite rain image (about $ageH h old): no significant rain over Bangladesh.',
          'NASA-র উপগ্রহ-বৃষ্টি চিত্রে (প্রায় $ageH ঘণ্টা আগের) বাংলাদেশের ওপর উল্লেখযোগ্য বৃষ্টি নেই।'));
    } else {
      final top = last.regionCoverage.entries.where((e) => e.value >= 0.1).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final names = [
        for (final e in top.take(3)) bdDivisions.firstWhere((d) => d.nameEn == e.key).nameBn,
      ];
      final namesEn = [for (final e in top.take(3)) e.key];
      lines.add(t(
        'NASA satellite rain image (about $ageH h old): rain over about $cover% of Bangladesh'
            '${namesEn.isEmpty ? '' : ', mostly ${namesEn.join(', ')}'}.',
        'NASA-র উপগ্রহ-বৃষ্টি চিত্রে (প্রায় $ageH ঘণ্টা আগের) বাংলাদেশের প্রায় $cover% এলাকায় বৃষ্টি'
            '${names.isEmpty ? '' : ', বেশি ${names.join(', ')} বিভাগে'}।',
      ));
    }
    final trend = r.trend;
    if (r.frames.length >= 2 && trend.abs() >= 0.03) {
      lines.add(trend > 0
          ? t('The rain area was growing.', 'বৃষ্টির এলাকা বাড়ছিল।')
          : t('The rain area was shrinking.', 'বৃষ্টির এলাকা কমছিল।'));
    }
    if (r.bearingDeg != null && r.speedKmh != null) {
      lines.add(t(
        'Rain clouds moving ${directionName(r.bearingDeg!, false)} at about ${r.speedKmh!.round()} km/h.',
        'বৃষ্টির মেঘ ${directionName(r.bearingDeg!, true)} দিকে ঘণ্টায় প্রায় ${r.speedKmh!.round()} কিমি বেগে সরছিল।',
      ));
    }
    if (last.surroundCoverage > 0.05 && cover < 5) {
      lines.add(t('There is rain in the surrounding region (Bay of Bengal / neighbouring states).',
          'আশপাশের অঞ্চলে (বঙ্গোপসাগর/পার্শ্ববর্তী রাজ্য) বৃষ্টি আছে।'));
    }
    return AiSection('🛰️', t('Radar / satellite analysis', 'রাডার ও উপগ্রহ বিশ্লেষণ'), lines);
  }

  List<DisasterEvent> get bayStorms => [
        for (final e in input.storms)
          if (e.kind == WarningKind.cyclone && e.lat >= 5 && e.lat <= 24 && e.lon >= 78 && e.lon <= 100) e
      ];

  AiSection? warningsSection() {
    final lines = <String>[
      for (final w in input.warnings.take(3)) '⚠️ BMD: ${w.headline}',
      for (final e in bayStorms)
        t('🌀 Cyclone ${e.name} active in the Bay of Bengal (alert ${e.alertLevel}).',
            '🌀 বঙ্গোপসাগরে ঘূর্ণিঝড় ${e.name} সক্রিয় (সতর্কতা: ${e.alertLevel})।'),
    ];
    if (lines.isEmpty) return null;
    return AiSection('📢', t('Warnings', 'সতর্কবার্তা'), lines);
  }

  /// Share of models with ≥1 mm in the next 24 h: (wet, total).
  (int, int)? modelAgreement() {
    final m = input.models;
    if (m == null || m.hourly.isEmpty) return null;
    final i0 = m.hourly.indexFor(input.nowSec).clamp(0, m.hourly.length - 1);
    var wet = 0, total = 0;
    for (final id in input.modelIds) {
      final key = 'precipitation_$id';
      if (!m.hourly.values.containsKey(key)) continue;
      var sum = 0.0;
      var any = false;
      for (var i = i0; i < math.min(m.hourly.length, i0 + 24); i++) {
        final v = m.hourly.at(key, i);
        if (v != null) {
          sum += v;
          any = true;
        }
      }
      if (!any) continue;
      total++;
      if (sum >= 1) wet++;
    }
    return total < 3 ? null : (wet, total);
  }

  AiBriefing build() {
    final sections = <AiSection>[];
    final warn = warningsSection();
    if (warn != null) sections.add(warn);
    sections.add(nowSection());
    final next2 = nextTwoHours();
    if (next2 != null) sections.add(next2);
    final today = todaySection();
    sections.add(today);
    sections.add(daysSection());
    final riskLines = risks();
    if (riskLines.isNotEmpty) sections.add(AiSection('🛡️', t('Risks & advice', 'ঝুঁকি ও পরামর্শ'), riskLines));
    final nat = nationalSection();
    if (nat != null) sections.add(nat);
    final radar = radarSection();
    if (radar != null) sections.add(radar);

    int? confidence;
    final agree = modelAgreement();
    if (agree != null) {
      final (wet, total) = agree;
      final share = wet / total;
      confidence = (share >= 0.8 || share <= 0.2) ? 2 : ((share >= 0.6 || share <= 0.4) ? 1 : 0);
      final level = [t('low', 'কম'), t('medium', 'মাঝারি'), t('high', 'উচ্চ')][confidence];
      sections.add(AiSection('🎯', t('Confidence', 'আস্থা'), [
        t('$wet of $total weather models expect rain in the next 24 hours — confidence $level.',
            '$totalটি আবহাওয়া মডেলের $wetটি আগামী ২৪ ঘণ্টায় বৃষ্টির কথা বলছে — আস্থা $level।'),
      ]));
    }

    final headline = _headline(riskLines);
    final spoken = [
      headline,
      if (next2 != null) next2.lines.first,
      today.lines.first,
      ...riskLines.take(2),
    ].join(' ');

    final sources = <String>[
      'Open-Meteo (ECMWF, GFS, ICON…)',
      if (input.nowcast != null) t('15-minute rain forecast', '১৫ মিনিটের বৃষ্টি পূর্বাভাস'),
      if (input.models != null) t('multi-model comparison', 'একাধিক মডেলের তুলনা'),
      if (input.radar != null) 'NASA GPM IMERG',
      if (input.warnings.isNotEmpty || input.national != null) 'BMD',
      if (input.storms.isNotEmpty) 'GDACS',
      if (input.airQuality != null) 'CAMS',
    ];

    String fix(String x) => bengali ? toBnDigits(x) : x;
    return AiBriefing(
      headline: fix(headline),
      sections: [
        for (final sec in sections) AiSection(sec.emoji, sec.title, [for (final l in sec.lines) fix(l)]),
      ],
      spoken: fix(spoken),
      sources: sources,
      confidence: confidence,
    );
  }

  String _headline(List<String> riskLines) {
    final storms = bayStorms;
    if (storms.isNotEmpty) {
      return t('Cyclone ${storms.first.name} is active in the Bay of Bengal — follow BMD signals.',
          'বঙ্গোপসাগরে ঘূর্ণিঝড় ${storms.first.name} সক্রিয় — আবহাওয়া অধিদপ্তরের সংকেত অনুসরণ করুন।');
    }
    final severe = input.warnings.where(
        (w) => w.severity == WarningSeverity.extreme || w.severity == WarningSeverity.severe);
    if (severe.isNotEmpty) return 'BMD: ${severe.first.headline}';
    final n = input.nowcast;
    if (n != null) {
      if (n.rainingNow) {
        final stop = n.minutesUntilDry(input.nowSec);
        return stop == null
            ? t('Raining in ${input.placeName} now, likely to continue.', '${input.placeName}-এ এখন বৃষ্টি হচ্ছে, চলতে পারে।')
            : t('Raining now; should ease in about $stop minutes.', 'এখন বৃষ্টি হচ্ছে, প্রায় $stop মিনিট পর থামতে পারে।');
      }
      final start = n.minutesUntilRain(input.nowSec);
      if (start != null) {
        return t('Rain likely in ${input.placeName} in about $start minutes.',
            '${input.placeName}-এ প্রায় $start মিনিট পর বৃষ্টি হতে পারে।');
      }
    }
    final windows = wetWindows(18);
    if (windows.isNotEmpty) {
      final w = windows.first;
      return t('${input.placeName}: ${windowText(w)}.', '${input.placeName}-এ ${windowText(w)}।');
    }
    final heat = heatWave(f.daily.at('temperature_2m_max', 0));
    if (heat != null) {
      return t('$heat today, high ${temp(f.daily.at('temperature_2m_max', 0))}.',
          'আজ $heat, সর্বোচ্চ ${temp(f.daily.at('temperature_2m_max', 0))}।');
    }
    final aqi = input.airQuality?.current['us_aqi'];
    if (aqi != null && aqi > 150) {
      return t('Mostly dry, but the air is unhealthy (AQI ${aqi.round()}).',
          'আবহাওয়া মোটামুটি শুকনো, তবে বাতাস অস্বাস্থ্যকর (AQI ${aqi.round()})।');
    }
    return t('Mostly dry in ${input.placeName} today, high ${temp(f.daily.at('temperature_2m_max', 0))}.',
        'আজ ${input.placeName}-এ আবহাওয়া মোটামুটি শুকনো, সর্বোচ্চ ${temp(f.daily.at('temperature_2m_max', 0))}।');
  }
}
