import 'package:flutter/material.dart';
import 'clean_reminder_store.dart';

class CleanReminderEditorResult {
  final bool deleted;
  final CleanReminder? item;

  const CleanReminderEditorResult._({required this.deleted, required this.item});

  const CleanReminderEditorResult.saved(CleanReminder item)
      : this._(deleted: false, item: item);

  const CleanReminderEditorResult.deleted()
      : this._(deleted: true, item: null);
}

class CleanReminderEditorModal extends StatefulWidget {
  final CleanReminder initial;
  final bool isNew;

  const CleanReminderEditorModal({
    super.key,
    required this.initial,
    required this.isNew,
  });

  @override
  State<CleanReminderEditorModal> createState() => _CleanReminderEditorModalState();
}

class _CleanReminderEditorModalState extends State<CleanReminderEditorModal> {
  late CleanReminderType _type;
  late bool _enabled;
  late int _hour;
  late int _minute;
  int? _onceDateMs;
  late Set<int> _weekdays;
  late TextEditingController _noteCtl;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _type = r.type;
    _enabled = r.enabled;
    _hour = r.hour;
    _minute = r.minute;
    _onceDateMs = r.onceDateMs;
    _weekdays = r.weekdays.toSet();
    _noteCtl = TextEditingController(text: r.note);
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    super.dispose();
  }

  String _timeText() =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  String _onceDateText() {
    if (_onceDateMs == null) return 'No date selected';
    final d = DateTime.fromMillisecondsSinceEpoch(_onceDateMs!);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final init = _onceDateMs == null ? now : DateTime.fromMillisecondsSinceEpoch(_onceDateMs!);

    final picked = await showDatePicker(
      context: context,
      initialDate: init.isBefore(now) ? now : init,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;

    final combined = DateTime(picked.year, picked.month, picked.day, _hour, _minute);
    setState(() => _onceDateMs = combined.millisecondsSinceEpoch);
  }

  void _toggleWeekday(int wd) {
    setState(() {
      if (_weekdays.contains(wd)) {
        _weekdays.remove(wd);
      } else {
        _weekdays.add(wd);
      }
    });
  }

  bool get _canSave {
    if (_type == CleanReminderType.once) {
      return _onceDateMs != null;
    }
    return _weekdays.isNotEmpty;
  }

  CleanReminder _buildResult() {
    int? onceMs = _onceDateMs;
    if (_type == CleanReminderType.once && onceMs != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(onceMs);
      onceMs = DateTime(d.year, d.month, d.day, _hour, _minute).millisecondsSinceEpoch;
    }

    return CleanReminder(
      id: widget.initial.id,
      baseNotifId: widget.initial.baseNotifId,
      enabled: _enabled,
      type: _type,
      hour: _hour,
      minute: _minute,
      onceDateMs: _type == CleanReminderType.once ? onceMs : null,
      weekdays: _type == CleanReminderType.weekly ? (_weekdays.toList()..sort()) : const [],
      note: _noteCtl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isNew ? 'New Cleaning Reminder' : 'Edit Cleaning Reminder';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = MediaQuery.of(context).size.height * 0.80;

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: maxH,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  Row(
                    children: [
                      const Text('Type', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      SegmentedButton<CleanReminderType>(
                        segments: const [
                          ButtonSegment(value: CleanReminderType.once, label: Text('One-time')),
                          ButtonSegment(value: CleanReminderType.weekly, label: Text('Weekly')),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) {
                          final v = s.first;
                          setState(() {
                            _type = v;
                            if (_type == CleanReminderType.once && _onceDateMs == null) {
                              final now = DateTime.now();
                              _onceDateMs = DateTime(now.year, now.month, now.day, _hour, _minute)
                                  .millisecondsSinceEpoch;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Time', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_timeText()),
                    trailing: OutlinedButton(
                      onPressed: _pickTime,
                      child: const Text('Select'),
                    ),
                  ),
                  if (_type == CleanReminderType.once) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(_onceDateText()),
                      trailing: OutlinedButton(
                        onPressed: _pickDate,
                        child: const Text('Select'),
                      ),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child: Text(
                          'Repeat on',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        _wdChip(1, 'Mon'),
                        _wdChip(2, 'Tue'),
                        _wdChip(3, 'Wed'),
                        _wdChip(4, 'Thu'),
                        _wdChip(5, 'Fri'),
                        _wdChip(6, 'Sat'),
                        _wdChip(7, 'Sun'),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtl,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'e.g., wipe paws, clean outer ears...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (!widget.isNew)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context, const CleanReminderEditorResult.deleted());
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _canSave
                            ? () {
                                final r = _buildResult();
                                Navigator.pop(
                                  context,
                                  widget.isNew ? r : CleanReminderEditorResult.saved(r),
                                );
                              }
                            : null,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _wdChip(int wd, String label) {
    final selected = _weekdays.contains(wd);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _toggleWeekday(wd),
    );
  }
}
