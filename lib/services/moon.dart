import 'dart:math' as math;

/// Moon phase from astronomical computation (mean synodic month with the
/// main periodic corrections; accurate to a few hours, which is plenty for
/// a phase name and illumination percentage).
class MoonPhase {
  const MoonPhase({required this.age, required this.fraction, required this.illumination});

  /// Days since new moon.
  final double age;

  /// 0 = new, 0.5 = full, approaching 1 = next new moon.
  final double fraction;

  /// Illuminated fraction 0..1.
  final double illumination;

  /// 0..7: new, waxing crescent, first quarter, waxing gibbous, full,
  /// waning gibbous, last quarter, waning crescent.
  int get index => ((fraction * 8) + 0.5).floor() % 8;

  bool get waxing => fraction < 0.5;

  static const double synodicMonth = 29.530588853;

  static MoonPhase at(DateTime timeUtc) {
    final jd = timeUtc.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;
    final t = (jd - 2451545.0) / 36525.0;
    double rad(double d) => d * math.pi / 180;
    double norm(double d) => ((d % 360) + 360) % 360;
    // Mean elongation, Sun's and Moon's mean anomaly (Meeus, ch. 47-49).
    final d = norm(297.8501921 + 445267.1114034 * t);
    final m = norm(357.5291092 + 35999.0502909 * t);
    final mp = norm(134.9633964 + 477198.8675055 * t);
    // Phase angle i (Meeus eq. 48.4).
    final i = norm(180 -
        d -
        6.289 * math.sin(rad(mp)) +
        2.100 * math.sin(rad(m)) -
        1.274 * math.sin(rad(2 * d - mp)) -
        0.658 * math.sin(rad(2 * d)) -
        0.214 * math.sin(rad(2 * mp)) -
        0.110 * math.sin(rad(d)));
    final illumination = (1 + math.cos(rad(i))) / 2;
    // Elongation 0..360 gives the position in the cycle.
    final elongation = norm(180 - i);
    final fraction = elongation / 360.0;
    return MoonPhase(
      age: fraction * synodicMonth,
      fraction: fraction,
      illumination: illumination,
    );
  }
}
