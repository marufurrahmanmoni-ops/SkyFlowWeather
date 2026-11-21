import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:skyflow_weather/core/geo.dart';
import 'package:skyflow_weather/core/png_encoder.dart';
import 'package:skyflow_weather/core/units.dart';
import 'package:skyflow_weather/data/models/forecast.dart';
import 'package:skyflow_weather/data/models/place.dart';
import 'package:skyflow_weather/data/models/settings.dart';
import 'package:skyflow_weather/features/map/color_scale.dart';
import 'package:skyflow_weather/features/map/grid.dart';
import 'package:skyflow_weather/features/map/map_viewport.dart';
import 'package:skyflow_weather/services/moon.dart';

void main() {
  group('Coordinates', () {
    test('parses decimal coordinates', () {
      final p = Geo.parseCoordinates('23.81, 90.41')!;
      expect(p.lat, closeTo(23.81, 1e-9));
      expect(p.lon, closeTo(90.41, 1e-9));
    });

    test('parses hemisphere letters', () {
      final p = Geo.parseCoordinates('33.9S 151.2E')!;
      expect(p.lat, closeTo(-33.9, 1e-9));
      expect(p.lon, closeTo(151.2, 1e-9));
    });

    test('parses degrees and minutes', () {
      final p = Geo.parseCoordinates("23°48'N 90°24'E")!;
      expect(p.lat, closeTo(23.8, 1e-6));
      expect(p.lon, closeTo(90.4, 1e-6));
    });

    test('rejects text and out-of-range values', () {
      expect(Geo.parseCoordinates('Dhaka'), isNull);
      expect(Geo.parseCoordinates('95, 10'), isNull);
    });

    test('point in polygon', () {
      const square = [GeoPoint(0, 0), GeoPoint(0, 10), GeoPoint(10, 10), GeoPoint(10, 0)];
      expect(Geo.pointInPolygon(5, 5, square), isTrue);
      expect(Geo.pointInPolygon(15, 5, square), isFalse);
    });

    test('distance Dhaka–Chattogram is about 215 km', () {
      final d = Geo.distanceKm(23.81, 90.41, 22.36, 91.78);
      expect(d, inInclusiveRange(200, 230));
    });
  });

  group('Map projection', () {
    test('project/unproject round trip', () {
      const vp = MapViewport(lat: 23.7, lon: 90.4, zoom: 6, size: Size(400, 800));
      final o = vp.project(22.0, 91.5);
      final back = vp.unproject(o);
      expect(back.lat, closeTo(22.0, 1e-6));
      expect(back.lon, closeTo(91.5, 1e-6));
    });

    test('centre projects to the middle of the screen', () {
      const vp = MapViewport(lat: 10, lon: 20, zoom: 4, size: Size(300, 600));
      final o = vp.project(10, 20);
      expect(o.dx, closeTo(150, 1e-6));
      expect(o.dy, closeTo(300, 1e-6));
      expect(vp.isVisible(const Offset(150, 300)), isTrue);
    });
  });

  group('Grid', () {
    test('grid is aligned to its step and covers the view', () {
      const view = GeoBounds(south: 20.3, west: 87.9, north: 26.8, east: 92.8);
      final spec = GridSpec.forView(view, 8);
      expect(spec.count, lessThanOrEqualTo(260));
      expect((spec.west / spec.step - (spec.west / spec.step).round()).abs(), lessThan(1e-9));
      expect(spec.west, lessThanOrEqualTo(view.west));
      expect(spec.east, greaterThanOrEqualTo(view.east));
      expect(spec.north, greaterThanOrEqualTo(view.north));
      expect(spec.south, lessThanOrEqualTo(view.south));
    });

    test('bilinear sample interpolates and skips missing values', () {
      const spec = GridSpec(step: 1, north: 1, west: 0, rows: 2, cols: 2);
      final data = Float32List.fromList([0, 10, 20, double.nan]);
      final field = GridField(spec: spec, times: const [0], data: {'v': data}, fetchedAt: DateTime(2026));
      expect(field.sample('v', 0, 1, 0), closeTo(0, 1e-6));
      expect(field.sample('v', 0, 1, 0.5), closeTo(5, 1e-6));
      expect(field.sample('v', 0, 0, 0), closeTo(20, 1e-6));
      expect(field.sample('v', 0, 5, 5).isNaN, isTrue);
    });

    test('accumulated frame sums over time', () {
      const spec = GridSpec(step: 1, north: 0, west: 0, rows: 2, cols: 2);
      final data = Float32List.fromList([1, 1, 1, 1, 2, 2, 2, double.nan]);
      final field = GridField(spec: spec, times: const [0, 3600], data: {'p': data}, fetchedAt: DateTime(2026));
      final f = field.frame('p', 1, accumulateFrom: true);
      expect(f[0], closeTo(3, 1e-6));
      expect(f[3], closeTo(1, 1e-6));
    });
  });

  group('Colour scale', () {
    test('interpolates between stops and clamps at the ends', () {
      final scale = ColorScale([(0, 0xFF000000), (10, 0xFFFFFFFF)]);
      final mid = scale.argbAt(5);
      expect((mid >> 16) & 0xFF, inInclusiveRange(126, 129));
      expect(scale.argbAt(-5) & 0xFFFFFF, 0x000000);
      expect(scale.argbAt(50) & 0xFFFFFF, 0xFFFFFF);
    });
  });

  group('PNG encoder', () {
    test('writes a valid PNG signature and IHDR', () {
      final rgba = Uint8List(4 * 3 * 2)..fillRange(0, 24, 200);
      final png = PngEncoder.encodeRgba(rgba, 3, 2);
      expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final bd = ByteData.sublistView(png);
      expect(String.fromCharCodes(png.sublist(12, 16)), 'IHDR');
      expect(bd.getUint32(16), 3);
      expect(bd.getUint32(20), 2);
    });
  });

  group('Units', () {
    const f = UnitFormatter(
      temp: TempUnit.fahrenheit,
      wind: WindUnit.knots,
      pressureUnit: PressureUnit.inhg,
      precip: PrecipUnit.mm,
      locale: 'en',
    );

    test('converts and round-trips', () {
      expect(f.convert(Quantity.temperature, 100), closeTo(212, 1e-9));
      expect(f.convert(Quantity.speed, 1.852), closeTo(1, 1e-9));
      expect(f.convert(Quantity.pressure, 1013.25), closeTo(29.92, 0.01));
      expect(f.toBase(Quantity.temperature, f.convert(Quantity.temperature, 23.4)), closeTo(23.4, 1e-9));
    });

    test('formats missing values as a dash', () {
      expect(f.format(Quantity.temperature, null), '–');
      expect(f.format(Quantity.temperature, double.nan), '–');
    });

    test('compass labels', () {
      expect(compassLabel(0), 'N');
      expect(compassLabel(90), 'E');
      expect(compassLabel(225), 'SW');
      expect(compassLabel(359), 'N');
    });
  });

  group('Moon', () {
    test('full moon 25 Jan 2024', () {
      final m = MoonPhase.at(DateTime.utc(2024, 1, 25, 17, 54));
      expect(m.illumination, greaterThan(0.98));
      expect(m.index, 4);
    });

    test('new moon 11 Jan 2024', () {
      final m = MoonPhase.at(DateTime.utc(2024, 1, 11, 11, 57));
      expect(m.illumination, lessThan(0.02));
      expect(m.index, 0);
    });
  });

  group('Models', () {
    test('settings JSON round trip', () {
      const place = Place(id: 'om:1185241', name: 'Dhaka', lat: 23.71, lon: 90.41, countryCode: 'BD');
      final s = const AppSettings().copyWith(
        tempUnit: TempUnit.fahrenheit,
        language: AppLanguage.bn,
        lastLayer: 'temperature',
        lastPlace: place,
        layerOpacity: {'temperature': 0.5},
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back.tempUnit, TempUnit.fahrenheit);
      expect(back.language, AppLanguage.bn);
      expect(back.lastLayer, 'temperature');
      expect(back.lastPlace?.name, 'Dhaka');
      expect(back.opacityFor('temperature'), 0.5);
    });

    test('Open-Meteo response parsing keeps nulls', () {
      final r = OmResponse.fromJson({
        'latitude': 23.7,
        'longitude': 90.4,
        'utc_offset_seconds': 21600,
        'timezone': 'Asia/Dhaka',
        'current': {'time': 1000, 'interval': 900, 'temperature_2m': 28.5},
        'hourly': {
          'time': [0, 3600, 7200],
          'temperature_2m': [27.0, null, 29.0],
        },
      }, fetchedAt: DateTime(2026));
      expect(r.utcOffsetSeconds, 21600);
      expect(r.current['temperature_2m'], 28.5);
      expect(r.current.containsKey('interval'), isFalse);
      expect(r.hourly.at('temperature_2m', 1), isNull);
      expect(r.hourly.indexFor(4000), 1);
    });
  });
}
