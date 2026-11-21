import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/models/weather_code.dart';

/// Original vector weather icons drawn from simple shapes.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({super.key, required this.code, this.isDay = true, this.size = 32});

  final int? code;
  final bool isDay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = code == null ? WxIcon.overcast : WeatherCodes.icon(code!);
    return CustomPaint(
      size: Size.square(size),
      painter: _WeatherIconPainter(icon, isDay),
    );
  }
}

class _WeatherIconPainter extends CustomPainter {
  _WeatherIconPainter(this.icon, this.isDay);

  final WxIcon icon;
  final bool isDay;

  static const _sun = Color(0xFFFFC542);
  static const _sunCore = Color(0xFFFFB020);
  static const _moon = Color(0xFFE7EDF7);
  static const _cloudLight = Color(0xFFE9EEF5);
  static const _cloudMid = Color(0xFFB9C4D3);
  static const _cloudDark = Color(0xFF8C99AC);
  static const _rain = Color(0xFF4CC3FF);
  static const _snow = Color(0xFFFFFFFF);
  static const _bolt = Color(0xFFFFD43B);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    switch (icon) {
      case WxIcon.clear:
        _celestial(canvas, Offset(s * 0.5, s * 0.5), s * 0.26, s);
      case WxIcon.mainlyClear:
        _celestial(canvas, Offset(s * 0.42, s * 0.4), s * 0.22, s);
        _cloud(canvas, Rect.fromLTWH(s * 0.38, s * 0.52, s * 0.56, s * 0.3), _cloudLight);
      case WxIcon.partlyCloudy:
        _celestial(canvas, Offset(s * 0.36, s * 0.34), s * 0.2, s);
        _cloud(canvas, Rect.fromLTWH(s * 0.22, s * 0.42, s * 0.7, s * 0.38), _cloudLight);
      case WxIcon.overcast:
        _cloud(canvas, Rect.fromLTWH(s * 0.06, s * 0.24, s * 0.62, s * 0.34), _cloudDark);
        _cloud(canvas, Rect.fromLTWH(s * 0.2, s * 0.4, s * 0.74, s * 0.4), _cloudMid);
      case WxIcon.fog:
        _cloud(canvas, Rect.fromLTWH(s * 0.14, s * 0.18, s * 0.72, s * 0.36), _cloudMid);
        final p = Paint()
          ..color = _cloudLight
          ..strokeWidth = s * 0.06
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final y = s * (0.64 + i * 0.12);
          canvas.drawLine(Offset(s * (0.16 + i * 0.05), y), Offset(s * (0.84 - i * 0.04), y), p);
        }
      case WxIcon.drizzle:
        _cloud(canvas, Rect.fromLTWH(s * 0.12, s * 0.16, s * 0.76, s * 0.42), _cloudMid);
        _drops(canvas, s, 3, 0.08, _rain);
      case WxIcon.rain:
        _cloud(canvas, Rect.fromLTWH(s * 0.12, s * 0.14, s * 0.76, s * 0.42), _cloudMid);
        _streaks(canvas, s, 3, _rain);
      case WxIcon.heavyRain:
        _cloud(canvas, Rect.fromLTWH(s * 0.1, s * 0.12, s * 0.8, s * 0.44), _cloudDark);
        _streaks(canvas, s, 4, _rain);
      case WxIcon.freezingRain:
        _cloud(canvas, Rect.fromLTWH(s * 0.12, s * 0.14, s * 0.76, s * 0.42), _cloudMid);
        _streaks(canvas, s, 2, _rain);
        _flakes(canvas, s, 1, offset: 0.62);
      case WxIcon.snow:
        _cloud(canvas, Rect.fromLTWH(s * 0.12, s * 0.14, s * 0.76, s * 0.42), _cloudLight);
        _flakes(canvas, s, 3);
      case WxIcon.showers:
        _celestial(canvas, Offset(s * 0.34, s * 0.3), s * 0.17, s);
        _cloud(canvas, Rect.fromLTWH(s * 0.2, s * 0.26, s * 0.72, s * 0.38), _cloudMid);
        _streaks(canvas, s, 3, _rain, top: 0.7);
      case WxIcon.snowShowers:
        _celestial(canvas, Offset(s * 0.34, s * 0.3), s * 0.17, s);
        _cloud(canvas, Rect.fromLTWH(s * 0.2, s * 0.26, s * 0.72, s * 0.38), _cloudLight);
        _flakes(canvas, s, 2, offset: 0.74);
      case WxIcon.thunder:
      case WxIcon.thunderHail:
        _cloud(canvas, Rect.fromLTWH(s * 0.1, s * 0.12, s * 0.8, s * 0.44), _cloudDark);
        _bolts(canvas, s);
        if (icon == WxIcon.thunderHail) {
          final p = Paint()..color = _snow;
          canvas.drawCircle(Offset(s * 0.28, s * 0.8), s * 0.04, p);
          canvas.drawCircle(Offset(s * 0.74, s * 0.76), s * 0.04, p);
        } else {
          _streaks(canvas, s, 2, _rain, top: 0.66, xs: const [0.3, 0.72]);
        }
    }
  }

  void _celestial(Canvas canvas, Offset c, double r, double s) {
    if (isDay) {
      final rays = Paint()
        ..color = _sun
        ..strokeWidth = s * 0.055
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(
          c + Offset(math.cos(a), math.sin(a)) * (r * 1.32),
          c + Offset(math.cos(a), math.sin(a)) * (r * 1.7),
          rays,
        );
      }
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(colors: [_sun, _sunCore])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    } else {
      // Crescent: a disc with an offset disc removed.
      final outer = Path()..addOval(Rect.fromCircle(center: c, radius: r * 1.1));
      final inner = Path()
        ..addOval(Rect.fromCircle(center: c + Offset(r * 0.55, -r * 0.35), radius: r * 0.95));
      canvas.drawPath(
        Path.combine(PathOperation.difference, outer, inner),
        Paint()..color = _moon,
      );
    }
  }

  void _cloud(Canvas canvas, Rect r, Color color) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, r.top + r.height * 0.45, r.width, r.height * 0.55),
        Radius.circular(r.height * 0.28),
      ))
      ..addOval(Rect.fromCircle(
        center: Offset(r.left + r.width * 0.32, r.top + r.height * 0.52),
        radius: r.height * 0.36,
      ))
      ..addOval(Rect.fromCircle(
        center: Offset(r.left + r.width * 0.6, r.top + r.height * 0.4),
        radius: r.height * 0.46,
      ));
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, Color.lerp(color, Colors.black, 0.18)!],
        ).createShader(r),
    );
  }

  void _streaks(Canvas canvas, double s, int n, Color color,
      {double top = 0.66, List<double>? xs}) {
    final p = Paint()
      ..color = color
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;
    final positions = xs ?? [for (var i = 0; i < n; i++) 0.3 + i * (0.42 / math.max(1, n - 1))];
    for (final x in positions) {
      canvas.drawLine(Offset(s * x, s * top), Offset(s * (x - 0.06), s * (top + 0.2)), p);
    }
  }

  void _drops(Canvas canvas, double s, int n, double r, Color color) {
    final p = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(s * (0.3 + i * 0.2), s * (0.74 + (i.isOdd ? 0.08 : 0))), s * r * 0.5, p);
    }
  }

  void _flakes(Canvas canvas, double s, int n, {double offset = 0.74}) {
    final p = Paint()
      ..color = _snow
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final c = Offset(s * (0.32 + i * (0.36 / math.max(1, n - 1))), s * (offset + (i.isOdd ? 0.08 : 0)));
      final r = s * 0.075;
      for (var k = 0; k < 3; k++) {
        final a = k * math.pi / 3;
        final d = Offset(math.cos(a), math.sin(a)) * r;
        canvas.drawLine(c - d, c + d, p);
      }
    }
  }

  void _bolts(Canvas canvas, double s) {
    final path = Path()
      ..moveTo(s * 0.54, s * 0.5)
      ..lineTo(s * 0.4, s * 0.74)
      ..lineTo(s * 0.52, s * 0.74)
      ..lineTo(s * 0.44, s * 0.95)
      ..lineTo(s * 0.66, s * 0.66)
      ..lineTo(s * 0.54, s * 0.66)
      ..lineTo(s * 0.62, s * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = _bolt);
  }

  @override
  bool shouldRepaint(_WeatherIconPainter old) => old.icon != icon || old.isDay != isDay;
}
