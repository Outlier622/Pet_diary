import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AllergyPref {
  final String allergies;
  final String preferences;
  final String avoid;

  AllergyPref({
    required this.allergies,
    required this.preferences,
    required this.avoid,
  });

  Map<String, dynamic> toJson() => {
        'allergies': allergies,
        'preferences': preferences,
        'avoid': avoid,
      };

  static AllergyPref fromJson(Map<String, dynamic> m) => AllergyPref(
        allergies: (m['allergies'] ?? '').toString(),
        preferences: (m['preferences'] ?? '').toString(),
        avoid: (m['avoid'] ?? '').toString(),
      );
}

class AllergyPrefStore {
  static const _key = 'food_allergy_pref_v1';

  static Future<AllergyPref> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return AllergyPref(allergies: '', preferences: '', avoid: '');
    }
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return AllergyPref.fromJson(m);
    } catch (_) {
      return AllergyPref(allergies: '', preferences: '', avoid: '');
    }
  }

  static Future<void> save(AllergyPref v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(v.toJson()));
  }
}
