import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Meilleurs temps par difficulté (indépendant du système de stats
/// générique, qui n'a pas de notion de "temps" par variante de jeu).
class MemoryRecordsService {
  const MemoryRecordsService();

  static const _key = 'memory_best_times';

  Future<Map<String, int>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return Map<String, int>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<int?> bestTimeFor(String difficultyKey) async {
    final all = await _load();
    return all[difficultyKey];
  }

  /// Enregistre [seconds] si c'est un nouveau record pour cette difficulté.
  /// Retourne true si un nouveau record a été établi.
  Future<bool> recordTime(String difficultyKey, int seconds) async {
    final all = await _load();
    final current = all[difficultyKey];
    if (current != null && current <= seconds) return false;
    all[difficultyKey] = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
    return true;
  }
}
