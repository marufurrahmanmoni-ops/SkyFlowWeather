# SkyFlow Weather

An original, Windy-style weather app for Android, built with Flutter: a full-screen interactive weather map with animated wind particles and 20 data layers, detailed forecasts with meteogram and airgram, weather-model comparison, radar and satellite playback, cyclone tracking, and weather alerts. English and Bengali (বাংলা).

<img src="docs/icon.png" width="96" alt="SkyFlow Weather icon">

**Developer:** Md. Marufur Rahman Moni

---

## বাংলায় দ্রুত নির্দেশনা (ফোন থেকে APK বানানো)

1. ZIP ফাইলটি ফোনে আনজিপ করুন।
2. GitHub-এ আপনার রিপো (`lenslingo/Windy`) খুলুন → **Add file → Upload files**।
3. আনজিপ করা ফোল্ডারের **ভেতরের সব ফাইল ও ফোল্ডার** আপলোড করুন (যাতে রিপোর মূলে `pubspec.yaml`, `lib/`, `android/`, `.github/` থাকে)। **Commit changes** চাপুন।
   - `.github` ফোল্ডারটি লুকানো থাকতে পারে — অবশ্যই আপলোড করবেন, নইলে বিল্ড চলবে না।
4. **Actions** ট্যাবে যান → "Build Android" চলবে (প্রায় ১৫–২৫ মিনিট)।
5. শেষ হলে রানটি খুলে নিচে **Artifacts** থেকে `SkyFlowWeather-debug-apk` বা `SkyFlowWeather-release-apk` নামিয়ে ইনস্টল করুন।
6. বিল্ড ব্যর্থ হলে লাল ✗ চিহ্নিত ধাপটি খুলে লগটি কপি করে পাঠান — ঠিক করে দেওয়া যাবে।

---

## Features

**Map (main screen)**
- Full-screen MapLibre map (OpenFreeMap dark, fiord, light or streets base map), smooth pan and zoom.
- 20 weather layers, each with its own colour gradient, legend, units and opacity control:
  wind speed, wind direction (arrows), wind gusts, temperature, feels-like, rain & precipitation, rain accumulation, snowfall, cloud cover, pressure (with isobars), humidity, visibility, thunderstorms (CAPE), lightning potential, air quality (US AQI), UV index, wave height, wave direction, sea temperature, marine swell.
- Animated wind particles (on wind layers, optionally on every layer), adjustable density.
- Values drawn directly on the map; tap anywhere for a point forecast; long-press to save a favourite.
- Hourly timeline up to 72 h with play/pause and day markers.
- Search (city, region, country or coordinates), GPS location, quick access to favourites.
- Remembers the last layer, map position and selected place.

**Forecast**
- Current conditions, feels-like, wind and gusts, humidity, pressure, rain chance, precipitation, clouds, visibility, dew point, UV, sunrise/sunset, daylight, moonrise/moonset and moon phase.
- Next 24 hours, hourly (72 h), 7-day and extended (up to 16 days) forecasts, air quality, and marine data for coastal places.
- **Meteogram** (fl_chart): temperature, feels-like, precipitation, rain probability, wind, gusts, direction, pressure and cloud layers; horizontal scrolling and tap-to-select hour; 3- or 7-day range.
- **Airgram**: cloud cover by pressure level, isotherms with the 0 °C level, wind arrows, approximate altitudes.
- **Model comparison**: ECMWF IFS, ECMWF AIFS, GFS, ICON, GEM, UK Met Office, Météo-France, JMA and CMA for temperature, wind, wind direction, precipitation, cloud and pressure, with a daily table and model spread. Models without data for the location or period are shown as unavailable, never faked.

**Radar & satellite**
- Precipitation from NASA IMERG (global, delayed), NEXRAD radar (USA), infrared satellite for every region (Himawari, Meteosat IODC — best for Bangladesh — GOES-East/West, Meteosat Third Generation) and a world cloud map.
- History playback (1 h, 3 h, 6 h), timeline, auto refresh every 5 minutes, coverage outline.
- Active tropical cyclones from GDACS with track and wind-area polygons.

**Alerts**
- Official warnings: Bangladesh Meteorological Department (CAP feed), US National Weather Service, and GDACS cyclones and floods worldwide.
- Forecast-based threshold alerts per favourite (heavy rain per hour/day, thunderstorms, gusts, heat, cold). These are clearly labelled as *not* official warnings.
- Background checks about every 3 hours (WorkManager) with de-duplicated notifications.

**General**
- English and Bengali, °C/°F, km/h · mph · knots · m/s, hPa/inHg, mm/in, 12/24-hour clock. Forecast times use each location's own time zone automatically.
- SQLite cache with offline fallback ("showing data from …"), retries with backoff, last-updated time and source attribution on every data screen.

## Building

### From your phone (GitHub Actions)

The workflow in `.github/workflows/build.yml` runs on every push. It sets up Java 21 and Flutter 3.50.1, runs `flutter analyze` and the unit tests, then builds:

| Artifact | Use |
|---|---|
| `SkyFlowWeather-debug-apk` | Testing on your phone |
| `SkyFlowWeather-release-apk` | Faster, smaller APK for normal use |
| `SkyFlowWeather-release-aab` | Upload to Google Play |

Push a tag such as `v1.0.0` to also publish these files as a GitHub Release.

### On a computer

Requirements: Flutter **3.50.1** (stable), JDK **21**, Android SDK 36.

```bash
flutter pub get
flutter test
flutter build apk --debug        # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release
```

### Release signing

Without a key, release builds are signed with the debug key so they still install. For Play Store builds:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- **Locally:** put the `.jks` in `android/app/` and create `android/key.properties`:
  ```
  storeFile=upload-keystore.jks
  storePassword=...
  keyAlias=upload
  keyPassword=...
  ```
- **On GitHub:** add repository secrets `KEYSTORE_BASE64` (output of `base64 -w0 upload-keystore.jks`), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

Never commit the keystore or `key.properties` (both are in `.gitignore`).

## API configuration

No API keys are needed for testing. All endpoints are in `lib/core/constants.dart` and can be overridden at build time with `--dart-define`, so you never have to edit code or ship a secret:

| Define | Default |
|---|---|
| `OPEN_METEO_FORECAST_URL` | `https://api.open-meteo.com/v1/forecast` |
| `OPEN_METEO_GEOCODING_URL` | `https://geocoding-api.open-meteo.com/v1/search` |
| `OPEN_METEO_AIR_QUALITY_URL` | `https://air-quality-api.open-meteo.com/v1/air-quality` |
| `OPEN_METEO_MARINE_URL` | `https://marine-api.open-meteo.com/v1/marine` |
| `OPEN_METEO_API_KEY` | empty |

**Commercial use:** the free Open-Meteo API is for non-commercial use (10,000 calls/day). For a public or commercial release, buy an Open-Meteo API plan and put your key on a small proxy server (for example a Cloudflare Worker) that forwards requests to `customer-api.open-meteo.com`. Then build with your proxy URLs:

```bash
flutter build apk --release \
  --dart-define=OPEN_METEO_FORECAST_URL=https://weather.example.com/v1/forecast \
  --dart-define=OPEN_METEO_AIR_QUALITY_URL=https://weather.example.com/v1/air-quality \
  --dart-define=OPEN_METEO_MARINE_URL=https://weather.example.com/v1/marine
```

A key passed with `OPEN_METEO_API_KEY` is compiled into the APK and can be extracted, so only use it for private builds.

### Adding or replacing a data provider

Every source sits behind an interface in `lib/data/sources/interfaces.dart` (`ForecastSource`, `GeocodingSource`, `ReverseGeocodingSource`, `GridSource`, `WarningSource`, `StormSource`). Implement the interface and change one line in `lib/state/providers.dart`. Imagery products are a list in `lib/data/sources/imagery.dart`; any other CAP-over-RSS warning feed can be added with `CapRssWarningSource`.

## Data sources and licensing

| Provider | Used for | Terms |
|---|---|---|
| [Open-Meteo](https://open-meteo.com/en/terms) | Forecast, models, pressure levels, geocoding, air quality (CAMS), marine, map layers | CC BY 4.0; free API non-commercial only |
| [OpenFreeMap](https://openfreemap.org/) | Base map | Free; © OpenMapTiles © OpenStreetMap |
| [Nominatim](https://operations.osmfoundation.org/policies/nominatim/) | Names for tapped points | ≤1 request/s (enforced), cached 30 days |
| [NASA GIBS](https://www.earthdata.nasa.gov/data/tools/gibs) | Himawari/GOES infrared, IMERG precipitation | Open NASA data |
| [EUMETSAT EUMETView](https://view.eumetsat.int/) | Meteosat infrared, world cloud map | Check EUMETSAT data policy before commercial use |
| [Iowa Environmental Mesonet](https://mesonet.agron.iastate.edu/) | NEXRAD radar (USA) | Public NOAA data |
| [BMD CAP](https://cap.bmd.gov.bd/) | Bangladesh official warnings | Public domain |
| [NWS](https://www.weather.gov/documentation/services-web-api) | US official alerts | Public domain |
| [GDACS](https://www.gdacs.org/) | Tropical cyclones and floods | Free with attribution |

RainViewer is **not** used: its public API is limited to personal and educational use.

## Known limitations (honest list)

- **Map layers are sampled on a grid.** The free Open-Meteo API returns point forecasts, so the map requests a grid of points for the visible area (6–11 columns, set by *Data detail*) and interpolates smoothly between them. Small features (single thunderstorm cells) can be softened. Each grid point counts as one API call; the app throttles itself to stay under the free per-minute limit and shows a message when it waits.
- **Ground radar** is only available for the USA (NEXRAD). There is no free, licensed radar API for Bangladesh or most other countries; elsewhere use the IMERG satellite precipitation (about 4–6 h behind real time) and the infrared satellite loops. Precipitation type (rain/snow) is not provided by these sources; use the Snowfall forecast layer.
- **Lightning:** real lightning-strike networks need a commercial licence. The *Lightning potential* layer uses DWD ICON model data, which exists only for Central Europe; elsewhere it stays empty (the app says so). The *Thunderstorms* layer (CAPE) works worldwide.
- **Official warnings** cover Bangladesh, the USA, and GDACS events worldwide. Other national services can be added as CAP feeds.
- Some satellite frames can be blank when a provider has not published that time step yet.
- **iOS** is not configured yet. The code has no Android-only logic; run `flutter create --platforms=ios .` and add location usage descriptions to `ios/Runner/Info.plist`.
- This code was written and statically checked without a local Flutter toolchain; the first full compile happens in GitHub Actions. If a build step fails, the log will point to the exact file and line.

## Project structure

```
lib/
  main.dart, app.dart          app start-up, theme, localisation
  core/                        constants, theme, units, time formatting, geo maths,
                               PNG encoder, XML helpers, strings (en/bn)
  data/
    db/                        SQLite: settings, favourites, recents, HTTP cache, alert log
    net/                       Dio client, retry, offline cache
    models/                    places, forecasts, warnings, settings
    sources/                   provider adapters (Open-Meteo, Nominatim, BMD, NWS, GDACS, imagery)
  state/providers.dart         Riverpod providers and controllers
  services/                    location, notifications, moon phase, alert engine, background checks
  features/
    map/                       map screen, layer catalogue, grid loader, frame renderer
                               (background isolate), particles, overlays, legend, timeline
    forecast/                  overview, meteogram, airgram, model comparison
    radar/                     radar & satellite playback, storm tracks
    favorites/, alerts/, search/, settings/, shell/, common/
android/                       Android project (Gradle KTS, AGP 9.3, Kotlin 2.4, minSdk 24)
test/                          unit tests
.github/workflows/build.yml    CI: analyze, test, debug APK, release APK, AAB
```

## Tech stack

Flutter 3.50 · Dart 3 · Material 3 (`material_ui`) · Riverpod 3 · Dio 5 · MapLibre (`maplibre_gl` 0.28) · fl_chart 1.3 · sqflite · flutter_local_notifications · WorkManager · geolocator.
