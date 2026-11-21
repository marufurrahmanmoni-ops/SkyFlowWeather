import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';

/// Shared geometry for horizontally scrolling, x-aligned charts.
class ChartGeometry {
  const ChartGeometry({required this.count, required this.hourWidth});

  static const double leftReserved = 44;
  static const double rightPad = 10;

  final int count;
  final double hourWidth;

  double get width => leftReserved + (count - 1) * hourWidth + rightPad;

  double xFor(int i) => leftReserved + i * hourWidth;

  int indexAt(double dx) =>
      ((dx - leftReserved) / hourWidth).round().clamp(0, count - 1).toInt();
}

List<FlSpot> spotsOf(List<double?> values) => [
      for (var i = 0; i < values.length; i++)
        values[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), values[i]!),
    ];

/// A compact line chart with the same x-mapping for every chart.
Widget alignedLineChart({
  required ChartGeometry geo,
  required double height,
  required List<LineChartBarData> bars,
  required String Function(double) leftLabel,
  required List<int> dayStarts,
  int? selected,
  double? minY,
  double? maxY,
  double? interval,
  List<HorizontalLine> horizontalLines = const [],
}) {
  return SizedBox(
    width: geo.width,
    height: height,
    child: Padding(
      padding: const EdgeInsets.only(right: ChartGeometry.rightPad),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (geo.count - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: bars,
          lineTouchData: const LineTouchData(enabled: false),
          clipData: const FlClipData.all(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: interval,
            verticalInterval: 1,
            checkToShowVerticalLine: (v) => dayStarts.contains(v.round()),
            getDrawingVerticalLine: (_) => const FlLine(color: Color(0x33FFFFFF), strokeWidth: 1),
            getDrawingHorizontalLine: (_) => const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: ChartGeometry.leftReserved,
                interval: interval,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(leftLabel(v),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: horizontalLines,
            verticalLines: [
              if (selected != null)
                VerticalLine(
                  x: selected.toDouble(),
                  color: AppColors.accent,
                  strokeWidth: 1.4,
                  dashArray: const [4, 3],
                ),
            ],
          ),
        ),
        duration: Duration.zero,
      ),
    ),
  );
}

/// Time axis with day names at midnight and hour labels.
class TimeAxis extends StatelessWidget {
  const TimeAxis({
    super.key,
    required this.geo,
    required this.times,
    required this.utcOffset,
    required this.fmt,
    required this.labelEvery,
  });

  final ChartGeometry geo;
  final List<int> times;
  final int utcOffset;
  final TimeFmt fmt;
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: geo.width,
      height: 34,
      child: CustomPaint(painter: _TimeAxisPainter(this)),
    );
  }
}

class _TimeAxisPainter extends CustomPainter {
  _TimeAxisPainter(this.axis);
  final TimeAxis axis;

  TextPainter _tp(String s, TextStyle style) =>
      TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    const hourStyle = TextStyle(fontSize: 10, color: AppColors.textSecondary);
    const dayStyle = TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w700);
    for (var i = 0; i < axis.times.length; i++) {
      final t = TimeFmt.atLocation(axis.times[i], axis.utcOffset);
      final x = axis.geo.xFor(i);
      if (t.hour == 0 || i == 0) {
        final tp = _tp('${axis.fmt.weekday(t)} ${axis.fmt.dayMonth(t)}', dayStyle);
        tp.paint(canvas, Offset(x + 3, 0));
      }
      if (t.hour % axis.labelEvery == 0) {
        final tp = _tp(axis.fmt.hour(t), hourStyle);
        tp.paint(canvas, Offset(x - tp.width / 2, 18));
      }
    }
  }

  @override
  bool shouldRepaint(_TimeAxisPainter old) => old.axis.times != axis.times;
}
