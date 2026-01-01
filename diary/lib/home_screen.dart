import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pet_profile_page.dart';
import 'edge_buttons.dart';
import 'quick_panel.dart';
import '/hygiene/hygiene_modal.dart';
import '/food/food_modal.dart';
import 'health/health_modal.dart';
import 'album/album_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _kBgPathKey = 'bg_image_path';

  final _picker = ImagePicker();
  File? _bgFile;

  // 点击空白区域隐藏/恢复 UI
  bool _uiHidden = false;

  static const String _baseUrl = "http://10.12.0.109:5000";
  static const String _apiKey = "dev-key";

  @override
  void initState() {
    super.initState();
    _loadSavedBackground();
  }

  // 长按中心区域：选择背景 + 持久化 +（可选）识别
  Future<void> _pickAndPersistBackground() async {
    try {
      final XFile? x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (x == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${appDir.path}/backgrounds');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }

      final ext = (x.name.contains('.')) ? x.name.split('.').last : 'jpg';
      final targetPath = '${bgDir.path}/bg.$ext';
      final saved = await File(x.path).copy(targetPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kBgPathKey, saved.path);

      if (!mounted) return;
      setState(() => _bgFile = saved);

      // 你要的话可以打开：选背景后顺便请求后端识别（用现成 /breed）
      // await _classifyAndToast(saved);

      _snack('背景已更新');
    } catch (e) {
      if (!mounted) return;
      _snack('选择/保存失败：$e');
    }
  }

  Future<void> _classifyAndToast(File file) async {
    try {
      final info = await _uploadAndClassifyBackground(file);
      if (!mounted) return;

      final animal = (info['animal'] ?? '').toString();
      final breed = (info['breed'] ?? '').toString();
      final conf = (info['confidence'] ?? '').toString();

      _snack("识别结果：$animal · $breed（$conf%）");
    } catch (e) {
      if (!mounted) return;
      _snack("识别失败：$e");
    }
  }

  Future<Map<String, dynamic>> _uploadAndClassifyBackground(File file) async {
    // 用你现成后端 route：/breed（返回 animal/breed/confidence）
    final uri = Uri.parse("$_baseUrl/breed");

    final req = http.MultipartRequest('POST', uri);
    req.headers['X-API-Key'] = _apiKey;
    req.files.add(await http.MultipartFile.fromPath('image', file.path));

    final resp = await req.send();
    final body = await resp.stream.bytesToString();

    if (resp.statusCode != 200) {
      debugPrint("BG classify failed: ${resp.statusCode} body=$body");
      throw "HTTP ${resp.statusCode}: $body";
    }

    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<void> _loadSavedBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kBgPathKey);
    if (path == null) return;

    final f = File(path);
    if (await f.exists()) {
      if (!mounted) return;
      setState(() => _bgFile = f);
    } else {
      await prefs.remove(_kBgPathKey);
    }
  }

  Future<void> _clearBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kBgPathKey);

    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
      await prefs.remove(_kBgPathKey);
    }

    if (!mounted) return;
    setState(() => _bgFile = null);

    _snack('已恢复默认背景');
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }

  void _openPetProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PetProfilePage()),
    );
  }

  void _toggleUiHidden() {
    setState(() => _uiHidden = !_uiHidden);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 背景永远显示
            Positioned.fill(
              child: _bgFile == null
                  ? const ColoredBox(color: Color(0xFFBDBDBD))
                  : Image.file(_bgFile!, fit: BoxFit.cover),
            ),

            // 遮罩永远显示（你也可以选择：隐藏 UI 时不加遮罩）
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withOpacity(0.18)),
            ),

            // 关键：点击空白区域切换隐藏/恢复
            // 注意：把它放在“所有按钮/UI 下面”，这样按钮会先吃掉手势，不会误触隐藏
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleUiHidden,
                child: const SizedBox.expand(),
              ),
            ),

            // ======= UI 层：只有在 _uiHidden == false 时显示 =======
            if (!_uiHidden) ...[
              // 中央区域（点击进详情；长按选背景）
              Align(
                alignment: Alignment.center,
                child: _CenterPetArea(
                  onPickBackground: _pickAndPersistBackground,
                  onOpenProfile: _openPetProfile,
                ),
              ),

              // 四周按钮
              EdgeButtons(
                onHygiene: () {
                  QuickPanel.show(
                    context,
                    title: '卫生管理',
                    child: const HygieneModal(),
                  );
                },
                onFood: () {
                  QuickPanel.show(
                    context,
                    title: '饮食管理',
                    child: const FoodModal(),
                  );
                },
                onHealth: () {
                  QuickPanel.show(
                    context,
                    title: '健康状态',
                    child: const HealthModal(),
                  );
                },
                onAlbum: () {
                  QuickPanel.show(
                    context,
                    title: '成长相册',
                    child: const AlbumModal(),
                  );
                },
              ),

              // 底部“恢复默认”按钮（你之前要求删除“选择背景”）
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 110),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: _clearBackground,
                          child: const Text('恢复默认'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '提示：点击空白区域可隐藏/恢复 UI',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CenterPetArea extends StatefulWidget {
  final VoidCallback onPickBackground; // 长按
  final VoidCallback onOpenProfile; // 点击

  const _CenterPetArea({
    required this.onPickBackground,
    required this.onOpenProfile,
  });

  @override
  State<_CenterPetArea> createState() => _CenterPetAreaState();
}

class _CenterPetAreaState extends State<_CenterPetArea> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpenProfile,
      onLongPress: widget.onPickBackground,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🐾 宠物区域',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                '点击：进入详情\n长按：选择背景',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
