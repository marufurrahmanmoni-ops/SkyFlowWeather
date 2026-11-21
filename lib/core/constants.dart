/// App-wide constants and data-provider endpoints.
///
/// Endpoints can be overridden at build time with `--dart-define`, so that a
/// commercial deployment can point the app at its own proxy server (which
/// holds any secret API key) without changing code:
///
/// ```
/// flutter build apk --dart-define=OPEN_METEO_FORECAST_URL=https://weather-proxy.example.com/v1/forecast
/// ```
library;

class AppInfo {
  static const developer = 'Md. Marufur Rahman Moni';
  static const developerPhoto = 'assets/images/developer.jpg';
  AppInfo._();

  static const String name = 'SkyFlow Weather';
  static const String version = '1.0.0';
  static const String repository = 'https://github.com/lenslingo/Windy';

  /// Identifies the app to public APIs (NWS and Nominatim require this).
  static const String userAgent =
      'SkyFlowWeather/1.0 (Android; +https://github.com/lenslingo/Windy)';
}

class Endpoints {
  Endpoints._();

  static const String openMeteoForecast = String.fromEnvironment(
    'OPEN_METEO_FORECAST_URL',
    defaultValue: 'https://api.open-meteo.com/v1/forecast',
  );
  static const String openMeteoGeocoding = String.fromEnvironment(
    'OPEN_METEO_GEOCODING_URL',
    defaultValue: 'https://geocoding-api.open-meteo.com/v1/search',
  );
  static const String openMeteoAirQuality = String.fromEnvironment(
    'OPEN_METEO_AIR_QUALITY_URL',
    defaultValue: 'https://air-quality-api.open-meteo.com/v1/air-quality',
  );
  static const String openMeteoMarine = String.fromEnvironment(
    'OPEN_METEO_MARINE_URL',
    defaultValue: 'https://marine-api.open-meteo.com/v1/marine',
  );

  /// Optional, non-secret API key appended to Open-Meteo requests. Leave
  /// empty for the free non-commercial API. Do not put a secret key here for
  /// public builds; use a proxy (see README).
  static const String openMeteoApiKey = String.fromEnvironment(
    'OPEN_METEO_API_KEY',
    defaultValue: '',
  );

  static const String nominatimReverse =
      'https://nominatim.openstreetmap.org/reverse';

  // Official warnings.
  static const String bmdCapRss = 'https://cap.bmd.gov.bd/api/cap/rss.xml';
  static const String nwsAlertsActive = 'https://api.weather.gov/alerts/active';
  static const String gdacsEventSearch =
      'https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH';

  // Imagery.
  static const String gibsWmts =
      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best';
  static const String eumetsatWms = 'https://view.eumetsat.int/geoserver/wms';
  static const String iemTileCache =
      'https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0';
  static const String iemTileArchive =
      'https://mesonet.agron.iastate.edu/c/tile.py/1.0.0';
}

/// Base map styles. All are free to use with attribution.
class MapStyles {
  MapStyles._();

  static const String openFreeMapDark = 'https://tiles.openfreemap.org/styles/dark';
  static const String openFreeMapFiord =
      'https://tiles.openfreemap.org/styles/fiord';
  static const String openFreeMapPositron =
      'https://tiles.openfreemap.org/styles/positron';
  static const String openFreeMapLiberty =
      'https://tiles.openfreemap.org/styles/liberty';
  static const String maplibreDemo = 'https://demotiles.maplibre.org/style.json';
}
