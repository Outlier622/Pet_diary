import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GroomLogItem {
  final String id;
  final int dateMs;
  final String note;

  GroomLogItem({
    required this.id,
    required this.dateMs,
    required this.note,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'note': note,
      };

  static GroomLogItem fromJson(Map<String, dynamic> m) => GroomLogItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int) ? m['dateMs'] as int : int.parse(m['dateMs'].toString()),
        note: (m['note'] ?? '').toString(),
      );
}

class GroomLogStore {
  static const _key = 'hygiene_groom_logs_v1';

  static Future<List<GroomLogItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list
          .map((e) => GroomLogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<GroomLogItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);
  }
}
