import '../../core/constants.dart';
import '../../core/units.dart';
import 'place.dart';

enum AppLanguage { system, en, bn }

enum BaseMapStyle { dark, fiord, positron, liberty }

enum DetailLevel { low, medium, high }

extension BaseMapStyleUrl on BaseMapStyle {
  String get url {
    switch (this) {
      case BaseMapStyle.dark:
        return MapStyles.openFreeMapDark;
      case BaseMapStyle.fiord:
        return MapStyles.openFreeMapFiord;
      case BaseMapStyle.positron:
        return MapStyles.openFreeMapPositron;
      case BaseMapStyle.liberty:
        return MapStyles.openFreeMapLiberty;
    }
  }
}

extension DetailColumns on DetailLevel {
  /// Approximate number of grid columns across the visible map.
  int get columns {
    switch (this) {
      case DetailLevel.low:
        return 6;
      case DetailLevel.medium:
        return 8;
      case DetailLevel.high:
        return 11;
    }
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

class AppSettings {
  const AppSettings({
    this.language = AppLanguage.system,
    this.tempUnit = TempUnit.celsius,
    this.windUnit = WindUnit.kmh,
    this.pressureUnit = PressureUnit.hpa,
    this.precipUnit = PrecipUnit.mm,
    this.use24h = false,
    this.mapStyle = BaseMapStyle.dark,
    this.detail = DetailLevel.medium,
    this.particles = true,
    this.particlesAllLayers = false,
    this.particleDensity = 1.0,
    this.showValues = true,
    this.showIsobars = true,
    this.showArrows = true,
    this.reduceMotion = false,
    this.backgroundAlerts = false,
    this.bmdAllWarnings = true,
    this.rainAlarmEnabled = false,
    this.rainAlarmPlace,
    this.rainAlarmLeadMinutes = 60,
    this.rainAlarmMinProbability = 60,
    this.rainAlarmStorms = true,
    this.rainAlarmVoice = true,
    this.lastLayer = 'windSpeed',
    this.layerOpacity = const {},
    this.lastPlace,
    this.cameraLat = 23.7,
    this.cameraLon = 90.35,
    this.cameraZoom = 5.6,
  });

  final AppLanguage language;
  final TempUnit tempUnit;
  final WindUnit windUnit;
  final PressureUnit pressureUnit;
  final PrecipUnit precipUnit;
  final bool use24h;
  final BaseMapStyle mapStyle;
  final DetailLevel detail;
  final bool particles;
  final bool particlesAllLayers;
  final double particleDensity;
  final bool showValues;
  final bool showIsobars;
  final bool showArrows;
  final bool reduceMotion;
  final bool backgroundAlerts;

  /// Notify every new Bangladesh Meteorological Department warning.
  final bool bmdAllWarnings;

  /// Rain/storm alarm for one chosen area.
  final bool rainAlarmEnabled;
  final Place? rainAlarmPlace;

  /// How far ahead to warn (minutes).
  final int rainAlarmLeadMinutes;

  /// Lowest rain probability (percent) that sounds the alarm.
  final int rainAlarmMinProbability;

  /// Also alarm for thunderstorms and strong gusts.
  final bool rainAlarmStorms;

  /// Speak the warning aloud.
  final bool rainAlarmVoice;
  final String lastLayer;
  final Map<String, double> layerOpacity;
  final Place? lastPlace;
  final double cameraLat;
  final double cameraLon;
  final double cameraZoom;

  double opacityFor(String layerId) => layerOpacity[layerId] ?? 0.78;

  AppSettings copyWith({
    AppLanguage? language,
    TempUnit? tempUnit,
    WindUnit? windUnit,
    PressureUnit? pressureUnit,
    PrecipUnit? precipUnit,
    bool? use24h,
    BaseMapStyle? mapStyle,
    DetailLevel? detail,
    bool? particles,
    bool? particlesAllLayers,
    double? particleDensity,
    bool? showValues,
    bool? showIsobars,
    bool? showArrows,
    bool? reduceMotion,
    bool? backgroundAlerts,
    bool? bmdAllWarnings,
    bool? rainAlarmEnabled,
    Place? rainAlarmPlace,
    int? rainAlarmLeadMinutes,
    int? rainAlarmMinProbability,
    bool? rainAlarmStorms,
    bool? rainAlarmVoice,
    String? lastLayer,
    Map<String, double>? layerOpacity,
    Place? lastPlace,
    double? cameraLat,
    double? cameraLon,
    double? cameraZoom,
  }) {
    return AppSettings(
      language: language ?? this.language,
      tempUnit: tempUnit ?? this.tempUnit,
      windUnit: windUnit ?? this.windUnit,
      pressureUnit: pressureUnit ?? this.pressureUnit,
      precipUnit: precipUnit ?? this.precipUnit,
      use24h: use24h ?? this.use24h,
      mapStyle: mapStyle ?? this.mapStyle,
      detail: detail ?? this.detail,
      particles: particles ?? this.particles,
      particlesAllLayers: particlesAllLayers ?? this.particlesAllLayers,
      particleDensity: particleDensity ?? this.particleDensity,
      showValues: showValues ?? this.showValues,
      showIsobars: showIsobars ?? this.showIsobars,
      showArrows: showArrows ?? this.showArrows,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      backgroundAlerts: backgroundAlerts ?? this.backgroundAlerts,
      bmdAllWarnings: bmdAllWarnings ?? this.bmdAllWarnings,
      rainAlarmEnabled: rainAlarmEnabled ?? this.rainAlarmEnabled,
      rainAlarmPlace: rainAlarmPlace ?? this.rainAlarmPlace,
      rainAlarmLeadMinutes: rainAlarmLeadMinutes ?? this.rainAlarmLeadMinutes,
      rainAlarmMinProbability: rainAlarmMinProbability ?? this.rainAlarmMinProbability,
      rainAlarmStorms: rainAlarmStorms ?? this.rainAlarmStorms,
      rainAlarmVoice: rainAlarmVoice ?? this.rainAlarmVoice,
      lastLayer: lastLayer ?? this.lastLayer,
      layerOpacity: layerOpacity ?? this.layerOpacity,
      lastPlace: lastPlace ?? this.lastPlace,
      cameraLat: cameraLat ?? this.cameraLat,
      cameraLon: cameraLon ?? this.cameraLon,
      cameraZoom: cameraZoom ?? this.cameraZoom,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language.name,
        'tempUnit': tempUnit.name,
        'windUnit': windUnit.name,
        'pressureUnit': pressureUnit.name,
        'precipUnit': precipUnit.name,
        'use24h': use24h,
        'mapStyle': mapStyle.name,
        'detail': detail.name,
        'particles': particles,
        'particlesAllLayers': particlesAllLayers,
        'particleDensity': particleDensity,
        'showValues': showValues,
        'showIsobars': showIsobars,
        'showArrows': showArrows,
        'reduceMotion': reduceMotion,
        'backgroundAlerts': backgroundAlerts,
        'bmdAllWarnings': bmdAllWarnings,
        'rainAlarmEnabled': rainAlarmEnabled,
        'rainAlarmPlace': rainAlarmPlace?.toJson(),
        'rainAlarmLeadMinutes': rainAlarmLeadMinutes,
        'rainAlarmMinProbability': rainAlarmMinProbability,
        'rainAlarmStorms': rainAlarmStorms,
        'rainAlarmVoice': rainAlarmVoice,
        'lastLayer': lastLayer,
        'layerOpacity': layerOpacity,
        'lastPlace': lastPlace?.toJson(),
        'cameraLat': cameraLat,
        'cameraLon': cameraLon,
        'cameraZoom': cameraZoom,
      };

  factory AppSettings.fromJson(Object? json) {
    if (json is! Map) return const AppSettings();
    const d = AppSettings();
    bool b(String k, bool def) => json[k] is bool ? json[k] as bool : def;
    double n(String k, double def) => (json[k] as num?)?.toDouble() ?? def;
    final opacity = <String, double>{};
    final rawOpacity = json['layerOpacity'];
    if (rawOpacity is Map) {
      rawOpacity.forEach((k, v) {
        if (k is String && v is num) opacity[k] = v.toDouble().clamp(0.1, 1.0).toDouble();
      });
    }
    return AppSettings(
      language: _enumByName(AppLanguage.values, json['language'], d.language),
      tempUnit: _enumByName(TempUnit.values, json['tempUnit'], d.tempUnit),
      windUnit: _enumByName(WindUnit.values, json['windUnit'], d.windUnit),
      pressureUnit:
          _enumByName(PressureUnit.values, json['pressureUnit'], d.pressureUnit),
      precipUnit: _enumByName(PrecipUnit.values, json['precipUnit'], d.precipUnit),
      use24h: b('use24h', d.use24h),
      mapStyle: _enumByName(BaseMapStyle.values, json['mapStyle'], d.mapStyle),
      detail: _enumByName(DetailLevel.values, json['detail'], d.detail),
      particles: b('particles', d.particles),
      particlesAllLayers: b('particlesAllLayers', d.particlesAllLayers),
      particleDensity: n('particleDensity', d.particleDensity).clamp(0.3, 2.0).toDouble(),
      showValues: b('showValues', d.showValues),
      showIsobars: b('showIsobars', d.showIsobars),
      showArrows: b('showArrows', d.showArrows),
      reduceMotion: b('reduceMotion', d.reduceMotion),
      backgroundAlerts: b('backgroundAlerts', d.backgroundAlerts),
      bmdAllWarnings: b('bmdAllWarnings', d.bmdAllWarnings),
      rainAlarmEnabled: b('rainAlarmEnabled', d.rainAlarmEnabled),
      rainAlarmPlace: Place.tryFromJson(json['rainAlarmPlace']),
      rainAlarmLeadMinutes: (json['rainAlarmLeadMinutes'] as num?)?.toInt() ?? d.rainAlarmLeadMinutes,
      rainAlarmMinProbability:
          (json['rainAlarmMinProbability'] as num?)?.toInt() ?? d.rainAlarmMinProbability,
      rainAlarmStorms: b('rainAlarmStorms', d.rainAlarmStorms),
      rainAlarmVoice: b('rainAlarmVoice', d.rainAlarmVoice),
      lastLayer: json['lastLayer'] as String? ?? d.lastLayer,
      layerOpacity: opacity,
      lastPlace: Place.tryFromJson(json['lastPlace']),
      cameraLat: n('cameraLat', d.cameraLat).clamp(-80.0, 80.0).toDouble(),
      cameraLon: n('cameraLon', d.cameraLon).clamp(-180.0, 180.0).toDouble(),
      cameraZoom: n('cameraZoom', d.cameraZoom).clamp(1.0, 14.0).toDouble(),
    );
  }

  UnitFormatter formatter(String locale) => UnitFormatter(
        temp: tempUnit,
        wind: windUnit,
        pressureUnit: pressureUnit,
        precip: precipUnit,
        locale: locale,
      );
}
