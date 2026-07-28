import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Sauvegarde automatique générique de l'état d'une partie en cours,
/// namespacée par jeu. Chaque jeu sérialise son propre état en
/// `Map<String, dynamic>` (types primitifs uniquement).
class GameSaveService {
  final String gameKey;
  const GameSaveService(this.gameKey);

  String get _key => 'save_$gameKey';

  Future<void> saveState(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
