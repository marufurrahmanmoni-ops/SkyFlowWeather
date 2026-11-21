import 'dart:math' as math;

import '../core/units.dart';
import '../data/models/forecast.dart';
import '../data/models/place.dart';
import '../data/models/warnings.dart';
import '../data/sources/interfaces.dart';

/// Turns forecast data into threshold alerts. These are clearly labelled in
/// the UI as forecast-based, never as official warnings.
class AlertEngine {
  const AlertEngine();

  List<ForecastAlert> evaluate(OmResponse forecast, AlertRules rules,
      {int hoursAhead = 48, DateTime? now}) {
    final out = <ForecastAlert>[];
    final h = forecast.hourly;
    if (h.isEmpty) return out;
    final nowSec = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final start = h.indexFor(nowSec);
    final end = math.min(start + hoursAhead, h.length);

    ForecastAlert? firstAbove(String key, double threshold, WarningKind kind, Quantity q,
        {bool below = false}) {
      for (var i = start; i < end; i++) {
        final v = h.at(key, i);
        if (v == null) continue;
        if (below ? v <= threshold : v >= threshold) {
          // Report the peak of the event, timed at its first hour.
          var peak = v;
          for (var j = i; j < end; j++) {
            final w = h.at(key, j);
            if (w == null) break;
            if (below ? w > threshold : w < threshold) break;
            if (below ? w < peak : w > peak) peak = w;
          }
          return ForecastAlert(
            kind: kind,
            time: h.time[i],
            value: peak,
            threshold: threshold,
            quantity: q,
          );
        }
      }
      return null;
    }

    if (rules.heavyRain) {
      final a = firstAbove('precipitation', rules.rainPerHour, WarningKind.rain, Quantity.precipRate);
      if (a != null) {
        out.add(a);
      } else {
        final d = forecast.daily;
        for (var i = 0; i < d.length && i < 3; i++) {
          final sum = d.at('precipitation_sum', i);
          if (sum != null && sum >= rules.rainPerDay && d.time[i] + 86400 > nowSec) {
            out.add(ForecastAlert(
              kind: WarningKind.rain,
              time: d.time[i],
              value: sum,
              threshold: rules.rainPerDay,
              quantity: Quantity.precipAmount,
            ));
            break;
          }
        }
      }
    }
    if (rules.thunderstorm) {
      ForecastAlert? thunder;
      for (var i = start; i < end; i++) {
        final code = h.at('weather_code', i);
        final cape = h.at('cape', i);
        if ((code != null && code >= 95) || (cape != null && cape >= rules.cape)) {
          thunder = ForecastAlert(
            kind: WarningKind.thunderstorm,
            time: h.time[i],
            value: cape ?? 0,
            threshold: rules.cape,
            quantity: Quantity.energy,
          );
          break;
        }
      }
      if (thunder != null) out.add(thunder);
    }
    if (rules.strongWind) {
      final a = firstAbove('wind_gusts_10m', rules.gust, WarningKind.wind, Quantity.speed);
      if (a != null) out.add(a);
    }
    if (rules.heat) {
      final a = firstAbove('temperature_2m', rules.heatAt, WarningKind.heat, Quantity.temperature);
      if (a != null) out.add(a);
    }
    if (rules.cold) {
      final a = firstAbove('temperature_2m', rules.coldAt, WarningKind.cold, Quantity.temperature,
          below: true);
      if (a != null) out.add(a);
    }
    return out;
  }

  /// Keeps only official warnings the user asked for.
  List<OfficialWarning> filterOfficial(List<OfficialWarning> warnings, AlertRules rules) {
    return warnings.where((w) {
      switch (w.kind) {
        case WarningKind.flood:
          return rules.officialFlood;
        case WarningKind.cyclone:
          return rules.officialCyclone;
        case WarningKind.rain:
        case WarningKind.thunderstorm:
        case WarningKind.wind:
        case WarningKind.heat:
        case WarningKind.cold:
        case WarningKind.severe:
        case WarningKind.other:
          return rules.officialSevere;
      }
    }).toList();
  }
}

class WarningsResult {
  const WarningsResult({
    required this.warnings,
    required this.checkedSources,
    required this.failedSources,
  });

  final List<OfficialWarning> warnings;
  final List<String> checkedSources;
  final List<String> failedSources;
}

/// Aggregates all official warning sources that cover a place.
class WarningService {
  const WarningService(this.sources);

  final List<WarningSource> sources;

  Future<WarningsResult> forPlace(Place place, {required String language}) async {
    final applicable = sources.where((s) => s.covers(place)).toList();
    final checked = <String>[];
    final failed = <String>[];
    final results = await Future.wait(applicable.map((s) async {
      try {
        final list = await s.activeFor(place, language: language);
        checked.add(s.label);
        return list;
      } catch (_) {
        failed.add(s.label);
        return <OfficialWarning>[];
      }
    }));
    final seen = <String>{};
    final all = <OfficialWarning>[];
    for (final w in results.expand((e) => e)) {
      if (seen.add(w.id)) all.add(w);
    }
    all.sort((a, b) {
      final s = a.severity.index.compareTo(b.severity.index);
      if (s != 0) return s;
      return (b.sent ?? DateTime(0)).compareTo(a.sent ?? DateTime(0));
    });
    return WarningsResult(warnings: all, checkedSources: checked, failedSources: failed);
  }
}
