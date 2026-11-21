/// Provider adapter interfaces.
///
/// Every external data source sits behind one of these interfaces, so a
/// provider can be replaced (for example a licensed commercial API behind a
/// proxy) without touching UI or state code.
library;

import 'dart:typed_data';

import '../../core/geo.dart';
import '../models/forecast.dart';
import '../models/place.dart';
import '../models/warnings.dart';

abstract class ForecastSource {
  String get name;
  String get attribution;
  String get attributionUrl;

  Future<ForecastBundle> forecast(Place place, {bool forceRefresh = false});

  /// Hourly forecast for several models; series keys are `variable_model`.
  Future<OmResponse> modelComparison(Place place, List<String> models,
      {int days = 10});

  /// Pressure-level data for the airgram.
  Future<OmResponse> pressureLevels(Place place, List<int> levels);

  /// Current conditions for many places in one request.
  Future<List<OmResponse?>> currentForMany(List<Place> places);

  /// Compact forecast used for alert evaluation (next ~2 days).
  Future<OmResponse> alertForecast(Place place);
}

abstract class GeocodingSource {
  Future<List<Place>> search(String query, {required String language});
}

abstract class ReverseGeocodingSource {
  Future<Place?> reverse(double lat, double lon, {required String language});
}

/// Hourly series for a single grid point. Values are NaN where missing.
class PointSeries {
  const PointSeries(this.startTime, this.data);

  /// Unix seconds of index 0 (hourly steps).
  final int startTime;
  final Map<String, Float32List> data;

  int get length => data.isEmpty ? 0 : data.values.first.length;
}

/// A dataset that can be sampled on a lat/lon grid for map layers.
class GridRequest {
  const GridRequest({
    required this.url,
    required this.variables,
    this.extra = const {},
  });

  final String url;
  final List<String> variables;
  final Map<String, String> extra;

  String get key => '$url|${variables.join(',')}|${extra.entries.map((e) => '${e.key}=${e.value}').join('&')}';
}

abstract class GridSource {
  /// Returns one series per requested point (same order). A null entry means
  /// the provider had no data for that point.
  Future<List<PointSeries?>> fetch(GridRequest request, List<GeoPoint> points);
}

abstract class WarningSource {
  String get id;
  String get label;

  /// Whether this source can have warnings for the location.
  bool covers(Place place);

  Future<List<OfficialWarning>> activeFor(Place place, {required String language});
}

abstract class StormSource {
  Future<List<DisasterEvent>> activeEvents({Set<String> types = const {'TC'}});

  /// GeoJSON FeatureCollection with the event's track and wind areas.
  Future<Map<String, dynamic>?> geometry(DisasterEvent event);
}
