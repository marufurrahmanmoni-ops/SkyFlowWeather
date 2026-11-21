import '../../core/geo.dart';

/// A named location: from search, GPS, a map tap or a favourite.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.admin1,
    this.country,
    this.countryCode,
    this.timezone,
    this.elevation,
    this.isCoordinateOnly = false,
  });

  /// A point without a known name; the label is the coordinates.
  factory Place.coordinates(double lat, double lon, {String? name}) {
    final p = GeoPoint(lat, lon);
    return Place(
      id: 'coord:${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}',
      name: name ?? p.format(digits: 2),
      lat: lat,
      lon: lon,
      isCoordinateOnly: name == null,
    );
  }

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? admin1;
  final String? country;
  final String? countryCode;
  final String? timezone;
  final double? elevation;
  final bool isCoordinateOnly;

  GeoPoint get point => GeoPoint(lat, lon);

  String get subtitle {
    final parts = <String>[
      if (admin1 != null && admin1!.isNotEmpty && admin1 != name) admin1!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    if (parts.isEmpty) return point.format(digits: 2);
    return parts.join(', ');
  }

  Place copyWith({String? name, String? admin1, String? country, String? countryCode, bool? isCoordinateOnly}) {
    return Place(
      id: id,
      name: name ?? this.name,
      lat: lat,
      lon: lon,
      admin1: admin1 ?? this.admin1,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      timezone: timezone,
      elevation: elevation,
      isCoordinateOnly: isCoordinateOnly ?? this.isCoordinateOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'admin1': admin1,
        'country': country,
        'countryCode': countryCode,
        'timezone': timezone,
        'elevation': elevation,
        'coordOnly': isCoordinateOnly,
      };

  static Place? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return Place(
      id: json['id'] as String? ?? 'coord:$lat,$lon',
      name: json['name'] as String? ?? GeoPoint(lat, lon).format(digits: 2),
      lat: lat,
      lon: lon,
      admin1: json['admin1'] as String?,
      country: json['country'] as String?,
      countryCode: json['countryCode'] as String?,
      timezone: json['timezone'] as String?,
      elevation: (json['elevation'] as num?)?.toDouble(),
      isCoordinateOnly: json['coordOnly'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A saved favourite place.
class FavoritePlace {
  const FavoritePlace({
    required this.id,
    required this.place,
    required this.sortOrder,
    this.customName,
    required this.alertRules,
  });

  final int id;
  final Place place;
  final String? customName;
  final int sortOrder;
  final AlertRules alertRules;

  String get displayName =>
      (customName != null && customName!.trim().isNotEmpty) ? customName! : place.name;

  FavoritePlace copyWith({String? customName, int? sortOrder, AlertRules? alertRules}) {
    return FavoritePlace(
      id: id,
      place: place,
      customName: customName ?? this.customName,
      sortOrder: sortOrder ?? this.sortOrder,
      alertRules: alertRules ?? this.alertRules,
    );
  }
}

/// Per-favourite alert configuration. Thresholds are stored in base units
/// (mm, km/h, °C, J/kg).
class AlertRules {
  const AlertRules({
    this.enabled = false,
    this.heavyRain = true,
    this.rainPerHour = 10,
    this.rainPerDay = 50,
    this.thunderstorm = true,
    this.cape = 2000,
    this.strongWind = true,
    this.gust = 60,
    this.heat = true,
    this.heatAt = 38,
    this.cold = false,
    this.coldAt = 8,
    this.officialFlood = true,
    this.officialCyclone = true,
    this.officialSevere = true,
  });

  final bool enabled;
  final bool heavyRain;
  final double rainPerHour;
  final double rainPerDay;
  final bool thunderstorm;
  final double cape;
  final bool strongWind;
  final double gust;
  final bool heat;
  final double heatAt;
  final bool cold;
  final double coldAt;
  final bool officialFlood;
  final bool officialCyclone;
  final bool officialSevere;

  AlertRules copyWith({
    bool? enabled,
    bool? heavyRain,
    double? rainPerHour,
    double? rainPerDay,
    bool? thunderstorm,
    double? cape,
    bool? strongWind,
    double? gust,
    bool? heat,
    double? heatAt,
    bool? cold,
    double? coldAt,
    bool? officialFlood,
    bool? officialCyclone,
    bool? officialSevere,
  }) {
    return AlertRules(
      enabled: enabled ?? this.enabled,
      heavyRain: heavyRain ?? this.heavyRain,
      rainPerHour: rainPerHour ?? this.rainPerHour,
      rainPerDay: rainPerDay ?? this.rainPerDay,
      thunderstorm: thunderstorm ?? this.thunderstorm,
      cape: cape ?? this.cape,
      strongWind: strongWind ?? this.strongWind,
      gust: gust ?? this.gust,
      heat: heat ?? this.heat,
      heatAt: heatAt ?? this.heatAt,
      cold: cold ?? this.cold,
      coldAt: coldAt ?? this.coldAt,
      officialFlood: officialFlood ?? this.officialFlood,
      officialCyclone: officialCyclone ?? this.officialCyclone,
      officialSevere: officialSevere ?? this.officialSevere,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'heavyRain': heavyRain,
        'rainPerHour': rainPerHour,
        'rainPerDay': rainPerDay,
        'thunderstorm': thunderstorm,
        'cape': cape,
        'strongWind': strongWind,
        'gust': gust,
        'heat': heat,
        'heatAt': heatAt,
        'cold': cold,
        'coldAt': coldAt,
        'officialFlood': officialFlood,
        'officialCyclone': officialCyclone,
        'officialSevere': officialSevere,
      };

  factory AlertRules.fromJson(Object? json) {
    if (json is! Map) return const AlertRules();
    const d = AlertRules();
    bool b(String k, bool def) => json[k] is bool ? json[k] as bool : def;
    double n(String k, double def) => (json[k] as num?)?.toDouble() ?? def;
    return AlertRules(
      enabled: b('enabled', d.enabled),
      heavyRain: b('heavyRain', d.heavyRain),
      rainPerHour: n('rainPerHour', d.rainPerHour),
      rainPerDay: n('rainPerDay', d.rainPerDay),
      thunderstorm: b('thunderstorm', d.thunderstorm),
      cape: n('cape', d.cape),
      strongWind: b('strongWind', d.strongWind),
      gust: n('gust', d.gust),
      heat: b('heat', d.heat),
      heatAt: n('heatAt', d.heatAt),
      cold: b('cold', d.cold),
      coldAt: n('coldAt', d.coldAt),
      officialFlood: b('officialFlood', d.officialFlood),
      officialCyclone: b('officialCyclone', d.officialCyclone),
      officialSevere: b('officialSevere', d.officialSevere),
    );
  }
}
