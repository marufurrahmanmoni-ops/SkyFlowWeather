import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/format.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/place.dart';
import '../../data/models/warnings.dart';
import '../../data/sources/rain_nowcast.dart';
import '../../services/home_widget_service.dart';
import '../../state/providers.dart';
import '../ai/ai_briefing_screen.dart';
import '../alarm/rain_alarm_screen.dart';
import '../alerts/alerts_screen.dart' show WarningCard, severityColor;
import '../common/widgets.dart';

/// Rain across Bangladesh, the official BMD and BAF radars, and BMD
/// warnings with active cyclones. Shown in place of the Radar tab's map.
class BdRainScreen extends ConsumerWidget {
  const BdRainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    void close() => ref.read(radarBdModeProvider.notifier).set(false);
    // System back is handled by the app shell (it closes this screen).
    return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: close),
            title: Text(s.bdRainRadar),
            actions: [
              IconButton(
                tooltip: s.isBengali ? 'AI আবহাওয়া বার্তা' : 'AI weather update',
                icon: const Text('🤖', style: TextStyle(fontSize: 20)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => AiBriefingScreen(
                    place: ref.read(selectedPlaceProvider) ??
                        placeFromCity(bdCities.first, s.isBengali),
                  ),
                )),
              ),
              IconButton(
                tooltip: s.isBengali ? 'বৃষ্টি অ্যালার্ম' : 'Rain alarm',
                icon: const Icon(Icons.alarm_add_outlined),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const RainAlarmScreen())),
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: const Icon(Icons.water_drop_outlined, size: 20), text: s.tabRainNow),
                Tab(icon: const Icon(Icons.radar, size: 20), text: s.tabBmdRadar),
                Tab(icon: const Icon(Icons.radar, size: 20), text: s.tabBafRadar),
                Tab(icon: const Icon(Icons.cyclone, size: 20), text: s.tabWarningsCyclones),
              ],
            ),
          ),
          body: const TabBarView(
            // Swiping would fight with panning inside the radar pages.
            physics: NeverScrollableScrollPhysics(),
            children: [
              _RainByArea(),
              _WebRadar(pages: [
                _RadarPage('Radar', 'https://bmd.gov.bd/web/en/radar'),
                _RadarPage('Full screen', 'https://radar.bmd.gov.bd/'),
              ]),
              _WebRadar(pages: [_RadarPage('BAF MET', 'https://met.baf.mil.bd/')]),
              _WarningsAndCyclones(),
            ],
          ),
        ),
    );
  }
}

// ----------------------------------------------------------- rain by area

class _RainByArea extends ConsumerWidget {
  const _RainByArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final async = ref.watch(bdRainProvider);
    final units = ref.watch(unitsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(bdRainProvider.future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          ErrorView(error: e, onRetry: () => ref.invalidate(bdRainProvider)),
        ]),
        data: (list) {
          final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final rows = <(BdCity, RainNowcast)>[
            for (var i = 0; i < bdCities.length && i < list.length; i++)
              if (list[i] != null) (bdCities[i], list[i]!),
          ];
          int rank(RainNowcast n) {
            if (n.rainingNow) return -1000 + n.intensity;
            return n.minutesUntilRain(nowSec) ?? (10000 - (n.probability ?? 0));
          }

          rows.sort((a, b) => rank(a.$2).compareTo(rank(b.$2)));
          final wetNow = rows.where((r) => r.$2.rainingNow).length;
          final wetSoon = rows.where((r) => !r.$2.rainingNow && r.$2.minutesUntilRain(nowSec) != null).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              GlassPanel(
                child: Row(
                  children: [
                    _Stat(value: '$wetNow', label: s.rainingNowLabel, color: AppColors.accent),
                    _Stat(value: '$wetSoon', label: s.next2hRain, color: AppColors.amber),
                    _Stat(
                        value: '${rows.length - wetNow - wetSoon}',
                        label: s.dry,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (final (city, n) in rows)
                _CityRainTile(city: city, n: n, nowSec: nowSec, strings: s, units: units),
              const SizedBox(height: 10),
              Text(s.nowcastModelNote,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      );
}

Color rainIntensityColor(int intensity) => switch (intensity) {
      0 => AppColors.textSecondary,
      1 => const Color(0xFF4CC3FF),
      2 => const Color(0xFF2F7BFF),
      _ => const Color(0xFFB146FF),
    };

String rainIntensityLabel(AppStrings s, int intensity) => switch (intensity) {
      0 => s.dry,
      1 => s.rainLight,
      2 => s.rainModerate,
      _ => s.rainHeavy,
    };

class _CityRainTile extends ConsumerWidget {
  const _CityRainTile({
    required this.city,
    required this.n,
    required this.nowSec,
    required this.strings,
    required this.units,
  });

  final BdCity city;
  final RainNowcast n;
  final int nowSec;
  final AppStrings strings;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    final color = rainIntensityColor(n.intensity);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(n.intensity == 0 ? Icons.wb_cloudy_outlined : Icons.water_drop, color: color),
        ),
        title: Text(city.name(s.isBengali), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (n.intensity > 0) rainIntensityLabel(s, n.intensity),
            HomeWidgetService.rainLine(s, n, nowSec),
          ].join(' · '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (n.probability != null)
              Text(units.format(Quantity.percent, n.probability!.toDouble()),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            if (n.next2hMm >= RainNowcast.wetThreshold)
              Text(s.mmNext2h(units.format(Quantity.precipAmount, n.next2hMm)),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        onTap: () {
          ref.read(selectedPlaceProvider.notifier).select(Place(
                id: 'bd:${city.nameEn.toLowerCase()}',
                name: city.name(s.isBengali),
                lat: city.lat,
                lon: city.lon,
                country: 'Bangladesh',
                countryCode: 'BD',
              ));
          ref.read(shellTabProvider.notifier).go(1);
        },
      ),
    );
  }
}

// ------------------------------------------------------------- web radar

class _RadarPage {
  const _RadarPage(this.label, this.url);
  final String label;
  final String url;
}

class _WebRadar extends StatefulWidget {
  const _WebRadar({required this.pages});
  final List<_RadarPage> pages;

  @override
  State<_WebRadar> createState() => _WebRadarState();
}

class _WebRadarState extends State<_WebRadar> {
  late final WebViewController _controller;
  int _page = 0;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.navy)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (_) {
          if (mounted) setState(() => _failed = false);
        },
        onWebResourceError: (e) {
          // Only a failed main page means nothing can be shown.
          if (e.isForMainFrame ?? true) {
            if (mounted) setState(() => _failed = true);
          }
        },
      ));
    _load();
  }

  void _load() => _controller.loadRequest(Uri.parse(widget.pages[_page].url));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final page = widget.pages[_page];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 0),
          child: Row(
            children: [
              if (widget.pages.length > 1)
                for (var i = 0; i < widget.pages.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(widget.pages[i].label),
                      selected: i == _page,
                      onSelected: (_) {
                        setState(() => _page = i);
                        _load();
                      },
                    ),
                  ),
              const Spacer(),
              IconButton(tooltip: s.reload, icon: const Icon(Icons.refresh), onPressed: _controller.reload),
              IconButton(
                tooltip: s.openInBrowser,
                icon: const Icon(Icons.open_in_new),
                onPressed: () => openExternal(context, page.url),
              ),
            ],
          ),
        ),
        if (_progress < 100 && !_failed) LinearProgressIndicator(value: _progress / 100),
        Expanded(
          child: _failed
              ? ListView(children: [
                  ErrorView(error: s.webLoadFailed, onRetry: _load),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => openExternal(context, page.url),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(s.openInBrowser),
                    ),
                  ),
                ])
              : WebViewWidget(controller: _controller),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(s.radarSiteNote,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

// ------------------------------------------------- warnings and cyclones

class _WarningsAndCyclones extends ConsumerWidget {
  const _WarningsAndCyclones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final fmt = ref.watch(timeFmtProvider);
    final warnings = ref.watch(bmdWarningsProvider);
    final storms = ref.watch(stormsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bmdWarningsProvider);
        ref.invalidate(stormsProvider);
        await ref.read(bmdWarningsProvider.future).catchError((Object _) => <OfficialWarning>[]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          SectionCard(
            title: s.bmdWarnings,
            child: warnings.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                  error: e, compact: true, onRetry: () => ref.invalidate(bmdWarningsProvider)),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(s.noBmdWarnings, style: const TextStyle(color: AppColors.textSecondary)),
                    )
                  : Column(children: [
                      for (final w in list) WarningCard(warning: w, fmt: fmt, strings: s),
                    ]),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: s.activeStorms,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.cycloneMapHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                ...storms.when<List<Widget>>(
                  loading: () => [const LinearProgressIndicator()],
                  error: (e, _) => [ErrorView(error: e, compact: true)],
                  data: (list) => list.isEmpty
                      ? [Text(s.noActiveStorms)]
                      : [
                          for (final e in list)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.cyclone, color: severityColor(e.severity)),
                              title: Text(e.name),
                              subtitle: Text([
                                '${s.alertLevel}: ${e.alertLevel}',
                                if (e.severityText != null) e.severityText!,
                                if (e.country != null) e.country!,
                              ].join(' · ')),
                            ),
                        ],
                ),
                const SizedBox(height: 4),
                FilledButton.tonalIcon(
                  onPressed: () => ref.read(radarBdModeProvider.notifier).set(false),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(s.showCyclonesOnMap),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
