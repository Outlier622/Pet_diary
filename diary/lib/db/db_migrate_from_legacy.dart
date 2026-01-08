// lib/db/db_migrate_from_legacy.dart
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../album/album_store.dart';

// food
import '../food/feed_log_store.dart';
import '../food/water_log_store.dart';
import '../food/allergy_pref_store.dart';

// health
import '../health/weight_log_store.dart';
import '../health/med_log_store.dart';
import '../health/visit_vax_log_store.dart';

// hygiene
import '../hygiene/bath_log_store.dart';
import '../hygiene/deworm_log_store.dart';
import '../hygiene/groom_log_store.dart';
import '../hygiene/clean_reminder_store.dart';

import 'app_db.dart';
import 'schema.dart';

class MigrateResult {
  final Map<String, int> migratedByType;
  const MigrateResult(this.migratedByType);

  int get total => migratedByType.values.fold(0, (a, b) => a + b);

  @override
  String toString() => migratedByType.entries.map((e) => '${e.key}=${e.value}').join(', ');
}

class DbMigrateFromLegacy {
  static const String defaultPetId = 'default_pet';

  static Future<String> dbPath() async {
    final db = await AppDb.instance.database;
    return db.path;
  }

  static Future<int> countEventsByType(String type) async {
    final db = await AppDb.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${DbSchema.tEvents} '
      'WHERE ${DbSchema.ePetId}=? AND ${DbSchema.eType}=?',
      [defaultPetId, type],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // -------------------------
  // Safe helpers (no assumptions)
  // -------------------------

  static DateTime _dtFromMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  /// 尽力从对象里推断发生时间：dateMs / dueMs / nextMs / timeMs / occurredMs
  static DateTime _inferOccurredAt(dynamic o) {
    final now = DateTime.now();

    int? ms;
    try {
      final v = o.dateMs;
      if (v is int) ms = v;
      if (v is String) ms = int.tryParse(v);
    } catch (_) {}

    ms ??= _tryReadInt(o, () => o.dueMs);
    ms ??= _tryReadInt(o, () => o.nextMs);
    ms ??= _tryReadInt(o, () => o.timeMs);
    ms ??= _tryReadInt(o, () => o.occurredMs);
    ms ??= _tryReadInt(o, () => o.createdMs);

    return (ms != null) ? _dtFromMs(ms) : now;
  }

  static int? _tryReadInt(dynamic o, dynamic Function() getter) {
    try {
      final v = getter();
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
    } catch (_) {}
    return null;
  }

  /// 尽力拿到 id：o.id，否则用 fallback
  static String _inferId(dynamic o, String fallback) {
    try {
      final v = o.id;
      if (v != null) return v.toString();
    } catch (_) {}
    return fallback;
  }

  /// 尽力拿到 payload：toJson / toMap，否则 raw string
  static Map<String, dynamic> _inferPayload(dynamic o, {Map<String, dynamic>? extra}) {
    Map<String, dynamic>? m;

    try {
      final v = o.toJson();
      if (v is Map) m = Map<String, dynamic>.from(v.cast<String, dynamic>());
    } catch (_) {}

    if (m == null) {
      try {
        final v = o.toMap();
        if (v is Map) m = Map<String, dynamic>.from(v.cast<String, dynamic>());
      } catch (_) {}
    }

    m ??= {'raw': o.toString()};

    if (extra != null && extra.isNotEmpty) {
      m.addAll(extra);
    }
    return m;
  }

  // -------------------------
  // Main migration
  // -------------------------

  static Future<MigrateResult> migrateAll({void Function(String msg)? log}) async {
    log ??= (_) {};
    final db = await AppDb.instance.database;

    log('Loading legacy stores...');

    // album
    final albums = await AlbumStore.load();

    // food
    final feeds = await FeedLogStore.load();
    final waters = await WaterLogStore.load();

    // ⚠️ AllergyPref 是“设置类”，通常是单个对象，不是 List
    final allergyPref = await AllergyPrefStore.load();

    // health
    final weights = await WeightLogStore.load();
    final meds = await MedLogStore.load();
    final visitVax = await VisitVaxLogStore.load();

    // hygiene
    final baths = await BathLogStore.load();
    final deworms = await DewormLogStore.load();
    final grooms = await GroomLogStore.load();
    final cleanReminders = await CleanReminderStore.load();

    log('Loaded counts: '
        'album=${albums.length}, '
        'feed=${feeds.length}, water=${waters.length}, allergy_pref=1, '
        'weight=${weights.length}, med=${meds.length}, visit_vax=${visitVax.length}, '
        'bath=${baths.length}, deworm=${deworms.length}, groom=${grooms.length}, clean_reminder=${cleanReminders.length}');

    final Map<String, int> migrated = {
      'album': 0,
      'feed': 0,
      'water': 0,
      'allergy_pref': 0,
      'weight': 0,
      'med': 0,
      'visit_vax': 0,
      'bath': 0,
      'deworm': 0,
      'groom': 0,
      'clean_reminder': 0,
    };

    await db.transaction((txn) async {
      final batch = txn.batch();
      final nowIso = DateTime.now().toIso8601String();

      void upsertEvent({
        required String id,
        required String type,
        required DateTime occurredAt,
        required Map<String, dynamic> payload,
      }) {
        batch.insert(
          DbSchema.tEvents,
          {
            DbSchema.eId: id,
            DbSchema.ePetId: defaultPetId,
            DbSchema.eType: type,
            DbSchema.eOccurredAt: occurredAt.toIso8601String(),
            DbSchema.ePayloadJson: jsonEncode(payload),
            DbSchema.eSyncStatus: DbSchema.syncSynced,
            DbSchema.eUpdatedAt: nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        migrated[type] = (migrated[type] ?? 0) + 1;
      }

      // -------------------------
      // album (AlbumItem 没有 toJson -> 手写 payload)
      // -------------------------
      for (final a in albums) {
        upsertEvent(
          id: a.id,
          type: 'album',
          occurredAt: DateTime.fromMillisecondsSinceEpoch(a.dateMs),
          payload: {
            'id': a.id,
            'dateMs': a.dateMs,
            'imagePath': a.imagePath,
            'note': a.note,
          },
        );
      }

      // -------------------------
      // food: feed (你给的 FeedLogItem 有 toJson/dateMs)
      // -------------------------
      for (final f in feeds) {
        upsertEvent(
          id: f.id,
          type: 'feed',
          occurredAt: DateTime.fromMillisecondsSinceEpoch(f.dateMs),
          payload: f.toJson(),
        );
      }

      // -------------------------
      // food: water (不假设字段，用 dynamic 推断)
      // -------------------------
      for (final w in waters) {
        final dyn = w as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'water_${DateTime.now().microsecondsSinceEpoch}'),
          type: 'water',
          occurredAt: _inferOccurredAt(dyn),
          payload: _inferPayload(dyn),
        );
      }

      // -------------------------
      // food: allergy_pref (单对象设置类)
      // 用固定 id，重复跑会 replace，不会重复插入
      // -------------------------
      if (allergyPref != null) {
        final dyn = allergyPref as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'allergy_pref'),
          type: 'allergy_pref',
          occurredAt: _inferOccurredAt(dyn), // 没有时间就 now
          payload: _inferPayload(dyn),
        );
      }

      // -------------------------
      // health logs (dynamic 推断，保证字段名不同也能迁)
      // -------------------------
      for (final w in weights) {
        final dyn = w as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'weight_${DateTime.now().microsecondsSinceEpoch}'),
          type: 'weight',
          occurredAt: _inferOccurredAt(dyn),
          payload: _inferPayload(dyn),
        );
      }

      for (final m in meds) {
        final dyn = m as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'med_${DateTime.now().microsecondsSinceEpoch}'),
          type: 'med',
          occurredAt: _inferOccurredAt(dyn),
          payload: _inferPayload(dyn),
        );
      }

      for (final v in visitVax) {
        final dyn = v as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'visit_vax_${DateTime.now().microsecondsSinceEpoch}'),
          type: 'visit_vax',
          occurredAt: _inferOccurredAt(dyn),
          payload: _inferPayload(dyn),
        );
      }

      // -------------------------
      // hygiene logs
      // -------------------------
      for (final b in baths) {
        final dyn = b as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'bath_${DateTime.now().microsecondsSinceEpoch}'),
          type: 'bath',
          occurredAt: _inferOccurredAt(dyn),
          payload: _inferPayload(dyn),
        );
      }

      for (final d in deworms) {
        final dyn = d as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'deworm_${DateTime.now().microsecondsSinceEpoch}'),
          type: 'deworm',
          occurredAt: _inferOccurredAt(dyn),
          payload: _inferPayload(dyn),
        );
      }

      for (final g in grooms) {
        final dyn = g as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'groom_${DateTime.now().microsecondsSinceEpoch}'),
          type: 'groom',
          occurredAt: _inferOccurredAt(dyn),
          payload: _inferPayload(dyn),
        );
      }

      // clean_reminder：你报错说没有 dateMs，所以也用推断
      for (final r in cleanReminders) {
        final dyn = r as dynamic;
        upsertEvent(
          id: _inferId(dyn, 'clean_reminder_${DateTime.now().microsecondsSinceEpoch}'),
          type: 'clean_reminder',
          occurredAt: _inferOccurredAt(dyn),
          payload: _inferPayload(dyn),
        );
      }

      await batch.commit(noResult: true);
    });

    log('Migration upsert done. ${migrated.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    return MigrateResult(migrated);
  }
}
