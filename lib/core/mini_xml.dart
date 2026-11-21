/// Tiny tolerant XML helpers for RSS and CAP (Common Alerting Protocol)
/// feeds. Handles namespace prefixes (`cap:headline` or `headline`), CDATA
/// and the common character entities. Not a general XML parser.
class MiniXml {
  MiniXml._();

  static final Map<String, RegExp> _cache = {};

  static RegExp _elementRe(String tag) => _cache.putIfAbsent(
        tag,
        () => RegExp(
          '<(?:[\\w.-]+:)?$tag(?:\\s[^>]*)?>([\\s\\S]*?)</(?:[\\w.-]+:)?$tag\\s*>',
        ),
      );

  /// Inner XML of every `<tag>` element.
  static List<String> elements(String xml, String tag) =>
      _elementRe(tag).allMatches(xml).map((m) => m.group(1) ?? '').toList();

  /// Decoded text of the first `<tag>` element, or null.
  static String? text(String xml, String tag) {
    final m = _elementRe(tag).firstMatch(xml);
    if (m == null) return null;
    final v = decode(m.group(1) ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static List<String> texts(String xml, String tag) => elements(xml, tag)
      .map((e) => decode(e).trim())
      .where((e) => e.isNotEmpty)
      .toList();

  static String decode(String s) {
    var out = s.replaceAllMapped(
      RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>'),
      (m) => m.group(1) ?? '',
    );
    out = out
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
    out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    return out.replaceAll('&amp;', '&');
  }

  /// Removes HTML tags (for descriptions that embed markup).
  static String stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Parses RFC 822 dates used by RSS, e.g. `Thu, 19 Nov 2026 04:34:00 +0000`.
  static DateTime? parseRfc822(String? s) {
    if (s == null) return null;
    final m = RegExp(
            r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|GMT|UTC|Z)?')
        .firstMatch(s);
    if (m == null) return DateTime.tryParse(s)?.toUtc();
    final month = _months[m.group(2)!.toLowerCase()];
    if (month == null) return null;
    var dt = DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    );
    final tz = m.group(7);
    if (tz != null && (tz.startsWith('+') || tz.startsWith('-'))) {
      final sign = tz.startsWith('-') ? -1 : 1;
      final hh = int.parse(tz.substring(1, 3));
      final mm = int.parse(tz.substring(3, 5));
      dt = dt.subtract(Duration(minutes: sign * (hh * 60 + mm)));
    }
    return dt;
  }

  /// Parses ISO-8601 timestamps such as `2026-05-14T04:59:00-00:00`.
  static DateTime? parseIso(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s.trim())?.toUtc();
  }
}
