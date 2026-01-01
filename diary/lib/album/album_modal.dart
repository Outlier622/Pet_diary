import 'package:flutter/material.dart';
import '../center_modal.dart';
import 'album_timeline_modal.dart';

class AlbumModal extends StatelessWidget {
  const AlbumModal({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Column(
        children: [
          const Text(
            '成长相册',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                CenterModal.show(
                  context,
                  title: '成长相册（时间轴）',
                  child: const AlbumTimelineModal(),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(16),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_album_outlined, size: 40),
                    SizedBox(height: 10),
                    Text('时间轴展示', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('按日期记录照片与备注', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
