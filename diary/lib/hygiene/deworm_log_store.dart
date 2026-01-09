import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/timeline_dao.dart';

enum DewormType { internal, external }

String dewormTypeToText(DewormType t) {
  return t == DewormType.internal ? 'Internal' : 'External';
}

DewormType dewormTypeFromText(String s) {
  final v = s.toLowerCase();
  if (v == 'external') return DewormType.external;
  return DewormType.internal;
}

class DewormLogItem {
  final String id;
  final int dateMs;
  final DewormType type;
  final String note;

  DewormLogItem({
    required this.id,
    required this.dateMs,
    required this.type,
    required this.note,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'type': dewormTypeToText(type),
        'note': note,
      };

  static DewormLogItem fromJson(Map<String, dynamic> m) => DewormLogItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int)
            ? m['dateMs'] as int
            : int.parse(m['dateMs'].toString()),
        type: dewormTypeFromText((m['type'] ?? 'Internal').toString()),
        note: (m['note'] ?? '').toString(),
      );
}

class DewormLogStore {
  static const _key = 'hygiene_deworm_logs_v1';

  static Future<List<DewormLogItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list
          .map((e) => DewormLogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<DewormLogItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);

    await TimelineDao.instance.syncTypeFromSnapshot<DewormLogItem>(
      type: 'deworm',
      items: items,
      idOf: (x) => x.id,
      dateMsOf: (x) => x.dateMs,
      payloadOf: (x) => x.toJson(),
    );
  }
}
