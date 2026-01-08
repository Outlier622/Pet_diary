import 'dart:convert';
import 'package:sqflite_common/sqflite.dart';

import 'app_db.dart';
import 'schema.dart';

class TimelineDao {
  TimelineDao._();
  static final TimelineDao instance = TimelineDao._();

  static const String defaultPetId = 'default_pet';

  Future<Database> get _db async => AppDb.instance.database;

  Future<void> syncTypeFromSnapshot<T>({
    required String type,
    String petId = defaultPetId,
    required List<T> items,
    required String Function(T) idOf,
    required int Function(T) dateMsOf,
    required Map<String, dynamic> Function(T) payloadOf,
  }) 
  
    async {
    final db = await _db;

    final existing = await db.query(
      DbSchema.tEvents,
      columns: [DbSchema.eId],
      where: '${DbSchema.ePetId}=? AND ${DbSchema.eType}=?',
      whereArgs: [petId, type],
    );
    final existingIds = existing.map((r) => (r[DbSchema.eId] ?? '').toString()).where((s) => s.isNotEmpty).toSet();

    final incomingIds = <String>{};
    final batch = db.batch();

    for (final it in items) {
      final id = idOf(it);
      if (id.isEmpty) continue;
      incomingIds.add(id);

      final occurredAt = DateTime.fromMillisecondsSinceEpoch(dateMsOf(it)).toIso8601String();
      final payloadJson = jsonEncode(payloadOf(it));

      batch.insert(
        DbSchema.tEvents,
        {
          DbSchema.eId: id,
          DbSchema.ePetId: petId,
          DbSchema.eType: type,
          DbSchema.eOccurredAt: occurredAt,
          DbSchema.ePayloadJson: payloadJson,
          DbSchema.eSyncStatus: 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final oldId in existingIds.difference(incomingIds)) {
      batch.delete(
        DbSchema.tEvents,
        where: '${DbSchema.ePetId}=? AND ${DbSchema.eType}=? AND ${DbSchema.eId}=?',
        whereArgs: [petId, type, oldId],
      );
    }

    await batch.commit(noResult: true);
  }
    /// Return rows for a given type, newest first.
  /// Row keys match what AlbumStore expects: id, occurredAt, payloadJson.
  Future<List<Map<String, Object?>>> listByType(
    String type, {
    String petId = defaultPetId,
  }) async {
    final db = await _db;
    return db.query(
      DbSchema.tEvents,
      columns: [
        DbSchema.eId,
        DbSchema.eOccurredAt,
        DbSchema.ePayloadJson,
      ],
      where: '${DbSchema.ePetId}=? AND ${DbSchema.eType}=?',
      whereArgs: [petId, type],
      orderBy: '${DbSchema.eOccurredAt} DESC',
    );
  }

  /// Insert or replace one row by (petId, type, id).
  Future<void> upsert({
    required String id,
    required String type,
    DateTime? occurredAt,
    required Map<String, dynamic> payload,
    String petId = defaultPetId,
  }) async {
    final db = await _db;
    final occurredAtIso = (occurredAt ?? DateTime.now()).toIso8601String();
    final payloadJson = jsonEncode(payload);

    await db.insert(
      DbSchema.tEvents,
      {
        DbSchema.eId: id,
        DbSchema.ePetId: petId,
        DbSchema.eType: type,
        DbSchema.eOccurredAt: occurredAtIso,
        DbSchema.ePayloadJson: payloadJson,
        DbSchema.eSyncStatus: 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete by id (and petId).
  /// Note: If you want to delete only within a type, add `type` as parameter.
  Future<void> delete(
    String id, {
    String petId = defaultPetId,
  }) async {
    final db = await _db;
    await db.delete(
      DbSchema.tEvents,
      where: '${DbSchema.ePetId}=? AND ${DbSchema.eId}=?',
      whereArgs: [petId, id],
    );
  }

}
