import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/geo.dart';
import '../core/l10n/app_strings.dart';
import '../core/units.dart';
import '../data/db/app_database.dart';
import '../data/models/forecast.dart';
import '../data/models/place.dart';
import '../data/models/settings.dart';
import '../data/models/warnings.dart';
import '../data/net/cached_fetcher.dart';
import '../data/net/http.dart';
import '../data/sources/geocoding.dart';
import '../data/sources/interfaces.dart';
import '../data/sources/open_meteo.dart';
import '../data/sources/rain_nowcast.dart';
import '../data/sources/warnings_sources.dart';
import '../features/map/grid.dart' show GridRepository;
import '../services/alert_engine.dart';
import '../services/home_widget_service.dart';
import '../services/location_service.dart';

// ------------------------------------------------------------------ core

/// Overridden in `main()` with the opened database.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

/// Overridden in `main()` with settings loaded from the database.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final dioProvider = Provider<Dio>((ref) {
  final dio = HttpClientFactory.create();
  ref.onDispose(dio.close);
  return dio;
});

final fetcherProvider = Provider<CachedFetcher>(
  (ref) => CachedFetcher(ref.watch(dioProvider), ref.watch(appDatabaseProvider)),
);

// ------------------------------------------------------- provider adapters

final forecastSourceProvider = Provider<ForecastSource>(
  (ref) => OpenMeteoForecastSource(ref.watch(fetcherProvider)),
);

final geocodingSourceProvider = Provider<GeocodingSource>(
  (ref) => OpenMeteoGeocodingSource(ref.watch(fetcherProvider)),
);

final reverseGeocodingSourceProvider = Provider<ReverseGeocodingSource>(
  (ref) => NominatimReverseSource(ref.watch(fetcherProvider)),
);

final gridSourceProvider = Provider<GridSource>(
  (ref) => OpenMeteoGridSource(ref.watch(fetcherProvider)),
);

/// Shared so downloaded map data (and the request budget) survive leaving
/// and reopening the Map tab.
final gridRepositoryProvider = Provider<GridRepository>(
  (ref) => GridRepository(ref.watch(gridSourceProvider)),
);

final gdacsSourceProvider = Provider<GdacsSource>(
  (ref) => GdacsSource(ref.watch(fetcherProvider)),
);

/// The Bangladesh Meteorological Department CAP warning feed.
CapRssWarningSource bmdWarningSource(CachedFetcher fetcher) => bmdWarningSourceFor(fetcher);

List<WarningSource> buildWarningSources(CachedFetcher fetcher, GdacsSource gdacs) => [
      bmdWarningSource(fetcher),
      NwsWarningSource(fetcher),
      gdacs,
    ];

final warningServiceProvider = Provider<WarningService>(
  (ref) => WarningService(
    buildWarningSources(ref.watch(fetcherProvider), ref.watch(gdacsSourceProvider)),
  ),
);

final locationServiceProvider = Provider<LocationService>((ref) => const LocationService());

final alertEngineProvider = Provider<AlertEngine>((ref) => const AlertEngine());

// --------------------------------------------------------------- settings

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  void update(AppSettings Function(AppSettings current) change) {
    state = change(state);
    unawaited(_persist(state));
  }

  Future<void> _persist(AppSettings s) async {
    try {
      await ref.read(appDatabaseProvider).setValue('settings', jsonEncode(s.toJson()));
    } catch (_) {
      // Persisting settings is best effort.
    }
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

Future<AppSettings> loadSettings(AppDatabase db) async {
  try {
    final raw = await db.getValue('settings');
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw));
  } catch (_) {
    return const AppSettings();
  }
}

String resolveLanguage(AppLanguage language) {
  if (language == AppLanguage.system) {
    return PlatformDispatcher.instance.locale.languageCode == 'bn' ? 'bn' : 'en';
  }
  return language.name;
}

final languageProvider = Provider<String>(
  (ref) => resolveLanguage(ref.watch(settingsProvider.select((s) => s.language))),
);

final stringsProvider = Provider<AppStrings>((ref) => AppStrings(ref.watch(languageProvider)));

final unitsProvider = Provider<UnitFormatter>(
  (ref) => ref.watch(settingsProvider).formatter(ref.watch(languageProvider)),
);

final timeFmtProvider = Provider<TimeFmt>(
  (ref) => TimeFmt(
    locale: ref.watch(languageProvider),
    use24h: ref.watch(settingsProvider.select((s) => s.use24h)),
  ),
);

// ---------------------------------------------------------- navigation

class ShellTabController extends Notifier<int> {
  @override
  int build() => 0;

  void go(int index) => state = index;
}

final shellTabProvider = NotifierProvider<ShellTabController, int>(ShellTabController.new);

class MapFocusRequest {
  const MapFocusRequest(this.point, {this.zoom, required this.nonce});
  final GeoPoint point;
  final double? zoom;
  final int nonce;
}

class MapFocusController extends Notifier<MapFocusRequest?> {
  int _nonce = 0;

  @override
  MapFocusRequest? build() => null;

  void focus(GeoPoint point, {double? zoom}) {
    _nonce++;
    state = MapFocusRequest(point, zoom: zoom, nonce: _nonce);
  }
}

final mapFocusProvider =
    NotifierProvider<MapFocusController, MapFocusRequest?>(MapFocusController.new);

// ------------------------------------------------------------- places

class SelectedPlaceController extends Notifier<Place?> {
  @override
  Place? build() => ref.read(initialSettingsProvider).lastPlace;

  void select(Place place, {bool remember = true}) {
    state = place;
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastPlace: place));
    if (remember && !place.isCoordinateOnly) {
      unawaited(ref
          .read(appDatabaseProvider)
          .addRecent(place)
          .then((_) => ref.invalidate(recentsProvider))
          .catchError((Object _) {}));
    }
  }
}

final selectedPlaceProvider =
    NotifierProvider<SelectedPlaceController, Place?>(SelectedPlaceController.new);

final recentsProvider = FutureProvider<List<Place>>(
  (ref) => ref.watch(appDatabaseProvider).recents(),
);

class FavoritesController extends AsyncNotifier<List<FavoritePlace>> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<List<FavoritePlace>> build() => _db.favorites();

  Future<void> _reload() async {
    state = AsyncData(await _db.favorites());
  }

  Future<void> add(Place place) async {
    await _db.addFavorite(place);
    await _reload();
  }

  Future<void> remove(int id) async {
    await _db.removeFavorite(id);
    await _reload();
  }

  Future<void> rename(int id, String? name) async {
    await _db.renameFavorite(id, name);
    await _reload();
  }

  Future<void> updateRules(int id, AlertRules rules) async {
    await _db.updateAlertRules(id, rules);
    await _reload();
  }

  Future<void> reorder(List<int> ids) async {
    await _db.reorderFavorites(ids);
    await _reload();
  }

  FavoritePlace? find(Place place) {
    final list = state.value ?? const <FavoritePlace>[];
    for (final f in list) {
      if (f.place.id == place.id ||
          ((f.place.lat - place.lat).abs() < 0.005 && (f.place.lon - place.lon).abs() < 0.005)) {
        return f;
      }
    }
    return null;
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, List<FavoritePlace>>(FavoritesController.new);

// ------------------------------------------------------------- forecasts

/// Place ids whose next forecast load must bypass the cache.
final forceRefreshIdsProvider = Provider<Set<String>>((ref) => <String>{});

void _keepAliveFor(Ref ref, Duration duration) {
  final link = ref.keepAlive();
  final timer = Timer(duration, link.close);
  ref.onDispose(timer.cancel);
}

final forecastProvider =
    FutureProvider.autoDispose.family<ForecastBundle, Place>((ref, place) async {
  _keepAliveFor(ref, const Duration(minutes: 10));
  final force = ref.read(forceRefreshIdsProvider).remove(place.id);
  return ref.watch(forecastSourceProvider).forecast(
    place,
    forceRefresh: force,
    // Saved data shows instantly; redraw when the fresh copy arrives.
    onRevalidated: () {
      if (ref.mounted) ref.invalidateSelf();
    },
  );
});

/// Models offered for comparison (Open-Meteo model ids, 2026 naming).
class WeatherModel {
  const WeatherModel(this.id, this.label);
  final String id;
  final String label;
}

const comparisonModels = [
  WeatherModel('ecmwf_ifs025', 'ECMWF IFS 0.25°'),
  WeatherModel('ecmwf_aifs025_single', 'ECMWF AIFS (AI)'),
  WeatherModel('ncep_gfs_seamless', 'NOAA GFS'),
  WeatherModel('dwd_icon_seamless', 'DWD ICON'),
  WeatherModel('cmc_gem_seamless', 'Canada GEM'),
  WeatherModel('ukmo_seamless', 'UK Met Office'),
  WeatherModel('meteofrance_seamless', 'Météo-France'),
  WeatherModel('jma_seamless', 'JMA'),
  WeatherModel('cma_grapes_global', 'CMA GRAPES'),
];

final modelComparisonProvider =
    FutureProvider.autoDispose.family<OmResponse, Place>((ref, place) async {
  _keepAliveFor(ref, const Duration(minutes: 10));
  return ref
      .watch(forecastSourceProvider)
      .modelComparison(place, [for (final m in comparisonModels) m.id]);
});

const airgramLevels = [1000, 925, 850, 700, 600, 500, 400, 300, 250, 200];

final pressureLevelsProvider =
    FutureProvider.autoDispose.family<OmResponse, Place>((ref, place) async {
  _keepAliveFor(ref, const Duration(minutes: 10));
  return ref.watch(forecastSourceProvider).pressureLevels(place, airgramLevels);
});

final warningsProvider =
    FutureProvider.autoDispose.family<WarningsResult, Place>((ref, place) async {
  _keepAliveFor(ref, const Duration(minutes: 5));
  return ref
      .watch(warningServiceProvider)
      .forPlace(place, language: ref.watch(languageProvider));
});

final favoritesCurrentProvider = FutureProvider.autoDispose<List<OmResponse?>>((ref) async {
  final favs = await ref.watch(favoritesProvider.future);
  return ref.watch(forecastSourceProvider).currentForMany([for (final f in favs) f.place]);
});

final stormsProvider = FutureProvider.autoDispose<List<DisasterEvent>>((ref) async {
  _keepAliveFor(ref, const Duration(minutes: 10));
  return ref.watch(gdacsSourceProvider).activeEvents(types: const {'TC'});
});

final reverseGeocodeProvider =
    FutureProvider.autoDispose.family<Place?, GeoPoint>((ref, point) async {
  try {
    return await ref
        .watch(reverseGeocodingSourceProvider)
        .reverse(point.lat, point.lon, language: ref.watch(languageProvider));
  } catch (_) {
    return null;
  }
});

// ------------------------------------------------- Bangladesh rain & radar

final rainNowcastSourceProvider = Provider<RainNowcastSource>(
  (ref) => RainNowcastSource(ref.watch(fetcherProvider)),
);

/// Rain now and in the next two hours for the towns in [bdCities].
final bdRainProvider = FutureProvider.autoDispose<List<RainNowcast?>>((ref) async {
  _keepAliveFor(ref, const Duration(minutes: 10));
  return ref.watch(rainNowcastSourceProvider).fetch([for (final c in bdCities) (c.lat, c.lon)]);
});

/// Rain in the next two hours for one place (Forecast overview card).
final placeNowcastProvider =
    FutureProvider.autoDispose.family<RainNowcast?, Place>((ref, place) async {
  _keepAliveFor(ref, const Duration(minutes: 10));
  final list = await ref.watch(rainNowcastSourceProvider).fetch([(place.lat, place.lon)]);
  return list.firstOrNull;
});

/// Every active BMD warning, wherever it applies.
final bmdWarningsProvider = FutureProvider.autoDispose<List<OfficialWarning>>((ref) async {
  _keepAliveFor(ref, const Duration(minutes: 5));
  return bmdWarningSource(ref.watch(fetcherProvider)).allActive(language: ref.watch(languageProvider));
});

/// Whether the Radar tab shows the Bangladesh rain & radar screen instead of
/// the map (swapped in place so two native map views never overlap).
class RadarBdModeController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

final radarBdModeProvider = NotifierProvider<RadarBdModeController, bool>(RadarBdModeController.new);

/// Redraws the home-screen widget whenever the selected place or the
/// language changes (watched by the app shell).
final homeWidgetSyncProvider = Provider<void>((ref) {
  final place = ref.watch(selectedPlaceProvider);
  final language = ref.watch(languageProvider);
  unawaited(HomeWidgetService.refresh(
    fetcher: ref.read(fetcherProvider),
    settings: ref.read(settingsProvider),
    language: language,
    place: place,
  ));
});

/// Detailed air quality (all pollutants and sub-indices, 5 days hourly).
final airQualityDetailProvider =
    FutureProvider.autoDispose.family<OmResponse, Place>((ref, place) async {
  _keepAliveFor(ref, const Duration(minutes: 10));
  final r = await ref.watch(fetcherProvider).getJson(
        Endpoints.openMeteoAirQuality,
        query: withOpenMeteoKey({
          'latitude': place.lat.toStringAsFixed(4),
          'longitude': place.lon.toStringAsFixed(4),
          'timezone': 'auto',
          'timeformat': 'unixtime',
          'current': 'us_aqi,european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide,sulphur_dioxide,'
              'carbon_monoxide,dust,uv_index,aerosol_optical_depth,us_aqi_pm2_5,us_aqi_pm10,'
              'us_aqi_ozone,us_aqi_nitrogen_dioxide,us_aqi_sulphur_dioxide,us_aqi_carbon_monoxide',
          'hourly': 'us_aqi,european_aqi,pm2_5,pm10',
          'forecast_days': 5,
        }),
        maxAge: const Duration(minutes: 30),
        maxStale: const Duration(hours: 12),
        onRevalidated: () {
          if (ref.mounted) ref.invalidateSelf();
        },
      );
  final data = r.data;
  if (data is! Map<String, dynamic>) {
    throw const ApiException(ApiErrorKind.unknown, message: 'Unexpected response');
  }
  if (data['error'] == true) {
    throw ApiException(ApiErrorKind.badRequest, message: data['reason'] as String?);
  }
  return OmResponse.fromJson(data, fetchedAt: r.fetchedAt, stale: r.stale);
});
