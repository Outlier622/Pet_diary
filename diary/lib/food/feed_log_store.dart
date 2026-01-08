import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/timeline_dao.dart';

class FeedLogItem {
  final String id;
  final int dateMs;
  final String food; 
  final String amount;
  final String note;

  FeedLogItem({
    required this.id,
    required this.dateMs,
    required this.food,
    required this.amount,
    required this.note,
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateMs': dateMs,
        'food': food,
        'amount': amount,
        'note': note,
      };

  static FeedLogItem fromJson(Map<String, dynamic> m) => FeedLogItem(
        id: (m['id'] ?? '').toString(),
        dateMs: (m['dateMs'] is int) ? m['dateMs'] as int : int.parse(m['dateMs'].toString()),
        food: (m['food'] ?? '').toString(),
        amount: (m['amount'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
      );
}

class FeedLogStore {
  static const _key = 'food_feed_logs_v1';

  static Future<List<FeedLogItem>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final items = list
          .map((e) => FeedLogItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      items.sort((a, b) => b.dateMs.compareTo(a.dateMs));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<FeedLogItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key, encoded);

    await TimelineDao.instance.syncTypeFromSnapshot<FeedLogItem>(
      type: 'feed',
      items: items,
      idOf: (x) => x.id,
      dateMsOf: (x) => x.dateMs,
      payloadOf: (x) => x.toJson(),
    );
  }
}
