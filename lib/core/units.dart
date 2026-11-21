import 'dart:math' as math;

import 'package:intl/intl.dart';

enum TempUnit { celsius, fahrenheit }

enum WindUnit { kmh, mph, knots, ms }

enum PressureUnit { hpa, inhg }

enum PrecipUnit { mm, inch }

/// Physical quantity of a value. All values inside the app are kept in the
/// base unit noted here and converted only for display.
enum Quantity {
  temperature, // °C
  speed, // km/h
  pressure, // hPa
  precipRate, // mm/h
  precipAmount, // mm
  snowfall, // cm
  percent, // %
  distance, // m
  energy, // J/kg
  index, // unitless
  waveHeight, // m
  period, // s
  direction, // degrees
}

/// Converts and formats values according to the user's unit settings.
class UnitFormatter {
  const UnitFormatter({
    required this.temp,
    required this.wind,
    required this.pressureUnit,
    required this.precip,
    required this.locale,
  });

  final TempUnit temp;
  final WindUnit wind;
  final PressureUnit pressureUnit;
  final PrecipUnit precip;
  final String locale;

  double convert(Quantity q, double v) {
    switch (q) {
      case Quantity.temperature:
        return temp == TempUnit.celsius ? v : v * 9 / 5 + 32;
      case Quantity.speed:
        switch (wind) {
          case WindUnit.kmh:
            return v;
          case WindUnit.mph:
            return v / 1.609344;
          case WindUnit.knots:
            return v / 1.852;
          case WindUnit.ms:
            return v / 3.6;
        }
      case Quantity.pressure:
        return pressureUnit == PressureUnit.hpa ? v : v * 0.0295299830714;
      case Quantity.precipRate:
      case Quantity.precipAmount:
        return precip == PrecipUnit.mm ? v : v / 25.4;
      case Quantity.snowfall:
        return precip == PrecipUnit.mm ? v : v / 2.54;
      case Quantity.distance:
        return v / 1000.0; // km
      case Quantity.percent:
      case Quantity.energy:
      case Quantity.index:
      case Quantity.waveHeight:
      case Quantity.period:
      case Quantity.direction:
        return v;
    }
  }

  /// Converts a display-unit value back to the base unit.
  double toBase(Quantity q, double v) {
    switch (q) {
      case Quantity.temperature:
        return temp == TempUnit.celsius ? v : (v - 32) * 5 / 9;
      case Quantity.speed:
        switch (wind) {
          case WindUnit.kmh:
            return v;
          case WindUnit.mph:
            return v * 1.609344;
          case WindUnit.knots:
            return v * 1.852;
          case WindUnit.ms:
            return v * 3.6;
        }
      case Quantity.pressure:
        return pressureUnit == PressureUnit.hpa ? v : v / 0.0295299830714;
      case Quantity.precipRate:
      case Quantity.precipAmount:
        return precip == PrecipUnit.mm ? v : v * 25.4;
      case Quantity.snowfall:
        return precip == PrecipUnit.mm ? v : v * 2.54;
      case Quantity.distance:
        return v * 1000.0;
      case Quantity.percent:
      case Quantity.energy:
      case Quantity.index:
      case Quantity.waveHeight:
      case Quantity.period:
      case Quantity.direction:
        return v;
    }
  }

  String unit(Quantity q) {
    switch (q) {
      case Quantity.temperature:
        return temp == TempUnit.celsius ? '°C' : '°F';
      case Quantity.speed:
        switch (wind) {
          case WindUnit.kmh:
            return 'km/h';
          case WindUnit.mph:
            return 'mph';
          case WindUnit.knots:
            return 'kn';
          case WindUnit.ms:
            return 'm/s';
        }
      case Quantity.pressure:
        return pressureUnit == PressureUnit.hpa ? 'hPa' : 'inHg';
      case Quantity.precipRate:
        return precip == PrecipUnit.mm ? 'mm/h' : 'in/h';
      case Quantity.precipAmount:
        return precip == PrecipUnit.mm ? 'mm' : 'in';
      case Quantity.snowfall:
        return precip == PrecipUnit.mm ? 'cm' : 'in';
      case Quantity.percent:
        return '%';
      case Quantity.distance:
        return 'km';
      case Quantity.energy:
        return 'J/kg';
      case Quantity.index:
        return '';
      case Quantity.waveHeight:
        return 'm';
      case Quantity.period:
        return 's';
      case Quantity.direction:
        return '°';
    }
  }

  int decimals(Quantity q, double displayValue) {
    switch (q) {
      case Quantity.temperature:
      case Quantity.speed:
      case Quantity.percent:
      case Quantity.energy:
      case Quantity.direction:
        return 0;
      case Quantity.pressure:
        return pressureUnit == PressureUnit.hpa ? 0 : 2;
      case Quantity.precipRate:
      case Quantity.precipAmount:
        if (precip == PrecipUnit.inch) return 2;
        return displayValue.abs() < 10 ? 1 : 0;
      case Quantity.snowfall:
        return 1;
      case Quantity.distance:
        return displayValue < 10 ? 1 : 0;
      case Quantity.index:
        return displayValue.abs() < 10 ? 1 : 0;
      case Quantity.waveHeight:
        return 1;
      case Quantity.period:
        return 0;
    }
  }

  static final Map<String, NumberFormat> _formats = {};

  String number(double v, {int decimals = 0}) {
    final f = _formats.putIfAbsent(
      '$locale:$decimals',
      () => NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals),
    );
    return f.format(v);
  }

  /// Formats a base-unit value for display, e.g. `31 °C` or `12 km/h`.
  String format(Quantity q, double? v, {bool withUnit = true, int? decimals}) {
    if (v == null || v.isNaN) return '–';
    final d = convert(q, v);
    final digits = decimals ?? this.decimals(q, d);
    final n = number(d, decimals: digits);
    if (!withUnit) return n;
    final u = unit(q);
    if (u.isEmpty) return n;
    if (u == '%' || u == '°') return '$n$u';
    if (q == Quantity.temperature) return '$n°';
    return '$n $u';
  }

  /// Temperature with explicit unit letter, e.g. `31 °C`.
  String tempFull(double? c) {
    if (c == null || c.isNaN) return '–';
    return '${number(convert(Quantity.temperature, c))} ${unit(Quantity.temperature)}';
  }
}

/// 16-point compass label for a direction in degrees.
String compassLabel(double degrees) {
  const labels = [
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
  ];
  final i = ((degrees % 360) / 22.5).round() % 16;
  return labels[i];
}

/// Dew point (°C) via the Magnus formula, used only when the API value is
/// missing.
double dewPointFrom(double tempC, double rh) {
  const a = 17.62, b = 243.12;
  final g = math.log(rh.clamp(1, 100).toDouble() / 100.0) + a * tempC / (b + tempC);
  return b * g / (a - g);
}
