import 'package:flutter/material.dart';
import 'feed_log_store.dart';

class FeedLogModal extends StatefulWidget {
  const FeedLogModal({super.key});

  @override
  State<FeedLogModal> createState() => _FeedLogModalState();
}

class _FeedLogModalState extends State<FeedLogModal> {
  List<FeedLogItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final items = await FeedLogStore.load();
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
    final item = FeedLogItem(
      id: id,
      dateMs: draft.date.millisecondsSinceEpoch,
      food: draft.food.trim(),
      amount: draft.amount.trim(),
      note: draft.note.trim(),
    );

    final next = [item, ..._items]..sort((a, b) => b.dateMs.compareTo(a.dateMs));
    setState(() => _items = next);
    await FeedLogStore.saveAll(next);
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry?'),
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
    await FeedLogStore.saveAll(next);
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
                  'Entries: ${_items.length}',
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
                      'No feeding logs yet.\nTap "Add" to create your first entry.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final line2 = [
                        if (it.food.isNotEmpty) 'Food: ${it.food}',
                        if (it.amount.isNotEmpty) 'Amount: ${it.amount}',
                        if (it.note.isNotEmpty) 'Note: ${it.note}',
                      ].join(' · ');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(_fmtDate(it.date), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: line2.isEmpty ? null : Text(line2),
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
  final String food;
  final String amount;
  final String note;
  _Draft(this.date, this.food, this.amount, this.note);
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  DateTime _date = DateTime.now();
  final _foodCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _foodCtrl.dispose();
    _amountCtrl.dispose();
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
      title: const Text('Add feeding log'),
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
            controller: _foodCtrl,
            decoration: const InputDecoration(
              labelText: 'Food / Brand (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Amount (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _Draft(_date, _foodCtrl.text, _amountCtrl.text, _noteCtrl.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
