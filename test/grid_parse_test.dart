import 'package:flutter_test/flutter_test.dart';
import 'package:skyflow_weather/data/sources/open_meteo.dart';

void main() {
  group('parseGridResponse', () {
    test('parses a multi-location response in point order', () {
      const body = '['
          '{"hourly":{"time":[3600,7200],"temperature_2m":[10.5,null]}},'
          '{"hourly":{"time":[3600,7200],"temperature_2m":[1,2]}}'
          ']';
      final r = parseGridResponse(body, const ['temperature_2m'], 2);
      expect(r.error, isNull);
      expect(r.series, hasLength(2));
      expect(r.series[0]!.startTime, 3600);
      expect(r.series[0]!.data['temperature_2m']![0], closeTo(10.5, 1e-6));
      expect(r.series[0]!.data['temperature_2m']![1].isNaN, isTrue);
      expect(r.series[1]!.data['temperature_2m']![1], 2);
    });

    test('a single-location object counts as one point; missing points are null', () {
      const body = '{"hourly":{"time":[0],"wind_speed_10m":[5]}}';
      final r = parseGridResponse(body, const ['wind_speed_10m'], 2);
      expect(r.series[0], isNotNull);
      expect(r.series[1], isNull);
    });

    test('reports API errors and invalid JSON', () {
      expect(parseGridResponse('{"error":true,"reason":"bad"}', const ['x'], 1).error, 'bad');
      expect(parseGridResponse('not json', const ['x'], 1).error, isNotNull);
    });
  });
}
