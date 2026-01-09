import 'package:flutter/material.dart';
import 'clean_reminder_store.dart';
import 'clean_reminder_service.dart';
import 'clean_reminder_editor_modal.dart';

class CleanReminderModal extends StatefulWidget {
  const CleanReminderModal({super.key});

  @override
  State<CleanReminderModal> createState() => _CleanReminderModalState();
}

class _CleanReminderModalState extends State<CleanReminderModal> {
  bool _loading = true;
  List<CleanReminder> _items = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final list = await CleanReminderStore.load();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });

      await CleanReminderService.instance.init().timeout(const Duration(seconds: 6));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // ignore: avoid_print
      print('CleanReminder init failed: $e');
    }
  }

  Future<void> _saveAll(List<CleanReminder> next) async {
    setState(() => _items = next);
    await CleanReminderStore.save(next);
  }

  Future<void> _applySchedule(CleanReminder r) async {
    final title = 'Cleaning Reminder';
    final body = r.note.isEmpty ? 'Time to clean your pet.' : r.note;

    if (r.type == CleanReminderType.once) {
      if (r.onceDateMs == null) return;
      final when = DateTime.fromMillisecondsSinceEpoch(r.onceDateMs!);
      await CleanReminderService.instance.scheduleOnce(
        id: r.baseNotifId,
        when: when,
        title: title,
        body: body,
      );
    } else {
      for (final wd in r.weekdays) {
        await CleanReminderService.instance.scheduleWeekly(
          id: r.baseNotifId + wd,
          weekday: wd,
          hour: r.hour,
          minute: r.minute,
          title: title,
          body: body,
        );
      }
    }
  }

  Future<void> _toggle(CleanReminder r, bool enabled) async {
    final updated = CleanReminder(
      id: r.id,
      baseNotifId: r.baseNotifId,
      enabled: enabled,
      type: r.type,
      hour: r.hour,
      minute: r.minute,
      onceDateMs: r.onceDateMs,
      weekdays: r.weekdays,
      note: r.note,
    );

    final next = [updated, ..._items.where((e) => e.id != r.id)];
    await _saveAll(next);

    await CleanReminderService.instance.cancelAll(updated.allNotifIds());
    if (!enabled) return;
    await _applySchedule(updated);
  }

  Future<void> _delete(CleanReminder r) async {
    await CleanReminderService.instance.cancelAll(r.allNotifIds());
    final next = _items.where((e) => e.id != r.id).toList();
    await _saveAll(next);
  }

  String _time(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String _weekdayText(List<int> wds) {
    const map = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final s = [...wds]..sort();
    return s.map((e) => map[e] ?? e.toString()).join(' ');
  }

  String _formatNext(DateTime? t) {
    if (t == null) return 'Next: not set / expired';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayT = DateTime(t.year, t.month, t.day);
    final diffDays = dayT.difference(today).inDays;

    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');

    String prefix;
    if (diffDays == 0) {
      prefix = 'Today';
    } else if (diffDays == 1) {
      prefix = 'Tomorrow';
    } else if (diffDays == 2) {
      prefix = 'In two days';
    } else {
      prefix = '${t.month}/${t.day}';
    }

    return 'Next: $prefix $hh:$mm';
  }

  Future<void> _addNew() async {
    final baseId = 100000 + (DateTime.now().millisecondsSinceEpoch % 50000);
    final draft = CleanReminder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      baseNotifId: baseId,
      enabled: true,
      type: CleanReminderType.weekly,
      hour: 9,
      minute: 0,
      onceDateMs: null,
      weekdays: const [1],
      note: '',
    );

    final result = await showDialog<CleanReminder>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CleanReminderEditorModal(
        initial: draft,
        isNew: true,
      ),
    );

    if (result == null) return;

    final next = [result, ..._items.where((e) => e.id != result.id)];
    await _saveAll(next);

    await CleanReminderService.instance.cancelAll(result.allNotifIds());
    if (result.enabled) {
      await _applySchedule(result);
    }
  }

  Future<void> _edit(CleanReminder r) async {
    final result = await showDialog<CleanReminderEditorResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CleanReminderEditorModal(
        initial: r,
        isNew: false,
      ),
    );

    if (result == null) return;

    if (result.deleted) {
      await _delete(r);
      return;
    }

    final updated = result.item!;
    final next = [updated, ..._items.where((e) => e.id != updated.id)];
    await _saveAll(next);

    await CleanReminderService.instance.cancelAll(r.allNotifIds());
    await CleanReminderService.instance.cancelAll(updated.allNotifIds());
    if (updated.enabled) {
      await _applySchedule(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final h = MediaQuery.of(context).size.height * 0.80;

    return SafeArea(
      child: SizedBox(
        height: h,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cleaning Reminders',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addNew,
                    icon: const Icon(Icons.add),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No reminders yet.\nTap "New" to create one.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = _items[i];
                          final line1 = r.type == CleanReminderType.once
                              ? 'One-time'
                              : 'Weekly · ${_weekdayText(r.weekdays)} · ${_time(r.hour, r.minute)}';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Switch(
                              value: r.enabled,
                              onChanged: (v) => _toggle(r, v),
                            ),
                            title: Text(
                              line1,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(r.note.isEmpty ? 'Default message' : r.note),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(r),
                            ),
                            onTap: () => _edit(r),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
