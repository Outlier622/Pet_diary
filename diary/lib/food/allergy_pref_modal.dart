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
      const SnackBar(content: Text('Saved.'), duration: Duration(seconds: 1)),
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
                const Text('Allergies (ingredients or brands, multi-line)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _allergyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g., chicken, dairy protein…',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Preferences (favorite foods)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _prefCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g., salmon flavor, wet food…',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Avoid (do not feed)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _avoidCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g., salty snacks, bones…',
                  ),
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
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
