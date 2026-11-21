import '../../core/constants.dart';
import '../../core/geo.dart';

enum ImageryKind { radar, satellitePrecip, satelliteIr }

/// A time-dimensioned raster tile product (radar or satellite) from a
/// provider whose terms allow use with attribution.
class ImageryProduct {
  const ImageryProduct({
    required this.id,
    required this.kind,
    required this.stepMinutes,
    required this.latencyMinutes,
    required this.maxZoom,
    required this.attribution,
    required this.infoUrl,
    required this.coverage,
    required this.urlFor,
    this.tileSize = 256,
    this.animated = true,
    this.subSatelliteLon,
  });

  final String id;
  final ImageryKind kind;

  /// Interval between published frames.
  final int stepMinutes;

  /// Typical delay before a frame is published.
  final int latencyMinutes;
  final double maxZoom;
  final String attribution;
  final String infoUrl;

  /// Approximate coverage polygons (lat/lon), used to outline the coverage.
  /// Empty means global.
  final List<List<GeoPoint>> coverage;
  final String Function(DateTime utc) urlFor;
  final double tileSize;
  final bool animated;
  final double? subSatelliteLon;

  /// Frame times (UTC, oldest first) covering [history].
  List<DateTime> frameTimes(DateTime nowUtc, Duration history, {int maxFrames = 12}) {
    final stepMs = stepMinutes * 60000;
    final latest = nowUtc.subtract(Duration(minutes: latencyMinutes));
    final latestMs = (latest.millisecondsSinceEpoch ~/ stepMs) * stepMs;
    if (!animated) {
      return [DateTime.fromMillisecondsSinceEpoch(latestMs, isUtc: true)];
    }
    var count = (history.inMinutes ~/ stepMinutes) + 1;
    var stride = 1;
    while (count > maxFrames) {
      stride++;
      count = (history.inMinutes ~/ (stepMinutes * stride)) + 1;
    }
    return [
      for (var i = count - 1; i >= 0; i--)
        DateTime.fromMillisecondsSinceEpoch(latestMs - i * stride * stepMs, isUtc: true),
    ];
  }

  bool coversPoint(double lat, double lon) {
    if (coverage.isEmpty) return true;
    for (final poly in coverage) {
      if (Geo.pointInPolygon(lat, lon, poly)) return true;
    }
    return false;
  }
}

String _iso(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:00Z';
}

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}';
}

List<GeoPoint> _rect(double south, double west, double north, double east) => [
      GeoPoint(south, west),
      GeoPoint(north, west),
      GeoPoint(north, east),
      GeoPoint(south, east),
      GeoPoint(south, west),
    ];

/// Geostationary full-disk coverage, approximated as ±70° around the
/// sub-satellite point and split at the antimeridian.
List<List<GeoPoint>> _disk(double subLon) {
  final west = subLon - 70, east = subLon + 70;
  if (west < -180) {
    return [_rect(-70, -180, 70, east), _rect(-70, west + 360, 70, 180)];
  }
  if (east > 180) {
    return [_rect(-70, west, 70, 180), _rect(-70, -180, 70, east - 360)];
  }
  return [_rect(-70, west, 70, east)];
}

String _gibsWmts(String layer, DateTime t) =>
    '${Endpoints.gibsWmts}/$layer/default/${_iso(t)}/GoogleMapsCompatible_Level6/{z}/{y}/{x}.png';

String _gibsWms(String layer, DateTime t) =>
    'https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?SERVICE=WMS&REQUEST=GetMap&VERSION=1.1.1'
    '&LAYERS=$layer&STYLES=&FORMAT=image%2Fpng&TRANSPARENT=TRUE&SRS=EPSG%3A3857'
    '&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256&TIME=${_iso(t)}';

String _eumetsatWms(String layer, DateTime? t) =>
    '${Endpoints.eumetsatWms}?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0'
    '&LAYERS=$layer&STYLES=&FORMAT=image%2Fpng&TRANSPARENT=TRUE&CRS=EPSG%3A3857'
    '&BBOX={bbox-epsg-3857}&WIDTH=256&HEIGHT=256${t == null ? '' : '&TIME=${_iso(t)}'}';

class ImageryCatalog {
  ImageryCatalog._();

  static final List<ImageryProduct> all = [
    ImageryProduct(
      id: 'imerg',
      kind: ImageryKind.satellitePrecip,
      stepMinutes: 30,
      latencyMinutes: 300,
      maxZoom: 6,
      attribution: 'NASA GPM IMERG via NASA GIBS',
      infoUrl: 'https://gpm.nasa.gov/data/imerg',
      coverage: [_rect(-60, -180, 60, 180)],
      urlFor: (t) => _gibsWms('IMERG_Precipitation_Rate', t),
    ),
    ImageryProduct(
      id: 'nexrad',
      kind: ImageryKind.radar,
      stepMinutes: 5,
      latencyMinutes: 10,
      maxZoom: 10,
      attribution: 'NOAA NEXRAD via Iowa Environmental Mesonet',
      infoUrl: 'https://mesonet.agron.iastate.edu/ogc/',
      coverage: [_rect(23.5, -126, 50.5, -65.5)],
      urlFor: (t) =>
          '${Endpoints.iemTileArchive}/ridge::USCOMP-N0Q-${_stamp(t)}/{z}/{x}/{y}.png',
    ),
    ImageryProduct(
      id: 'himawari',
      kind: ImageryKind.satelliteIr,
      stepMinutes: 10,
      latencyMinutes: 40,
      maxZoom: 6,
      attribution: 'JMA Himawari via NASA GIBS',
      infoUrl: 'https://www.earthdata.nasa.gov/data/tools/gibs',
      coverage: _disk(140.7),
      subSatelliteLon: 140.7,
      urlFor: (t) => _gibsWmts('Himawari_AHI_Band13_Clean_Infrared', t),
    ),
    ImageryProduct(
      id: 'iodc',
      kind: ImageryKind.satelliteIr,
      stepMinutes: 15,
      latencyMinutes: 35,
      maxZoom: 7,
      attribution: 'EUMETSAT Meteosat (IODC) via EUMETView',
      infoUrl: 'https://view.eumetsat.int/',
      coverage: _disk(45.5),
      subSatelliteLon: 45.5,
      urlFor: (t) => _eumetsatWms('msg_iodc:ir108', t),
    ),
    ImageryProduct(
      id: 'goesEast',
      kind: ImageryKind.satelliteIr,
      stepMinutes: 10,
      latencyMinutes: 40,
      maxZoom: 6,
      attribution: 'NOAA GOES-East via NASA GIBS',
      infoUrl: 'https://www.earthdata.nasa.gov/data/tools/gibs',
      coverage: _disk(-75.2),
      subSatelliteLon: -75.2,
      urlFor: (t) => _gibsWmts('GOES-East_ABI_Band13_Clean_Infrared', t),
    ),
    ImageryProduct(
      id: 'goesWest',
      kind: ImageryKind.satelliteIr,
      stepMinutes: 10,
      latencyMinutes: 40,
      maxZoom: 6,
      attribution: 'NOAA GOES-West via NASA GIBS',
      infoUrl: 'https://www.earthdata.nasa.gov/data/tools/gibs',
      coverage: _disk(-137.2),
      subSatelliteLon: -137.2,
      urlFor: (t) => _gibsWmts('GOES-West_ABI_Band13_Clean_Infrared', t),
    ),
    ImageryProduct(
      id: 'mtg',
      kind: ImageryKind.satelliteIr,
      stepMinutes: 10,
      latencyMinutes: 35,
      maxZoom: 7,
      attribution: 'EUMETSAT Meteosat Third Generation via EUMETView',
      infoUrl: 'https://view.eumetsat.int/',
      coverage: _disk(0),
      subSatelliteLon: 0,
      urlFor: (t) => _eumetsatWms('mtg_fd:ir105_hrfi', t),
    ),
    ImageryProduct(
      id: 'worldCloud',
      kind: ImageryKind.satelliteIr,
      stepMinutes: 60,
      latencyMinutes: 60,
      maxZoom: 6,
      attribution: 'EUMETSAT multi-satellite cloud composite via EUMETView',
      infoUrl: 'https://view.eumetsat.int/',
      coverage: const [],
      animated: false,
      urlFor: (t) => _eumetsatWms('mumi:worldcloudmap_ir108', null),
    ),
  ];

  static ImageryProduct byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);

  /// Best satellite product for a longitude (closest sub-satellite point).
  static ImageryProduct satelliteFor(double lat, double lon) {
    ImageryProduct best = byId('himawari');
    var bestDist = double.infinity;
    for (final p in all) {
      final sub = p.subSatelliteLon;
      if (sub == null) continue;
      var d = (lon - sub).abs();
      if (d > 180) d = 360 - d;
      // Prefer IODC over Himawari for South Asia (better viewing angle).
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }
}
