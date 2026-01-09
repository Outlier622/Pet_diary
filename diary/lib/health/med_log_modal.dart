import 'package:flutter/material.dart';
import 'med_log_store.dart';

class MedLogModal extends StatefulWidget {
  const MedLogModal({super.key});

  @override
  State<MedLogModal> createState() => _MedLogModalState();
}

class _MedLogModalState extends State<MedLogModal> {
  List<MedLogItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final items = await MedLogStore.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _add() async {
    final draft = await showDialog<_Draft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _AddDialog(),
    );
    if (draft == null) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final item = MedLogItem(
      id: id,
      dateMs: draft.date.millisecondsSinceEpoch,
      medName: draft.medName.trim(),
      dosage: draft.dosage.trim(),
      schedule: draft.schedule.trim(),
      note: draft.note.trim(),
    );

    final next = [item, ..._items]..sort((a, b) => b.dateMs.compareTo(a.dateMs));
    setState(() => _items = next);
    await MedLogStore.saveAll(next);
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    final next = _items.where((e) => e.id != id).toList();
    setState(() => _items = next);
    await MedLogStore.saveAll(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }

    return SizedBox(
      height: 460,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ${_items.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'No medication logs yet.\nTap "Add" to create one.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final parts = <String>[];
                      parts.add('Medication: ${it.medName}');
                      if (it.dosage.isNotEmpty) parts.add('Dosage: ${it.dosage}');
                      if (it.schedule.isNotEmpty) parts.add('Schedule: ${it.schedule}');
                      if (it.note.isNotEmpty) parts.add('Notes: ${it.note}');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          _fmtDate(it.date),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(parts.join(' · ')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(it.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Draft {
  final DateTime date;
  final String medName;
  final String dosage;
  final String schedule;
  final String note;

  _Draft(this.date, this.medName, this.dosage, this.schedule, this.note);
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  DateTime _date = DateTime.now();
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _scheduleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Medication Log'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Date:'),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _pickDate, child: Text(_fmt(_date))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Medication name (required)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dosageCtrl,
            decoration: const InputDecoration(
              labelText: 'Dosage (optional, e.g., 1/2 tablet, 2 ml)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _scheduleCtrl,
            decoration: const InputDecoration(
              labelText: 'Schedule (optional, e.g., once daily)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Medication name is required'), duration: Duration(seconds: 1)),
              );
              return;
            }
            Navigator.pop(
              context,
              _Draft(_date, name, _dosageCtrl.text, _scheduleCtrl.text, _noteCtrl.text),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
