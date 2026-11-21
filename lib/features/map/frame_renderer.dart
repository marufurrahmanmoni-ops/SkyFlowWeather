import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/geo.dart';
import '../../core/png_encoder.dart';
import 'color_scale.dart';
import 'grid.dart';

/// Everything needed to colour one or more frames, as sendable data.
class FrameJob {
  FrameJob({
    required this.frames,
    required this.rows,
    required this.cols,
    required this.north,
    required this.west,
    required this.step,
    required this.stopValues,
    required this.stopColors,
    required this.transparentBelow,
    required this.width,
    required this.height,
  });

  /// One `rows * cols` array per frame.
  final List<Float32List> frames;
  final int rows;
  final int cols;
  final double north;
  final double west;
  final double step;
  final Float64List stopValues;
  final Int32List stopColors;
  final double transparentBelow;
  final int width;
  final int height;

  double get south => north - (rows - 1) * step;
  double get east => west + (cols - 1) * step;
}

/// Picks an image size that keeps pixels roughly square in mercator space.
(int, int) imageSizeFor(GridSpec spec) {
  final mx = Geo.mercX(spec.east) - Geo.mercX(spec.west);
  final my = Geo.mercY(spec.south) - Geo.mercY(spec.north);
  final aspect = my <= 0 || mx <= 0 ? 1.0 : my / mx;
  var w = math.min(256, math.max(64, spec.cols * 20));
  var h = (w * aspect).round();
  if (h > 512) {
    h = 512;
    w = math.max(32, (h / aspect).round());
  }
  return (w, math.max(32, h));
}

/// Renders frames to PNG bytes in a background isolate.
Future<List<Uint8List>> renderFramesInBackground(FrameJob job) {
  return Isolate.run(() => renderFrames(job));
}

List<Uint8List> renderFrames(FrameJob job) {
  final w = job.width, h = job.height;
  final mTop = Geo.mercY(job.north);
  final mBottom = Geo.mercY(job.south);
  // Precompute fractional row/col for every pixel row/column.
  final rowF = Float64List(h);
  for (var y = 0; y < h; y++) {
    final my = mTop + (y + 0.5) / h * (mBottom - mTop);
    final lat = Geo.latFromMercY(my);
    rowF[y] = ((job.north - lat) / job.step).clamp(0.0, job.rows - 1.0).toDouble();
  }
  final colF = Float64List(w);
  for (var x = 0; x < w; x++) {
    final lon = job.west + (x + 0.5) / w * (job.east - job.west);
    colF[x] = ((lon - job.west) / job.step).clamp(0.0, job.cols - 1.0).toDouble();
  }

  final out = <Uint8List>[];
  final rgba = Uint8List(w * h * 4);
  for (final values in job.frames) {
    var p = 0;
    for (var y = 0; y < h; y++) {
      final fr = rowF[y];
      final r0 = fr.floor();
      final r1 = math.min(r0 + 1, job.rows - 1);
      final dr = fr - r0;
      for (var x = 0; x < w; x++) {
        final fc = colF[x];
        final c0 = fc.floor();
        final c1 = math.min(c0 + 1, job.cols - 1);
        final dc = fc - c0;
        final v00 = values[r0 * job.cols + c0];
        final v01 = values[r0 * job.cols + c1];
        final v10 = values[r1 * job.cols + c0];
        final v11 = values[r1 * job.cols + c1];
        var sum = 0.0, wsum = 0.0;
        final w00 = (1 - dr) * (1 - dc), w01 = (1 - dr) * dc;
        final w10 = dr * (1 - dc), w11 = dr * dc;
        if (!v00.isNaN) {
          sum += v00 * w00;
          wsum += w00;
        }
        if (!v01.isNaN) {
          sum += v01 * w01;
          wsum += w01;
        }
        if (!v10.isNaN) {
          sum += v10 * w10;
          wsum += w10;
        }
        if (!v11.isNaN) {
          sum += v11 * w11;
          wsum += w11;
        }
        if (wsum < 0.25) {
          // Mostly missing (land for ocean layers, outside model domain).
          rgba[p] = 0;
          rgba[p + 1] = 0;
          rgba[p + 2] = 0;
          rgba[p + 3] = 0;
        } else {
          final v = sum / wsum;
          if (v < job.transparentBelow) {
            rgba[p] = 0;
            rgba[p + 1] = 0;
            rgba[p + 2] = 0;
            rgba[p + 3] = 0;
          } else {
            final argb = ColorScale.sampleArgb(v, job.stopValues, job.stopColors);
            // Fade out where data is partially missing.
            final edge = wsum >= 0.75 ? 1.0 : (wsum - 0.25) / 0.5;
            rgba[p] = (argb >> 16) & 0xFF;
            rgba[p + 1] = (argb >> 8) & 0xFF;
            rgba[p + 2] = argb & 0xFF;
            rgba[p + 3] = (((argb >> 24) & 0xFF) * edge).round();
          }
        }
        p += 4;
      }
    }
    out.add(PngEncoder.encodeRgba(rgba, w, h));
  }
  return out;
}
