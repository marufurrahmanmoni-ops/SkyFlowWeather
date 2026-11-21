/// Hand-written English and Bengali strings.
///
/// Lookups fall back to English, then to the key, so a missing translation
/// never crashes the UI.
class AppStrings {
  AppStrings(String languageCode) : languageCode = languageCode == 'bn' ? 'bn' : 'en';

  final String languageCode;

  bool get isBengali => languageCode == 'bn';

  String t(String key) {
    final table = isBengali ? _bn : _en;
    return table[key] ?? _en[key] ?? key;
  }

  String _f(String key, Map<String, String> args) {
    var s = t(key);
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  // ---------------------------------------------------------------- general
  String get appName => t('appName');
  String get navMap => t('navMap');
  String get navForecast => t('navForecast');
  String get navRadar => t('navRadar');
  String get navFavourites => t('navFavourites');
  String get navSettings => t('navSettings');
  String get retry => t('retry');
  String get cancel => t('cancel');
  String get save => t('save');
  String get delete => t('delete');
  String get rename => t('rename');
  String get close => t('close');
  String get ok => t('ok');
  String get add => t('add');
  String get loading => t('loading');
  String get now => t('now');
  String get today => t('today');
  String get tomorrow => t('tomorrow');
  String get noData => t('noData');
  String get unavailable => t('unavailable');
  String get source => t('source');
  String get dataSources => t('dataSources');
  String get openLink => t('openLink');
  String get learnMore => t('learnMore');
  String lastUpdated(String time) => _f('lastUpdated', {'time': time});
  String showingCached(String time) => _f('showingCached', {'time': time});
  String get offline => t('offline');

  // ---------------------------------------------------------------- errors
  String get errNetwork => t('errNetwork');
  String get errTimeout => t('errTimeout');
  String get errRateLimit => t('errRateLimit');
  String get errServer => t('errServer');
  String get errBadRequest => t('errBadRequest');
  String get errUnknown => t('errUnknown');
  String get errLocationDisabled => t('errLocationDisabled');
  String get errLocationDenied => t('errLocationDenied');
  String get errLocationDeniedForever => t('errLocationDeniedForever');
  String get errLocationTimeout => t('errLocationTimeout');
  String get openSettings => t('openSettings');

  // ---------------------------------------------------------------- map
  String get searchHint => t('searchHint');
  String get layers => t('layers');
  String get legend => t('legend');
  String get opacity => t('opacity');
  String get play => t('play');
  String get pause => t('pause');
  String get mapSettings => t('mapSettings');
  String get mapStyle => t('mapStyle');
  String get valuesOnMap => t('valuesOnMap');
  String get windAnimation => t('windAnimation');
  String get windAnimationAllLayers => t('windAnimationAllLayers');
  String get particleDensity => t('particleDensity');
  String get isobars => t('isobars');
  String get directionArrows => t('directionArrows');
  String get mapDetail => t('mapDetail');
  String get low => t('low');
  String get medium => t('medium');
  String get high => t('high');
  String get openForecast => t('openForecast');
  String get addFavourite => t('addFavourite');
  String get removeFavourite => t('removeFavourite');
  String get addedToFavourites => t('addedToFavourites');
  String get loadingLayer => t('loadingLayer');
  String get layerNoDataHere => t('layerNoDataHere');
  String get myLocation => t('myLocation');
  String get selectedPoint => t('selectedPoint');
  String get layerControls => t('layerControls');
  String get groupWind => t('groupWind');
  String get groupTemperature => t('groupTemperature');
  String get groupPrecipitation => t('groupPrecipitation');
  String get groupAtmosphere => t('groupAtmosphere');
  String get groupAirQuality => t('groupAirQuality');
  String get groupOcean => t('groupOcean');
  String get accumulationFrom => t('accumulationFrom');
  String get rateLimitPause => t('rateLimitPause');
  String get zoomInForData => t('zoomInForData');
  String get longPressHint => t('longPressHint');

  String layerName(String id) => t('layer_$id');
  String layerDescription(String id) => t('layerDesc_$id');

  // ---------------------------------------------------------------- forecast
  String get feelsLike => t('feelsLike');
  String get wind => t('wind');
  String get gusts => t('gusts');
  String get humidity => t('humidity');
  String get pressure => t('pressure');
  String get rainProbability => t('rainProbability');
  String get precipitation => t('precipitation');
  String get cloudCover => t('cloudCover');
  String get visibility => t('visibility');
  String get dewPoint => t('dewPoint');
  String get uvIndex => t('uvIndex');
  String get sunrise => t('sunrise');
  String get sunset => t('sunset');
  String get daylight => t('daylight');
  String get sunAndMoon => t('sunAndMoon');
  String get moonrise => t('moonrise');
  String get moonset => t('moonset');
  String get moonPhase => t('moonPhase');
  String get illumination => t('illumination');
  String get next24h => t('next24h');
  String get hourlyForecast => t('hourlyForecast');
  String get dailyForecast => t('dailyForecast');
  String get extendedForecast => t('extendedForecast');
  String get overview => t('overview');
  String get meteogram => t('meteogram');
  String get airgram => t('airgram');
  String get models => t('models');
  String get details => t('details');
  String get airQuality => t('airQuality');
  String get marine => t('marine');
  String get waveHeight => t('waveHeight');
  String get wavePeriod => t('wavePeriod');
  String get waveDirection => t('waveDirection');
  String get seaTemperature => t('seaTemperature');
  String get swell => t('swell');
  String get snowfall => t('snowfall');
  String get cape => t('cape');
  String get noLocationSelected => t('noLocationSelected');
  String get chooseLocation => t('chooseLocation');
  String get useMyLocation => t('useMyLocation');
  String get elevation => t('elevation');
  String get timezone => t('timezone');
  String get tapChartHint => t('tapChartHint');
  String get temperature => t('temperature');
  String get windDirection => t('windDirection');
  String get noMoonrise => t('noMoonrise');
  String get noMoonset => t('noMoonset');
  String moonPhaseName(int index) => t('moon$index');
  String weatherCode(int code) => t('wc$code');
  String aqiCategory(int index) => t('aqi$index');
  String uvCategory(int index) => t('uv$index');

  // ---------------------------------------------------------------- models
  String get compareModels => t('compareModels');
  String get modelUnavailable => t('modelUnavailable');
  String dataUntil(String time) => _f('dataUntil', {'time': time});
  String get spread => t('spread');
  String get modelNote => t('modelNote');
  String get dailyMax => t('dailyMax');
  String get dailyMin => t('dailyMin');
  String get dailyTotal => t('dailyTotal');
  String get dailyMaxWind => t('dailyMaxWind');
  String get dailyMean => t('dailyMean');
  String get model => t('model');
  String get availableModels => t('availableModels');

  // ---------------------------------------------------------------- airgram
  String get altitude => t('altitude');
  String get freezingLevel => t('freezingLevel');
  String get airgramNote => t('airgramNote');
  String get cloudLayers => t('cloudLayers');


  // ------------------------------------------------- Bangladesh rain & radar
  String get bdRainRadar => t('bdRainRadar');
  String get bdShort => t('bdShort');
  String get tabRainNow => t('tabRainNow');
  String get tabBmdRadar => t('tabBmdRadar');
  String get tabBafRadar => t('tabBafRadar');
  String get tabWarningsCyclones => t('tabWarningsCyclones');
  String get rainingNowLabel => t('rainingNowLabel');
  String get rainContinuing => t('rainContinuing');
  String get noRainNext2h => t('noRainNext2h');
  String get next2hRain => t('next2hRain');
  String get nowcastModelNote => t('nowcastModelNote');
  String get openInBrowser => t('openInBrowser');
  String get reload => t('reload');
  String get webLoadFailed => t('webLoadFailed');
  String get bmdWarnings => t('bmdWarnings');
  String get noBmdWarnings => t('noBmdWarnings');
  String get cycloneMapHint => t('cycloneMapHint');
  String get showCyclonesOnMap => t('showCyclonesOnMap');
  String get notifyBmdAll => t('notifyBmdAll');
  String get notifyBmdAllHint => t('notifyBmdAllHint');
  String get radarSiteNote => t('radarSiteNote');
  String get rainLight => t('rainLight');
  String get rainModerate => t('rainModerate');
  String get rainHeavy => t('rainHeavy');
  String get dry => t('dry');
  String rainStartsIn(int minutes) => _f('rainStartsIn', {'m': _n(minutes)});
  String rainStopsIn(int minutes) => _f('rainStopsIn', {'m': _n(minutes)});
  String widgetUpdated(String time) => _f('widgetUpdated', {'t': time});
  String mmNext2h(String mm) => _f('mmNext2h', {'mm': mm});
  String _n(int v) {
    if (!isBengali) return '$v';
    const d = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return '$v'.split('').map((c) => int.tryParse(c) == null ? c : d[int.parse(c)]).join();
  }

  // ---------------------------------------------------------------- radar
  String get radarAndSatellite => t('radarAndSatellite');
  String get product => t('product');
  String get coverage => t('coverage');
  String get storms => t('storms');
  String get activeStorms => t('activeStorms');
  String get noActiveStorms => t('noActiveStorms');
  String get autoRefresh => t('autoRefresh');
  String get history => t('history');
  String get lastHour => t('lastHour');
  String get last3h => t('last3h');
  String get last6h => t('last6h');
  String get precipTypeNote => t('precipTypeNote');
  String get frameMissingNote => t('frameMissingNote');
  String get stormTrack => t('stormTrack');
  String get alertLevel => t('alertLevel');
  String get maxWind => t('maxWind');
  String get radarProductInfo => t('radarProductInfo');
  String get coverageGlobal => t('coverageGlobal');
  String productName(String id) => t('product_$id');
  String productCoverage(String id) => t('productCoverage_$id');

  // ---------------------------------------------------------------- favourites
  String get favourites => t('favourites');
  String get noFavourites => t('noFavourites');
  String get noFavouritesHint => t('noFavouritesHint');
  String get renameFavourite => t('renameFavourite');
  String get removeFavouriteConfirm => t('removeFavouriteConfirm');
  String get recentSearches => t('recentSearches');
  String get clearRecents => t('clearRecents');
  String get name => t('name');

  // ---------------------------------------------------------------- alerts
  String get alerts => t('alerts');
  String get alertSettings => t('alertSettings');
  String get officialWarnings => t('officialWarnings');
  String get forecastAlerts => t('forecastAlerts');
  String get forecastAlertDisclaimer => t('forecastAlertDisclaimer');
  String get noOfficialWarnings => t('noOfficialWarnings');
  String get noForecastAlerts => t('noForecastAlerts');
  String get warningSourcesNote => t('warningSourcesNote');
  String get heavyRain => t('heavyRain');
  String get thunderstorms => t('thunderstorms');
  String get strongWinds => t('strongWinds');
  String get extremeHeat => t('extremeHeat');
  String get extremeCold => t('extremeCold');
  String get floodWarnings => t('floodWarnings');
  String get tropicalCyclones => t('tropicalCyclones');
  String get severeWeather => t('severeWeather');
  String get enableAlertsForPlace => t('enableAlertsForPlace');
  String get backgroundChecks => t('backgroundChecks');
  String get backgroundChecksHint => t('backgroundChecksHint');
  String get notificationPermissionDenied => t('notificationPermissionDenied');
  String get expires => t('expires');
  String get issuedBy => t('issuedBy');
  String get area => t('area');
  String get checkNow => t('checkNow');
  String get severity => t('severity');
  String get instruction => t('instruction');
  String get rainHourThreshold => t('rainHourThreshold');
  String get rainDayThreshold => t('rainDayThreshold');
  String get gustThreshold => t('gustThreshold');
  String get heatThreshold => t('heatThreshold');
  String get coldThreshold => t('coldThreshold');
  String get capeThreshold => t('capeThreshold');
  String get officialSources => t('officialSources');
  String alertExpected(String what, String when) =>
      _f('alertExpected', {'what': what, 'when': when});
  String forecastAlertBody(String place, String detail) =>
      _f('forecastAlertBody', {'place': place, 'detail': detail});
  String get notificationChannelName => t('notificationChannelName');
  String get notificationChannelDesc => t('notificationChannelDesc');

  // ---------------------------------------------------------------- search
  String get searchPlaces => t('searchPlaces');
  String get coordinatesHint => t('coordinatesHint');
  String get currentLocation => t('currentLocation');
  String get noResults => t('noResults');
  String get typeToSearch => t('typeToSearch');
  String get coordinates => t('coordinates');

  // ---------------------------------------------------------------- settings
  String get language => t('language');
  String get systemDefault => t('systemDefault');
  String get english => t('english');
  String get bangla => t('bangla');
  String get units => t('units');
  String get temperatureUnit => t('temperatureUnit');
  String get windUnit => t('windUnit');
  String get pressureUnit => t('pressureUnit');
  String get precipitationUnit => t('precipitationUnit');
  String get timeFormat => t('timeFormat');
  String get hour12 => t('hour12');
  String get hour24 => t('hour24');
  String get mapAndAnimation => t('mapAndAnimation');
  String get styleDark => t('styleDark');
  String get styleFiord => t('styleFiord');
  String get stylePositron => t('stylePositron');
  String get styleLiberty => t('styleLiberty');
  String get dataAndStorage => t('dataAndStorage');
  String get clearCache => t('clearCache');
  String get cacheCleared => t('cacheCleared');
  String get about => t('about');
  String get version => t('version');
  String get aboutText => t('aboutText');
  String get developer => t('developer');
  String get openSourceLicenses => t('openSourceLicenses');
  String get providerConfig => t('providerConfig');
  String get providerConfigText => t('providerConfigText');
  String get attributionText => t('attributionText');
  String get reduceMotion => t('reduceMotion');
}

const Map<String, String> _en = {
  'bdRainRadar': 'Bangladesh rain & radar',
  'bdShort': 'Bangladesh',
  'tabRainNow': 'Rain by area',
  'tabBmdRadar': 'BMD radar',
  'tabBafRadar': 'BAF radar',
  'tabWarningsCyclones': 'Warnings & cyclones',
  'rainingNowLabel': 'Raining now',
  'rainContinuing': 'Rain continuing',
  'noRainNext2h': 'No rain in the next 2 h',
  'next2hRain': 'Rain in the next 2 hours',
  'nowcastModelNote': '15-minute values come from weather models (Open-Meteo), not radar. Check the BMD/BAF radar for what is falling right now.',
  'openInBrowser': 'Open in browser',
  'reload': 'Reload',
  'webLoadFailed': 'The page could not be loaded. Check your connection, or the site may be down.',
  'bmdWarnings': 'BMD warnings',
  'noBmdWarnings': 'No active BMD warnings',
  'cycloneMapHint': 'Active tropical cyclones (GDACS). Tracks are drawn on the Radar map.',
  'showCyclonesOnMap': 'Show on radar map',
  'notifyBmdAll': 'All BMD warnings',
  'notifyBmdAllHint': 'Notify every new Bangladesh Meteorological Department warning (checked about every 30 min)',
  'radarSiteNote': 'Official site shown inside the app. Its content and availability are controlled by the site owner.',
  'rainLight': 'Light',
  'rainModerate': 'Moderate',
  'rainHeavy': 'Heavy',
  'dry': 'Dry',
  'rainStartsIn': 'Rain in ~{m} min',
  'rainStopsIn': 'Stops in ~{m} min',
  'widgetUpdated': 'Updated {t}',
  'mmNext2h': '{mm} in 2 h',
  'appName': 'SkyFlow Weather',
  'navMap': 'Map',
  'navForecast': 'Forecast',
  'navRadar': 'Radar',
  'navFavourites': 'Favourites',
  'navSettings': 'Settings',
  'retry': 'Retry',
  'cancel': 'Cancel',
  'save': 'Save',
  'delete': 'Delete',
  'rename': 'Rename',
  'close': 'Close',
  'ok': 'OK',
  'add': 'Add',
  'loading': 'Loading…',
  'now': 'Now',
  'today': 'Today',
  'tomorrow': 'Tomorrow',
  'noData': 'No data',
  'unavailable': 'Unavailable',
  'source': 'Source',
  'dataSources': 'Data sources & attribution',
  'openLink': 'Open link',
  'learnMore': 'Learn more',
  'lastUpdated': 'Updated {time}',
  'showingCached': 'Offline – showing data from {time}',
  'offline': 'Offline',
  'errNetwork': 'No internet connection. Check your network and try again.',
  'errTimeout': 'The weather service took too long to respond.',
  'errRateLimit':
      'The free data service rate limit was reached. Please wait a minute and try again.',
  'errServer': 'The weather service is temporarily unavailable.',
  'errBadRequest': 'The data service rejected the request.',
  'errUnknown': 'Something went wrong.',
  'errLocationDisabled': 'Location services are turned off.',
  'errLocationDenied': 'Location permission was denied.',
  'errLocationDeniedForever':
      'Location permission is permanently denied. Enable it in system settings.',
  'errLocationTimeout': 'Could not get your location in time.',
  'openSettings': 'Open settings',
  'searchHint': 'Search city, place or coordinates',
  'layers': 'Layers',
  'legend': 'Legend',
  'opacity': 'Opacity',
  'play': 'Play',
  'pause': 'Pause',
  'mapSettings': 'Map settings',
  'mapStyle': 'Base map',
  'valuesOnMap': 'Show values on map',
  'windAnimation': 'Wind particle animation',
  'windAnimationAllLayers': 'Wind particles on every layer',
  'particleDensity': 'Particle density',
  'isobars': 'Isobars',
  'directionArrows': 'Direction arrows',
  'mapDetail': 'Data detail (more detail uses more requests)',
  'low': 'Low',
  'medium': 'Medium',
  'high': 'High',
  'openForecast': 'Full forecast',
  'addFavourite': 'Add to favourites',
  'removeFavourite': 'Remove from favourites',
  'addedToFavourites': 'Added to favourites',
  'loadingLayer': 'Loading weather data…',
  'layerNoDataHere': 'This layer has no data in the visible area.',
  'myLocation': 'My location',
  'selectedPoint': 'Selected point',
  'layerControls': 'Layer controls',
  'groupWind': 'Wind',
  'groupTemperature': 'Temperature',
  'groupPrecipitation': 'Rain, snow & storms',
  'groupAtmosphere': 'Clouds & atmosphere',
  'groupAirQuality': 'Air quality & UV',
  'groupOcean': 'Ocean',
  'accumulationFrom': 'Total since now',
  'rateLimitPause':
      'Pausing new data requests to stay within the free API limit…',
  'zoomInForData': 'Zoom in a little to load data for this layer.',
  'longPressHint': 'Tap the map for a point forecast · long-press to save',
  'layer_windSpeed': 'Wind speed',
  'layer_windDirection': 'Wind direction',
  'layer_windGusts': 'Wind gusts',
  'layer_temperature': 'Temperature',
  'layer_feelsLike': 'Feels like',
  'layer_precipitation': 'Rain & precipitation',
  'layer_rainAccumulation': 'Rain accumulation',
  'layer_snowfall': 'Snowfall',
  'layer_clouds': 'Cloud cover',
  'layer_pressure': 'Pressure',
  'layer_humidity': 'Humidity',
  'layer_visibility': 'Visibility',
  'layer_thunderstorm': 'Thunderstorms',
  'layer_lightning': 'Lightning potential',
  'layer_aqi': 'Air quality (US AQI)',
  'layer_uvIndex': 'UV index',
  'layer_waveHeight': 'Wave height',
  'layer_waveDirection': 'Wave direction',
  'layer_seaTemperature': 'Sea temperature',
  'layer_marine': 'Marine: swell',
  'layerDesc_windSpeed': 'Wind speed at 10 m above ground.',
  'layerDesc_windDirection':
      'Arrows show where the wind blows to; colours show speed.',
  'layerDesc_windGusts': 'Maximum gust speed at 10 m during the hour.',
  'layerDesc_temperature': 'Air temperature at 2 m.',
  'layerDesc_feelsLike':
      'Apparent temperature combining heat, humidity and wind.',
  'layerDesc_precipitation': 'Total precipitation (rain, showers, snow) per hour.',
  'layerDesc_rainAccumulation':
      'Precipitation added up from the current hour to the selected time.',
  'layerDesc_snowfall': 'Snowfall per hour.',
  'layerDesc_clouds': 'Total cloud cover.',
  'layerDesc_pressure': 'Mean sea-level pressure with isobars.',
  'layerDesc_humidity': 'Relative humidity at 2 m.',
  'layerDesc_visibility': 'Horizontal visibility; low values mean fog or haze.',
  'layerDesc_thunderstorm':
      'Convective available potential energy (CAPE). High values mean thunderstorms can develop.',
  'layerDesc_lightning':
      'DWD ICON lightning potential index. Model data is available only over Central Europe; elsewhere the layer stays empty.',
  'layerDesc_aqi': 'US Air Quality Index from the CAMS forecast.',
  'layerDesc_uvIndex': 'UV index including cloud effects.',
  'layerDesc_waveHeight': 'Significant wave height (ocean only).',
  'layerDesc_waveDirection': 'Mean wave direction (ocean only).',
  'layerDesc_seaTemperature': 'Sea surface temperature (ocean only).',
  'layerDesc_marine': 'Swell wave height and direction (ocean only).',
  'feelsLike': 'Feels like',
  'wind': 'Wind',
  'gusts': 'Gusts',
  'humidity': 'Humidity',
  'pressure': 'Pressure',
  'rainProbability': 'Rain chance',
  'precipitation': 'Precipitation',
  'cloudCover': 'Cloud cover',
  'visibility': 'Visibility',
  'dewPoint': 'Dew point',
  'uvIndex': 'UV index',
  'sunrise': 'Sunrise',
  'sunset': 'Sunset',
  'daylight': 'Daylight',
  'sunAndMoon': 'Sun & moon',
  'moonrise': 'Moonrise',
  'moonset': 'Moonset',
  'moonPhase': 'Moon phase',
  'illumination': 'Illumination',
  'next24h': 'Next 24 hours',
  'hourlyForecast': 'Hourly forecast',
  'dailyForecast': '7-day forecast',
  'extendedForecast': 'Extended forecast',
  'overview': 'Overview',
  'meteogram': 'Meteogram',
  'airgram': 'Airgram',
  'models': 'Models',
  'details': 'Details',
  'airQuality': 'Air quality',
  'marine': 'Marine',
  'waveHeight': 'Wave height',
  'wavePeriod': 'Wave period',
  'waveDirection': 'Wave direction',
  'seaTemperature': 'Sea temperature',
  'swell': 'Swell',
  'snowfall': 'Snowfall',
  'cape': 'Storm energy (CAPE)',
  'noLocationSelected': 'No location selected',
  'chooseLocation': 'Search for a place, tap the map, or use your location.',
  'useMyLocation': 'Use my location',
  'elevation': 'Elevation',
  'timezone': 'Time zone',
  'tapChartHint': 'Scroll sideways · tap to inspect an hour',
  'temperature': 'Temperature',
  'windDirection': 'Wind direction',
  'noMoonrise': 'No moonrise today',
  'noMoonset': 'No moonset today',
  'moon0': 'New moon',
  'moon1': 'Waxing crescent',
  'moon2': 'First quarter',
  'moon3': 'Waxing gibbous',
  'moon4': 'Full moon',
  'moon5': 'Waning gibbous',
  'moon6': 'Last quarter',
  'moon7': 'Waning crescent',
  'wc0': 'Clear sky',
  'wc1': 'Mainly clear',
  'wc2': 'Partly cloudy',
  'wc3': 'Overcast',
  'wc45': 'Fog',
  'wc48': 'Freezing fog',
  'wc51': 'Light drizzle',
  'wc53': 'Drizzle',
  'wc55': 'Dense drizzle',
  'wc56': 'Light freezing drizzle',
  'wc57': 'Freezing drizzle',
  'wc61': 'Light rain',
  'wc63': 'Rain',
  'wc65': 'Heavy rain',
  'wc66': 'Light freezing rain',
  'wc67': 'Freezing rain',
  'wc71': 'Light snow',
  'wc73': 'Snow',
  'wc75': 'Heavy snow',
  'wc77': 'Snow grains',
  'wc80': 'Light showers',
  'wc81': 'Showers',
  'wc82': 'Violent showers',
  'wc85': 'Light snow showers',
  'wc86': 'Snow showers',
  'wc95': 'Thunderstorm',
  'wc96': 'Thunderstorm with hail',
  'wc99': 'Severe thunderstorm with hail',
  'aqi0': 'Good',
  'aqi1': 'Moderate',
  'aqi2': 'Unhealthy for sensitive groups',
  'aqi3': 'Unhealthy',
  'aqi4': 'Very unhealthy',
  'aqi5': 'Hazardous',
  'uv0': 'Low',
  'uv1': 'Moderate',
  'uv2': 'High',
  'uv3': 'Very high',
  'uv4': 'Extreme',
  'compareModels': 'Compare weather models',
  'modelUnavailable': 'Not available for this location',
  'dataUntil': 'Data until {time}',
  'spread': 'Spread',
  'modelNote':
      'Each line is a separate forecast model. A large spread between models means the forecast is less certain.',
  'dailyMax': 'Daily max',
  'dailyMin': 'Daily min',
  'dailyTotal': 'Daily total',
  'dailyMaxWind': 'Daily max wind',
  'dailyMean': 'Daily mean',
  'model': 'Model',
  'availableModels': 'Models',
  'altitude': 'Altitude',
  'freezingLevel': '0 °C level',
  'airgramNote':
      'Cloud cover at pressure levels (shaded), temperature lines every 5 °C and wind arrows. Altitudes are approximate (from geopotential height).',
  'cloudLayers': 'Cloud layers',
  'radarAndSatellite': 'Radar & satellite',
  'product': 'Product',
  'coverage': 'Coverage',
  'storms': 'Storms',
  'activeStorms': 'Active tropical cyclones',
  'noActiveStorms': 'No active tropical cyclones reported by GDACS.',
  'autoRefresh': 'Auto refresh',
  'history': 'History',
  'lastHour': '1 h',
  'last3h': '3 h',
  'last6h': '6 h',
  'precipTypeNote':
      'Precipitation type (rain/snow) is not provided by these free imagery sources. Use the Snowfall layer on the map for forecast snow.',
  'frameMissingNote':
      'Some frames may be blank while a provider has not published them yet.',
  'stormTrack': 'Track',
  'alertLevel': 'Alert level',
  'maxWind': 'Max wind',
  'radarProductInfo': 'About this product',
  'coverageGlobal': 'Global',
  'product_imerg': 'Precipitation (satellite, global)',
  'product_nexrad': 'Weather radar (USA)',
  'product_himawari': 'Satellite IR: Asia–Pacific',
  'product_iodc': 'Satellite IR: Indian Ocean',
  'product_goesEast': 'Satellite IR: Americas (East)',
  'product_goesWest': 'Satellite IR: Americas (West)',
  'product_mtg': 'Satellite IR: Europe & Africa',
  'product_worldCloud': 'World cloud map',
  'productCoverage_imerg':
      'NASA IMERG Early Run, global 60°N–60°S, every 30 min, published with about 4–6 hours delay.',
  'productCoverage_nexrad':
      'NOAA NEXRAD base reflectivity mosaic over the contiguous United States via Iowa Environmental Mesonet, every 5 min.',
  'productCoverage_himawari':
      'JMA Himawari infrared (10.4 µm) via NASA GIBS. Covers East & South-East Asia and Australia, every 10 min.',
  'productCoverage_iodc':
      'EUMETSAT Meteosat Indian Ocean infrared (10.8 µm). Covers South Asia including Bangladesh, every 15 min.',
  'productCoverage_goesEast':
      'NOAA GOES-East infrared (10.3 µm) via NASA GIBS. Covers the Americas and Atlantic, every 10 min.',
  'productCoverage_goesWest':
      'NOAA GOES-West infrared (10.3 µm) via NASA GIBS. Covers the Pacific and western Americas, every 10 min.',
  'productCoverage_mtg':
      'EUMETSAT Meteosat Third Generation infrared (10.5 µm). Covers Europe, Africa and the Middle East, every 10 min.',
  'productCoverage_worldCloud':
      'EUMETSAT multi-satellite global infrared cloud composite, about every hour.',
  'favourites': 'Favourites',
  'noFavourites': 'No favourite places yet',
  'noFavouritesHint':
      'Long-press the map, or use the star on a forecast, to save places here.',
  'renameFavourite': 'Rename place',
  'removeFavouriteConfirm': 'Remove this place from favourites?',
  'recentSearches': 'Recent searches',
  'clearRecents': 'Clear',
  'name': 'Name',
  'alerts': 'Alerts',
  'alertSettings': 'Alert settings',
  'officialWarnings': 'Official warnings',
  'forecastAlerts': 'Forecast alerts',
  'forecastAlertDisclaimer':
      'Calculated by SkyFlow from forecast data and your thresholds. These are not official warnings.',
  'noOfficialWarnings': 'No active official warnings found for this location.',
  'noForecastAlerts': 'Nothing in the forecast reaches your thresholds.',
  'warningSourcesNote':
      'Sources: Bangladesh Meteorological Department (CAP), US National Weather Service, and GDACS (EU JRC / UN) for cyclones and floods. Other countries are not covered yet.',
  'heavyRain': 'Heavy rainfall',
  'thunderstorms': 'Thunderstorms',
  'strongWinds': 'Strong winds',
  'extremeHeat': 'Extreme heat',
  'extremeCold': 'Extreme cold',
  'floodWarnings': 'Flood warnings',
  'tropicalCyclones': 'Tropical cyclones',
  'severeWeather': 'Severe weather warnings',
  'enableAlertsForPlace': 'Alerts for this place',
  'backgroundChecks': 'Check alerts in the background',
  'backgroundChecksHint':
      'About every 3 hours while you have internet. Uses little data.',
  'notificationPermissionDenied':
      'Notifications are blocked. Allow them in system settings to receive alerts.',
  'expires': 'Expires',
  'issuedBy': 'Issued by',
  'area': 'Area',
  'checkNow': 'Check now',
  'severity': 'Severity',
  'instruction': 'What to do',
  'rainHourThreshold': 'Rain per hour (mm)',
  'rainDayThreshold': 'Rain per day (mm)',
  'gustThreshold': 'Wind gusts',
  'heatThreshold': 'Temperature at or above',
  'coldThreshold': 'Temperature at or below',
  'capeThreshold': 'Thunderstorm energy, CAPE (J/kg)',
  'officialSources': 'Official warning types',
  'alertExpected': '{what} expected {when}',
  'forecastAlertBody': '{place}: {detail}',
  'notificationChannelName': 'Weather alerts',
  'notificationChannelDesc': 'Official warnings and forecast threshold alerts',
  'searchPlaces': 'Search places',
  'coordinatesHint': 'Tip: you can also type coordinates, e.g. 23.81, 90.41',
  'currentLocation': 'Current location',
  'noResults': 'No places found',
  'typeToSearch': 'Type at least 2 letters',
  'coordinates': 'Coordinates',
  'language': 'Language',
  'systemDefault': 'System default',
  'english': 'English',
  'bangla': 'বাংলা',
  'units': 'Units',
  'temperatureUnit': 'Temperature',
  'windUnit': 'Wind speed',
  'pressureUnit': 'Pressure',
  'precipitationUnit': 'Precipitation',
  'timeFormat': 'Time format',
  'hour12': '12-hour',
  'hour24': '24-hour',
  'mapAndAnimation': 'Map & animation',
  'styleDark': 'Dark',
  'styleFiord': 'Fiord',
  'stylePositron': 'Light',
  'styleLiberty': 'Streets',
  'dataAndStorage': 'Data & storage',
  'clearCache': 'Clear cached weather data',
  'cacheCleared': 'Cache cleared',
  'about': 'About',
  'version': 'Version',
  'developer': 'Developer',
  'aboutText':
      'SkyFlow Weather is an independent app. Weather data comes from public providers listed under Data sources.',
  'openSourceLicenses': 'Open-source licences',
  'providerConfig': 'Data provider configuration',
  'providerConfigText':
      'The app uses the free, non-commercial Open-Meteo API by default. For commercial use, build the app with your own proxy server URL (see README). No secret API keys are stored in the app.',
  'attributionText': 'Weather data by Open-Meteo.com (CC BY 4.0)',
  'reduceMotion': 'Reduce motion',
};

const Map<String, String> _bn = {
  'bdRainRadar': 'বাংলাদেশ বৃষ্টি ও রাডার',
  'bdShort': 'বাংলাদেশ',
  'tabRainNow': 'এলাকাভিত্তিক বৃষ্টি',
  'tabBmdRadar': 'BMD রাডার',
  'tabBafRadar': 'BAF রাডার',
  'tabWarningsCyclones': 'সতর্কবার্তা ও ঘূর্ণিঝড়',
  'rainingNowLabel': 'এখন বৃষ্টি হচ্ছে',
  'rainContinuing': 'বৃষ্টি চলবে',
  'noRainNext2h': 'আগামী ২ ঘণ্টায় বৃষ্টি নেই',
  'next2hRain': 'আগামী ২ ঘণ্টায় বৃষ্টি',
  'nowcastModelNote': '১৫ মিনিটের হিসাব আবহাওয়া মডেল (Open-Meteo) থেকে, রাডার থেকে নয়। এই মুহূর্তে কোথায় বৃষ্টি হচ্ছে দেখতে BMD/BAF রাডার দেখুন।',
  'openInBrowser': 'ব্রাউজারে খুলুন',
  'reload': 'আবার লোড করুন',
  'webLoadFailed': 'পেজটি লোড হয়নি। ইন্টারনেট সংযোগ দেখুন, অথবা সাইটটি এখন বন্ধ থাকতে পারে।',
  'bmdWarnings': 'BMD সতর্কবার্তা',
  'noBmdWarnings': 'এখন BMD-র কোনো সক্রিয় সতর্কবার্তা নেই',
  'cycloneMapHint': 'সক্রিয় ঘূর্ণিঝড় (GDACS)। গতিপথ Radar ম্যাপে আঁকা থাকে।',
  'showCyclonesOnMap': 'রাডার ম্যাপে দেখুন',
  'notifyBmdAll': 'BMD-র সব সতর্কবার্তা',
  'notifyBmdAllHint': 'আবহাওয়া অধিদপ্তরের প্রতিটি নতুন সতর্কবার্তার নোটিফিকেশন (প্রায় ৩০ মিনিট পরপর চেক)',
  'radarSiteNote': 'অফিশিয়াল সাইটটি অ্যাপের ভেতরে দেখানো হচ্ছে। এর তথ্য ও চালু থাকা সাইটের মালিকের নিয়ন্ত্রণে।',
  'rainLight': 'হালকা',
  'rainModerate': 'মাঝারি',
  'rainHeavy': 'ভারী',
  'dry': 'শুকনো',
  'rainStartsIn': 'প্রায় {m} মিনিটে বৃষ্টি',
  'rainStopsIn': 'প্রায় {m} মিনিটে থামবে',
  'widgetUpdated': 'আপডেট {t}',
  'mmNext2h': '২ ঘণ্টায় {mm}',
  'appName': 'স্কাইফ্লো ওয়েদার',
  'navMap': 'মানচিত্র',
  'navForecast': 'পূর্বাভাস',
  'navRadar': 'রাডার',
  'navFavourites': 'প্রিয়',
  'navSettings': 'সেটিংস',
  'retry': 'আবার চেষ্টা করুন',
  'cancel': 'বাতিল',
  'save': 'সংরক্ষণ',
  'delete': 'মুছুন',
  'rename': 'নাম বদলান',
  'close': 'বন্ধ',
  'ok': 'ঠিক আছে',
  'add': 'যোগ করুন',
  'loading': 'লোড হচ্ছে…',
  'now': 'এখন',
  'today': 'আজ',
  'tomorrow': 'আগামীকাল',
  'noData': 'তথ্য নেই',
  'unavailable': 'পাওয়া যায়নি',
  'source': 'উৎস',
  'dataSources': 'তথ্যের উৎস ও স্বীকৃতি',
  'openLink': 'লিংক খুলুন',
  'learnMore': 'আরও জানুন',
  'lastUpdated': 'হালনাগাদ {time}',
  'showingCached': 'অফলাইন – {time}-এর তথ্য দেখানো হচ্ছে',
  'offline': 'অফলাইন',
  'errNetwork': 'ইন্টারনেট সংযোগ নেই। নেটওয়ার্ক দেখে আবার চেষ্টা করুন।',
  'errTimeout': 'আবহাওয়া সেবা সাড়া দিতে বেশি সময় নিচ্ছে।',
  'errRateLimit':
      'বিনামূল্যের ডেটা সেবার সীমা পূর্ণ হয়েছে। এক মিনিট অপেক্ষা করে আবার চেষ্টা করুন।',
  'errServer': 'আবহাওয়া সেবা সাময়িকভাবে বন্ধ আছে।',
  'errBadRequest': 'ডেটা সেবা অনুরোধটি গ্রহণ করেনি।',
  'errUnknown': 'কিছু একটা সমস্যা হয়েছে।',
  'errLocationDisabled': 'লোকেশন সার্ভিস বন্ধ আছে।',
  'errLocationDenied': 'লোকেশনের অনুমতি দেওয়া হয়নি।',
  'errLocationDeniedForever':
      'লোকেশনের অনুমতি স্থায়ীভাবে বন্ধ। সিস্টেম সেটিংস থেকে চালু করুন।',
  'errLocationTimeout': 'সময়মতো আপনার অবস্থান পাওয়া যায়নি।',
  'openSettings': 'সেটিংস খুলুন',
  'searchHint': 'শহর, স্থান বা স্থানাঙ্ক খুঁজুন',
  'layers': 'স্তর',
  'legend': 'রং-নির্দেশিকা',
  'opacity': 'স্বচ্ছতা',
  'play': 'চালান',
  'pause': 'থামান',
  'mapSettings': 'মানচিত্র সেটিংস',
  'mapStyle': 'ভিত্তি মানচিত্র',
  'valuesOnMap': 'মানচিত্রে মান দেখান',
  'windAnimation': 'বাতাসের কণা অ্যানিমেশন',
  'windAnimationAllLayers': 'সব স্তরে বাতাসের কণা',
  'particleDensity': 'কণার ঘনত্ব',
  'isobars': 'সমচাপ রেখা',
  'directionArrows': 'দিক নির্দেশক তীর',
  'mapDetail': 'তথ্যের সূক্ষ্মতা (বেশি সূক্ষ্মতায় বেশি অনুরোধ লাগে)',
  'low': 'কম',
  'medium': 'মাঝারি',
  'high': 'বেশি',
  'openForecast': 'সম্পূর্ণ পূর্বাভাস',
  'addFavourite': 'প্রিয়তে যোগ করুন',
  'removeFavourite': 'প্রিয় থেকে সরান',
  'addedToFavourites': 'প্রিয়তে যোগ হয়েছে',
  'loadingLayer': 'আবহাওয়ার তথ্য লোড হচ্ছে…',
  'layerNoDataHere': 'দৃশ্যমান এলাকায় এই স্তরের কোনো তথ্য নেই।',
  'myLocation': 'আমার অবস্থান',
  'selectedPoint': 'নির্বাচিত স্থান',
  'layerControls': 'স্তরের নিয়ন্ত্রণ',
  'groupWind': 'বাতাস',
  'groupTemperature': 'তাপমাত্রা',
  'groupPrecipitation': 'বৃষ্টি, তুষার ও ঝড়',
  'groupAtmosphere': 'মেঘ ও বায়ুমণ্ডল',
  'groupAirQuality': 'বায়ুর মান ও ইউভি',
  'groupOcean': 'সমুদ্র',
  'accumulationFrom': 'এখন থেকে মোট',
  'rateLimitPause':
      'বিনামূল্যের API-সীমার মধ্যে থাকতে নতুন অনুরোধ সাময়িকভাবে থামানো হয়েছে…',
  'zoomInForData': 'এই স্তরের তথ্য পেতে একটু জুম করুন।',
  'longPressHint': 'স্থানের পূর্বাভাসের জন্য ট্যাপ করুন · সংরক্ষণে চেপে ধরুন',
  'layer_windSpeed': 'বাতাসের গতি',
  'layer_windDirection': 'বাতাসের দিক',
  'layer_windGusts': 'দমকা হাওয়া',
  'layer_temperature': 'তাপমাত্রা',
  'layer_feelsLike': 'অনুভূত তাপমাত্রা',
  'layer_precipitation': 'বৃষ্টি ও বর্ষণ',
  'layer_rainAccumulation': 'মোট বৃষ্টিপাত',
  'layer_snowfall': 'তুষারপাত',
  'layer_clouds': 'মেঘের আচ্ছাদন',
  'layer_pressure': 'বায়ুচাপ',
  'layer_humidity': 'আর্দ্রতা',
  'layer_visibility': 'দৃশ্যমানতা',
  'layer_thunderstorm': 'বজ্রঝড়',
  'layer_lightning': 'বজ্রপাতের সম্ভাবনা',
  'layer_aqi': 'বায়ুর মান (US AQI)',
  'layer_uvIndex': 'ইউভি সূচক',
  'layer_waveHeight': 'ঢেউয়ের উচ্চতা',
  'layer_waveDirection': 'ঢেউয়ের দিক',
  'layer_seaTemperature': 'সমুদ্রের তাপমাত্রা',
  'layer_marine': 'সামুদ্রিক: সোয়েল ঢেউ',
  'layerDesc_windSpeed': 'ভূমি থেকে ১০ মিটার উচ্চতায় বাতাসের গতি।',
  'layerDesc_windDirection':
      'তীর বাতাস কোন দিকে বইছে তা দেখায়; রং গতি দেখায়।',
  'layerDesc_windGusts': 'ঘণ্টার মধ্যে ১০ মিটারে সর্বোচ্চ দমকা হাওয়া।',
  'layerDesc_temperature': '২ মিটার উচ্চতায় বাতাসের তাপমাত্রা।',
  'layerDesc_feelsLike': 'তাপ, আর্দ্রতা ও বাতাস মিলিয়ে অনুভূত তাপমাত্রা।',
  'layerDesc_precipitation': 'প্রতি ঘণ্টায় মোট বর্ষণ (বৃষ্টি, ঝরো বৃষ্টি, তুষার)।',
  'layerDesc_rainAccumulation':
      'বর্তমান ঘণ্টা থেকে নির্বাচিত সময় পর্যন্ত যোগফল।',
  'layerDesc_snowfall': 'প্রতি ঘণ্টায় তুষারপাত।',
  'layerDesc_clouds': 'মোট মেঘের আচ্ছাদন।',
  'layerDesc_pressure': 'সমুদ্রপৃষ্ঠের গড় বায়ুচাপ ও সমচাপ রেখা।',
  'layerDesc_humidity': '২ মিটারে আপেক্ষিক আর্দ্রতা।',
  'layerDesc_visibility': 'অনুভূমিক দৃশ্যমানতা; কম মান মানে কুয়াশা বা ধোঁয়াশা।',
  'layerDesc_thunderstorm':
      'পরিচলন শক্তি (CAPE)। বেশি মান মানে বজ্রঝড় তৈরি হতে পারে।',
  'layerDesc_lightning':
      'DWD ICON মডেলের বজ্রপাত সম্ভাবনা সূচক। এই তথ্য শুধু মধ্য ইউরোপের জন্য পাওয়া যায়; অন্যত্র স্তরটি ফাঁকা থাকবে।',
  'layerDesc_aqi': 'CAMS পূর্বাভাস থেকে মার্কিন বায়ুমান সূচক।',
  'layerDesc_uvIndex': 'মেঘের প্রভাবসহ ইউভি সূচক।',
  'layerDesc_waveHeight': 'উল্লেখযোগ্য ঢেউয়ের উচ্চতা (শুধু সমুদ্রে)।',
  'layerDesc_waveDirection': 'ঢেউয়ের গড় দিক (শুধু সমুদ্রে)।',
  'layerDesc_seaTemperature': 'সমুদ্রপৃষ্ঠের তাপমাত্রা (শুধু সমুদ্রে)।',
  'layerDesc_marine': 'সোয়েল ঢেউয়ের উচ্চতা ও দিক (শুধু সমুদ্রে)।',
  'feelsLike': 'অনুভূত',
  'wind': 'বাতাস',
  'gusts': 'দমকা',
  'humidity': 'আর্দ্রতা',
  'pressure': 'বায়ুচাপ',
  'rainProbability': 'বৃষ্টির সম্ভাবনা',
  'precipitation': 'বৃষ্টিপাত',
  'cloudCover': 'মেঘ',
  'visibility': 'দৃশ্যমানতা',
  'dewPoint': 'শিশিরাঙ্ক',
  'uvIndex': 'ইউভি সূচক',
  'sunrise': 'সূর্যোদয়',
  'sunset': 'সূর্যাস্ত',
  'daylight': 'দিনের দৈর্ঘ্য',
  'sunAndMoon': 'সূর্য ও চাঁদ',
  'moonrise': 'চন্দ্রোদয়',
  'moonset': 'চন্দ্রাস্ত',
  'moonPhase': 'চাঁদের দশা',
  'illumination': 'আলোকিত অংশ',
  'next24h': 'পরবর্তী ২৪ ঘণ্টা',
  'hourlyForecast': 'ঘণ্টাভিত্তিক পূর্বাভাস',
  'dailyForecast': '৭ দিনের পূর্বাভাস',
  'extendedForecast': 'দীর্ঘমেয়াদি পূর্বাভাস',
  'overview': 'সারসংক্ষেপ',
  'meteogram': 'মেটিওগ্রাম',
  'airgram': 'এয়ারগ্রাম',
  'models': 'মডেল',
  'details': 'বিস্তারিত',
  'airQuality': 'বায়ুর মান',
  'marine': 'সামুদ্রিক',
  'waveHeight': 'ঢেউয়ের উচ্চতা',
  'wavePeriod': 'ঢেউয়ের পর্যায়কাল',
  'waveDirection': 'ঢেউয়ের দিক',
  'seaTemperature': 'সমুদ্রের তাপমাত্রা',
  'swell': 'সোয়েল',
  'snowfall': 'তুষারপাত',
  'cape': 'ঝড়ের শক্তি (CAPE)',
  'noLocationSelected': 'কোনো স্থান নির্বাচিত নয়',
  'chooseLocation':
      'কোনো স্থান খুঁজুন, মানচিত্রে ট্যাপ করুন বা আপনার অবস্থান ব্যবহার করুন।',
  'useMyLocation': 'আমার অবস্থান ব্যবহার করুন',
  'elevation': 'উচ্চতা',
  'timezone': 'সময় অঞ্চল',
  'tapChartHint': 'পাশে স্ক্রল করুন · কোনো ঘণ্টা দেখতে ট্যাপ করুন',
  'temperature': 'তাপমাত্রা',
  'windDirection': 'বাতাসের দিক',
  'noMoonrise': 'আজ চন্দ্রোদয় নেই',
  'noMoonset': 'আজ চন্দ্রাস্ত নেই',
  'moon0': 'অমাবস্যা',
  'moon1': 'শুক্লপক্ষের বাঁকা চাঁদ',
  'moon2': 'প্রথম চতুর্থাংশ',
  'moon3': 'শুক্লপক্ষের স্ফীত চাঁদ',
  'moon4': 'পূর্ণিমা',
  'moon5': 'কৃষ্ণপক্ষের স্ফীত চাঁদ',
  'moon6': 'শেষ চতুর্থাংশ',
  'moon7': 'কৃষ্ণপক্ষের বাঁকা চাঁদ',
  'wc0': 'পরিষ্কার আকাশ',
  'wc1': 'প্রধানত পরিষ্কার',
  'wc2': 'আংশিক মেঘলা',
  'wc3': 'মেঘাচ্ছন্ন',
  'wc45': 'কুয়াশা',
  'wc48': 'জমাট কুয়াশা',
  'wc51': 'হালকা গুঁড়ি বৃষ্টি',
  'wc53': 'গুঁড়ি বৃষ্টি',
  'wc55': 'ঘন গুঁড়ি বৃষ্টি',
  'wc56': 'হালকা হিমায়িত গুঁড়ি বৃষ্টি',
  'wc57': 'হিমায়িত গুঁড়ি বৃষ্টি',
  'wc61': 'হালকা বৃষ্টি',
  'wc63': 'বৃষ্টি',
  'wc65': 'ভারী বৃষ্টি',
  'wc66': 'হালকা হিমায়িত বৃষ্টি',
  'wc67': 'হিমায়িত বৃষ্টি',
  'wc71': 'হালকা তুষারপাত',
  'wc73': 'তুষারপাত',
  'wc75': 'ভারী তুষারপাত',
  'wc77': 'তুষারকণা',
  'wc80': 'হালকা ঝরো বৃষ্টি',
  'wc81': 'ঝরো বৃষ্টি',
  'wc82': 'প্রবল ঝরো বৃষ্টি',
  'wc85': 'হালকা তুষার ঝরো',
  'wc86': 'তুষার ঝরো',
  'wc95': 'বজ্রঝড়',
  'wc96': 'শিলাসহ বজ্রঝড়',
  'wc99': 'শিলাসহ তীব্র বজ্রঝড়',
  'aqi0': 'ভালো',
  'aqi1': 'মাঝারি',
  'aqi2': 'সংবেদনশীলদের জন্য অস্বাস্থ্যকর',
  'aqi3': 'অস্বাস্থ্যকর',
  'aqi4': 'খুবই অস্বাস্থ্যকর',
  'aqi5': 'বিপজ্জনক',
  'uv0': 'কম',
  'uv1': 'মাঝারি',
  'uv2': 'উচ্চ',
  'uv3': 'খুব উচ্চ',
  'uv4': 'চরম',
  'compareModels': 'আবহাওয়া মডেলের তুলনা',
  'modelUnavailable': 'এই স্থানের জন্য পাওয়া যায় না',
  'dataUntil': '{time} পর্যন্ত তথ্য',
  'spread': 'পার্থক্য',
  'modelNote':
      'প্রতিটি রেখা আলাদা পূর্বাভাস মডেল। মডেলগুলোর মধ্যে পার্থক্য বেশি হলে পূর্বাভাস কম নিশ্চিত।',
  'dailyMax': 'দৈনিক সর্বোচ্চ',
  'dailyMin': 'দৈনিক সর্বনিম্ন',
  'dailyTotal': 'দৈনিক মোট',
  'dailyMaxWind': 'দৈনিক সর্বোচ্চ বাতাস',
  'dailyMean': 'দৈনিক গড়',
  'model': 'মডেল',
  'availableModels': 'মডেলসমূহ',
  'altitude': 'উচ্চতা',
  'freezingLevel': '০ °সে স্তর',
  'airgramNote':
      'বিভিন্ন চাপ-স্তরে মেঘ (ছায়া), প্রতি ৫ °সে তাপমাত্রা রেখা ও বাতাসের তীর। উচ্চতা আনুমানিক (জিওপটেনশিয়াল উচ্চতা থেকে)।',
  'cloudLayers': 'মেঘের স্তর',
  'radarAndSatellite': 'রাডার ও স্যাটেলাইট',
  'product': 'পণ্য',
  'coverage': 'আওতা',
  'storms': 'ঝড়',
  'activeStorms': 'সক্রিয় ঘূর্ণিঝড়',
  'noActiveStorms': 'GDACS কোনো সক্রিয় ঘূর্ণিঝড়ের খবর দেয়নি।',
  'autoRefresh': 'স্বয়ংক্রিয় হালনাগাদ',
  'history': 'ইতিহাস',
  'lastHour': '১ ঘ',
  'last3h': '৩ ঘ',
  'last6h': '৬ ঘ',
  'precipTypeNote':
      'এই বিনামূল্যের ছবির উৎসগুলো বৃষ্টি না তুষার তা আলাদা করে না। পূর্বাভাসে তুষার দেখতে মানচিত্রের তুষারপাত স্তর ব্যবহার করুন।',
  'frameMissingNote':
      'সরবরাহকারী প্রকাশ না করা পর্যন্ত কিছু ফ্রেম ফাঁকা থাকতে পারে।',
  'stormTrack': 'গতিপথ',
  'alertLevel': 'সতর্কতা স্তর',
  'maxWind': 'সর্বোচ্চ বাতাস',
  'radarProductInfo': 'এই পণ্য সম্পর্কে',
  'coverageGlobal': 'বিশ্বব্যাপী',
  'product_imerg': 'বৃষ্টিপাত (স্যাটেলাইট, বিশ্বব্যাপী)',
  'product_nexrad': 'আবহাওয়া রাডার (যুক্তরাষ্ট্র)',
  'product_himawari': 'স্যাটেলাইট IR: এশিয়া–প্রশান্ত মহাসাগর',
  'product_iodc': 'স্যাটেলাইট IR: ভারত মহাসাগর',
  'product_goesEast': 'স্যাটেলাইট IR: আমেরিকা (পূর্ব)',
  'product_goesWest': 'স্যাটেলাইট IR: আমেরিকা (পশ্চিম)',
  'product_mtg': 'স্যাটেলাইট IR: ইউরোপ ও আফ্রিকা',
  'product_worldCloud': 'বিশ্ব মেঘ মানচিত্র',
  'productCoverage_imerg':
      'NASA IMERG আর্লি রান, ৬০° উ–৬০° দ, প্রতি ৩০ মিনিটে, প্রায় ৪–৬ ঘণ্টা দেরিতে প্রকাশিত।',
  'productCoverage_nexrad':
      'Iowa Environmental Mesonet-এর মাধ্যমে NOAA NEXRAD রাডার মোজাইক, শুধু যুক্তরাষ্ট্রের মূল ভূখণ্ড, প্রতি ৫ মিনিটে।',
  'productCoverage_himawari':
      'NASA GIBS-এর মাধ্যমে JMA হিমাওয়ারি ইনফ্রারেড। পূর্ব ও দক্ষিণ-পূর্ব এশিয়া ও অস্ট্রেলিয়া, প্রতি ১০ মিনিটে।',
  'productCoverage_iodc':
      'EUMETSAT মেটিওস্যাট ভারত মহাসাগর ইনফ্রারেড। বাংলাদেশসহ দক্ষিণ এশিয়া, প্রতি ১৫ মিনিটে।',
  'productCoverage_goesEast':
      'NASA GIBS-এর মাধ্যমে NOAA GOES-East ইনফ্রারেড। আমেরিকা ও আটলান্টিক, প্রতি ১০ মিনিটে।',
  'productCoverage_goesWest':
      'NASA GIBS-এর মাধ্যমে NOAA GOES-West ইনফ্রারেড। প্রশান্ত মহাসাগর ও পশ্চিম আমেরিকা, প্রতি ১০ মিনিটে।',
  'productCoverage_mtg':
      'EUMETSAT মেটিওস্যাট থার্ড জেনারেশন ইনফ্রারেড। ইউরোপ, আফ্রিকা ও মধ্যপ্রাচ্য, প্রতি ১০ মিনিটে।',
  'productCoverage_worldCloud':
      'EUMETSAT-এর একাধিক স্যাটেলাইটের বিশ্বব্যাপী ইনফ্রারেড মেঘ চিত্র, প্রায় প্রতি ঘণ্টায়।',
  'favourites': 'প্রিয় স্থান',
  'noFavourites': 'এখনো কোনো প্রিয় স্থান নেই',
  'noFavouritesHint':
      'মানচিত্রে চেপে ধরুন অথবা পূর্বাভাসের তারকা চিহ্ন ব্যবহার করে স্থান সংরক্ষণ করুন।',
  'renameFavourite': 'স্থানের নাম বদলান',
  'removeFavouriteConfirm': 'এই স্থানটি প্রিয় থেকে সরাবেন?',
  'recentSearches': 'সাম্প্রতিক খোঁজ',
  'clearRecents': 'মুছে ফেলুন',
  'name': 'নাম',
  'alerts': 'সতর্কতা',
  'alertSettings': 'সতর্কতার সেটিংস',
  'officialWarnings': 'সরকারি সতর্কবার্তা',
  'forecastAlerts': 'পূর্বাভাসভিত্তিক সতর্কতা',
  'forecastAlertDisclaimer':
      'পূর্বাভাসের তথ্য ও আপনার নির্ধারিত সীমা থেকে স্কাইফ্লো এটি হিসাব করেছে। এগুলো সরকারি সতর্কবার্তা নয়।',
  'noOfficialWarnings': 'এই স্থানের জন্য কোনো সক্রিয় সরকারি সতর্কবার্তা পাওয়া যায়নি।',
  'noForecastAlerts': 'পূর্বাভাসে কিছুই আপনার নির্ধারিত সীমায় পৌঁছায়নি।',
  'warningSourcesNote':
      'উৎস: বাংলাদেশ আবহাওয়া অধিদপ্তর (CAP), মার্কিন ন্যাশনাল ওয়েদার সার্ভিস, এবং ঘূর্ণিঝড় ও বন্যার জন্য GDACS (EU JRC / জাতিসংঘ)। অন্যান্য দেশ এখনো অন্তর্ভুক্ত নয়।',
  'heavyRain': 'ভারী বৃষ্টিপাত',
  'thunderstorms': 'বজ্রঝড়',
  'strongWinds': 'প্রবল বাতাস',
  'extremeHeat': 'তীব্র গরম',
  'extremeCold': 'তীব্র শীত',
  'floodWarnings': 'বন্যা সতর্কতা',
  'tropicalCyclones': 'ঘূর্ণিঝড়',
  'severeWeather': 'তীব্র আবহাওয়া সতর্কতা',
  'enableAlertsForPlace': 'এই স্থানের সতর্কতা',
  'backgroundChecks': 'পটভূমিতে সতর্কতা যাচাই',
  'backgroundChecksHint': 'ইন্টারনেট থাকলে প্রায় প্রতি ৩ ঘণ্টায়। খুব কম ডেটা লাগে।',
  'notificationPermissionDenied':
      'নোটিফিকেশন বন্ধ আছে। সতর্কতা পেতে সিস্টেম সেটিংসে অনুমতি দিন।',
  'expires': 'মেয়াদ শেষ',
  'issuedBy': 'জারি করেছে',
  'area': 'এলাকা',
  'checkNow': 'এখনই যাচাই করুন',
  'severity': 'তীব্রতা',
  'instruction': 'করণীয়',
  'rainHourThreshold': 'প্রতি ঘণ্টায় বৃষ্টি (মিমি)',
  'rainDayThreshold': 'প্রতিদিন বৃষ্টি (মিমি)',
  'gustThreshold': 'দমকা হাওয়া',
  'heatThreshold': 'তাপমাত্রা এর সমান বা বেশি',
  'coldThreshold': 'তাপমাত্রা এর সমান বা কম',
  'capeThreshold': 'বজ্রঝড়ের শক্তি, CAPE (J/kg)',
  'officialSources': 'সরকারি সতর্কবার্তার ধরন',
  'alertExpected': '{when} {what}-এর সম্ভাবনা',
  'forecastAlertBody': '{place}: {detail}',
  'notificationChannelName': 'আবহাওয়া সতর্কতা',
  'notificationChannelDesc': 'সরকারি সতর্কবার্তা ও পূর্বাভাসের সীমা-সতর্কতা',
  'searchPlaces': 'স্থান খুঁজুন',
  'coordinatesHint': 'টিপ: স্থানাঙ্কও লিখতে পারেন, যেমন 23.81, 90.41',
  'currentLocation': 'বর্তমান অবস্থান',
  'noResults': 'কোনো স্থান পাওয়া যায়নি',
  'typeToSearch': 'অন্তত ২টি অক্ষর লিখুন',
  'coordinates': 'স্থানাঙ্ক',
  'language': 'ভাষা',
  'systemDefault': 'সিস্টেম অনুযায়ী',
  'english': 'English',
  'bangla': 'বাংলা',
  'units': 'একক',
  'temperatureUnit': 'তাপমাত্রা',
  'windUnit': 'বাতাসের গতি',
  'pressureUnit': 'বায়ুচাপ',
  'precipitationUnit': 'বৃষ্টিপাত',
  'timeFormat': 'সময়ের ধরন',
  'hour12': '১২ ঘণ্টা',
  'hour24': '২৪ ঘণ্টা',
  'mapAndAnimation': 'মানচিত্র ও অ্যানিমেশন',
  'styleDark': 'গাঢ়',
  'styleFiord': 'ফিয়র্ড',
  'stylePositron': 'হালকা',
  'styleLiberty': 'রাস্তা',
  'dataAndStorage': 'ডেটা ও সংরক্ষণ',
  'clearCache': 'সংরক্ষিত আবহাওয়ার তথ্য মুছুন',
  'cacheCleared': 'ক্যাশ মুছে ফেলা হয়েছে',
  'about': 'সম্পর্কে',
  'version': 'সংস্করণ',
  'developer': 'ডেভেলপার',
  'aboutText':
      'স্কাইফ্লো ওয়েদার একটি স্বতন্ত্র অ্যাপ। আবহাওয়ার তথ্য আসে "তথ্যের উৎস" অংশে তালিকাভুক্ত সরবরাহকারীদের কাছ থেকে।',
  'openSourceLicenses': 'ওপেন-সোর্স লাইসেন্স',
  'providerConfig': 'ডেটা সরবরাহকারীর কনফিগারেশন',
  'providerConfigText':
      'অ্যাপটি ডিফল্টভাবে বিনামূল্যের, অবাণিজ্যিক Open-Meteo API ব্যবহার করে। বাণিজ্যিক ব্যবহারের জন্য নিজের প্রক্সি সার্ভারের URL দিয়ে অ্যাপ বিল্ড করুন (README দেখুন)। অ্যাপে কোনো গোপন API কী রাখা হয় না।',
  'attributionText': 'আবহাওয়ার তথ্য: Open-Meteo.com (CC BY 4.0)',
  'reduceMotion': 'অ্যানিমেশন কমান',
};
