import 'package:intl/intl.dart';

/// Date and time formatting that respects the app language and 12/24-hour
/// setting.
///
/// Forecast times are shown in the forecast location's own time zone: we
/// shift the UTC instant by the location's UTC offset and format it as UTC,
/// so the device time zone never leaks in.
class TimeFmt {
  TimeFmt({required this.locale, required this.use24h});

  final String locale;
  final bool use24h;

  late final DateFormat _hm = DateFormat(use24h ? 'HH:mm' : 'h:mm a', locale);
  late final DateFormat _h = DateFormat(use24h ? 'HH' : 'h a', locale);
  late final DateFormat _weekday = DateFormat('EEE', locale);
  late final DateFormat _weekdayLong = DateFormat('EEEE', locale);
  late final DateFormat _dayMonth = DateFormat('d MMM', locale);
  late final DateFormat _weekdayHm =
      DateFormat(use24h ? 'EEE HH:mm' : 'EEE h:mm a', locale);
  late final DateFormat _full =
      DateFormat(use24h ? 'EEE d MMM, HH:mm' : 'EEE d MMM, h:mm a', locale);

  /// Wall-clock time at a location for a unix timestamp (seconds).
  static DateTime atLocation(int unixSeconds, int utcOffsetSeconds) {
    return DateTime.fromMillisecondsSinceEpoch(
      (unixSeconds + utcOffsetSeconds) * 1000,
      isUtc: true,
    );
  }

  /// Device-local time for a unix timestamp (seconds).
  static DateTime local(int unixSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);

  String hm(DateTime t) => _hm.format(t);
  String hour(DateTime t) => _h.format(t);
  String weekday(DateTime t) => _weekday.format(t);
  String weekdayLong(DateTime t) => _weekdayLong.format(t);
  String dayMonth(DateTime t) => _dayMonth.format(t);
  String weekdayHm(DateTime t) => _weekdayHm.format(t);
  String full(DateTime t) => _full.format(t);

  /// "Today"/"Tomorrow"/weekday label relative to [reference] (both in the
  /// same clock).
  String relativeDay(DateTime t, DateTime reference,
      {required String today, required String tomorrow}) {
    final d0 = DateTime.utc(reference.year, reference.month, reference.day);
    final d1 = DateTime.utc(t.year, t.month, t.day);
    final diff = d1.difference(d0).inDays;
    if (diff == 0) return today;
    if (diff == 1) return tomorrow;
    return weekday(t);
  }

  /// Compact "x min ago" style age, localized digits.
  String age(DateTime then, DateTime now) {
    final d = now.difference(then);
    final nf = NumberFormat.decimalPattern(locale);
    final bn = locale == 'bn';
    if (d.inMinutes < 1) return bn ? 'এইমাত্র' : 'just now';
    if (d.inMinutes < 60) {
      return bn ? '${nf.format(d.inMinutes)} মিনিট আগে' : '${d.inMinutes} min ago';
    }
    if (d.inHours < 24) {
      return bn ? '${nf.format(d.inHours)} ঘণ্টা আগে' : '${d.inHours} h ago';
    }
    return bn ? '${nf.format(d.inDays)} দিন আগে' : '${d.inDays} d ago';
  }

  String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final nf = NumberFormat.decimalPattern(locale);
    if (locale == 'bn') return '${nf.format(h)} ঘ ${nf.format(m)} মি';
    return '${h}h ${m}m';
  }
}
