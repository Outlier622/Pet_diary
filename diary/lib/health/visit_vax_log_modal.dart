import 'package:flutter/material.dart';
import 'visit_vax_log_store.dart';

class VisitVaxLogModal extends StatefulWidget {
  const VisitVaxLogModal({super.key});

  @override
  State<VisitVaxLogModal> createState() => _VisitVaxLogModalState();
}

class _VisitVaxLogModalState extends State<VisitVaxLogModal> {
  List<VisitVaxLogItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final items = await VisitVaxLogStore.load();
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
    final item = VisitVaxLogItem(
      id: id,
      dateMs: draft.date.millisecondsSinceEpoch,
      type: draft.type,
      title: draft.title.trim(),
      note: draft.note.trim(),
    );

    final next = [item, ..._items]..sort((a, b) => b.dateMs.compareTo(a.dateMs));
    setState(() => _items = next);
    await VisitVaxLogStore.saveAll(next);
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
    await VisitVaxLogStore.saveAll(next);
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
                      'No entries yet.\nTap "Add" to create one.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final tag = vvTypeToText(it.type);
                      final sub = [
                        '$tag: ${it.title}',
                        if (it.note.isNotEmpty) 'Notes: ${it.note}',
                      ].join(' · ');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          _fmtDate(it.date),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(sub),
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
  final VisitVaxType type;
  final String title;
  final String note;

  _Draft(this.date, this.type, this.title, this.note);
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  DateTime _date = DateTime.now();
  VisitVaxType _type = VisitVaxType.visit;
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
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
      title: const Text('Add Entry'),
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
          Row(
            children: [
              const Text('Type:'),
              const SizedBox(width: 8),
              DropdownButton<VisitVaxType>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: VisitVaxType.visit, child: Text('Vet Visit')),
                  DropdownMenuItem(value: VisitVaxType.vaccine, child: Text('Vaccine')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _type = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: _type == VisitVaxType.visit
                  ? 'Clinic / Procedure (required)'
                  : 'Vaccine name (required)',
              border: const OutlineInputBorder(),
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
            final t = _titleCtrl.text.trim();
            if (t.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This field is required'), duration: Duration(seconds: 1)),
              );
              return;
            }
            Navigator.pop(context, _Draft(_date, _type, t, _noteCtrl.text));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
