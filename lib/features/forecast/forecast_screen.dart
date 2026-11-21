import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/models/place.dart';
import '../../state/providers.dart';
import '../alerts/alerts_screen.dart';
import '../common/widgets.dart';
import '../search/search_screen.dart';
import 'airgram.dart';
import 'meteogram.dart';
import 'model_comparison.dart';
import 'overview_tab.dart';

class ForecastScreen extends ConsumerWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final place = ref.watch(selectedPlaceProvider);
    if (place == null) return _EmptyForecast(strings: s);
    final favorites = ref.watch(favoritesProvider);
    final fav = favorites.value == null ? null : ref.read(favoritesProvider.notifier).find(place);
    final title = fav?.displayName ?? place.name;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                place.subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: s.searchPlaces,
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push<Place>(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            IconButton(
              tooltip: s.alerts,
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AlertsScreen(place: place)),
              ),
            ),
            IconButton(
              tooltip: fav == null ? s.addFavourite : s.removeFavourite,
              icon: Icon(fav == null ? Icons.star_border : Icons.star,
                  color: fav == null ? null : AppColors.amber),
              onPressed: () async {
                final n = ref.read(favoritesProvider.notifier);
                if (fav == null) {
                  await n.add(place);
                  if (context.mounted) showMessage(context, s.addedToFavourites);
                } else {
                  await n.remove(fav.id);
                }
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: s.overview),
              Tab(text: s.meteogram),
              Tab(text: s.airgram),
              Tab(text: s.models),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OverviewTab(place: place),
            MeteogramTab(place: place),
            AirgramTab(place: place),
            ModelComparisonTab(place: place),
          ],
        ),
      ),
    );
  }
}

class _EmptyForecast extends ConsumerWidget {
  const _EmptyForecast({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.navForecast)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.travel_explore, size: 56, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(s.noLocationSelected, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(s.chooseLocation,
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push<Place>(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
                icon: const Icon(Icons.search),
                label: Text(s.searchPlaces),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
