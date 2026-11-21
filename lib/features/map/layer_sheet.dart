import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/models/settings.dart';
import '../../state/providers.dart';
import 'layer_catalog.dart';

/// Bottom sheet for choosing a weather layer and its controls.
class LayerSheet extends ConsumerWidget {
  const LayerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LayerSheet(),
    );
  }

  String _category(AppStrings s, LayerCategory c) {
    switch (c) {
      case LayerCategory.wind:
        return s.groupWind;
      case LayerCategory.temperature:
        return s.groupTemperature;
      case LayerCategory.precipitation:
        return s.groupPrecipitation;
      case LayerCategory.atmosphere:
        return s.groupAtmosphere;
      case LayerCategory.airQuality:
        return s.groupAirQuality;
      case LayerCategory.ocean:
        return s.groupOcean;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final current = LayerCatalog.byId(settings.lastLayer);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(s.layers, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final cat in LayerCategory.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Text(
                _category(s, cat).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in LayerCatalog.all.where((l) => l.category == cat))
                  ChoiceChip(
                    avatar: Icon(l.icon, size: 18),
                    label: Text(s.layerName(l.id)),
                    selected: l.id == current.id,
                    showCheckmark: false,
                    onSelected: (_) => notifier.update((x) => x.copyWith(lastLayer: l.id)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text(s.layerControls, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(s.layerDescription(current.id),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.opacity, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(s.opacity),
              Expanded(
                child: Slider(
                  value: settings.opacityFor(current.id),
                  min: 0.2,
                  max: 1.0,
                  divisions: 16,
                  label: '${(settings.opacityFor(current.id) * 100).round()}%',
                  onChanged: (v) => notifier.update((x) => x.copyWith(
                        layerOpacity: {...x.layerOpacity, current.id: v},
                      )),
                ),
              ),
            ],
          ),
          if (current.particles || settings.particlesAllLayers)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.windAnimation),
              value: settings.particles,
              onChanged: (v) => notifier.update((x) => x.copyWith(particles: v)),
            ),
          if (!current.particles)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.windAnimationAllLayers),
              value: settings.particlesAllLayers,
              onChanged: (v) => notifier.update((x) => x.copyWith(particlesAllLayers: v)),
            ),
          if (current.arrowVariable != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.directionArrows),
              value: settings.showArrows,
              onChanged: (v) => notifier.update((x) => x.copyWith(showArrows: v)),
            ),
          if (current.isobars)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.isobars),
              value: settings.showIsobars,
              onChanged: (v) => notifier.update((x) => x.copyWith(showIsobars: v)),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.valuesOnMap),
            value: settings.showValues,
            onChanged: (v) => notifier.update((x) => x.copyWith(showValues: v)),
          ),
        ],
      ),
    );
  }
}

/// Base map, data detail and animation settings.
class MapSettingsSheet extends ConsumerWidget {
  const MapSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const MapSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.mapSettings, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(s.mapStyle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<BaseMapStyle>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: BaseMapStyle.dark, label: Text(s.styleDark)),
              ButtonSegment(value: BaseMapStyle.fiord, label: Text(s.styleFiord)),
              ButtonSegment(value: BaseMapStyle.positron, label: Text(s.stylePositron)),
              ButtonSegment(value: BaseMapStyle.liberty, label: Text(s.styleLiberty)),
            ],
            selected: {settings.mapStyle},
            onSelectionChanged: (v) => notifier.update((x) => x.copyWith(mapStyle: v.first)),
          ),
          const SizedBox(height: 18),
          Text(s.mapDetail, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<DetailLevel>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: DetailLevel.low, label: Text(s.low)),
              ButtonSegment(value: DetailLevel.medium, label: Text(s.medium)),
              ButtonSegment(value: DetailLevel.high, label: Text(s.high)),
            ],
            selected: {settings.detail},
            onSelectionChanged: (v) => notifier.update((x) => x.copyWith(detail: v.first)),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.windAnimation),
            value: settings.particles,
            onChanged: (v) => notifier.update((x) => x.copyWith(particles: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.windAnimationAllLayers),
            value: settings.particlesAllLayers,
            onChanged: (v) => notifier.update((x) => x.copyWith(particlesAllLayers: v)),
          ),
          Row(
            children: [
              Text(s.particleDensity),
              Expanded(
                child: Slider(
                  value: settings.particleDensity,
                  min: 0.3,
                  max: 2.0,
                  divisions: 17,
                  onChanged: settings.particles
                      ? (v) => notifier.update((x) => x.copyWith(particleDensity: v))
                      : null,
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.valuesOnMap),
            value: settings.showValues,
            onChanged: (v) => notifier.update((x) => x.copyWith(showValues: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.reduceMotion),
            value: settings.reduceMotion,
            onChanged: (v) => notifier.update((x) => x.copyWith(reduceMotion: v)),
          ),
        ],
      ),
    );
  }
}
