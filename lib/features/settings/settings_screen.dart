import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/settings.dart';
import '../../services/background_worker.dart';
import '../../services/notification_service.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';
import 'sources_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _checking = false;

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.accent, letterSpacing: 1),
        ),
      );

  Widget _segment<T>(String title, List<(T, String)> options, T value, ValueChanged<T> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<T>(
            showSelectedIcon: false,
            segments: [for (final o in options) ButtonSegment<T>(value: o.$1, label: Text(o.$2))],
            selected: {value},
            onSelectionChanged: (v) => onChanged(v.first),
          ),
        ],
      ),
    );
  }

  Future<void> _checkNow() async {
    final s = S.of(context);
    setState(() => _checking = true);
    try {
      await NotificationService.instance.requestPermission();
      final sent = await AlertChecker.run(
        db: ref.read(appDatabaseProvider),
        fetcher: ref.read(fetcherProvider),
      );
      if (mounted) showMessage(context, '${s.checkNow}: $sent');
    } catch (e) {
      if (mounted) showMessage(context, describeError(e, s));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _header(context, s.language),
          _segment<AppLanguage>(
            s.language,
            [(AppLanguage.system, s.systemDefault), (AppLanguage.en, s.english), (AppLanguage.bn, s.bangla)],
            settings.language,
            (v) => n.update((x) => x.copyWith(language: v)),
          ),
          _header(context, s.units),
          _segment<TempUnit>(
            s.temperatureUnit,
            const [(TempUnit.celsius, '°C'), (TempUnit.fahrenheit, '°F')],
            settings.tempUnit,
            (v) => n.update((x) => x.copyWith(tempUnit: v)),
          ),
          _segment<WindUnit>(
            s.windUnit,
            const [(WindUnit.kmh, 'km/h'), (WindUnit.mph, 'mph'), (WindUnit.knots, 'kn'), (WindUnit.ms, 'm/s')],
            settings.windUnit,
            (v) => n.update((x) => x.copyWith(windUnit: v)),
          ),
          _segment<PressureUnit>(
            s.pressureUnit,
            const [(PressureUnit.hpa, 'hPa'), (PressureUnit.inhg, 'inHg')],
            settings.pressureUnit,
            (v) => n.update((x) => x.copyWith(pressureUnit: v)),
          ),
          _segment<PrecipUnit>(
            s.precipitationUnit,
            const [(PrecipUnit.mm, 'mm'), (PrecipUnit.inch, 'in')],
            settings.precipUnit,
            (v) => n.update((x) => x.copyWith(precipUnit: v)),
          ),
          _segment<bool>(
            s.timeFormat,
            [(false, s.hour12), (true, s.hour24)],
            settings.use24h,
            (v) => n.update((x) => x.copyWith(use24h: v)),
          ),
          _header(context, s.mapAndAnimation),
          _segment<BaseMapStyle>(
            s.mapStyle,
            [
              (BaseMapStyle.dark, s.styleDark),
              (BaseMapStyle.fiord, s.styleFiord),
              (BaseMapStyle.positron, s.stylePositron),
              (BaseMapStyle.liberty, s.styleLiberty),
            ],
            settings.mapStyle,
            (v) => n.update((x) => x.copyWith(mapStyle: v)),
          ),
          _segment<DetailLevel>(
            s.mapDetail,
            [(DetailLevel.low, s.low), (DetailLevel.medium, s.medium), (DetailLevel.high, s.high)],
            settings.detail,
            (v) => n.update((x) => x.copyWith(detail: v)),
          ),
          SwitchListTile(
            title: Text(s.windAnimation),
            value: settings.particles,
            onChanged: (v) => n.update((x) => x.copyWith(particles: v)),
          ),
          SwitchListTile(
            title: Text(s.reduceMotion),
            value: settings.reduceMotion,
            onChanged: (v) => n.update((x) => x.copyWith(reduceMotion: v)),
          ),
          _header(context, s.alerts),
          SwitchListTile(
            title: Text(s.backgroundChecks),
            subtitle: Text(s.backgroundChecksHint),
            value: settings.backgroundAlerts,
            onChanged: (v) async {
              if (v) {
                final ok = await NotificationService.instance.requestPermission();
                if (!ok && context.mounted) showMessage(context, s.notificationPermissionDenied);
              }
              n.update((x) => x.copyWith(backgroundAlerts: v));
              await BackgroundWorker.sync(ref.read(settingsProvider));
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.campaign_outlined),
            title: Text(s.notifyBmdAll),
            subtitle: Text(s.notifyBmdAllHint),
            value: settings.bmdAllWarnings,
            onChanged: (v) async {
              if (v) {
                final ok = await NotificationService.instance.requestPermission();
                if (!ok && context.mounted) showMessage(context, s.notificationPermissionDenied);
              }
              n.update((x) => x.copyWith(bmdAllWarnings: v));
              await BackgroundWorker.sync(ref.read(settingsProvider));
            },
          ),
          ListTile(
            leading: _checking
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.notifications_active_outlined),
            title: Text(s.checkNow),
            subtitle: Text(s.warningSourcesNote, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: _checking ? null : _checkNow,
          ),
          _header(context, s.dataAndStorage),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: Text(s.clearCache),
            onTap: () async {
              await ref.read(appDatabaseProvider).clearCache();
              if (context.mounted) showMessage(context, s.cacheCleared);
            },
          ),
          ListTile(
            leading: const Icon(Icons.policy),
            title: Text(s.dataSources),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SourcesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: Text(s.providerConfig),
            subtitle: Text(s.providerConfigText),
            isThreeLine: true,
          ),
          _header(context, s.about),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                  child: const CircleAvatar(
                    radius: 34,
                    backgroundImage: AssetImage(AppInfo.developerPhoto),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppInfo.developer,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.developer,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppInfo.name),
            subtitle: Text('${s.version} ${AppInfo.version}\n${s.aboutText}'),
            isThreeLine: true,
          ),
          ListTile(
            leading: const Icon(Icons.format_list_bulleted),
            title: Text(s.openSourceLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
              applicationVersion: AppInfo.version,
              applicationLegalese: '© 2026 ${AppInfo.developer}',
            ),
          ),
        ],
      ),
    );
  }
}
