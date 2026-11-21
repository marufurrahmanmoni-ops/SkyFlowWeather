import 'dart:math' as math;
import 'dart:ui';

import '../../core/geo.dart';

/// Web-mercator projection of the visible map, matching MapLibre's camera
/// (512-pixel world at zoom 0, north up, no tilt).
class MapViewport {
  const MapViewport({
    required this.lat,
    required this.lon,
    required this.zoom,
    required this.size,
  });

  final double lat;
  final double lon;
  final double zoom;
  final Size size;

  double get worldSize => 512.0 * math.pow(2, zoom).toDouble();

  double get _cx => Geo.mercX(lon) * worldSize;
  double get _cy => Geo.mercY(lat) * worldSize;

  Offset project(double pLat, double pLon) {
    final ws = worldSize;
    var x = Geo.mercX(pLon) * ws - _cx;
    // Choose the world copy nearest to the centre.
    if (x > ws / 2) x -= ws;
    if (x < -ws / 2) x += ws;
    final y = Geo.mercY(pLat) * ws - _cy;
    return Offset(x + size.width / 2, y + size.height / 2);
  }

  GeoPoint unproject(Offset p) {
    final ws = worldSize;
    final mx = (p.dx - size.width / 2 + _cx) / ws;
    final my = ((p.dy - size.height / 2 + _cy) / ws).clamp(0.0, 1.0).toDouble();
    var lonOut = Geo.lonFromMercX(mx);
    lonOut = ((lonOut + 180) % 360 + 360) % 360 - 180;
    return GeoPoint(Geo.latFromMercY(my), lonOut);
  }

  /// Visible bounds clamped to a single world copy.
  GeoBounds get bounds {
    final ws = worldSize;
    final halfW = size.width / 2 / ws * 360.0;
    final top = Geo.latFromMercY(((_cy - size.height / 2) / ws).clamp(0.0, 1.0).toDouble());
    final bottom = Geo.latFromMercY(((_cy + size.height / 2) / ws).clamp(0.0, 1.0).toDouble());
    return GeoBounds(
      south: math.max(-85.0, bottom),
      north: math.min(85.0, top),
      west: math.max(-180.0, lon - halfW),
      east: math.min(180.0, lon + halfW),
    );
  }

  bool isVisible(Offset o, {double margin = 40}) =>
      o.dx >= -margin &&
      o.dy >= -margin &&
      o.dx <= size.width + margin &&
      o.dy <= size.height + margin;

  /// Pixels per degree of longitude (constant in mercator).
  double get pixelsPerDegreeLon => worldSize / 360.0;

  @override
  bool operator ==(Object other) =>
      other is MapViewport &&
      other.lat == lat &&
      other.lon == lon &&
      other.zoom == zoom &&
      other.size == size;

  @override
  int get hashCode => Object.hash(lat, lon, zoom, size);
}
