/// Icon categories for WMO weather interpretation codes (WW) used by
/// Open-Meteo.
enum WxIcon {
  clear,
  mainlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  rain,
  heavyRain,
  freezingRain,
  snow,
  showers,
  snowShowers,
  thunder,
  thunderHail,
}

class WeatherCodes {
  WeatherCodes._();

  static const Set<int> known = {
    0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75,
    77, 80, 81, 82, 85, 86, 95, 96, 99,
  };

  static WxIcon icon(int code) {
    switch (code) {
      case 0:
        return WxIcon.clear;
      case 1:
        return WxIcon.mainlyClear;
      case 2:
        return WxIcon.partlyCloudy;
      case 3:
        return WxIcon.overcast;
      case 45:
      case 48:
        return WxIcon.fog;
      case 51:
      case 53:
      case 55:
        return WxIcon.drizzle;
      case 56:
      case 57:
      case 66:
      case 67:
        return WxIcon.freezingRain;
      case 61:
      case 63:
        return WxIcon.rain;
      case 65:
        return WxIcon.heavyRain;
      case 71:
      case 73:
      case 75:
      case 77:
        return WxIcon.snow;
      case 80:
      case 81:
      case 82:
        return WxIcon.showers;
      case 85:
      case 86:
        return WxIcon.snowShowers;
      case 95:
        return WxIcon.thunder;
      case 96:
      case 99:
        return WxIcon.thunderHail;
      default:
        return WxIcon.overcast;
    }
  }

  static bool isThunder(int code) => code >= 95;

  static bool isPrecipitation(int code) => code >= 51;
}
