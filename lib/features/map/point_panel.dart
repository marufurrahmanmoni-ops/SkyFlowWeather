import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/place.dart';
import '../../state/providers.dart';
import '../common/weather_icon.dart';
import '../common/widgets.dart';
import 'layer_catalog.dart';
import 'map_widgets.dart';
import 'overlay_engine.dart';

/// Compact forecast for the tapped map point.
class PointPanel extends ConsumerWidget {
  const PointPanel({
    super.key,
    required this.point,
    required this.engine,
    required this.onClose,
    this.knownPlace,
  });

  final GeoPoint point;
  final OverlayEngine engine;
  final VoidCallback onClose;
  final Place? knownPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final units = ref.watch(unitsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final reverse = knownPlace == null ? ref.watch(reverseGeocodeProvider(point)) : null;
    final named = knownPlace ?? reverse?.value;
    final place = named ??
        Place.coordinates(point.lat, point.lon);
    final coordPlace = Place.coordinates(point.lat, point.lon);
    final forecast = ref.watch(forecastProvider(knownPlace ?? coordPlace));
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.value?.any((f) =>
            (f.place.lat - point.lat).abs() < 0.005 && (f.place.lon - point.lon).abs() < 0.005) ??
        false;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final layer = engine.layer;
        final layerValue = engine.valueAt(point.lat, point.lon);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        named == null ? s.selectedPoint : '${place.subtitle} · ${point.format(digits: 2)}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: isFavorite ? s.removeFavourite : s.addFavourite,
                  icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite ? AppColors.amber : null),
                  onPressed: () async {
                    final notifier = ref.read(favoritesProvider.notifier);
                    if (isFavorite) {
                      final f = notifier.find(place);
                      if (f != null) await notifier.remove(f.id);
                    } else {
                      await notifier.add(place);
                      if (context.mounted) showMessage(context, s.addedToFavourites);
                    }
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: s.close,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 6),
            forecast.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (e, _) => ErrorView(
                error: e,
                compact: true,
                onRetry: () => ref.invalidate(forecastProvider(knownPlace ?? coordPlace)),
              ),
              data: (bundle) {
                final f = bundle.forecast;
                final code = f.current['weather_code']?.round();
                final isDay = (f.current['is_day'] ?? 1) >= 1;
                final h = f.hourly;
                final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                final start = h.indexFor(nowSec);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        WeatherIcon(code: code, isDay: isDay, size: 44),
                        const SizedBox(width: 10),
                        Text(
                          units.format(Quantity.temperature, f.current['temperature_2m']),
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                code == null ? '' : s.weatherCode(code),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${s.wind} ${units.format(Quantity.speed, f.current['wind_speed_10m'])} · ${s.humidity} ${units.format(Quantity.percent, f.current['relative_humidity_2m'])}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        _LayerValueChip(layer: layer, value: layerValueLabel(units, layer, layerValue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 66,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var k = 1; k <= 6; k++)
                            if (start + k * 3 < h.length)
                              Builder(builder: (context) {
                                final i = start + k * 3;
                                final t = TimeFmt.atLocation(h.time[i], f.utcOffsetSeconds);
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(fmt.hour(t),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    WeatherIcon(
                                      code: h.at('weather_code', i)?.round(),
                                      isDay: (h.at('is_day', i) ?? 1) >= 1,
                                      size: 24,
                                    ),
                                    Text(units.format(Quantity.temperature, h.at('temperature_2m', i)),
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  ],
                                );
                              }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        ref.read(selectedPlaceProvider.notifier).select(knownPlace ?? named ?? coordPlace);
                        ref.read(shellTabProvider.notifier).go(1);
                      },
                      icon: const Icon(Icons.show_chart),
                      label: Text(s.openForecast),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _LayerValueChip extends StatelessWidget {
  const _LayerValueChip({required this.layer, required this.value});

  final WeatherLayerDef layer;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(layer.icon, size: 15, color: AppColors.accent),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
