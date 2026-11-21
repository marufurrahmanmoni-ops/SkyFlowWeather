import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/models/place.dart';
import '../../data/models/warnings.dart';
import '../../services/alert_text.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';
import '../favorites/alert_rules_sheet.dart';

Color severityColor(WarningSeverity s) {
  switch (s) {
    case WarningSeverity.extreme:
      return const Color(0xFFE53935);
    case WarningSeverity.severe:
      return const Color(0xFFFF7043);
    case WarningSeverity.moderate:
      return const Color(0xFFFFB547);
    case WarningSeverity.minor:
      return const Color(0xFFFFE066);
    case WarningSeverity.unknown:
      return AppColors.textSecondary;
  }
}

/// Official warnings and forecast-threshold alerts for one place.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final units = ref.watch(unitsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final warnings = ref.watch(warningsProvider(place));
    final forecast = ref.watch(forecastProvider(place));
    ref.watch(favoritesProvider);
    final fav = ref.read(favoritesProvider.notifier).find(place);
    final rules = fav?.alertRules ?? const AlertRules(enabled: true);
    final engine = ref.watch(alertEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${s.alerts} · ${fav?.displayName ?? place.name}', overflow: TextOverflow.ellipsis),
        actions: [
          if (fav != null)
            IconButton(
              tooltip: s.alertSettings,
              icon: const Icon(Icons.tune),
              onPressed: () => AlertRulesSheet.show(context, fav),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(warningsProvider(place));
          try {
            await ref.read(warningsProvider(place).future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            SectionCard(
              title: s.officialWarnings,
              child: warnings.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(
                  error: e,
                  compact: true,
                  onRetry: () => ref.invalidate(warningsProvider(place)),
                ),
                data: (result) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (result.warnings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.success),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s.noOfficialWarnings)),
                          ],
                        ),
                      ),
                    for (final w in result.warnings) WarningCard(warning: w, fmt: fmt, strings: s),
                    if (result.failedSources.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${s.unavailable}: ${result.failedSources.join(', ')}',
                          style: const TextStyle(fontSize: 12, color: AppColors.amber),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(s.warningSourcesNote,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: s.forecastAlerts,
              child: forecast.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(error: e, compact: true),
                data: (bundle) {
                  final alerts = engine.evaluate(bundle.forecast, rules);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (alerts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(s.noForecastAlerts),
                        ),
                      for (final a in alerts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
                          title: Text(warningKindLabel(s, a.kind)),
                          subtitle: Text(forecastAlertText(s, units, fmt, a)),
                        ),
                      const SizedBox(height: 6),
                      Text(s.forecastAlertDisclaimer,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (fav == null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.star_border, color: AppColors.amber),
                  title: Text(s.addFavourite),
                  subtitle: Text(s.enableAlertsForPlace),
                  onTap: () async {
                    await ref.read(favoritesProvider.notifier).add(place);
                    final added = ref.read(favoritesProvider.notifier).find(place);
                    if (added != null && context.mounted) await AlertRulesSheet.show(context, added);
                  },
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: Icon(
                    fav.alertRules.enabled ? Icons.notifications_active : Icons.notifications_outlined,
                    color: fav.alertRules.enabled ? AppColors.accent : AppColors.textSecondary,
                  ),
                  title: Text(s.alertSettings),
                  subtitle: Text(s.enableAlertsForPlace),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => AlertRulesSheet.show(context, fav),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One official warning, tap to expand.
class WarningCard extends StatefulWidget {
  const WarningCard({super.key, required this.warning, required this.fmt, required this.strings});

  final OfficialWarning warning;
  final TimeFmt fmt;
  final AppStrings strings;

  @override
  State<WarningCard> createState() => _WarningCardStateImpl();
}

class _WarningCardStateImpl extends State<WarningCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.warning;
    final s = widget.strings;
    final color = severityColor(w.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    child: Text(w.source,
                        style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(warningKindLabel(s, w.kind),
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Text(w.headline, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                [
                  if (w.senderName != null) '${s.issuedBy}: ${w.senderName}',
                  if (w.sent != null) widget.fmt.full(w.sent!.toLocal()),
                  if (w.expires != null) '${s.expires}: ${widget.fmt.full(w.expires!.toLocal())}',
                ].join(' · '),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              if (_expanded) ...[
                if (w.areaDesc != null) ...[
                  const SizedBox(height: 8),
                  Text('${s.area}: ${w.areaDesc}', style: const TextStyle(fontSize: 12.5)),
                ],
                if (w.description != null) ...[
                  const SizedBox(height: 8),
                  Text(w.description!, style: const TextStyle(fontSize: 13)),
                ],
                if (w.instruction != null) ...[
                  const SizedBox(height: 8),
                  Text(s.instruction, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(w.instruction!, style: const TextStyle(fontSize: 13)),
                ],
                if (w.link != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => openExternal(context, w.link!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(s.openLink),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
