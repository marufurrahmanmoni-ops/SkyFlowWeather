import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/place.dart';
import '../../services/background_worker.dart';
import '../../services/notification_service.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';

/// Edits the alert thresholds of one favourite place.
class AlertRulesSheet extends ConsumerStatefulWidget {
  const AlertRulesSheet({super.key, required this.favorite});

  final FavoritePlace favorite;

  static Future<void> show(BuildContext context, FavoritePlace favorite) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AlertRulesSheet(favorite: favorite),
    );
  }

  @override
  ConsumerState<AlertRulesSheet> createState() => _AlertRulesSheetState();
}

class _AlertRulesSheetState extends ConsumerState<AlertRulesSheet> {
  late AlertRules _rules = widget.favorite.alertRules;
  bool _saving = false;

  Future<void> _save() async {
    final s = S.of(context);
    setState(() => _saving = true);
    if (_rules.enabled) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted && mounted) showMessage(context, s.notificationPermissionDenied);
    }
    await ref.read(favoritesProvider.notifier).updateRules(widget.favorite.id, _rules);
    final settings = ref.read(settingsProvider);
    final anyEnabled =
        (ref.read(favoritesProvider).value ?? const <FavoritePlace>[]).any((f) => f.alertRules.enabled);
    if (anyEnabled && !settings.backgroundAlerts) {
      ref.read(settingsProvider.notifier).update((x) => x.copyWith(backgroundAlerts: true));
      await BackgroundWorker.sync(ref.read(settingsProvider));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final units = ref.watch(unitsProvider);
    final theme = Theme.of(context);

    Widget threshold({
      required String title,
      required bool on,
      required ValueChanged<bool> onToggle,
      required Quantity quantity,
      required double value,
      required double min,
      required double max,
      required int divisions,
      required ValueChanged<double> onChanged,
    }) {
      final display = units.convert(quantity, value);
      final dMin = units.convert(quantity, min);
      final dMax = units.convert(quantity, max);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text(units.format(quantity, value)),
            value: on,
            onChanged: _rules.enabled ? onToggle : null,
          ),
          Slider(
            value: display.clamp(dMin, dMax).toDouble(),
            min: dMin,
            max: dMax,
            divisions: divisions,
            onChanged: (_rules.enabled && on) ? (v) => onChanged(units.toBase(quantity, v)) : null,
          ),
        ],
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('${s.alertSettings} · ${widget.favorite.displayName}', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.enableAlertsForPlace, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.backgroundChecksHint),
            value: _rules.enabled,
            onChanged: (v) => setState(() => _rules = _rules.copyWith(enabled: v)),
          ),
          const Divider(height: 24),
          Text(s.forecastAlerts, style: theme.textTheme.titleMedium),
          Text(s.forecastAlertDisclaimer,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          threshold(
            title: '${s.heavyRain} · ${s.rainHourThreshold}',
            on: _rules.heavyRain,
            onToggle: (v) => setState(() => _rules = _rules.copyWith(heavyRain: v)),
            quantity: Quantity.precipRate,
            value: _rules.rainPerHour,
            min: 2,
            max: 50,
            divisions: 48,
            onChanged: (v) => setState(() => _rules = _rules.copyWith(rainPerHour: v)),
          ),
          threshold(
            title: s.rainDayThreshold,
            on: _rules.heavyRain,
            onToggle: (v) => setState(() => _rules = _rules.copyWith(heavyRain: v)),
            quantity: Quantity.precipAmount,
            value: _rules.rainPerDay,
            min: 10,
            max: 300,
            divisions: 58,
            onChanged: (v) => setState(() => _rules = _rules.copyWith(rainPerDay: v)),
          ),
          threshold(
            title: '${s.thunderstorms} · ${s.capeThreshold}',
            on: _rules.thunderstorm,
            onToggle: (v) => setState(() => _rules = _rules.copyWith(thunderstorm: v)),
            quantity: Quantity.energy,
            value: _rules.cape,
            min: 500,
            max: 5000,
            divisions: 45,
            onChanged: (v) => setState(() => _rules = _rules.copyWith(cape: v)),
          ),
          threshold(
            title: '${s.strongWinds} · ${s.gustThreshold}',
            on: _rules.strongWind,
            onToggle: (v) => setState(() => _rules = _rules.copyWith(strongWind: v)),
            quantity: Quantity.speed,
            value: _rules.gust,
            min: 30,
            max: 200,
            divisions: 34,
            onChanged: (v) => setState(() => _rules = _rules.copyWith(gust: v)),
          ),
          threshold(
            title: '${s.extremeHeat} · ${s.heatThreshold}',
            on: _rules.heat,
            onToggle: (v) => setState(() => _rules = _rules.copyWith(heat: v)),
            quantity: Quantity.temperature,
            value: _rules.heatAt,
            min: 28,
            max: 50,
            divisions: 22,
            onChanged: (v) => setState(() => _rules = _rules.copyWith(heatAt: v)),
          ),
          threshold(
            title: '${s.extremeCold} · ${s.coldThreshold}',
            on: _rules.cold,
            onToggle: (v) => setState(() => _rules = _rules.copyWith(cold: v)),
            quantity: Quantity.temperature,
            value: _rules.coldAt,
            min: -30,
            max: 15,
            divisions: 45,
            onChanged: (v) => setState(() => _rules = _rules.copyWith(coldAt: v)),
          ),
          const Divider(height: 24),
          Text(s.officialSources, style: theme.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.tropicalCyclones),
            value: _rules.officialCyclone,
            onChanged: _rules.enabled
                ? (v) => setState(() => _rules = _rules.copyWith(officialCyclone: v))
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.floodWarnings),
            value: _rules.officialFlood,
            onChanged: _rules.enabled
                ? (v) => setState(() => _rules = _rules.copyWith(officialFlood: v))
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.severeWeather),
            value: _rules.officialSevere,
            onChanged: _rules.enabled
                ? (v) => setState(() => _rules = _rules.copyWith(officialSevere: v))
                : null,
          ),
          Text(s.warningSourcesNote, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(s.save),
          ),
        ],
      ),
    );
  }
}
