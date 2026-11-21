import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/models/settings.dart';
import '../../data/models/warnings.dart';
import '../../data/sources/imagery.dart';
import '../../state/providers.dart';
import '../alerts/alerts_screen.dart' show severityColor;
import '../common/widgets.dart';

/// Radar and satellite imagery with a playback timeline, coverage outline
/// and active tropical cyclone tracks (GDACS).
class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  MapLibreMapController? _controller;
  bool _styleReady = false;
  String? _belowLayer;
  late ImageryProduct _product;
  Duration _history = const Duration(hours: 3);
  List<DateTime> _frames = const [];
  int _frame = 0;
  int _generation = 0;
  final List<String> _layerIds = [];
  final List<String> _sourceIds = [];
  final List<String> _stormLayerIds = [];
  final List<String> _stormSourceIds = [];
  Timer? _playTimer;
  Timer? _refreshTimer;
  bool _autoRefresh = true;
  bool _showStorms = true;
  bool _building = false;
  DateTime? _builtAt;
  bool _stormsDrawn = false;
  bool _showStormList = false;

  static const _coverageSource = 'radar-coverage-src';
  static const _coverageLayer = 'radar-coverage-lyr';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final place = ref.read(selectedPlaceProvider);
    final lat = place?.lat ?? settings.cameraLat;
    final lon = place?.lon ?? settings.cameraLon;
    final nexrad = ImageryCatalog.byId('nexrad');
    _product = nexrad.coversPoint(lat, lon) ? nexrad : ImageryCatalog.satelliteFor(lat, lon);
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_autoRefresh && mounted) _rebuild();
    });
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  double get _opacity => _product.kind == ImageryKind.satelliteIr ? 0.82 : 0.9;

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    _layerIds.clear();
    _sourceIds.clear();
    _stormLayerIds.clear();
    _stormSourceIds.clear();
    _stormsDrawn = false;
    _belowLayer = await _firstSymbolLayer();
    await _rebuild();
    final storms = ref.read(stormsProvider).value;
    if (storms != null) await _drawStorms(storms);
  }

  Future<String?> _firstSymbolLayer() async {
    try {
      final raw = await _controller?.getStyle();
      if (raw == null) return null;
      final style = jsonDecode(raw);
      if (style is Map && style['layers'] is List) {
        for (final l in style['layers'] as List) {
          if (l is Map && l['type'] == 'symbol') return l['id'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _removeFrames() async {
    final c = _controller;
    if (c == null) return;
    for (final id in _layerIds) {
      try {
        await c.removeLayer(id);
      } catch (_) {}
    }
    for (final id in _sourceIds) {
      try {
        await c.removeSource(id);
      } catch (_) {}
    }
    _layerIds.clear();
    _sourceIds.clear();
  }

  Future<void> _rebuild() async {
    final c = _controller;
    if (c == null || !_styleReady || _building) return;
    _building = true;
    _stop();
    try {
      await _removeFrames();
      final gen = ++_generation;
      final frames = _product.frameTimes(DateTime.now().toUtc(), _history);
      for (var i = 0; i < frames.length; i++) {
        final sourceId = 'radar-src-$gen-$i';
        final layerId = 'radar-lyr-$gen-$i';
        await c.addSource(
          sourceId,
          RasterSourceProperties(
            tiles: [_product.urlFor(frames[i])],
            tileSize: _product.tileSize,
            maxzoom: _product.maxZoom,
            attribution: _product.attribution,
          ),
        );
        _sourceIds.add(sourceId);
        await c.addRasterLayer(
          sourceId,
          layerId,
          RasterLayerProperties(
            rasterOpacity: i == frames.length - 1 ? _opacity : 0.0,
            rasterFadeDuration: 0,
          ),
          belowLayerId: _belowLayer,
        );
        _layerIds.add(layerId);
      }
      await _drawCoverage();
      if (mounted) {
        setState(() {
          _frames = frames;
          _frame = frames.length - 1;
          _builtAt = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Radar layer setup failed: $e');
    } finally {
      _building = false;
    }
  }

  Future<void> _drawCoverage() async {
    final c = _controller;
    if (c == null) return;
    final features = [
      for (final poly in _product.coverage)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in poly) [p.lon, p.lat],
            ],
          },
        },
    ];
    final geojson = <String, dynamic>{'type': 'FeatureCollection', 'features': features};
    try {
      await c.setGeoJsonSource(_coverageSource, geojson);
    } catch (_) {
      try {
        await c.addGeoJsonSource(_coverageSource, geojson);
        await c.addLineLayer(
          _coverageSource,
          _coverageLayer,
          const LineLayerProperties(
            lineColor: '#4CC3FF',
            lineWidth: 1.5,
            lineOpacity: 0.8,
            lineDasharray: [3, 2],
          ),
          enableInteraction: false,
        );
      } catch (e) {
        debugPrint('Coverage layer failed: $e');
      }
    }
  }

  Future<void> _showFrame(int index) async {
    final c = _controller;
    if (c == null || index < 0 || index >= _layerIds.length || index == _frame) return;
    final previous = _frame;
    setState(() => _frame = index);
    try {
      await c.setLayerProperties(
        _layerIds[index],
        RasterLayerProperties(rasterOpacity: _opacity, rasterFadeDuration: 0),
      );
      if (previous >= 0 && previous < _layerIds.length) {
        await c.setLayerProperties(
          _layerIds[previous],
          const RasterLayerProperties(rasterOpacity: 0.0, rasterFadeDuration: 0),
        );
      }
    } catch (_) {}
  }

  void _togglePlay() {
    if (_playTimer != null) {
      _stop();
      setState(() {});
      return;
    }
    if (_frames.length < 2) return;
    _playTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
      final next = (_frame + 1) % _frames.length;
      _showFrame(next);
    });
    setState(() {});
  }

  void _stop() {
    _playTimer?.cancel();
    _playTimer = null;
  }

  void _selectProduct(ImageryProduct p) {
    if (p.id == _product.id) return;
    setState(() => _product = p);
    _rebuild();
  }

  // --------------------------------------------------------------- storms

  Future<void> _clearStorms() async {
    final c = _controller;
    if (c == null) return;
    for (final id in _stormLayerIds) {
      try {
        await c.removeLayer(id);
      } catch (_) {}
    }
    for (final id in _stormSourceIds) {
      try {
        await c.removeSource(id);
      } catch (_) {}
    }
    _stormLayerIds.clear();
    _stormSourceIds.clear();
    _stormsDrawn = false;
  }

  String _hex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  Future<void> _drawStorms(List<DisasterEvent> storms) async {
    final c = _controller;
    if (c == null || !_styleReady || _stormsDrawn || !_showStorms) return;
    _stormsDrawn = true;
    final gdacs = ref.read(gdacsSourceProvider);
    for (final e in storms) {
      final color = _hex(severityColor(e.severity));
      final sourceId = 'storm-src-${e.eventId}';
      Map<String, dynamic>? geometry;
      try {
        geometry = await gdacs.geometry(e);
      } catch (_) {
        geometry = null;
      }
      geometry ??= {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'Point',
              'coordinates': [e.lon, e.lat],
            },
          },
        ],
      };
      try {
        await c.addGeoJsonSource(sourceId, geometry);
        _stormSourceIds.add(sourceId);
        await c.addFillLayer(
          sourceId,
          '$sourceId-fill',
          FillLayerProperties(fillColor: color, fillOpacity: 0.12),
          filter: ['==', ['geometry-type'], 'Polygon'],
          enableInteraction: false,
        );
        _stormLayerIds.add('$sourceId-fill');
        await c.addLineLayer(
          sourceId,
          '$sourceId-line',
          LineLayerProperties(lineColor: color, lineWidth: 2.0, lineOpacity: 0.9),
          filter: ['==', ['geometry-type'], 'LineString'],
          enableInteraction: false,
        );
        _stormLayerIds.add('$sourceId-line');
        await c.addCircleLayer(
          sourceId,
          '$sourceId-pts',
          CircleLayerProperties(
            circleRadius: 3.5,
            circleColor: color,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 1.0,
          ),
          filter: ['==', ['geometry-type'], 'Point'],
          enableInteraction: false,
        );
        _stormLayerIds.add('$sourceId-pts');
      } catch (err) {
        debugPrint('Storm layer failed: $err');
      }
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final fmt = ref.watch(timeFmtProvider);
    final storms = ref.watch(stormsProvider);
    ref.listen<AsyncValue<List<DisasterEvent>>>(stormsProvider, (prev, next) {
      final list = next.value;
      if (list != null) _drawStorms(list);
    });
    final padding = MediaQuery.paddingOf(context);
    final place = ref.watch(selectedPlaceProvider);

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: settings.mapStyle.url,
            initialCameraPosition: CameraPosition(
              target: LatLng(place?.lat ?? settings.cameraLat, place?.lon ?? settings.cameraLon),
              zoom: (settings.cameraZoom - 1).clamp(2.0, 7.0).toDouble(),
            ),
            onMapCreated: (c) => _controller = c,
            onStyleLoadedCallback: () => _onStyleLoaded(),
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            compassEnabled: false,
            attributionEnabled: false,
            logoEnabled: false,
            annotationOrder: const [],
            minMaxZoomPreference: const MinMaxZoomPreference(1.5, 10),
            foregroundLoadColor: AppColors.navy,
          ),
          Positioned(
            top: padding.top + 10,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.flag_circle, size: 18, color: Color(0xFF2EBD6B)),
                      label: Text(s.bdShort),
                      onPressed: () => ref.read(radarBdModeProvider.notifier).set(true),
                    ),
                  ),
                  for (final p in ImageryCatalog.all)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          p.kind == ImageryKind.radar
                              ? Icons.radar
                              : (p.kind == ImageryKind.satellitePrecip ? Icons.water_drop : Icons.satellite_alt),
                          size: 16,
                        ),
                        label: Text(s.productName(p.id)),
                        selected: p.id == _product.id,
                        showCheckmark: false,
                        backgroundColor: AppColors.panel,
                        onSelected: (_) => _selectProduct(p),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: GlassPanel(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _timeline(s, fmt),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: [
                          ButtonSegment(value: 1, label: Text(s.lastHour)),
                          ButtonSegment(value: 3, label: Text(s.last3h)),
                          ButtonSegment(value: 6, label: Text(s.last6h)),
                        ],
                        selected: {_history.inHours},
                        onSelectionChanged: _product.animated
                            ? (v) {
                                setState(() => _history = Duration(hours: v.first));
                                _rebuild();
                              }
                            : null,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: s.autoRefresh,
                        onPressed: () => setState(() => _autoRefresh = !_autoRefresh),
                        icon: Icon(Icons.refresh,
                            color: _autoRefresh ? AppColors.accent : AppColors.textMuted),
                      ),
                      IconButton(
                        tooltip: s.storms,
                        onPressed: () async {
                          setState(() => _showStorms = !_showStorms);
                          if (_showStorms) {
                            final list = ref.read(stormsProvider).value;
                            if (list != null) await _drawStorms(list);
                          } else {
                            await _clearStorms();
                          }
                        },
                        icon: Icon(Icons.cyclone,
                            color: _showStorms ? AppColors.amber : AppColors.textMuted),
                      ),
                      IconButton(
                        tooltip: s.radarProductInfo,
                        onPressed: () => _showInfo(context, s),
                        icon: const Icon(Icons.info_outline),
                      ),
                    ],
                  ),
                  Text(
                    '${s.coverage}: ${s.productCoverage(_product.id)}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _stormSection(s, storms, fmt),
                  SourceLine(
                    text:
                        '${_builtAt == null ? '' : '${s.lastUpdated(fmt.hm(_builtAt!))} · '}${_product.attribution}',
                    onTap: () => openExternal(context, _product.infoUrl),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(AppStrings s, TimeFmt fmt) {
    if (_frames.isEmpty) {
      return const SizedBox(height: 40, child: Center(child: LinearProgressIndicator(minHeight: 2)));
    }
    final idx = _frame.clamp(0, _frames.length - 1).toInt();
    final t = _frames[idx].toLocal();
    final age = fmt.age(t, DateTime.now());
    return Row(
      children: [
        IconButton.filled(
          onPressed: _frames.length < 2 ? null : _togglePlay,
          tooltip: _playTimer != null ? s.pause : s.play,
          icon: Icon(_playTimer != null ? Icons.pause : Icons.play_arrow),
          style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.navy),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${fmt.weekdayHm(t)} · $age', style: const TextStyle(fontWeight: FontWeight.w700)),
              Slider(
                value: idx.toDouble(),
                min: 0,
                max: (_frames.length - 1).toDouble().clamp(1.0, 1000.0).toDouble(),
                divisions: _frames.length > 1 ? _frames.length - 1 : null,
                onChanged: _frames.length < 2
                    ? null
                    : (v) {
                        _stop();
                        _showFrame(v.round());
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stormSection(AppStrings s, AsyncValue<List<DisasterEvent>> storms, TimeFmt fmt) {
    final list = storms.value ?? const <DisasterEvent>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _showStormList = !_showStormList),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.cyclone, size: 16, color: AppColors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    storms.isLoading
                        ? s.loading
                        : (list.isEmpty ? s.noActiveStorms : '${s.activeStorms}: ${list.length}'),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                if (list.isNotEmpty) Icon(_showStormList ? Icons.expand_less : Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
        if (_showStormList)
          for (final e in list)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cyclone, color: severityColor(e.severity)),
              title: Text(e.name),
              subtitle: Text(
                [
                  '${s.alertLevel}: ${e.alertLevel}',
                  if (e.severityText != null) e.severityText!,
                  if (e.country != null) e.country!,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: e.reportUrl == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => openExternal(context, e.reportUrl!),
                    ),
              onTap: () => _controller?.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(e.lat, e.lon), 5),
              ),
            ),
      ],
    );
  }

  void _showInfo(BuildContext context, AppStrings s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.productName(_product.id), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(s.productCoverage(_product.id)),
            const SizedBox(height: 10),
            Text(s.precipTypeNote, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(s.frameMissingNote, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => openExternal(context, _product.infoUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(_product.attribution),
            ),
          ],
        ),
      ),
    );
  }
}
