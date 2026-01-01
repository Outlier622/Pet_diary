import 'dart:io';
import 'package:flutter/material.dart';

class PetProfilePage extends StatelessWidget {
  final File? bgImageFile;
  final String? breedText;

  const PetProfilePage({
    super.key,
    this.bgImageFile,
    this.breedText,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = bgImageFile != null;
    final showBreed = (breedText != null && breedText!.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('宠物详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 顶部卡片：背景预览
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.grey.shade200,
              image: hasBg
                  ? DecorationImage(
                      image: FileImage(bgImageFile!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !hasBg
                ? const Center(
                    child: Text(
                      '尚未设置背景图\n回到主页长按“宠物区域”选择背景',
                      textAlign: TextAlign.center,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 14),

          // 识别结果
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.pets, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      showBreed ? (breedText!) : '尚未识别到品种（你可以先不管）',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 下面做“信息架构占位”：以后你再把具体记录页面接进来
          const Text(
            '功能入口（占位）',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          _EntryTile(
            icon: Icons.shower_outlined,
            title: '卫生管理',
            subtitle: '洗澡 / 梳毛清洁 / 驱虫 / 清洁提醒',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('卫生管理：后面再接入')),
              );
            },
          ),
          _EntryTile(
            icon: Icons.restaurant_outlined,
            title: '饮食管理',
            subtitle: '饮食记录 / 过敏与偏好等',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('饮食管理：后面再接入')),
              );
            },
          ),
          _EntryTile(
            icon: Icons.favorite_border,
            title: '健康状态',
            subtitle: '体重 / 症状 / 用药等（后面做）',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('健康状态：后面再做')),
              );
            },
          ),
          _EntryTile(
            icon: Icons.photo_library_outlined,
            title: '成长相册',
            subtitle: '时间轴展示（后面做）',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('成长相册：后面再做')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
