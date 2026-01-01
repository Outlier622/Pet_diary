import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WaterLogItem {
  final String id;
  final int dateMs;
  final String amount; // e.g. 200ml（可空）
  final String note;

  WaterLogItem({
    required this.id,
    required this.dateMs,
    required this.amount,
    required this.note,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'amount': amount,
        'note': note,
      };

  static WaterLogItem fromJson(Map<String, dynamic> m) => WaterLogItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int) ? m['dateMs'] as int : int.parse(m['dateMs'].toString()),
        amount: (m['amount'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
      );
}

class WaterLogStore {
  static const _key = 'food_water_logs_v1';

  static Future<List<WaterLogItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list
          .map((e) => WaterLogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<WaterLogItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);
  }
}
