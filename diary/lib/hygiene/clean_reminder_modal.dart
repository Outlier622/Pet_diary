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
      // 先加载本地数据，避免真机一直转圈
      final list = await CleanReminderStore.load();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });

      // 通知服务后台初始化，避免卡 UI
      await CleanReminderService.instance
          .init()
          .timeout(const Duration(seconds: 6));
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
    final title = '清洁提醒';
    final body = r.note.isEmpty ? '该给宠物做清洁啦' : r.note;

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
      1: '周一',
      2: '周二',
      3: '周三',
      4: '周四',
      5: '周五',
      6: '周六',
      7: '周日'
    };
    final s = [...wds]..sort();
    return s.map((e) => map[e] ?? e.toString()).join(' ');
  }

  String _formatNext(DateTime? t) {
    if (t == null) return '下次：未设置/已过期';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayT = DateTime(t.year, t.month, t.day);
    final diffDays = dayT.difference(today).inDays;

    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');

    String prefix;
    if (diffDays == 0) {
      prefix = '今天';
    } else if (diffDays == 1) {
      prefix = '明天';
    } else if (diffDays == 2) {
      prefix = '后天';
    } else {
      prefix = '${t.month}月${t.day}日';
    }

    return '下次：$prefix $hh:$mm';
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

    if (result == null) return; // 用户取消，不新增

    // 保存 + 排程
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

    // 重新应用通知
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
                    '清洁提醒',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addNew,
                  icon: const Icon(Icons.add),
                  label: const Text('新增'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Text('暂无提醒\n点击右上角新增', textAlign: TextAlign.center),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = _items[i];
                        final line1 = r.type == CleanReminderType.once
                            ? '仅一次'
                            : '每周 · ${_weekdayText(r.weekdays)} · ${_time(r.hour, r.minute)}';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Switch(
                            value: r.enabled,
                            onChanged: (v) => _toggle(r, v),
                          ),
                          title: Text(line1, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(r.note.isEmpty ? '默认文案' : r.note),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(r),
                          ),
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
