import 'package:material_ui/material_ui.dart';

import '../../core/l10n/localizations.dart';
import '../../core/theme.dart';
import '../common/widgets.dart';

class _Source {
  const _Source(this.name, this.use, this.licence, this.url);
  final String name;
  final String use;
  final String licence;
  final String url;
}

/// Data providers, what they are used for and their terms.
const _sources = [
  _Source('Open-Meteo', 'Forecasts, model comparison, pressure levels, geocoding, air quality (CAMS), marine',
      'CC BY 4.0 – free API for non-commercial use; commercial use needs an API subscription',
      'https://open-meteo.com/en/terms'),
  _Source('OpenFreeMap / OpenMapTiles / OpenStreetMap', 'Base map tiles and styles',
      'Free; © OpenMapTiles © OpenStreetMap contributors (ODbL)', 'https://openfreemap.org/'),
  _Source('OpenStreetMap Nominatim', 'Place names for tapped map points',
      'ODbL; max. 1 request per second (respected by the app)',
      'https://operations.osmfoundation.org/policies/nominatim/'),
  _Source('NASA GIBS', 'Satellite infrared (Himawari, GOES) and IMERG precipitation',
      'Free and open NASA data; attribution requested', 'https://www.earthdata.nasa.gov/data/tools/gibs'),
  _Source('EUMETSAT EUMETView', 'Meteosat infrared imagery and world cloud map',
      'EUMETSAT data policy – check terms before commercial use', 'https://view.eumetsat.int/'),
  _Source('Iowa Environmental Mesonet (NOAA NEXRAD)', 'US weather radar mosaic',
      'Public US government radar data served by Iowa State University', 'https://mesonet.agron.iastate.edu/'),
  _Source('Bangladesh Meteorological Department', 'Official CAP warnings for Bangladesh',
      'Public domain (CAP feed)', 'https://cap.bmd.gov.bd/'),
  _Source('US National Weather Service', 'Official US alerts', 'Public domain', 'https://www.weather.gov/'),
  _Source('GDACS (European Commission JRC, UN OCHA)', 'Active tropical cyclones and floods worldwide',
      'Free use with attribution', 'https://www.gdacs.org/'),
];

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.dataSources)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          for (final src in _sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text(src.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${src.use}\n${src.licence}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  isThreeLine: true,
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => openExternal(context, src.url),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(s.providerConfigText, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
