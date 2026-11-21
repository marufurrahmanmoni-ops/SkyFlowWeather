import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/geo.dart';
import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../../data/models/place.dart';
import '../../state/providers.dart';
import '../common/widgets.dart';

/// Global place search (city, region, country or coordinates) with recent
/// searches and GPS. Pops with the chosen [Place].
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _searching = false;
  Object? _error;
  int _token = 0;
  bool _locating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () => _search(text));
    setState(() {});
  }

  Future<void> _search(String text) async {
    final q = text.trim();
    final token = ++_token;
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(geocodingSourceProvider)
          .search(q, language: ref.read(languageProvider));
      if (token != _token || !mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (token != _token || !mounted) return;
      setState(() {
        _error = e;
        _searching = false;
      });
    }
  }

  void _choose(Place place) {
    ref.read(selectedPlaceProvider.notifier).select(place);
    Navigator.of(context).pop(place);
  }

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final s = S.of(context);
    try {
      final p = await ref.read(locationServiceProvider).current();
      Place? named;
      try {
        named = await ref
            .read(reverseGeocodingSourceProvider)
            .reverse(p.lat, p.lon, language: ref.read(languageProvider));
      } catch (_) {}
      if (!mounted) return;
      final place = named ?? Place.coordinates(p.lat, p.lon, name: s.currentLocation);
      ref.read(selectedPlaceProvider.notifier).select(place, remember: false);
      Navigator.of(context).pop(place);
    } catch (e) {
      if (mounted) showMessage(context, describeError(e, s));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = _controller.text.trim();
    final coords = Geo.parseCoordinates(text);
    final recents = ref.watch(recentsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.searchHint,
            border: InputBorder.none,
            suffixIcon: text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: _locating
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: AppColors.accent),
            title: Text(s.useMyLocation),
            onTap: _locating ? null : _useLocation,
          ),
          if (coords != null)
            ListTile(
              leading: const Icon(Icons.place, color: AppColors.accent),
              title: Text(coords.format(digits: 4)),
              subtitle: Text(s.coordinates),
              onTap: () => _choose(Place.coordinates(coords.lat, coords.lon)),
            ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) ErrorView(error: _error!, compact: true, onRetry: () => _search(text)),
          if (text.length >= 2 && !_searching && _error == null && _results.isEmpty && coords == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(s.noResults, style: const TextStyle(color: AppColors.textSecondary))),
            ),
          for (final p in _results)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(p.name),
              subtitle: Text(p.subtitle),
              trailing: p.countryCode == null
                  ? null
                  : Text(p.countryCode!, style: const TextStyle(color: AppColors.textMuted)),
              onTap: () => _choose(p),
            ),
          if (text.length < 2) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.recentSearches,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(appDatabaseProvider).clearRecents();
                      ref.invalidate(recentsProvider);
                    },
                    child: Text(s.clearRecents),
                  ),
                ],
              ),
            ),
            ...recents.when<List<Widget>>(
              data: (list) => [
                for (final p in list)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(p.name),
                    subtitle: Text(p.subtitle),
                    onTap: () => _choose(p),
                  ),
              ],
              loading: () => const [SizedBox.shrink()],
              error: (_, _) => const [SizedBox.shrink()],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(s.coordinatesHint, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
          ],
        ],
      ),
    );
  }
}
