import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../state/providers.dart';
import 'color_scale.dart';
import 'layer_catalog.dart';
import 'overlay_engine.dart';

/// Horizontal colour legend with tick labels in the user's units.
class LegendBar extends ConsumerWidget {
  const LegendBar({super.key, required this.layer, this.onTap});

  final WeatherLayerDef layer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final s = S.of(context);
    final unit = units.unit(layer.quantity);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(layer.icon, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.layerName(layer.id) + (layer.accumulate ? ' · ${s.accumulationFrom}' : ''),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty)
                Text(unit, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 26,
            child: CustomPaint(
              painter: _LegendPainter(layer.scale, (v) => units.format(layer.quantity, v, withUnit: false)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendPainter extends CustomPainter {
  _LegendPainter(this.scale, this.label);

  final ColorScale scale;
  final String Function(double) label;

  @override
  void paint(Canvas canvas, Size size) {
    const barH = 8.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, barH),
      const Radius.circular(4),
    );
    final ticks = scale.ticks;
    final minV = ticks.first < scale.min ? ticks.first : scale.min;
    final maxV = ticks.last > scale.max ? ticks.last : scale.max;
    final colors = <Color>[];
    final stops = <double>[];
    const n = 48;
    for (var i = 0; i <= n; i++) {
      final f = i / n;
      final v = minV + (maxV - minV) * f;
      var c = scale.colorAt(v);
      // Show translucent colours fully so the legend stays readable.
      c = c.withValues(alpha: c.a < 0.35 ? 0.35 : c.a);
      colors.add(c);
      stops.add(f);
    }
    canvas.drawRRect(
      rect,
      Paint()..shader = LinearGradient(colors: colors, stops: stops).createShader(rect.outerRect),
    );
    double xFor(double v) => (v - minV) / (maxV - minV) * size.width;
    for (final t in ticks) {
      final x = xFor(t).clamp(0.0, size.width).toDouble();
      final tp = TextPainter(
        text: TextSpan(
          text: label(t),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (x - tp.width / 2).clamp(0.0, size.width - tp.width).toDouble();
      tp.paint(canvas, Offset(dx, barH + 3));
    }
  }

  @override
  bool shouldRepaint(_LegendPainter old) => old.scale != scale;
}

/// Timeline with play/pause, hour slider and day markers.
class TimelineBar extends ConsumerWidget {
  const TimelineBar({super.key, required this.engine});

  final OverlayEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final fmt = ref.watch(timeFmtProvider);
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final times = engine.frameTimes;
        if (times.isEmpty) {
          return const SizedBox(height: 44);
        }
        final idx = engine.frameIndex.clamp(0, times.length - 1).toInt();
        final selected = TimeFmt.local(times[idx]);
        final now = DateTime.now();
        final isNow = idx == 0;
        return Row(
          children: [
            IconButton.filled(
              onPressed: times.length < 2 ? null : engine.togglePlay,
              tooltip: engine.playing ? s.pause : s.play,
              icon: Icon(engine.playing ? Icons.pause : Icons.play_arrow),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.navy,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        isNow
                            ? '${s.now} · ${fmt.hm(selected)}'
                            : '${fmt.relativeDay(selected, now, today: s.today, tomorrow: s.tomorrow)} ${fmt.hm(selected)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const Spacer(),
                      if (!isNow)
                        GestureDetector(
                          onTap: () => engine.setFrame(0),
                          child: Text(s.now,
                              style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 30,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _DayTicksPainter(times)),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          ),
                          child: Slider(
                            value: idx.toDouble(),
                            min: 0,
                            max: (times.length - 1).toDouble(),
                            divisions: times.length > 1 ? times.length - 1 : null,
                            onChanged: (v) => engine.setFrame(v.round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayTicksPainter extends CustomPainter {
  _DayTicksPainter(this.times);
  final List<int> times;

  @override
  void paint(Canvas canvas, Size size) {
    if (times.length < 2) return;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    const inset = 24.0;
    final w = size.width - inset * 2;
    for (var i = 1; i < times.length; i++) {
      final t = TimeFmt.local(times[i]);
      if (t.hour == 0) {
        final x = inset + w * i / (times.length - 1);
        canvas.drawLine(Offset(x, size.height / 2 - 7), Offset(x, size.height / 2 + 7), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DayTicksPainter old) => old.times != times;
}

/// Unit-aware label for a layer value, e.g. "28 km/h".
String layerValueLabel(UnitFormatter units, WeatherLayerDef layer, double v) {
  if (v.isNaN) return '–';
  if (layer.id == 'aqi') return units.number(v);
  return units.format(layer.quantity, v);
}
