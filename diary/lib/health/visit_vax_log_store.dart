import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum VisitVaxType { visit, vaccine }

String vvTypeToText(VisitVaxType t) => t == VisitVaxType.visit ? '就医' : '疫苗';
VisitVaxType vvTypeFromText(String s) => (s == '疫苗') ? VisitVaxType.vaccine : VisitVaxType.visit;

class VisitVaxLogItem {
  final String id;
  final int dateMs;
  final VisitVaxType type;
  final String title; // 医院/疫苗名/项目
  final String note;

  VisitVaxLogItem({
    required this.id,
    required this.dateMs,
    required this.type,
    required this.title,
    required this.note,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'type': vvTypeToText(type),
        'title': title,
        'note': note,
      };

  static VisitVaxLogItem fromJson(Map<String, dynamic> m) => VisitVaxLogItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int) ? m['dateMs'] as int : int.parse(m['dateMs'].toString()),
        type: vvTypeFromText((m['type'] ?? '就医').toString()),
        title: (m['title'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
      );
}

class VisitVaxLogStore {
  static const _key = 'health_visit_vax_logs_v1';

  static Future<List<VisitVaxLogItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list
          .map((e) => VisitVaxLogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<VisitVaxLogItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);
  }
}
