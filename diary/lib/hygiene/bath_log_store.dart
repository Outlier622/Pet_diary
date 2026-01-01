import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BathLogItem {
  final String id; // simple unique id
  final int dateMs; // date in millis (local midnight or chosen time)
  final String note;

  BathLogItem({
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

  static BathLogItem fromJson(Map<String, dynamic> m) => BathLogItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int) ? m['dateMs'] as int : int.parse(m['dateMs'].toString()),
        note: (m['note'] ?? '').toString(),
      );
}

class BathLogStore {
  static const _key = 'hygiene_bath_logs_v1';

  static Future<List<BathLogItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list.map((e) => BathLogItem.fromJson((e as Map).cast<String, dynamic>())).toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs)); // newest first
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<BathLogItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);
  }
}
