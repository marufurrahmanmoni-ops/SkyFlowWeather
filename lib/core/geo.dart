import 'dart:math' as math;

/// A latitude/longitude pair in degrees.
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint($lat, $lon)';

  String format({int digits = 3}) {
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(digits)}°$ns, ${lon.abs().toStringAsFixed(digits)}°$ew';
  }
}

/// Axis-aligned geographic bounds (no antimeridian crossing).
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(double lat, double lon) =>
      lat >= south && lat <= north && lon >= west && lon <= east;

  GeoBounds expand(double fraction) {
    final dLat = (north - south) * fraction;
    final dLon = (east - west) * fraction;
    return GeoBounds(
      south: math.max(-85.0, south - dLat),
      north: math.min(85.0, north + dLat),
      west: math.max(-180.0, west - dLon),
      east: math.min(180.0, east + dLon),
    );
  }

  @override
  String toString() => 'GeoBounds($south,$west → $north,$east)';
}

class Geo {
  Geo._();

  static const double maxLat = 85.05112878;

  static double degToRad(double d) => d * math.pi / 180.0;
  static double radToDeg(double r) => r * 180.0 / math.pi;

  /// Web-mercator X in 0..1 for a longitude.
  static double mercX(double lon) => (lon + 180.0) / 360.0;

  /// Web-mercator Y in 0..1 (0 = north) for a latitude.
  static double mercY(double lat) {
    final l = lat.clamp(-maxLat, maxLat).toDouble();
    final s = math.sin(degToRad(l));
    return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
  }

  static double lonFromMercX(double x) => x * 360.0 - 180.0;

  static double latFromMercY(double y) {
    final n = math.pi - 2.0 * math.pi * y;
    return radToDeg(math.atan(0.5 * (math.exp(n) - math.exp(-n))));
  }

  /// Great-circle distance in kilometres.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = degToRad(lat2 - lat1);
    final dLon = degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(degToRad(lat1)) *
            math.cos(degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// Ray-casting point-in-polygon test. [polygon] is a list of (lat, lon).
  static bool pointInPolygon(double lat, double lon, List<GeoPoint> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i], pj = polygon[j];
      final intersects = ((pi.lat > lat) != (pj.lat > lat)) &&
          (lon <
              (pj.lon - pi.lon) * (lat - pi.lat) / ((pj.lat - pi.lat) + 1e-12) +
                  pi.lon);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  /// Parses "23.81, 90.41", "23.81 90.41", "23.81N 90.41E" or
  /// "23°48'N 90°24'E" style input. Returns null if not coordinates.
  static GeoPoint? parseCoordinates(String input) {
    final s = input.trim().toUpperCase();
    final dms = RegExp(
        r'''^(\d{1,2})[°\s]+(\d{1,2})['\s]*(?:(\d{1,2}(?:\.\d+)?)["\s]*)?([NS])[,\s]+(\d{1,3})[°\s]+(\d{1,2})['\s]*(?:(\d{1,2}(?:\.\d+)?)["\s]*)?([EW])$''');
    final m1 = dms.firstMatch(s);
    if (m1 != null) {
      double part(String? v) => v == null ? 0 : double.parse(v);
      var lat = part(m1.group(1)) + part(m1.group(2)) / 60 + part(m1.group(3)) / 3600;
      var lon = part(m1.group(5)) + part(m1.group(6)) / 60 + part(m1.group(7)) / 3600;
      if (m1.group(4) == 'S') lat = -lat;
      if (m1.group(8) == 'W') lon = -lon;
      return _valid(lat, lon);
    }
    final dec = RegExp(
        r'^([+-]?\d{1,2}(?:\.\d+)?)\s*°?\s*([NS])?[,;\s]+([+-]?\d{1,3}(?:\.\d+)?)\s*°?\s*([EW])?$');
    final m2 = dec.firstMatch(s);
    if (m2 != null) {
      var lat = double.parse(m2.group(1)!);
      var lon = double.parse(m2.group(3)!);
      if (m2.group(2) == 'S') lat = -lat.abs();
      if (m2.group(4) == 'W') lon = -lon.abs();
      return _valid(lat, lon);
    }
    return null;
  }

  static GeoPoint? _valid(double lat, double lon) {
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return GeoPoint(lat, lon);
  }
}
