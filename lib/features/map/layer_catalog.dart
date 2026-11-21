import 'package:material_ui/material_ui.dart';

import '../../core/constants.dart';
import '../../core/units.dart';
import '../../data/sources/interfaces.dart';
import 'color_scale.dart';

/// A set of variables fetched together for the map grid. Layers sharing a
/// group reuse the same downloaded data when the user switches between them.
class LayerDataGroup {
  const LayerDataGroup(this.id, this.request);
  final String id;
  final GridRequest request;
}

class LayerGroups {
  LayerGroups._();

  static const wind = LayerDataGroup(
    'wind',
    GridRequest(
      url: Endpoints.openMeteoForecast,
      variables: ['wind_speed_10m', 'wind_direction_10m', 'wind_gusts_10m'],
    ),
  );
  static const thermo = LayerDataGroup(
    'thermo',
    GridRequest(
      url: Endpoints.openMeteoForecast,
      variables: ['temperature_2m', 'apparent_temperature', 'relative_humidity_2m', 'uv_index'],
    ),
  );
  static const precip = LayerDataGroup(
    'precip',
    GridRequest(
      url: Endpoints.openMeteoForecast,
      variables: ['precipitation', 'snowfall', 'cape'],
    ),
  );
  static const sky = LayerDataGroup(
    'sky',
    GridRequest(
      url: Endpoints.openMeteoForecast,
      variables: ['cloud_cover', 'pressure_msl', 'visibility'],
    ),
  );

  /// Lightning potential only exists in DWD ICON (Central Europe domain).
  static const lightning = LayerDataGroup(
    'lightning',
    GridRequest(
      url: Endpoints.openMeteoForecast,
      variables: ['lightning_potential'],
      extra: {'models': 'dwd_icon_seamless'},
    ),
  );
  static const airQuality = LayerDataGroup(
    'aq',
    GridRequest(url: Endpoints.openMeteoAirQuality, variables: ['us_aqi']),
  );
  static const marine = LayerDataGroup(
    'marine',
    GridRequest(
      url: Endpoints.openMeteoMarine,
      variables: [
        'wave_height',
        'wave_direction',
        'sea_surface_temperature',
        'swell_wave_height',
        'swell_wave_direction',
      ],
    ),
  );
}

enum LayerCategory { wind, temperature, precipitation, atmosphere, airQuality, ocean }

class WeatherLayerDef {
  const WeatherLayerDef({
    required this.id,
    required this.category,
    required this.group,
    required this.variable,
    required this.quantity,
    required this.scale,
    required this.icon,
    this.arrowVariable,
    this.arrowGroup,
    this.particles = false,
    this.isobars = false,
    this.accumulate = false,
    this.regionalOnly = false,
  });

  final String id;
  final LayerCategory category;
  final LayerDataGroup group;
  final String variable;
  final Quantity quantity;
  final ColorScale scale;
  final IconData icon;

  /// Direction variable (degrees, "coming from") for arrows.
  final String? arrowVariable;

  /// Group holding [arrowVariable] when different from [group].
  final LayerDataGroup? arrowGroup;

  /// Animated wind particles on this layer by default.
  final bool particles;

  /// Pressure isobars available.
  final bool isobars;

  /// Values are summed from the first timeline step.
  final bool accumulate;

  /// The provider has data only for some regions.
  final bool regionalOnly;
}

class LayerCatalog {
  LayerCatalog._();

  static final List<WeatherLayerDef> all = [
    WeatherLayerDef(
      id: 'windSpeed',
      category: LayerCategory.wind,
      group: LayerGroups.wind,
      variable: 'wind_speed_10m',
      quantity: Quantity.speed,
      scale: Scales.wind,
      icon: Icons.air,
      particles: true,
    ),
    WeatherLayerDef(
      id: 'windDirection',
      category: LayerCategory.wind,
      group: LayerGroups.wind,
      variable: 'wind_speed_10m',
      quantity: Quantity.speed,
      scale: Scales.wind,
      icon: Icons.navigation,
      arrowVariable: 'wind_direction_10m',
      particles: true,
    ),
    WeatherLayerDef(
      id: 'windGusts',
      category: LayerCategory.wind,
      group: LayerGroups.wind,
      variable: 'wind_gusts_10m',
      quantity: Quantity.speed,
      scale: Scales.wind,
      icon: Icons.storm,
      particles: true,
    ),
    WeatherLayerDef(
      id: 'temperature',
      category: LayerCategory.temperature,
      group: LayerGroups.thermo,
      variable: 'temperature_2m',
      quantity: Quantity.temperature,
      scale: Scales.temperature,
      icon: Icons.thermostat,
    ),
    WeatherLayerDef(
      id: 'feelsLike',
      category: LayerCategory.temperature,
      group: LayerGroups.thermo,
      variable: 'apparent_temperature',
      quantity: Quantity.temperature,
      scale: Scales.temperature,
      icon: Icons.wb_twilight,
    ),
    WeatherLayerDef(
      id: 'precipitation',
      category: LayerCategory.precipitation,
      group: LayerGroups.precip,
      variable: 'precipitation',
      quantity: Quantity.precipRate,
      scale: Scales.precipRate,
      icon: Icons.water_drop,
    ),
    WeatherLayerDef(
      id: 'rainAccumulation',
      category: LayerCategory.precipitation,
      group: LayerGroups.precip,
      variable: 'precipitation',
      quantity: Quantity.precipAmount,
      scale: Scales.precipAmount,
      icon: Icons.umbrella,
      accumulate: true,
    ),
    WeatherLayerDef(
      id: 'snowfall',
      category: LayerCategory.precipitation,
      group: LayerGroups.precip,
      variable: 'snowfall',
      quantity: Quantity.snowfall,
      scale: Scales.snowfall,
      icon: Icons.ac_unit,
    ),
    WeatherLayerDef(
      id: 'thunderstorm',
      category: LayerCategory.precipitation,
      group: LayerGroups.precip,
      variable: 'cape',
      quantity: Quantity.energy,
      scale: Scales.cape,
      icon: Icons.thunderstorm,
    ),
    WeatherLayerDef(
      id: 'lightning',
      category: LayerCategory.precipitation,
      group: LayerGroups.lightning,
      variable: 'lightning_potential',
      quantity: Quantity.energy,
      scale: Scales.lightning,
      icon: Icons.bolt,
      regionalOnly: true,
    ),
    WeatherLayerDef(
      id: 'clouds',
      category: LayerCategory.atmosphere,
      group: LayerGroups.sky,
      variable: 'cloud_cover',
      quantity: Quantity.percent,
      scale: Scales.clouds,
      icon: Icons.cloud,
    ),
    WeatherLayerDef(
      id: 'pressure',
      category: LayerCategory.atmosphere,
      group: LayerGroups.sky,
      variable: 'pressure_msl',
      quantity: Quantity.pressure,
      scale: Scales.pressure,
      icon: Icons.compress,
      isobars: true,
    ),
    WeatherLayerDef(
      id: 'humidity',
      category: LayerCategory.atmosphere,
      group: LayerGroups.thermo,
      variable: 'relative_humidity_2m',
      quantity: Quantity.percent,
      scale: Scales.humidity,
      icon: Icons.opacity,
    ),
    WeatherLayerDef(
      id: 'visibility',
      category: LayerCategory.atmosphere,
      group: LayerGroups.sky,
      variable: 'visibility',
      quantity: Quantity.distance,
      scale: Scales.visibility,
      icon: Icons.visibility,
    ),
    WeatherLayerDef(
      id: 'aqi',
      category: LayerCategory.airQuality,
      group: LayerGroups.airQuality,
      variable: 'us_aqi',
      quantity: Quantity.indexValue,
      scale: Scales.aqi,
      icon: Icons.air,
    ),
    WeatherLayerDef(
      id: 'uvIndex',
      category: LayerCategory.airQuality,
      group: LayerGroups.thermo,
      variable: 'uv_index',
      quantity: Quantity.indexValue,
      scale: Scales.uv,
      icon: Icons.wb_sunny,
    ),
    WeatherLayerDef(
      id: 'waveHeight',
      category: LayerCategory.ocean,
      group: LayerGroups.marine,
      variable: 'wave_height',
      quantity: Quantity.waveHeight,
      scale: Scales.waveHeight,
      icon: Icons.waves,
    ),
    WeatherLayerDef(
      id: 'waveDirection',
      category: LayerCategory.ocean,
      group: LayerGroups.marine,
      variable: 'wave_height',
      quantity: Quantity.waveHeight,
      scale: Scales.waveHeight,
      icon: Icons.explore,
      arrowVariable: 'wave_direction',
    ),
    WeatherLayerDef(
      id: 'seaTemperature',
      category: LayerCategory.ocean,
      group: LayerGroups.marine,
      variable: 'sea_surface_temperature',
      quantity: Quantity.temperature,
      scale: Scales.seaTemperature,
      icon: Icons.water,
    ),
    WeatherLayerDef(
      id: 'marine',
      category: LayerCategory.ocean,
      group: LayerGroups.marine,
      variable: 'swell_wave_height',
      quantity: Quantity.waveHeight,
      scale: Scales.waveHeight,
      icon: Icons.sailing,
      arrowVariable: 'swell_wave_direction',
    ),
  ];

  static WeatherLayerDef byId(String id) =>
      all.firstWhere((l) => l.id == id, orElse: () => all.first);
}
