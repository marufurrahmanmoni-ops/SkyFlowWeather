import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/forecast.dart';
import '../../data/models/place.dart';
import '../../state/providers.dart';
import '../alerts/alerts_screen.dart';
import '../common/weather_icon.dart';
import '../common/widgets.dart';
import '../search/search_screen.dart';
import 'alert_rules_sheet.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, FavoritePlace f) async {
    final s = S.of(context);
    final controller = TextEditingController(text: f.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.renameFavourite),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: s.name),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: Text(s.save)),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    final trimmed = name.trim();
    await ref.read(favoritesProvider.notifier).rename(f.id, trimmed.isEmpty ? null : trimmed);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, FavoritePlace f) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(f.displayName),
        content: Text(s.removeFavouriteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok == true) await ref.read(favoritesProvider.notifier).remove(f.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final favorites = ref.watch(favoritesProvider);
    final current = ref.watch(favoritesCurrentProvider);
    final units = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.favourites),
        actions: [
          IconButton(
            tooltip: s.searchPlaces,
            icon: const Icon(Icons.add),
            onPressed: () async {
              final place = await Navigator.of(context).push<Place>(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              if (place != null) await ref.read(favoritesProvider.notifier).add(place);
            },
          ),
        ],
      ),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(favoritesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_border, size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: 14),
                    Text(s.noFavourites, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(s.noFavouritesHint,
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }
          final conditions = current.value ?? const <OmResponse?>[];
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(favoritesCurrentProvider);
              try {
                await ref.read(favoritesCurrentProvider.future);
              } catch (_) {}
            },
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: list.length,
              onReorderItem: (oldIndex, newIndex) {
                final ids = [for (final f in list) f.id];
                final id = ids.removeAt(oldIndex);
                ids.insert(newIndex, id);
                ref.read(favoritesProvider.notifier).reorder(ids);
              },
              itemBuilder: (context, i) {
                final f = list[i];
                final c = i < conditions.length ? conditions[i] : null;
                final code = c?.current['weather_code']?.round();
                final isDay = (c?.current['is_day'] ?? 1) >= 1;
                return Padding(
                  key: ValueKey(f.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        ref.read(selectedPlaceProvider.notifier).select(f.place, remember: false);
                        ref.read(shellTabProvider.notifier).go(1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                        child: Row(
                          children: [
                            if (c == null)
                              const SizedBox(width: 40, height: 40)
                            else
                              WeatherIcon(code: code, isDay: isDay, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(f.displayName,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      if (f.alertRules.enabled) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.notifications_active, size: 15, color: AppColors.accent),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    code == null ? f.place.subtitle : '${s.weatherCode(code)} · ${f.place.subtitle}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(units.format(Quantity.temperature, c?.current['temperature_2m']),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300)),
                                Text(
                                  '↑${units.format(Quantity.temperature, c?.daily.at('temperature_2m_max', 0))} ↓${units.format(Quantity.temperature, c?.daily.at('temperature_2m_min', 0))}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'map':
                                    {
                                      // Switch tab first: the map's listeners pause while offstage.
                                      final focus = ref.read(mapFocusProvider.notifier);
                                      ref.read(shellTabProvider.notifier).go(0);
                                      WidgetsBinding.instance.addPostFrameCallback(
                                        (_) => focus.focus(f.place.point, zoom: 8),
                                      );
                                    }
                                  case 'alerts':
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => AlertsScreen(place: f.place),
                                    ));
                                  case 'rules':
                                    AlertRulesSheet.show(context, f);
                                  case 'rename':
                                    _rename(context, ref, f);
                                  case 'remove':
                                    _remove(context, ref, f);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'map', child: Text(s.navMap)),
                                PopupMenuItem(value: 'alerts', child: Text(s.alerts)),
                                PopupMenuItem(value: 'rules', child: Text(s.alertSettings)),
                                PopupMenuItem(value: 'rename', child: Text(s.rename)),
                                PopupMenuItem(value: 'remove', child: Text(s.delete)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
