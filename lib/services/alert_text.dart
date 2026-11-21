import '../core/format.dart';
import '../core/l10n/app_strings.dart';
import '../core/units.dart';
import '../data/models/warnings.dart';

String warningKindLabel(AppStrings s, WarningKind kind) {
  switch (kind) {
    case WarningKind.rain:
      return s.heavyRain;
    case WarningKind.thunderstorm:
      return s.thunderstorms;
    case WarningKind.wind:
      return s.strongWinds;
    case WarningKind.heat:
      return s.extremeHeat;
    case WarningKind.cold:
      return s.extremeCold;
    case WarningKind.flood:
      return s.floodWarnings;
    case WarningKind.cyclone:
      return s.tropicalCyclones;
    case WarningKind.severe:
    case WarningKind.other:
      return s.severeWeather;
  }
}

/// "Heavy rainfall expected Sat 14:00 · 12 mm/h"
String forecastAlertText(AppStrings s, UnitFormatter units, TimeFmt fmt, ForecastAlert a) {
  final when = fmt.weekdayHm(TimeFmt.local(a.time));
  final what = warningKindLabel(s, a.kind);
  final value = a.kind == WarningKind.thunderstorm && a.value <= 0
      ? ''
      : ' · ${units.format(a.quantity, a.value)}';
  return '${s.alertExpected(what, when)}$value';
}
