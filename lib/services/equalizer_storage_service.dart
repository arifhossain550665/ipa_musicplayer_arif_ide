import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 🎚️ Equalizer-এর শেষ অবস্থা (on/off, preset নাম, প্রতিটা band-এর gain)
// SharedPreferences-এ সেভ রাখা হয় যাতে app বন্ধ করে আবার খুললেও আগের
// EQ setting নিজে থেকেই ফিরে আসে — বারবার manually অন করা লাগবে না।
class EqualizerStorageService {
  static const _keyEnabled = 'eq_enabled';
  static const _keyPresetName = 'eq_preset_name';
  static const _keyGains = 'eq_gains';

  Future<void> saveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  Future<void> saveState(String presetName, List<double> gains) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPresetName, presetName);
    await prefs.setString(_keyGains, json.encode(gains));
  }

  // null রিটার্ন করে যদি আগে কখনো EQ ব্যবহার না করা হয়ে থাকে
  Future<EqualizerSavedState?> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyPresetName);
    final gainsStr = prefs.getString(_keyGains);
    if (name == null || gainsStr == null) return null;

    try {
      final gains = (json.decode(gainsStr) as List)
          .map((e) => (e as num).toDouble())
          .toList();
      return EqualizerSavedState(presetName: name, gains: gains);
    } catch (_) {
      return null;
    }
  }
}

class EqualizerSavedState {
  final String presetName;
  final List<double> gains;

  const EqualizerSavedState({required this.presetName, required this.gains});
}
