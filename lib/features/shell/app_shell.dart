import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../state/providers.dart';
import '../bangladesh/bd_rain_screen.dart';
import '../favorites/favorites_screen.dart';
import '../forecast/forecast_screen.dart';
import '../map/map_screen.dart';
import '../radar/radar_screen.dart';
import '../settings/settings_screen.dart';

/// Bottom navigation: Map, Forecast, Radar, Favourites, Settings.
///
/// Each map (main map and radar) is created only while its tab is open: a
/// hidden native map view can cover the other tabs on Android.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final index = ref.watch(shellTabProvider);
    final bdMode = ref.watch(radarBdModeProvider);
    ref.watch(homeWidgetSyncProvider);

    Widget page;
    switch (index) {
      case 1:
        page = const ForecastScreen();
      case 2:
        // Swapped in place (not pushed over the radar) so the radar's native
        // map view is gone while the web radars are shown.
        page = bdMode ? const BdRainScreen() : const RadarScreen();
      case 3:
        page = const FavoritesScreen();
      case 4:
        page = const SettingsScreen();
      default:
        page = const SizedBox.shrink();
    }

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (index == 2 && bdMode) {
          ref.read(radarBdModeProvider.notifier).set(false);
        } else if (index != 0) {
          ref.read(shellTabProvider.notifier).go(0);
        }
      },
      child: Scaffold(
        // The map is a native (platform) view. Keeping it alive offstage lets
        // Android draw it on top of the other tabs, which then look blank,
        // so it is only built while its tab is open.
        body: index == 0 ? const MapScreen(active: true) : page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => ref.read(shellTabProvider.notifier).go(i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              label: s.navMap,
            ),
            NavigationDestination(
              icon: const Icon(Icons.show_chart),
              selectedIcon: const Icon(Icons.stacked_line_chart),
              label: s.navForecast,
            ),
            NavigationDestination(
              icon: const Icon(Icons.radar),
              label: s.navRadar,
            ),
            NavigationDestination(
              icon: const Icon(Icons.star_border),
              selectedIcon: const Icon(Icons.star),
              label: s.navFavourites,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: s.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
