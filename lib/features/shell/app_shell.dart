import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../state/providers.dart';
import '../favorites/favorites_screen.dart';
import '../forecast/forecast_screen.dart';
import '../map/map_screen.dart';
import '../radar/radar_screen.dart';
import '../settings/settings_screen.dart';

/// Bottom navigation: Map, Forecast, Radar, Favourites, Settings.
///
/// The map stays alive (offstage) so returning to it is instant; the radar
/// map is created only while its tab is open to save memory.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final index = ref.watch(shellTabProvider);

    Widget page;
    switch (index) {
      case 1:
        page = const ForecastScreen();
      case 2:
        page = const RadarScreen();
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
        if (!didPop && index != 0) ref.read(shellTabProvider.notifier).go(0);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Offstage(
              offstage: index != 0,
              child: TickerMode(
                enabled: index == 0,
                child: MapScreen(active: index == 0),
              ),
            ),
            if (index != 0) Positioned.fill(child: page),
          ],
        ),
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
