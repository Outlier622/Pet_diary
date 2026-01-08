import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/timeline_dao.dart';
class WeightLogItem {
  final String id;
  final int dateMs;
  final double weightKg;
  final String note;

  WeightLogItem({
    required this.id,
    required this.dateMs,
    required this.weightKg,
    required this.note,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'weightKg': weightKg,
        'note': note,
      };

  static WeightLogItem fromJson(Map<String, dynamic> m) => WeightLogItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int) ? m['dateMs'] as int : int.parse(m['dateMs'].toString()),
        weightKg: double.tryParse((m['weightKg'] ?? '0').toString()) ?? 0.0,
        note: (m['note'] ?? '').toString(),
      );
}

class WeightLogStore {
  static const _key = 'health_weight_logs_v1';

  static Future<List<WeightLogItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list
          .map((e) => WeightLogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<WeightLogItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);

    await TimelineDao.instance.syncTypeFromSnapshot<WeightLogItem>(
      type: 'weight',
      items: items,
      idOf: (x) => x.id,
      dateMsOf: (x) => x.dateMs,
      payloadOf: (x) => x.toJson(),
    );
  }
}
