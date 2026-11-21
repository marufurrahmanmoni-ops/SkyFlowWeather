import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/place.dart';

/// Local SQLite storage: settings, favourites, recent searches, the HTTP
/// response cache and the alert notification log.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _version = 1;

  static Future<AppDatabase> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'skyflow.db'),
      version: _version,
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute(
            'CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        batch.execute('CREATE TABLE favorites ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'place_json TEXT NOT NULL, '
            'custom_name TEXT, '
            'sort_order INTEGER NOT NULL DEFAULT 0, '
            'alert_json TEXT, '
            'created_at INTEGER NOT NULL)');
        batch.execute('CREATE TABLE recents ('
            'place_id TEXT PRIMARY KEY, '
            'place_json TEXT NOT NULL, '
            'used_at INTEGER NOT NULL)');
        batch.execute('CREATE TABLE http_cache ('
            'key TEXT PRIMARY KEY, '
            'body TEXT NOT NULL, '
            'fetched_at INTEGER NOT NULL)');
        batch.execute('CREATE TABLE alert_log ('
            'key TEXT PRIMARY KEY, '
            'notified_at INTEGER NOT NULL)');
        await batch.commit(noResult: true);
      },
    );
    return AppDatabase._(db);
  }

  // ------------------------------------------------------------------ kv

  Future<String?> getValue(String key) async {
    final rows = await db.query('kv', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setValue(String key, String value) async {
    await db.insert('kv', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------------ favourites

  Future<List<FavoritePlace>> favorites() async {
    final rows = await db.query('favorites', orderBy: 'sort_order ASC, id ASC');
    final result = <FavoritePlace>[];
    for (final r in rows) {
      final place = Place.tryFromJson(_decode(r['place_json'] as String?));
      if (place == null) continue;
      result.add(FavoritePlace(
        id: r['id'] as int,
        place: place,
        customName: r['custom_name'] as String?,
        sortOrder: r['sort_order'] as int? ?? 0,
        alertRules: AlertRules.fromJson(_decode(r['alert_json'] as String?)),
      ));
    }
    return result;
  }

  Future<int> addFavorite(Place place) async {
    final existing = await favorites();
    for (final f in existing) {
      if (_samePlace(f.place, place)) return f.id;
    }
    final maxOrder = existing.isEmpty
        ? 0
        : existing.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    return db.insert('favorites', {
      'place_json': jsonEncode(place.toJson()),
      'custom_name': null,
      'sort_order': maxOrder,
      'alert_json': jsonEncode(const AlertRules().toJson()),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> renameFavorite(int id, String? name) async {
    await db.update('favorites', {'custom_name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> removeFavorite(int id) async {
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateAlertRules(int id, AlertRules rules) async {
    await db.update('favorites', {'alert_json': jsonEncode(rules.toJson())},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderFavorites(List<int> idsInOrder) async {
    final batch = db.batch();
    for (var i = 0; i < idsInOrder.length; i++) {
      batch.update('favorites', {'sort_order': i},
          where: 'id = ?', whereArgs: [idsInOrder[i]]);
    }
    await batch.commit(noResult: true);
  }

  static bool _samePlace(Place a, Place b) {
    if (a.id == b.id) return true;
    return (a.lat - b.lat).abs() < 0.005 && (a.lon - b.lon).abs() < 0.005;
  }

  // --------------------------------------------------------------- recents

  Future<List<Place>> recents({int limit = 12}) async {
    final rows = await db.query('recents', orderBy: 'used_at DESC', limit: limit);
    return rows
        .map((r) => Place.tryFromJson(_decode(r['place_json'] as String?)))
        .whereType<Place>()
        .toList();
  }

  Future<void> addRecent(Place place) async {
    await db.insert(
      'recents',
      {
        'place_id': place.id,
        'place_json': jsonEncode(place.toJson()),
        'used_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Keep the table small.
    await db.execute(
        'DELETE FROM recents WHERE place_id NOT IN (SELECT place_id FROM recents ORDER BY used_at DESC LIMIT 30)');
  }

  Future<void> clearRecents() => db.delete('recents');

  // ------------------------------------------------------------ http cache

  Future<CachedBody?> cached(String key) async {
    final rows =
        await db.query('http_cache', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return CachedBody(
      rows.first['body'] as String,
      DateTime.fromMillisecondsSinceEpoch(rows.first['fetched_at'] as int),
    );
  }

  Future<void> putCached(String key, String body) async {
    await db.insert(
      'http_cache',
      {'key': key, 'body': body, 'fetched_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes cache entries older than [maxAge].
  Future<void> pruneCache(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    await db.delete('http_cache', where: 'fetched_at < ?', whereArgs: [cutoff]);
  }

  Future<void> clearCache() => db.delete('http_cache');

  // ------------------------------------------------------------- alert log

  Future<bool> wasNotified(String key) async {
    final rows =
        await db.query('alert_log', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> markNotified(String key) async {
    await db.insert(
      'alert_log',
      {'key': key, 'notified_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final cutoff =
        DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    await db.delete('alert_log', where: 'notified_at < ?', whereArgs: [cutoff]);
  }

  static Object? _decode(String? s) {
    if (s == null) return null;
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }
}

class CachedBody {
  const CachedBody(this.body, this.fetchedAt);
  final String body;
  final DateTime fetchedAt;
}
