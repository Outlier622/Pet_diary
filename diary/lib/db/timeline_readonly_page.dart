import 'dart:convert';
import 'package:flutter/material.dart';

import 'app_db.dart';
import 'schema.dart';

enum _Range { all, days30, days7 }

class TimelineReadonlyPage extends StatefulWidget {
  const TimelineReadonlyPage({super.key});

  @override
  State<TimelineReadonlyPage> createState() => _TimelineReadonlyPageState();
}

class _TimelineReadonlyPageState extends State<TimelineReadonlyPage> {
  static const String _petId = 'default_pet';

  bool _loading = true;
  String _log = 'Ready.';
  _Range _range = _Range.all;

  int _total = 0;
  List<_TypeCount> _typeCounts = [];

  List<_EventRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _setLog(String s) => setState(() => _log = s);

  String _rangeLabel(_Range r) {
    switch (r) {
      case _Range.all:
        return 'All';
      case _Range.days30:
        return '30 days';
      case _Range.days7:
        return '7 days';
    }
  }

  DateTime? _rangeStart(_Range r) {
    final now = DateTime.now();
    switch (r) {
      case _Range.all:
        return null;
      case _Range.days30:
        return now.subtract(const Duration(days: 30));
      case _Range.days7:
        return now.subtract(const Duration(days: 7));
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _log = 'Loading...';
    });

    try {
      final db = await AppDb.instance.database;

      final start = _rangeStart(_range);
      final startIso = start?.toIso8601String();

      final totalRows = await db.rawQuery(
        startIso == null
            ? '''
SELECT COUNT(*) as c
FROM ${DbSchema.tEvents}
WHERE ${DbSchema.ePetId} = ?
'''
            : '''
SELECT COUNT(*) as c
FROM ${DbSchema.tEvents}
WHERE ${DbSchema.ePetId} = ?
  AND ${DbSchema.eOccurredAt} >= ?
''',
        startIso == null ? [_petId] : [_petId, startIso],
      );
      final total = (totalRows.first['c'] as int?) ?? 0;

      final typeRows = await db.rawQuery(
        startIso == null
            ? '''
SELECT ${DbSchema.eType} as t, COUNT(*) as c
FROM ${DbSchema.tEvents}
WHERE ${DbSchema.ePetId} = ?
GROUP BY ${DbSchema.eType}
ORDER BY c DESC
'''
            : '''
SELECT ${DbSchema.eType} as t, COUNT(*) as c
FROM ${DbSchema.tEvents}
WHERE ${DbSchema.ePetId} = ?
  AND ${DbSchema.eOccurredAt} >= ?
GROUP BY ${DbSchema.eType}
ORDER BY c DESC
''',
        startIso == null ? [_petId] : [_petId, startIso],
      );

      final counts = typeRows
          .map((m) => _TypeCount(
                type: (m['t'] ?? '').toString(),
                count: (m['c'] as int?) ?? 0,
              ))
          .toList();

      final list = await db.query(
        DbSchema.tEvents,
        columns: [
          DbSchema.eId,
          DbSchema.eType,
          DbSchema.eOccurredAt,
          DbSchema.ePayloadJson,
        ],
        where: startIso == null
            ? '${DbSchema.ePetId}=?'
            : '${DbSchema.ePetId}=? AND ${DbSchema.eOccurredAt}>=?',
        whereArgs: startIso == null ? [_petId] : [_petId, startIso],
        orderBy: '${DbSchema.eOccurredAt} DESC',
        limit: 300,
      );

      final rows = list.map((m) => _EventRow.fromDb(m)).toList();

      setState(() {
        _total = total;
        _typeCounts = counts;
        _rows = rows;
        _loading = false;
        _log = 'Loaded: total=$_total, types=${_typeCounts.length}, eventsShown=${_rows.length}.';
      });
    } catch (e) {
      setState(() {
        _total = 0;
        _typeCounts = [];
        _rows = [];
        _loading = false;
        _log = 'ERROR: $e';
      });
    }
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  IconData _iconForType(String t) {
    switch (t) {
      case 'album':
        return Icons.photo;
      case 'feed':
        return Icons.restaurant;
      case 'water':
        return Icons.water_drop;
      case 'weight':
        return Icons.monitor_weight;
      case 'med':
        return Icons.medication;
      case 'visit_vax':
        return Icons.local_hospital;
      case 'bath':
        return Icons.bathtub;
      case 'deworm':
        return Icons.bug_report;
      case 'groom':
        return Icons.content_cut;
      case 'clean_reminder':
        return Icons.notifications_active;
      case 'allergy_pref':
        return Icons.report_gmailerrorred;
      default:
        return Icons.event_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = _rangeLabel(_range);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SQLite Timeline (Read-only)'),
        actions: [
          PopupMenuButton<_Range>(
            tooltip: 'Range',
            initialValue: _range,
            onSelected: (r) async {
              setState(() => _range = r);
              await _reload();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Range.all, child: Text('All')),
              PopupMenuItem(value: _Range.days30, child: Text('Last 30 days')),
              PopupMenuItem(value: _Range.days7, child: Text('Last 7 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  rangeText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _reload,
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log: $_log'),
            const SizedBox(height: 12),

            _OverviewCard(
              loading: _loading,
              total: _total,
              typeCounts: _typeCounts,
              iconForType: _iconForType,
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? const Center(
                          child: Text(
                            'No events found in this range.\nAdd some data first (e.g., via demo writes or migration).',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (_, i) => _EventCard(
                            row: _rows[i],
                            fmt: _fmt,
                            iconForType: _iconForType,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCount {
  final String type;
  final int count;
  _TypeCount({required this.type, required this.count});
}

class _OverviewCard extends StatelessWidget {
  final bool loading;
  final int total;
  final List<_TypeCount> typeCounts;
  final IconData Function(String type) iconForType;

  const _OverviewCard({
    required this.loading,
    required this.total,
    required this.typeCounts,
    required this.iconForType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: loading
          ? const SizedBox(
              height: 72,
              child: Center(child: Text('Loading overview...')),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Overview', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('Total: $total', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                if (typeCounts.isEmpty)
                  const Text('No event types in this range.')
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: typeCounts.take(12).map((tc) {
                      return _TypePill(
                        icon: iconForType(tc.type),
                        label: tc.type,
                        count: tc.count,
                      );
                    }).toList(),
                  ),
              ],
            ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _TypePill({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EventRow {
  final String id;
  final String type;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  _EventRow({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.payload,
  });

  static _EventRow fromDb(Map<String, Object?> m) {
    final id = (m[DbSchema.eId] ?? '').toString();
    final type = (m[DbSchema.eType] ?? '').toString();
    final occurredAtStr = (m[DbSchema.eOccurredAt] ?? '').toString();

    DateTime occurredAt;
    try {
      occurredAt = DateTime.parse(occurredAtStr);
    } catch (_) {
      occurredAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final payloadRaw = m[DbSchema.ePayloadJson];
    Map<String, dynamic> payload = {};
    if (payloadRaw != null) {
      try {
        payload = (jsonDecode(payloadRaw.toString()) as Map).cast<String, dynamic>();
      } catch (_) {
        payload = {'raw': payloadRaw.toString()};
      }
    }

    return _EventRow(id: id, type: type, occurredAt: occurredAt, payload: payload);
  }
}

class _EventCard extends StatelessWidget {
  final _EventRow row;
  final String Function(DateTime) fmt;
  final IconData Function(String type) iconForType;

  const _EventCard({
    required this.row,
    required this.fmt,
    required this.iconForType,
  });

  String _titleForType(String t) {
    switch (t) {
      case 'album':
        return 'Album';
      case 'feed':
        return 'Feed';
      case 'water':
        return 'Water';
      case 'weight':
        return 'Weight';
      case 'med':
        return 'Medication';
      case 'visit_vax':
        return 'Visit or Vaccine';
      case 'bath':
        return 'Bath';
      case 'deworm':
        return 'Deworm';
      case 'groom':
        return 'Groom';
      case 'clean_reminder':
        return 'Clean Reminder';
      case 'allergy_pref':
        return 'Allergy & Preferences';
      default:
        return t;
    }
  }

  String _previewPayload(String type, Map<String, dynamic> p) {
    String pick(String k) => (p[k] ?? '').toString().trim();

    switch (type) {
      case 'feed':
        final food = pick('food');
        final amount = pick('amount');
        final note = pick('note');
        return [if (food.isNotEmpty) food, if (amount.isNotEmpty) amount, if (note.isNotEmpty) note]
            .join(' | ');
      case 'water':
        final amount = pick('amount');
        final note = pick('note');
        return [if (amount.isNotEmpty) amount, if (note.isNotEmpty) note].join(' | ');
      case 'weight':
        final kg = pick('weightKg');
        final w = kg.isNotEmpty ? kg : pick('weight');
        final note = pick('note');
        return [if (w.isNotEmpty) w, if (note.isNotEmpty) note].join(' | ');
      case 'med':
        final name = pick('medName');
        final dosage = pick('dosage');
        final schedule = pick('schedule');
        final note = pick('note');
        return [
          if (name.isNotEmpty) name,
          if (dosage.isNotEmpty) dosage,
          if (schedule.isNotEmpty) schedule,
          if (note.isNotEmpty) note,
        ].join(' | ');
      case 'album':
        final note = pick('note');
        final img = pick('imagePath');
        return [if (note.isNotEmpty) note, if (img.isNotEmpty) 'image saved'].join(' | ');
      default:
        if (p.isEmpty) return '';
        final keys = p.keys.take(6).toList();
        return keys.map((k) => '$k=${p[k]}').join(' | ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _previewPayload(row.type, row.payload);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              child: Icon(iconForType(row.type)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _titleForType(row.type),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(fmt(row.occurredAt), style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (subtitle.isNotEmpty) Text(subtitle),
                  const SizedBox(height: 6),
                  Text(
                    'id=${row.id}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
