import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';
import '../core/l10n/app_strings.dart';

enum LocationErrorKind { disabled, denied, deniedForever, timeout, unknown }

class LocationException implements Exception {
  const LocationException(this.kind);

  final LocationErrorKind kind;

  String describe(AppStrings s) {
    switch (kind) {
      case LocationErrorKind.disabled:
        return s.errLocationDisabled;
      case LocationErrorKind.denied:
        return s.errLocationDenied;
      case LocationErrorKind.deniedForever:
        return s.errLocationDeniedForever;
      case LocationErrorKind.timeout:
        return s.errLocationTimeout;
      case LocationErrorKind.unknown:
        return s.errUnknown;
    }
  }
}

/// GPS access with permission handling.
class LocationService {
  const LocationService();

  Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationErrorKind.disabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationErrorKind.deniedForever);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationException(LocationErrorKind.denied);
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return GeoPoint(last.latitude, last.longitude);
      throw const LocationException(LocationErrorKind.timeout);
    } catch (e) {
      if (e is LocationException) rethrow;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return GeoPoint(last.latitude, last.longitude);
      throw const LocationException(LocationErrorKind.unknown);
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
