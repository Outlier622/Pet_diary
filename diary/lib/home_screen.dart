import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/timeline_readonly_page.dart';

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

  bool _uiHidden = false;

  static const String _baseUrl = "http://10.12.0.109:5000";
  static const String _apiKey = "dev-key";

  @override
  void initState() {
    super.initState();
    _loadSavedBackground();
  }

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

      _snack('Background updated');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to save background: $e');
    }
  }

  Future<void> _classifyAndToast(File file) async {
    try {
      final info = await _uploadAndClassifyBackground(file);
      if (!mounted) return;

      final animal = (info['animal'] ?? '').toString();
      final breed = (info['breed'] ?? '').toString();
      final conf = (info['confidence'] ?? '').toString();

      _snack("Result: $animal · $breed ($conf%)");
    } catch (e) {
      if (!mounted) return;
      _snack("Classification failed: $e");
    }
  }

  Future<Map<String, dynamic>> _uploadAndClassifyBackground(File file) async {
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

    _snack('Restored default background');
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
    debugPrint('HOME_SCREEN_BUILD ✅');
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _bgFile == null
                  ? const ColoredBox(color: Color(0xFFBDBDBD))
                  : Image.file(_bgFile!, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withOpacity(0.18)),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleUiHidden,
                child: const SizedBox.expand(),
              ),
            ),
            if (!_uiHidden) ...[
              Align(
                alignment: Alignment.center,
                child: _CenterPetArea(
                  onPickBackground: _pickAndPersistBackground,
                  onOpenProfile: _openPetProfile,
                ),
              ),
              EdgeButtons(
                onHygiene: () {
                  QuickPanel.show(
                    context,
                    title: 'Hygiene',
                    child: const HygieneModal(),
                  );
                },
                onFood: () {
                  QuickPanel.show(
                    context,
                    title: 'Nutrition',
                    child: const FoodModal(),
                  );
                },
                onHealth: () {
                  QuickPanel.show(
                    context,
                    title: 'Health',
                    child: const HealthModal(),
                  );
                },
                onAlbum: () {
                  QuickPanel.show(
                    context,
                    title: 'Album',
                    child: const AlbumModal(),
                  );
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 110),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: _clearBackground,
                            child: const Text('Restore Default'),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TimelineReadonlyPage(),
                                ),
                              );
                            },
                            child: const Text('SQLite Timeline (Read-Only)'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tip: Tap empty space to hide/show the UI',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
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
  final VoidCallback onPickBackground;
  final VoidCallback onOpenProfile;

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
                '🐾 Pet Area',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Tap to open profile\nLong-press to choose a background',
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
