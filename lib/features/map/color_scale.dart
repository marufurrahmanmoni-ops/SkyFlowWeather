import 'dart:typed_data';
import 'dart:ui';

/// A piecewise-linear colour gradient defined on base-unit values.
class ColorScale {
  ColorScale(this.stops, {this.transparentBelow, this.legendTicks})
      : assert(stops.length >= 2);

  /// (value, ARGB colour) pairs in ascending value order.
  final List<(double, int)> stops;

  /// Values below this are drawn transparent (e.g. no rain).
  final double? transparentBelow;

  /// Values to label on the legend (base units). Defaults to the stops.
  final List<double>? legendTicks;

  double get min => stops.first.$1;
  double get max => stops.last.$1;

  List<double> get ticks => legendTicks ?? [for (final s in stops) s.$1];

  late final Float64List stopValues =
      Float64List.fromList([for (final s in stops) s.$1]);

  late final Int32List stopColors = Int32List.fromList([for (final s in stops) s.$2]);

  Color colorAt(double v) => Color(argbAt(v));

  int argbAt(double v) => sampleArgb(v, stopValues, stopColors);

  /// Shared with the isolate renderer.
  static int sampleArgb(double v, Float64List values, Int32List colors) {
    final n = values.length;
    if (v <= values[0]) return colors[0];
    if (v >= values[n - 1]) return colors[n - 1];
    var lo = 0, hi = n - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (values[mid] <= v) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final t = (v - values[lo]) / (values[hi] - values[lo]);
    final a = colors[lo], b = colors[hi];
    int ch(int shift) {
      final ca = (a >> shift) & 0xFF, cb = (b >> shift) & 0xFF;
      return (ca + (cb - ca) * t).round() & 0xFF;
    }

    return (ch(24) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }
}

/// Colour scales for each kind of map data. Values are base units.
class Scales {
  Scales._();

  static int _c(int rgb, [int alpha = 0xFF]) => (alpha << 24) | rgb;

  static final temperature = ColorScale([
    (-40, _c(0x9E7BFF)),
    (-25, _c(0x5B4BD6)),
    (-15, _c(0x3A6FE0)),
    (-5, _c(0x4FB3F0)),
    (0, _c(0x8FE3F2)),
    (5, _c(0x5FD3A5)),
    (12, _c(0x7FCF5A)),
    (18, _c(0xC9DB3E)),
    (24, _c(0xF2C232)),
    (30, _c(0xF08A2A)),
    (36, _c(0xE0442B)),
    (42, _c(0xB0183A)),
    (50, _c(0x6E0F3D)),
  ], legendTicks: const [-30, -15, 0, 10, 20, 30, 40]);

  static final wind = ColorScale([
    (0, _c(0x2E3F8F)),
    (5, _c(0x2F64B8)),
    (15, _c(0x2C93C9)),
    (25, _c(0x35B58F)),
    (35, _c(0x8BCB45)),
    (50, _c(0xE3C93A)),
    (65, _c(0xEE8B2E)),
    (85, _c(0xD9422E)),
    (110, _c(0xA81E5D)),
    (150, _c(0x6B2496)),
    (200, _c(0xE6E6FF)),
  ], legendTicks: const [0, 15, 35, 50, 65, 85, 110, 150]);

  static final precipRate = ColorScale([
    (0.1, _c(0x9FD8FF, 0x70)),
    (0.5, _c(0x5CB8F5, 0xC0)),
    (1, _c(0x3C8EEA)),
    (2, _c(0x2C64D6)),
    (4, _c(0x2EBF62)),
    (7, _c(0xC6DA36)),
    (10, _c(0xF2C233)),
    (20, _c(0xF0812A)),
    (35, _c(0xDC2F2F)),
    (60, _c(0xA51B8A)),
    (100, _c(0xF2D2FF)),
  ], transparentBelow: 0.1, legendTicks: const [0.5, 1, 2, 4, 10, 20, 35, 60]);

  static final precipAmount = ColorScale([
    (0.5, _c(0x9FD8FF, 0x70)),
    (2, _c(0x5CB8F5, 0xC0)),
    (5, _c(0x3C8EEA)),
    (10, _c(0x2C64D6)),
    (20, _c(0x2EBF62)),
    (40, _c(0xC6DA36)),
    (60, _c(0xF2C233)),
    (100, _c(0xF0812A)),
    (150, _c(0xDC2F2F)),
    (250, _c(0xA51B8A)),
    (400, _c(0xF2D2FF)),
  ], transparentBelow: 0.5, legendTicks: const [2, 10, 20, 40, 60, 100, 150, 250]);

  static final snowfall = ColorScale([
    (0.05, _c(0xCFE8FF, 0x70)),
    (0.3, _c(0xA8D4FF, 0xC0)),
    (0.7, _c(0x7FB2F5)),
    (1.5, _c(0x6A7FE8)),
    (3, _c(0x8E5BD8)),
    (5, _c(0xC24FC4)),
    (8, _c(0xFFFFFF)),
  ], transparentBelow: 0.05, legendTicks: const [0.3, 0.7, 1.5, 3, 5, 8]);

  static final clouds = ColorScale([
    (5, _c(0xFFFFFF, 0x00)),
    (30, _c(0xC8D2DE, 0x55)),
    (60, _c(0xDDE3EA, 0x99)),
    (85, _c(0xEEF1F5, 0xD0)),
    (100, _c(0xFFFFFF, 0xF0)),
  ], transparentBelow: 5, legendTicks: const [10, 30, 50, 70, 90, 100]);

  static final pressure = ColorScale([
    (960, _c(0x6B2496)),
    (980, _c(0x3B4BC8)),
    (995, _c(0x2C93C9)),
    (1005, _c(0x35B58F)),
    (1013, _c(0x8BCB45)),
    (1020, _c(0xE3C93A)),
    (1030, _c(0xEE8B2E)),
    (1045, _c(0xC7302E)),
  ], legendTicks: const [970, 990, 1000, 1010, 1020, 1030, 1040]);

  static final humidity = ColorScale([
    (0, _c(0xA0522D)),
    (20, _c(0xD98E3A)),
    (40, _c(0xE8D35A)),
    (60, _c(0x7FCF7A)),
    (75, _c(0x3DB5A4)),
    (90, _c(0x2D7FC9)),
    (100, _c(0x2B4BA8)),
  ], legendTicks: const [10, 30, 50, 70, 90]);

  static final visibility = ColorScale([
    (0, _c(0xE8E1F5, 0xF0)),
    (500, _c(0xC9B8E8, 0xD8)),
    (1000, _c(0xA88FD6, 0xC0)),
    (3000, _c(0x8A7AB0, 0x90)),
    (6000, _c(0x6E7390, 0x55)),
    (10000, _c(0x4A5068, 0x20)),
    (20000, _c(0x30364A, 0x00)),
  ], legendTicks: const [500, 1000, 3000, 6000, 10000, 20000]);

  static final cape = ColorScale([
    (100, _c(0x3DB57A, 0x00)),
    (300, _c(0x3DB57A, 0x90)),
    (700, _c(0xB7D33A)),
    (1200, _c(0xF2C233)),
    (2000, _c(0xF0812A)),
    (3000, _c(0xDC2F2F)),
    (4500, _c(0xB0189A)),
    (6000, _c(0xF2D2FF)),
  ], transparentBelow: 100, legendTicks: const [300, 700, 1200, 2000, 3000, 4500]);

  static final lightning = ColorScale([
    (0.5, _c(0xF2E24B, 0x40)),
    (2, _c(0xF2E24B, 0xB0)),
    (5, _c(0xF0A12A)),
    (10, _c(0xE0442B)),
    (20, _c(0xB0189A)),
    (40, _c(0xFFFFFF)),
  ], transparentBelow: 0.5, legendTicks: const [2, 5, 10, 20, 40]);

  static final aqi = ColorScale([
    (0, _c(0x00C853)),
    (50, _c(0x00E400)),
    (51, _c(0xFFFF00)),
    (100, _c(0xFFE600)),
    (101, _c(0xFF7E00)),
    (150, _c(0xFF6A00)),
    (151, _c(0xFF0000)),
    (200, _c(0xE00000)),
    (201, _c(0x8F3F97)),
    (300, _c(0x7A2F86)),
    (301, _c(0x7E0023)),
    (500, _c(0x5E001A)),
  ], legendTicks: const [0, 50, 100, 150, 200, 300, 500]);

  static final uv = ColorScale([
    (0, _c(0x3DB57A)),
    (2.5, _c(0x8BCB45)),
    (3, _c(0xF2E24B)),
    (5.5, _c(0xF2C233)),
    (6, _c(0xF08A2A)),
    (7.5, _c(0xE86A2A)),
    (8, _c(0xD9302E)),
    (10.5, _c(0xC01F2E)),
    (11, _c(0x9B4FC4)),
    (14, _c(0x6B2496)),
  ], legendTicks: const [0, 3, 6, 8, 11, 14]);

  static final waveHeight = ColorScale([
    (0, _c(0x1D2F7A)),
    (0.5, _c(0x2350B0)),
    (1, _c(0x2C8ACB)),
    (1.5, _c(0x35B5B0)),
    (2.5, _c(0x5FCB62)),
    (3.5, _c(0xD2D43A)),
    (5, _c(0xF0932E)),
    (7, _c(0xDC3A2E)),
    (10, _c(0xA51B8A)),
    (14, _c(0xF2D2FF)),
  ], legendTicks: const [0.5, 1, 2.5, 3.5, 5, 7, 10]);

  static final seaTemperature = ColorScale([
    (-2, _c(0x6B2496)),
    (4, _c(0x3B4BC8)),
    (10, _c(0x2C93C9)),
    (16, _c(0x35B5A0)),
    (21, _c(0x8BCB45)),
    (25, _c(0xE3C93A)),
    (28, _c(0xEE8B2E)),
    (31, _c(0xD9302E)),
    (34, _c(0x8E1A4A)),
  ], legendTicks: const [0, 5, 10, 15, 20, 25, 28, 31]);
}
