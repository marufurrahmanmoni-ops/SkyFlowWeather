import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/net/http.dart';

/// A latitude/longitude box.
class GeoBox {
  const GeoBox(this.south, this.west, this.north, this.east);
  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(double lat, double lon) => lat >= south && lat <= north && lon >= west && lon <= east;
}

/// Bangladesh's divisions (approximate boxes, enough for "where is it raining").
class RadarRegion {
  const RadarRegion(this.nameEn, this.nameBn, this.box);
  final String nameEn;
  final String nameBn;
  final GeoBox box;
}

const bangladeshBox = GeoBox(20.6, 88.0, 26.7, 92.7);

/// The image also covers the surroundings so rain approaching from the Bay
/// of Bengal, West Bengal, Assam or Meghalaya is seen.
const radarImageBox = GeoBox(19.0, 86.0, 28.0, 94.5);

const bdDivisions = [
  RadarRegion('Rangpur', 'রংপুর', GeoBox(25.0, 88.0, 26.6, 89.9)),
  RadarRegion('Rajshahi', 'রাজশাহী', GeoBox(23.8, 88.0, 25.3, 89.5)),
  RadarRegion('Mymensingh', 'ময়মনসিংহ', GeoBox(24.2, 89.6, 25.5, 91.2)),
  RadarRegion('Sylhet', 'সিলেট', GeoBox(23.9, 90.9, 25.2, 92.5)),
  RadarRegion('Dhaka', 'ঢাকা', GeoBox(23.0, 89.4, 24.8, 91.0)),
  RadarRegion('Khulna', 'খুলনা', GeoBox(21.6, 88.5, 24.2, 89.9)),
  RadarRegion('Barishal', 'বরিশাল', GeoBox(21.7, 89.8, 23.1, 91.0)),
  RadarRegion('Chattogram', 'চট্টগ্রাম', GeoBox(20.6, 90.6, 24.3, 92.7)),
];

/// Rain seen in one image.
class RadarSnapshot {
  const RadarSnapshot({
    required this.time,
    required this.bdCoverage,
    required this.surroundCoverage,
    required this.regionCoverage,
    this.centroidLat,
    this.centroidLon,
  });

  final DateTime time;

  /// Share (0..1) of Bangladesh with rain.
  final double bdCoverage;

  /// Share of the whole image (Bangladesh and surroundings) with rain.
  final double surroundCoverage;

  /// Division name (English) → share with rain.
  final Map<String, double> regionCoverage;

  /// Centre of all rain in the image.
  final double? centroidLat;
  final double? centroidLon;
}

/// Rain over the last hour: how much, where, growing or shrinking, moving where.
class RadarAnalysis {
  const RadarAnalysis({required this.frames, this.bearingDeg, this.speedKmh});

  final List<RadarSnapshot> frames;

  /// Direction the rain area is moving towards (0 = north), if measurable.
  final double? bearingDeg;
  final double? speedKmh;

  RadarSnapshot get latest => frames.last;

  /// Change in Bangladesh rain cover between the first and last frame.
  double get trend => frames.length < 2 ? 0 : frames.last.bdCoverage - frames.first.bdCoverage;
}

double _mercY(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));

/// Counts rain pixels in an RGBA image in Web-Mercator covering [box].
/// A pixel is rain when it is not transparent (the layer is clear where dry).
RadarSnapshot analyzeRgba(Uint8List rgba, int width, int height, GeoBox box, DateTime time) {
  final yTop = _mercY(box.north);
  final yBottom = _mercY(box.south);
  var bdTotal = 0, bdWet = 0, allWet = 0;
  final regTotal = List<int>.filled(bdDivisions.length, 0);
  final regWet = List<int>.filled(bdDivisions.length, 0);
  double sumLat = 0, sumLon = 0;
  for (var py = 0; py < height; py++) {
    final my = yTop + (yBottom - yTop) * (py + 0.5) / height;
    final lat = (2 * math.atan(math.exp(my)) - math.pi / 2) * 180 / math.pi;
    for (var px = 0; px < width; px++) {
      final lon = box.west + (box.east - box.west) * (px + 0.5) / width;
      final wet = rgba[(py * width + px) * 4 + 3] > 40;
      if (wet) {
        allWet++;
        sumLat += lat;
        sumLon += lon;
      }
      if (bangladeshBox.contains(lat, lon)) {
        bdTotal++;
        if (wet) bdWet++;
        for (var r = 0; r < bdDivisions.length; r++) {
          if (bdDivisions[r].box.contains(lat, lon)) {
            regTotal[r]++;
            if (wet) regWet[r]++;
          }
        }
      }
    }
  }
  return RadarSnapshot(
    time: time,
    bdCoverage: bdTotal == 0 ? 0 : bdWet / bdTotal,
    surroundCoverage: allWet / (width * height),
    regionCoverage: {
      for (var r = 0; r < bdDivisions.length; r++)
        bdDivisions[r].nameEn: regTotal[r] == 0 ? 0 : regWet[r] / regTotal[r],
    },
    centroidLat: allWet == 0 ? null : sumLat / allWet,
    centroidLon: allWet == 0 ? null : sumLon / allWet,
  );
}

/// Movement of the rain area between the first and last frame.
RadarAnalysis summarizeFrames(List<RadarSnapshot> frames) {
  if (frames.length < 2) return RadarAnalysis(frames: frames);
  final a = frames.first, b = frames.last;
  // The centre of the rain only means something when there is enough rain.
  if (a.centroidLat == null ||
      b.centroidLat == null ||
      a.surroundCoverage < 0.01 ||
      b.surroundCoverage < 0.01) {
    return RadarAnalysis(frames: frames);
  }
  const kmPerDeg = 111.2;
  final dy = (b.centroidLat! - a.centroidLat!) * kmPerDeg;
  final dx = (b.centroidLon! - a.centroidLon!) * kmPerDeg * math.cos(a.centroidLat! * math.pi / 180);
  final km = math.sqrt(dx * dx + dy * dy);
  final hours = b.time.difference(a.time).inMinutes / 60;
  if (km < 8 || hours <= 0) return RadarAnalysis(frames: frames);
  final bearing = (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
  return RadarAnalysis(frames: frames, bearingDeg: bearing, speedKmh: km / hours);
}

/// Bengali/English name of a compass direction the rain moves towards.
String directionName(double bearing, bool bn) {
  const en = ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'];
  const b = ['উত্তর', 'উত্তর-পূর্ব', 'পূর্ব', 'দক্ষিণ-পূর্ব', 'দক্ষিণ', 'দক্ষিণ-পশ্চিম', 'পশ্চিম', 'উত্তর-পশ্চিম'];
  final i = ((bearing + 22.5) % 360 ~/ 45);
  return bn ? b[i] : en[i];
}

/// Downloads the latest NASA GPM IMERG rain images over Bangladesh (three
/// frames, 30 minutes apart) and measures them on the phone.
class RadarAnalyzer {
  RadarAnalyzer._();

  /// IMERG "early" images appear about 4–6 hours after observation.
  static const Duration latency = Duration(minutes: 330);

  static String _iso(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:00Z';
  }

  static double _x(double lon) => lon * 20037508.34 / 180;
  static double _y(double lat) => _mercY(lat) * 20037508.34 / math.pi;

  static String imageUrl(DateTime t, {int width = 240, int height = 256}) {
    final b = radarImageBox;
    final bbox = '${_x(b.west)},${_y(b.south)},${_x(b.east)},${_y(b.north)}';
    return 'https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?SERVICE=WMS&REQUEST=GetMap'
        '&VERSION=1.1.1&LAYERS=IMERG_Precipitation_Rate&STYLES=&FORMAT=image%2Fpng&TRANSPARENT=TRUE'
        '&SRS=EPSG%3A3857&BBOX=$bbox&WIDTH=$width&HEIGHT=$height&TIME=${_iso(t)}';
  }

  static Future<RadarAnalysis?> analyzeLatest({Dio? dio}) async {
    final client = dio ?? HttpClientFactory.create();
    final now = DateTime.now().toUtc().subtract(latency);
    final newest = DateTime.utc(now.year, now.month, now.day, now.hour, now.minute >= 30 ? 30 : 0);
    final times = [for (final m in [60, 30, 0]) newest.subtract(Duration(minutes: m))];
    final frames = <RadarSnapshot>[];
    for (final t in times) {
      // A missing frame (not yet published, or a server error) is skipped.
      try {
        final res = await client.get<List<int>>(imageUrl(t),
            options: Options(responseType: ResponseType.bytes));
        final bytes = Uint8List.fromList(res.data ?? const []);
        if (bytes.isEmpty) continue;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data != null) {
          frames.add(analyzeRgba(
              data.buffer.asUint8List(), frame.image.width, frame.image.height, radarImageBox, t));
        }
        frame.image.dispose();
      } catch (e) {
        debugPrint('Radar frame $t failed: $e');
      }
    }
    return frames.isEmpty ? null : summarizeFrames(frames);
  }
}
