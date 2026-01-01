import 'package:flutter/material.dart';
import 'allergy_pref_store.dart';

class AllergyPrefModal extends StatefulWidget {
  const AllergyPrefModal({super.key});

  @override
  State<AllergyPrefModal> createState() => _AllergyPrefModalState();
}

class _AllergyPrefModalState extends State<AllergyPrefModal> {
  bool _loading = true;

  final _allergyCtrl = TextEditingController();
  final _prefCtrl = TextEditingController();
  final _avoidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final v = await AllergyPrefStore.load();
    if (!mounted) return;
    _allergyCtrl.text = v.allergies;
    _prefCtrl.text = v.preferences;
    _avoidCtrl.text = v.avoid;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _allergyCtrl.dispose();
    _prefCtrl.dispose();
    _avoidCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = AllergyPref(
      allergies: _allergyCtrl.text.trim(),
      preferences: _prefCtrl.text.trim(),
      avoid: _avoidCtrl.text.trim(),
    );
    await AllergyPrefStore.save(v);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }

    return SizedBox(
      height: 480,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const Text('过敏（可填食材/品牌，多行）', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _allergyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '例如：鸡肉、牛奶蛋白…'),
                ),
                const SizedBox(height: 12),

                const Text('偏好（爱吃什么）', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _prefCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '例如：三文鱼口味、湿粮…'),
                ),
                const SizedBox(height: 12),

                const Text('禁忌（不希望喂的）', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _avoidCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '例如：高盐零食、骨头…'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
