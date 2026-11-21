import 'package:flutter_test/flutter_test.dart';
import 'package:skyflow_weather/core/mini_xml.dart';
import 'package:skyflow_weather/data/models/forecast.dart';
import 'package:skyflow_weather/data/models/place.dart';
import 'package:skyflow_weather/data/models/warnings.dart';
import 'package:skyflow_weather/data/sources/warnings_sources.dart';
import 'package:skyflow_weather/services/alert_engine.dart';

const _cap = '''<?xml version="1.0" encoding="UTF-8"?>
<cap:alert xmlns:cap="urn:oasis:names:tc:emergency:cap:1.2">
  <cap:identifier>urn:oid:2.49.0.0.50.0.2026.11.19.1</cap:identifier>
  <cap:sender>bmd@example.org</cap:sender>
  <cap:sent>2026-11-19T04:34:00+06:00</cap:sent>
  <cap:status>Actual</cap:status>
  <cap:msgType>Alert</cap:msgType>
  <cap:info>
    <cap:language>en-US</cap:language>
    <cap:event>Severe Cyclonic Storm</cap:event>
    <cap:severity>Severe</cap:severity>
    <cap:expires>2099-11-21T04:34:00+06:00</cap:expires>
    <cap:senderName>Bangladesh Meteorological Department</cap:senderName>
    <cap:headline>Maritime ports advised to hoist signal &amp; stay alert</cap:headline>
    <cap:description><![CDATA[Deep sea fishing boats should stay in shelter.]]></cap:description>
    <cap:area>
      <cap:areaDesc>Coastal districts</cap:areaDesc>
      <cap:polygon>21.0,89.0 23.0,89.0 23.0,92.0 21.0,92.0 21.0,89.0</cap:polygon>
    </cap:area>
  </cap:info>
</cap:alert>''';

void main() {
  test('parses a CAP alert with namespaces, entities and CDATA', () {
    final w = parseCapAlert(_cap, source: 'BMD', language: 'en').single;
    expect(w.headline, 'Maritime ports advised to hoist signal & stay alert');
    expect(w.kind, WarningKind.cyclone);
    expect(w.severity, WarningSeverity.severe);
    expect(w.description, 'Deep sea fishing boats should stay in shelter.');
    expect(w.polygons.single.length, 5);
    expect(w.covers(22.6, 89.9), isTrue); // Pirojpur area
    expect(w.covers(24.9, 91.9), isFalse); // Sylhet
    expect(w.isActive(DateTime.utc(2026, 11, 20)), isTrue);
  });

  test('ignores cancelled and test messages', () {
    expect(parseCapAlert(_cap.replaceAll('Actual', 'Test'), source: 'BMD', language: 'en'), isEmpty);
    expect(parseCapAlert(_cap.replaceAll('>Alert<', '>Cancel<'), source: 'BMD', language: 'en'), isEmpty);
  });

  test('parses RFC 822 dates', () {
    final d = MiniXml.parseRfc822('Thu, 19 Nov 2026 04:34:00 +0600')!;
    expect(d, DateTime.utc(2026, 11, 18, 22, 34));
  });

  test('forecast alerts find the first hour above a threshold', () {
    final now = DateTime.utc(2026, 11, 21, 0);
    final t0 = now.millisecondsSinceEpoch ~/ 1000;
    final forecast = OmResponse(
      latitude: 0,
      longitude: 0,
      elevation: null,
      timezone: 'GMT',
      timezoneAbbreviation: 'GMT',
      utcOffsetSeconds: 0,
      current: const {},
      currentTime: null,
      hourly: TimeSeries([for (var i = 0; i < 6; i++) t0 + i * 3600], {
        'precipitation': [0, 2, 14, 22, 3, 0],
        'wind_gusts_10m': [20, 30, 40, 50, 45, 30],
        'temperature_2m': [30, 31, 32, 33, 32, 31],
        'cape': [0, 0, 0, 0, 0, 0],
        'weather_code': [3, 61, 65, 95, 61, 3],
      }),
      daily: TimeSeries.empty(),
      fetchedAt: now,
      stale: false,
    );
    final alerts = const AlertEngine().evaluate(forecast, const AlertRules(enabled: true), now: now);
    final rain = alerts.firstWhere((a) => a.kind == WarningKind.rain);
    expect(rain.time, t0 + 2 * 3600);
    expect(rain.value, 22);
    expect(alerts.any((a) => a.kind == WarningKind.thunderstorm), isTrue);
    expect(alerts.any((a) => a.kind == WarningKind.wind), isFalse); // 50 < 60 km/h
    expect(alerts.any((a) => a.kind == WarningKind.heat), isFalse); // 33 < 38 °C
  });
}
