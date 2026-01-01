import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'album_store.dart';

class AlbumTimelineModal extends StatefulWidget {
  const AlbumTimelineModal({super.key});

  @override
  State<AlbumTimelineModal> createState() => _AlbumTimelineModalState();
}

class _AlbumTimelineModalState extends State<AlbumTimelineModal> {
  List<AlbumItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final items = await AlbumStore.load();
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

  Future<String?> _pickAndCopyImageToAppDir() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final albumDir = Directory('${dir.path}/album');
    if (!await albumDir.exists()) {
      await albumDir.create(recursive: true);
    }

    final ext = x.name.contains('.') ? x.name.split('.').last : 'jpg';
    final filename = 'img_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}.$ext';
    final target = File('${albumDir.path}/$filename');

    await File(x.path).copy(target.path);
    return target.path;
  }

  Future<void> _add() async {
    final draft = await showDialog<_Draft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _AddDialog(),
    );
    if (draft == null) return;

    final imgPath = await _pickAndCopyImageToAppDir();
    if (imgPath == null) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final item = AlbumItem(
      id: id,
      dateMs: draft.date.millisecondsSinceEpoch,
      imagePath: imgPath,
      note: draft.note.trim(),
    );

    final next = [item, ..._items]..sort((a, b) => b.dateMs.compareTo(a.dateMs));
    setState(() => _items = next);
    await AlbumStore.saveAll(next);
  }

  Future<void> _delete(AlbumItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除这条相册记录？'),
        content: const Text('图片文件也会一并删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;

    // 删除文件（尽力而为）
    try {
      final f = File(it.imagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}

    final next = _items.where((e) => e.id != it.id).toList();
    setState(() => _items = next);
    await AlbumStore.saveAll(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }

    return SizedBox(
      height: 520,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('记录数：${_items.length}', style: const TextStyle(fontWeight: FontWeight.w600))),
              FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('添加')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('暂无相册记录\n点击右上角“添加”创建', textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _TimelineCard(
                      item: _items[i],
                      fmtDate: _fmtDate,
                      onDelete: _delete,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final AlbumItem item;
  final String Function(DateTime) fmtDate;
  final Future<void> Function(AlbumItem) onDelete;

  const _TimelineCard({
    required this.item,
    required this.fmtDate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧时间轴
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Container(width: 2, height: 120, color: Colors.black12),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 右侧内容卡
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(fmtDate(item.date), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => onDelete(item),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除',
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.file(
                        File(item.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Text('图片无法加载'),
                        ),
                      ),
                    ),
                  ),
                  if (item.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(item.note.trim()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Draft {
  final DateTime date;
  final String note;
  _Draft(this.date, this.note);
}

class _AddDialog extends StatefulWidget {
  const _AddDialog();

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  DateTime _date = DateTime.now();
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
      title: const Text('新增相册记录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('日期：'),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _pickDate, child: Text(_fmt(_date))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('下一步会让你选择一张图片。', style: TextStyle(color: Colors.black54)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _Draft(_date, _noteCtrl.text)),
          child: const Text('继续选图'),
        ),
      ],
    );
  }
}
