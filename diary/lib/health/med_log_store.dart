import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/timeline_dao.dart';
class MedLogItem {
  final String id;
  final int dateMs;

  final String medName;
  final String dosage;
  final String schedule;
  final String note;

  MedLogItem({
    required this.id,
    required this.dateMs,
    required this.medName,
    required this.dosage,
    required this.schedule,
    required this.note,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'medName': medName,
        'dosage': dosage,
        'schedule': schedule,
        'note': note,
      };

  static MedLogItem fromJson(Map<String, dynamic> m) => MedLogItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int) ? m['dateMs'] as int : int.parse(m['dateMs'].toString()),
        medName: (m['medName'] ?? '').toString(),
        dosage: (m['dosage'] ?? '').toString(),
        schedule: (m['schedule'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
      );
}

class MedLogStore {
  static const _key = 'health_med_logs_v1';

  static Future<List<MedLogItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list
          .map((e) => MedLogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<MedLogItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);

    await TimelineDao.instance.syncTypeFromSnapshot<MedLogItem>(
      type: 'med',
      items: items,
      idOf: (x) => x.id,
      dateMsOf: (x) => x.dateMs,
      payloadOf: (x) => x.toJson(),
    );
  }
}
