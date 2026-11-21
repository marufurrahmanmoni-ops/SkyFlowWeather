import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/geo.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/models/place.dart';
import '../../data/models/settings.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';
import '../search/search_screen.dart';
import '../settings/sources_screen.dart';
import 'grid.dart';
import 'layer_catalog.dart';
import 'layer_sheet.dart';
import 'map_viewport.dart';
import 'map_widgets.dart';
import 'overlay_engine.dart';
import 'overlay_painter.dart';
import 'particles.dart';
import 'point_panel.dart';

/// Full-screen interactive weather map (main dashboard).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.active});

  /// False while another tab is shown; animation pauses.
  final bool active;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  MapLibreMapController? _controller;
  final ValueNotifier<MapViewport?> _viewport = ValueNotifier(null);
  late final OverlayEngine _engine;
  late final ParticleController _particles;
  // Read once in initState so the camera can still be saved from dispose().
  late final SettingsController _settingsNotifier;
  Size _size = Size.zero;
  GeoPoint? _selected;
  Place? _selectedPlace;
  GeoPoint? _myLocation;
  Timer? _idleTimer;
  Timer? _persistTimer;
  bool _locating = false;
  bool _showLegendInfo = false;

  @override
  void initState() {
    super.initState();
    _settingsNotifier = ref.read(settingsProvider.notifier);
    final settings = ref.read(settingsProvider);
    final layer = LayerCatalog.byId(settings.lastLayer);
    _engine = OverlayEngine(
      GridRepository(ref.read(gridSourceProvider)),
      layer: layer,
      opacity: settings.opacityFor(layer.id),
    );
    _engine.configure(
      layer: layer,
      opacity: settings.opacityFor(layer.id),
      needWind: _needsWind(settings, layer),
      targetCols: settings.detail.columns,
    );
    _particles = ParticleController(vsync: this, source: _engine, viewport: _viewport)
      ..density = settings.particleDensity;
    _viewport.value = MapViewport(
      lat: settings.cameraLat,
      lon: settings.cameraLon,
      zoom: settings.cameraZoom,
      size: Size.zero,
    );
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    // Save a camera move that is still waiting for its debounce, since the
    // map is disposed whenever the user switches to another tab.
    if (_persistTimer?.isActive ?? false) _persistCamera();
    _persistTimer?.cancel();
    try {
      // The map widget may already have disposed its controller.
      _controller?.removeListener(_onCameraChanged);
    } catch (_) {}
    _particles.dispose();
    _engine.dispose();
    _viewport.dispose();
    super.dispose();
  }

  bool _needsWind(AppSettings s, WeatherLayerDef layer) =>
      s.particles && !s.reduceMotion && (layer.particles || s.particlesAllLayers);

  void _syncParticles(AppSettings settings) {
    final layer = _engine.layer;
    _particles.density = settings.particleDensity;
    _particles.setEnabled(widget.active && _needsWind(settings, layer));
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncParticles(ref.read(settingsProvider));
      if (!widget.active) _engine.stop();
    }
  }

  // ------------------------------------------------------------ map events

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.addListener(_onCameraChanged);
    _engine.attach(controller);
  }

  Future<void> _onStyleLoaded() async {
    await _engine.onStyleLoaded();
    _scheduleReload(immediate: true);
  }

  void _onCameraChanged() {
    final cp = _controller?.cameraPosition;
    if (cp == null) return;
    _viewport.value = MapViewport(
      lat: cp.target.latitude,
      lon: cp.target.longitude,
      zoom: cp.zoom,
      size: _size,
    );
  }

  void _onCameraIdle() {
    _onCameraChanged();
    _scheduleReload();
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 2), _persistCamera);
  }

  void _persistCamera() {
    final vp = _viewport.value;
    if (vp == null) return;
    _settingsNotifier.update(
      (s) => s.copyWith(cameraLat: vp.lat, cameraLon: vp.lon, cameraZoom: vp.zoom),
    );
  }

  void _scheduleReload({bool immediate = false}) {
    _idleTimer?.cancel();
    _idleTimer = Timer(Duration(milliseconds: immediate ? 0 : 350), () {
      final vp = _viewport.value;
      if (vp == null || vp.size.isEmpty) return;
      unawaited(_engine.updateViewport(vp));
    });
  }

  void _onTap(math.Point<double> point, LatLng latLng) {
    setState(() {
      _selected = GeoPoint(latLng.latitude, latLng.longitude);
      _selectedPlace = null;
    });
  }

  Future<void> _onLongPress(math.Point<double> point, LatLng latLng) async {
    final s = S.of(context);
    final p = GeoPoint(latLng.latitude, latLng.longitude);
    setState(() {
      _selected = p;
      _selectedPlace = null;
    });
    final place = await _reverse(p) ?? Place.coordinates(p.lat, p.lon);
    await ref.read(favoritesProvider.notifier).add(place);
    if (mounted) showMessage(context, '${s.addedToFavourites}: ${place.name}');
  }

  Future<Place?> _reverse(GeoPoint p) async {
    try {
      return await ref
          .read(reverseGeocodingSourceProvider)
          .reverse(p.lat, p.lon, language: ref.read(languageProvider));
    } catch (_) {
      return null;
    }
  }

  Future<void> _flyTo(GeoPoint p, {double? zoom}) async {
    final c = _controller;
    if (c == null) return;
    final z = zoom ?? math.max(_viewport.value?.zoom ?? 6.0, 7.5);
    await c.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lon), z),
      duration: const Duration(milliseconds: 900),
    );
  }

  Future<void> _selectPlace(Place place) async {
    setState(() {
      _selected = place.point;
      _selectedPlace = place;
    });
    ref.read(selectedPlaceProvider.notifier).select(place);
    await _flyTo(place.point, zoom: 8);
  }

  Future<void> _openSearch() async {
    final place = await Navigator.of(context).push<Place>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (place != null && mounted) await _selectPlace(place);
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final p = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      setState(() {
        _myLocation = p;
        _selected = p;
        _selectedPlace = null;
      });
      await _flyTo(p, zoom: 9);
      final named = await _reverse(p);
      if (!mounted) return;
      ref.read(selectedPlaceProvider.notifier).select(
            named ?? Place.coordinates(p.lat, p.lon),
            remember: false,
          );
    } catch (e) {
      if (mounted) showMessage(context, describeError(e, S.of(context)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final units = ref.watch(unitsProvider);
    final layer = LayerCatalog.byId(settings.lastLayer);

    ref.listen<MapFocusRequest?>(mapFocusProvider, (prev, next) {
      if (next == null) return;
      setState(() {
        _selected = next.point;
        _selectedPlace = null;
      });
      unawaited(_flyTo(next.point, zoom: next.zoom));
    });

    // Apply settings after every rebuild (idempotent). Riverpod pauses
    // listeners while this tab is offstage, so a rebuild is the reliable hook.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _engine.configure(
        layer: layer,
        opacity: settings.opacityFor(layer.id),
        needWind: _needsWind(settings, layer),
        targetCols: settings.detail.columns,
      );
      _syncParticles(settings);
    });

    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size != _size) {
            _size = size;
            final vp = _viewport.value;
            if (vp != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _viewport.value = MapViewport(lat: vp.lat, lon: vp.lon, zoom: vp.zoom, size: size);
                _scheduleReload();
              });
            }
          }
          return Stack(
            children: [
              MapLibreMap(
                styleString: settings.mapStyle.url,
                initialCameraPosition: CameraPosition(
                  target: LatLng(settings.cameraLat, settings.cameraLon),
                  zoom: settings.cameraZoom,
                ),
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
                onCameraIdle: _onCameraIdle,
                onMapClick: _onTap,
                onMapLongClick: (p, l) => unawaited(_onLongPress(p, l)),
                trackCameraPosition: true,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                compassEnabled: false,
                attributionEnabled: false,
                logoEnabled: false,
                annotationOrder: const [],
                minMaxZoomPreference: const MinMaxZoomPreference(1.2, 14),
                foregroundLoadColor: AppColors.navy,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: WeatherOverlayPainter(
                        engine: _engine,
                        viewport: _viewport,
                        units: units,
                        showValues: settings.showValues,
                        showArrows: settings.showArrows,
                        showIsobars: settings.showIsobars,
                        selected: _selected,
                        myLocation: _myLocation,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: ParticlePainter(_particles)),
                  ),
                ),
              ),
              // ------------------------------------------------- top bar
              Positioned(
                left: 12,
                right: 12,
                top: padding.top + 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchBar(
                      hint: s.searchHint,
                      onTap: _openSearch,
                      onLocate: _locate,
                      locating: _locating,
                      onSettings: () => MapSettingsSheet.show(context),
                      strings: s,
                    ),
                    const SizedBox(height: 8),
                    _FavoritesStrip(onSelect: (p) => unawaited(_selectPlace(p))),
                    const SizedBox(height: 6),
                    _StatusChips(engine: _engine, strings: s),
                  ],
                ),
              ),
              // --------------------------------------------- right controls
              Positioned(
                right: 12,
                bottom: 12,
                child: _BottomRightControls(
                  strings: s,
                  layer: layer,
                  onLayers: () => LayerSheet.show(context),
                  onZoomIn: () => _controller?.animateCamera(CameraUpdate.zoomIn()),
                  onZoomOut: () => _controller?.animateCamera(CameraUpdate.zoomOut()),
                  onLocate: _locate,
                  bottomInset: _selected == null ? 162 : 340,
                ),
              ),
              // ------------------------------------------------ bottom panel
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: GlassPanel(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        alignment: Alignment.topCenter,
                        child: _selected == null
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: PointPanel(
                                  key: ValueKey(_selected),
                                  point: _selected!,
                                  knownPlace: _selectedPlace,
                                  engine: _engine,
                                  onClose: () => setState(() {
                                    _selected = null;
                                    _selectedPlace = null;
                                  }),
                                ),
                              ),
                      ),
                      if (_selected != null) const Divider(height: 12),
                      LegendBar(
                        layer: layer,
                        onTap: () => setState(() => _showLegendInfo = !_showLegendInfo),
                      ),
                      if (_showLegendInfo)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            s.layerDescription(layer.id),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      const SizedBox(height: 4),
                      TimelineBar(engine: _engine),
                      _AttributionRow(engine: _engine, strings: s),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.hint,
    required this.onTap,
    required this.onLocate,
    required this.onSettings,
    required this.locating,
    required this.strings,
  });

  final String hint;
  final VoidCallback onTap;
  final VoidCallback onLocate;
  final VoidCallback onSettings;
  final bool locating;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      radius: 28,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hint,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: strings.myLocation,
            onPressed: onLocate,
            icon: locating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: strings.mapSettings,
            onPressed: onSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}

class _FavoritesStrip extends ConsumerWidget {
  const _FavoritesStrip({required this.onSelect});

  final void Function(Place place) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider).value ?? const [];
    if (favs.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: favs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = favs[i];
          return ActionChip(
            avatar: const Icon(Icons.star, size: 16, color: AppColors.amber),
            label: Text(f.displayName),
            backgroundColor: AppColors.panel,
            onPressed: () => onSelect(f.place.copyWith(name: f.displayName)),
          );
        },
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.engine, required this.strings});

  final OverlayEngine engine;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        Widget? chip;
        if (engine.throttled) {
          chip = _chip(Icons.hourglass_bottom, strings.rateLimitPause, AppColors.amber);
        } else if (engine.loading) {
          chip = _chip(null, strings.loadingLayer, AppColors.accent);
        } else if (engine.error != null) {
          chip = GestureDetector(
            onTap: engine.retry,
            child: _chip(Icons.refresh, describeError(engine.error!, strings), AppColors.danger),
          );
        } else if (engine.field != null && !engine.hasVisibleData) {
          chip = _chip(Icons.info_outline, strings.layerNoDataHere, AppColors.textSecondary);
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: chip ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _chip(IconData? icon, String text, Color color) {
    return GlassPanel(
      key: ValueKey(text),
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _BottomRightControls extends StatelessWidget {
  const _BottomRightControls({
    required this.strings,
    required this.layer,
    required this.onLayers,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.bottomInset,
  });

  final AppStrings strings;
  final WeatherLayerDef layer;
  final VoidCallback onLayers;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(24),
            elevation: 6,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onLayers,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers, color: AppColors.navy, size: 20),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        strings.layerName(layer.id),
                        style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          MapIconButton(icon: Icons.add, tooltip: '+', onPressed: onZoomIn),
          const SizedBox(height: 8),
          MapIconButton(icon: Icons.remove, tooltip: '−', onPressed: onZoomOut),
        ],
      ),
    );
  }
}

class _AttributionRow extends ConsumerWidget {
  const _AttributionRow({required this.engine, required this.strings});

  final OverlayEngine engine;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(timeFmtProvider);
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final at = engine.fetchedAt;
        final updated = at == null ? '' : '${strings.lastUpdated(fmt.hm(at))} · ';
        return SourceLine(
          text: '$updated© OpenFreeMap © OpenMapTiles © OpenStreetMap · Open-Meteo',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SourcesScreen()),
          ),
        );
      },
    );
  }
}

/// Small helper for formatting the map timeline in other widgets.
String mapTimeLabel(TimeFmt fmt, int unix) => fmt.weekdayHm(TimeFmt.local(unix));
