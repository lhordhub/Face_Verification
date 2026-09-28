// reference_store.dart
//
// Keeps your face reference (mean/std of the features) on the phone.
// The server is stateless, so the app sends this with every live check.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReferenceStore {
  static const String _key = 'face_reference_v1';

  static Future<void> save(Map<String, dynamic> reference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(reference));
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
