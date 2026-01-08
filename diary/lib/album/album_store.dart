import 'dart:convert';
import '../db/timeline_dao.dart';

class AlbumItem {
  final String id;
  final int dateMs;
  final String imagePath;
  final String note;

  AlbumItem({
    required this.id,
    required this.dateMs,
    required this.imagePath,
    required this.note,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);
}

class AlbumStore {
  static final TimelineDao _dao = TimelineDao.instance;

  static const String _type = 'album';

  static Future<List<AlbumItem>> load() async {
    final rows = await _dao.listByType(_type);

    return rows.map((r) {
      final payload = jsonDecode(r['payloadJson'] as String);
      return AlbumItem(
        id: r['id'] as String,
        dateMs: DateTime.parse(r['occurredAt'] as String).millisecondsSinceEpoch,
        imagePath: payload['imagePath'] as String,
        note: payload['note'] as String? ?? '',
      );
    }).toList();
  }

  static Future<void> saveAll(List<AlbumItem> items) async {
    for (final it in items) {
      await _dao.upsert(
        id: it.id,
        type: _type,
        occurredAt: DateTime.fromMillisecondsSinceEpoch(it.dateMs),
        payload: {
          'imagePath': it.imagePath,
          'note': it.note,
        },
      );
    }
  }

  static Future<void> delete(AlbumItem it) async {
    await _dao.delete(it.id);
  }
}
