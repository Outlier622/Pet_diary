import 'package:flutter/material.dart';
import 'deworm_log_store.dart';

class DewormLogModal extends StatefulWidget {
  const DewormLogModal({super.key});

  @override
  State<DewormLogModal> createState() => _DewormLogModalState();
}

class _DewormLogModalState extends State<DewormLogModal> {
  List<DewormLogItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final items = await DewormLogStore.load();
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
    final item = DewormLogItem(
      id: id,
      dateMs: draft.date.millisecondsSinceEpoch,
      type: draft.type,
      note: draft.note.trim(),
    );

    final next = [item, ..._items]..sort((a, b) => b.dateMs.compareTo(a.dateMs));
    setState(() => _items = next);
    await DewormLogStore.saveAll(next);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deworming log added'), duration: Duration(seconds: 1)),
    );
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
    await DewormLogStore.saveAll(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }

    return SizedBox(
      height: 440,
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
                      'No deworming logs yet.\nTap "Add" to create your first entry.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          '${_fmtDate(it.date)}  ·  ${dewormTypeToText(it.type)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: it.note.isEmpty ? null : Text(it.note),
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
  final DewormType type;
  final String note;
  _Draft(this.date, this.type, this.note);
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  DateTime _date = DateTime.now();
  DewormType _type = DewormType.internal;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
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
      title: const Text('Add Deworming Log'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Date:'),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _pickDate,
                child: Text(_fmt(_date)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Type:'),
              const SizedBox(width: 8),
              DropdownButton<DewormType>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: DewormType.internal, child: Text('Internal')),
                  DropdownMenuItem(value: DewormType.external, child: Text('External')),
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
            controller: _noteCtrl,
            maxLines: 3,
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
          onPressed: () => Navigator.pop(context, _Draft(_date, _type, _noteCtrl.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
