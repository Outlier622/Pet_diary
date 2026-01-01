import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'imagePath': imagePath,
        'note': note,
      };

  static AlbumItem fromJson(Map<String, dynamic> m) => AlbumItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int) ? m['dateMs'] as int : int.parse(m['dateMs'].toString()),
        imagePath: (m['imagePath'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
      );
}

class AlbumStore {
  static const _key = 'album_timeline_v1';

  static Future<List<AlbumItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list
          .map((e) => AlbumItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<AlbumItem> items) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
