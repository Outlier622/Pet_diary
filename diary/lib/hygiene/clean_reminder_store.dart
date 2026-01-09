import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'clean_reminder_store.dart';
import 'clean_reminder_service.dart';
enum CleanReminderType { once, weekly }

class CleanReminder {
  final String id;
  final int baseNotifId;
  final bool enabled;

  final CleanReminderType type;
  final int hour;
  final int minute;

  final int? onceDateMs;
  final List<int> weekdays; 
  final String note;

  CleanReminder({
    required this.id,
    required this.baseNotifId,
    required this.enabled,
    required this.type,
    required this.hour,
    required this.minute,
    required this.onceDateMs,
    required this.weekdays,
    required this.note,
  });
  CleanReminder copyWith({
  String? id,
  int? baseNotifId,
  bool? enabled,
  CleanReminderType? type,
  int? hour,
  int? minute,
  int? onceDateMs,
  List<int>? weekdays,
  String? note,
}) {
  return CleanReminder(
    id: id ?? this.id,
    baseNotifId: baseNotifId ?? this.baseNotifId,
    enabled: enabled ?? this.enabled,
    type: type ?? this.type,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    onceDateMs: onceDateMs ?? this.onceDateMs,
    weekdays: weekdays ?? this.weekdays,
    note: note ?? this.note,
  );
}


  List<int> allNotifIds() {
    if (type == CleanReminderType.once) {
      return [baseNotifId];
    }
    return weekdays.map((int w) => baseNotifId + w).toList();
  }
  DateTime? nextTriggerTime({DateTime? now}) {
  final DateTime baseNow = (now ?? DateTime.now());

  if (type == CleanReminderType.once) {
    if (onceDateMs == null) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(onceDateMs!);
    return t.isAfter(baseNow) ? t : null;
  }

  if (weekdays.isEmpty) return null;

  final sorted = [...weekdays]..sort();
  final nowWd = baseNow.weekday;

  DateTime candidateForWeekday(int wd, int addDays) {
    final day = DateTime(
      baseNow.year,
      baseNow.month,
      baseNow.day,
      hour,
      minute,
    ).add(Duration(days: addDays));
    return day;
  }

  if (sorted.contains(nowWd)) {
    final today = DateTime(baseNow.year, baseNow.month, baseNow.day, hour, minute);
    if (today.isAfter(baseNow)) return today;
  }

  int bestDelta = 9999;
  for (final wd in sorted) {
    int delta = wd - nowWd;
    if (delta <= 0) delta += 7;
    if (delta < bestDelta) bestDelta = delta;
  }

  return candidateForWeekday(nowWd, bestDelta);
}


  Map<String, dynamic> toJson() => {
        'id': id,
        'baseNotifId': baseNotifId,
        'enabled': enabled,
        'type': type.name,
        'hour': hour,
        'minute': minute,
        'onceDateMs': onceDateMs,
        'weekdays': weekdays,
        'note': note,
      };

  static CleanReminder fromJson(Map<String, dynamic> m) {
    return CleanReminder(
      id: m['id'] as String,
      baseNotifId: m['baseNotifId'] as int,
      enabled: m['enabled'] as bool,
      type: m['type'] == 'once'
          ? CleanReminderType.once
          : CleanReminderType.weekly,
      hour: m['hour'] as int,
      minute: m['minute'] as int,
      onceDateMs: m['onceDateMs'] as int?,
      weekdays: List<int>.from(m['weekdays'] ?? []),
      note: m['note'] ?? '',
    );
  }
}

class CleanReminderStore {
  static const String _key = 'clean_reminders_v1';

  static Future<List<CleanReminder>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    final List data = jsonDecode(raw);
    return data
        .map((e) => CleanReminder.fromJson(e))
        .toList();
  }

  static Future<void> save(List<CleanReminder> items) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
