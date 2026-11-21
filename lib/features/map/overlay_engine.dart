import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../data/net/http.dart';
import 'frame_renderer.dart';
import 'grid.dart';
import 'layer_catalog.dart';
import 'map_viewport.dart';
import 'particles.dart';

/// Connects the weather grid data with the MapLibre map:
/// loads data for the visible area, renders coloured frames in a background
/// isolate, pushes them into a geo-referenced image source and drives the
/// timeline animation.
class OverlayEngine extends ChangeNotifier implements WindFieldProvider {
  OverlayEngine(this._repo, {required WeatherLayerDef layer, required double opacity})
      : _layer = layer,
        _opacity = opacity;

  final GridRepository _repo;

  static const String sourceId = 'skyflow-weather-src';
  static const String layerId = 'skyflow-weather-layer';

  MapLibreMapController? _controller;
  bool _styleReady = false;
  bool _sourceAdded = false;
  String? _belowLayerId;

  WeatherLayerDef _layer;
  double _opacity;
  bool _needWind = false;
  int _targetCols = 8;

  GridSpec? _spec;
  GridField? _field;
  GridField? _wind;
  MapViewport? _lastViewport;

  List<int> _frameTimes = const [];
  int _frameIndex = 0;
  int _accumFrom = 0;

  bool _loading = false;
  bool _throttled = false;
  ApiException? _error;
  int _loadToken = 0;

  final Map<int, Uint8List> _png = {};
  int _renderToken = 0;
  Timer? _playTimer;
  bool _pushing = false;
  int? _pendingFrame;

  // ---------------------------------------------------------------- getters

  WeatherLayerDef get layer => _layer;
  double get opacity => _opacity;
  GridField? get field => _field;
  List<int> get frameTimes => _frameTimes;
  int get frameIndex => _frameIndex;
  bool get loading => _loading;
  bool get throttled => _throttled;
  ApiException? get error => _error;
  bool get playing => _playTimer != null;
  DateTime? get fetchedAt => _field?.fetchedAt;

  int get fieldTimeIndex {
    final f = _field;
    if (f == null || _frameTimes.isEmpty) return 0;
    return f.timeIndex(_frameTimes[_frameIndex.clamp(0, _frameTimes.length - 1).toInt()]);
  }

  int? get selectedTime =>
      _frameTimes.isEmpty ? null : _frameTimes[_frameIndex.clamp(0, _frameTimes.length - 1).toInt()];

  @override
  GridField? get windField => _wind;

  @override
  int get windTimeIndex {
    final w = _wind;
    final t = selectedTime;
    if (w == null || t == null) return 0;
    return w.timeIndex(t);
  }

  bool get hasVisibleData => _field?.hasAnyValue(_layer.variable) ?? false;

  /// Value of the active layer at a point for the selected time.
  double valueAt(double lat, double lon) {
    final f = _field;
    if (f == null || _frameTimes.isEmpty) return double.nan;
    if (_layer.accumulate) {
      var sum = 0.0;
      var any = false;
      for (var t = _accumFrom; t <= fieldTimeIndex; t++) {
        final v = f.sample(_layer.variable, t, lat, lon);
        if (!v.isNaN) {
          sum += v;
          any = true;
        }
      }
      return any ? sum : double.nan;
    }
    return f.sample(_layer.variable, fieldTimeIndex, lat, lon);
  }

  // ---------------------------------------------------------------- map wiring

  void attach(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> onStyleLoaded() async {
    _styleReady = true;
    _sourceAdded = false;
    _belowLayerId = await _firstSymbolLayer();
    if (_field != null) await _showFrame(_frameIndex);
  }

  Future<String?> _firstSymbolLayer() async {
    final c = _controller;
    if (c == null) return null;
    try {
      final styleJson = await c.getStyle();
      if (styleJson == null) return null;
      final style = jsonDecode(styleJson);
      if (style is! Map || style['layers'] is! List) return null;
      for (final l in style['layers'] as List) {
        if (l is Map && l['type'] == 'symbol' && l['id'] is String) return l['id'] as String;
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------- controls

  void configure({
    required WeatherLayerDef layer,
    required double opacity,
    required bool needWind,
    required int targetCols,
  }) {
    final groupChanged = layer.group.id != _layer.group.id;
    final windChanged = needWind != _needWind;
    final colsChanged = targetCols != _targetCols;
    final layerChanged = layer.id != _layer.id;
    if (!groupChanged && !windChanged && !colsChanged && !layerChanged && opacity == _opacity) {
      return;
    }
    _layer = layer;
    _needWind = needWind;
    _targetCols = targetCols;
    if (opacity != _opacity) {
      _opacity = opacity;
      unawaited(_applyOpacity());
    }
    if (groupChanged || windChanged || colsChanged) {
      _spec = null;
      final vp = _lastViewport;
      if (vp != null) unawaited(updateViewport(vp));
    } else if (layerChanged) {
      _png.clear();
      _renderToken++;
      unawaited(_showFrame(_frameIndex));
    }
    notifyListeners();
  }

  Future<void> updateViewport(MapViewport vp, {bool force = false}) async {
    _lastViewport = vp;
    if (vp.size.isEmpty) return;
    final spec = GridSpec.forView(vp.bounds.expand(0.2), _targetCols);
    final current = _spec;
    if (!force && current != null && current.covers(spec) && _field != null) return;
    await _load(GridSpec.forView(vp.bounds.expand(0.35), _targetCols));
  }

  Future<void> retry() async {
    final vp = _lastViewport;
    if (vp != null) await updateViewport(vp, force: true);
  }

  Future<void> _load(GridSpec spec) async {
    final token = ++_loadToken;
    _loading = true;
    _error = null;
    notifyListeners();
    bool cancelled() => token != _loadToken;
    void throttle(bool waiting) {
      if (_throttled != waiting) {
        _throttled = waiting;
        notifyListeners();
      }
    }

    try {
      final main = await _repo.load(spec, _layer.group.request,
          onThrottle: throttle, isCancelled: cancelled);
      GridField? wind;
      if (_layer.group.id == LayerGroups.wind.id) {
        wind = main;
      } else if (_needWind) {
        wind = await _repo.load(spec, LayerGroups.wind.request,
            onThrottle: throttle, isCancelled: cancelled);
      }
      if (cancelled()) return;
      final previousTime = selectedTime;
      _spec = spec;
      _field = main;
      _wind = wind;
      _png.clear();
      _renderToken++;
      _rebuildTimeline(previousTime);
      _error = null;
      unawaited(_showFrame(_frameIndex));
    } on ApiException catch (e) {
      if (!cancelled() && e.message != 'cancelled') _error = e;
    } catch (e) {
      if (!cancelled()) _error = toApiException(e);
    } finally {
      if (!cancelled()) {
        _loading = false;
        _throttled = false;
        notifyListeners();
      }
    }
  }

  void _rebuildTimeline(int? keepTime) {
    final f = _field;
    if (f == null || f.times.isEmpty) {
      _frameTimes = const [];
      _frameIndex = 0;
      return;
    }
    final nowHour = (DateTime.now().millisecondsSinceEpoch ~/ 3600000) * 3600;
    final times = f.times.where((t) => t >= nowHour).take(73).toList();
    _frameTimes = times.isEmpty ? [f.times.last] : times;
    _accumFrom = f.timeIndex(_frameTimes.first);
    if (keepTime != null) {
      final i = _frameTimes.indexOf(keepTime);
      _frameIndex = i >= 0 ? i : 0;
    } else {
      _frameIndex = 0;
    }
  }

  void setFrame(int index) {
    if (_frameTimes.isEmpty) return;
    final i = index.clamp(0, _frameTimes.length - 1).toInt();
    if (i == _frameIndex) return;
    _frameIndex = i;
    notifyListeners();
    unawaited(_showFrame(i));
  }

  void togglePlay() {
    if (_playTimer != null) {
      _playTimer!.cancel();
      _playTimer = null;
      notifyListeners();
      return;
    }
    if (_frameTimes.length < 2) return;
    unawaited(_prerenderAll());
    _playTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      final next = (_frameIndex + 1) % _frameTimes.length;
      // Wait for a frame that is not rendered yet instead of skipping.
      if (!_png.containsKey(next) && next != 0) return;
      _frameIndex = next;
      notifyListeners();
      unawaited(_showFrame(next));
    });
    notifyListeners();
  }

  void stop() {
    _playTimer?.cancel();
    _playTimer = null;
  }

  // ---------------------------------------------------------------- rendering

  FrameJob? _jobFor(List<int> frameIndexes) {
    final f = _field;
    final spec = _spec;
    if (f == null || spec == null || f.times.isEmpty) return null;
    final frames = <Float32List>[];
    for (final fi in frameIndexes) {
      final t = f.timeIndex(_frameTimes[fi]);
      frames.add(f.frame(_layer.variable, t, accumulateFrom: _layer.accumulate, from: _accumFrom));
    }
    final (w, h) = imageSizeFor(spec);
    return FrameJob(
      frames: frames,
      rows: spec.rows,
      cols: spec.cols,
      north: spec.north,
      west: spec.west,
      step: spec.step,
      stopValues: _layer.scale.stopValues,
      stopColors: _layer.scale.stopColors,
      transparentBelow: _layer.scale.transparentBelow ?? double.negativeInfinity,
      width: w,
      height: h,
    );
  }

  Future<void> _showFrame(int index) async {
    if (_frameTimes.isEmpty) return;
    var png = _png[index];
    if (png == null) {
      final token = _renderToken;
      final job = _jobFor([index]);
      if (job == null) return;
      try {
        final result = await renderFramesInBackground(job);
        if (token != _renderToken) return;
        png = result.first;
        _png[index] = png;
      } catch (e) {
        debugPrint('Frame render failed: $e');
        return;
      }
    }
    if (index != _frameIndex) return;
    await _push(png);
  }

  Future<void> _prerenderAll() async {
    final token = _renderToken;
    final missing = [
      for (var i = 0; i < _frameTimes.length; i++)
        if (!_png.containsKey(i)) i,
    ];
    for (var b = 0; b < missing.length; b += 8) {
      final chunk = missing.sublist(b, (b + 8).clamp(0, missing.length).toInt());
      final job = _jobFor(chunk);
      if (job == null) return;
      try {
        final result = await renderFramesInBackground(job);
        if (token != _renderToken) return;
        for (var k = 0; k < chunk.length; k++) {
          _png[chunk[k]] = result[k];
        }
      } catch (_) {
        return;
      }
    }
  }

  Future<void> _push(Uint8List png) async {
    final c = _controller;
    final spec = _spec;
    if (c == null || !_styleReady || spec == null) return;
    if (_pushing) {
      _pendingFrame = _frameIndex;
      return;
    }
    _pushing = true;
    try {
      final quad = LatLngQuad(
        topLeft: LatLng(spec.north, spec.west),
        topRight: LatLng(spec.north, _safeLon(spec.east)),
        bottomRight: LatLng(spec.south, _safeLon(spec.east)),
        bottomLeft: LatLng(spec.south, spec.west),
      );
      if (!_sourceAdded) {
        try {
          await c.addImageSource(sourceId, png, quad);
        } catch (_) {
          // Source may survive from a previous attach.
          await c.updateImageSource(sourceId, png, quad);
        }
        try {
          final below = _belowLayerId;
          if (below != null) {
            await c.addImageLayerBelow(layerId, sourceId, below);
          } else {
            await c.addImageLayer(layerId, sourceId);
          }
        } catch (_) {
          // Layer already exists.
        }
        _sourceAdded = true;
        await _applyOpacity();
      } else {
        await c.updateImageSource(sourceId, png, quad);
      }
    } catch (e) {
      debugPrint('Image source update failed: $e');
      _sourceAdded = false;
    } finally {
      _pushing = false;
    }
    final pending = _pendingFrame;
    _pendingFrame = null;
    if (pending != null && pending == _frameIndex) {
      final next = _png[pending];
      if (next != null) await _push(next);
    }
  }

  static double _safeLon(double lon) => lon >= 180 ? 179.9999 : lon;

  Future<void> _applyOpacity() async {
    final c = _controller;
    if (c == null || !_sourceAdded) return;
    try {
      await c.setLayerProperties(
        layerId,
        RasterLayerProperties(
          rasterOpacity: _opacity,
          rasterFadeDuration: 0,
          rasterResampling: 'linear',
        ),
      );
    } catch (e) {
      debugPrint('Opacity update failed: $e');
    }
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _playTimer?.cancel();
    _loadToken++;
    _renderToken++;
    super.dispose();
  }
}
