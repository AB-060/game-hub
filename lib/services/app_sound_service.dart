import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Événements sonores génériques, communs à tous les mini-jeux.
enum AppSfx { tap, move, success, capture, whistle, win, lose, draw, powerUp, danger, explosion }

/// Système audio commun à tous les jeux du hub (hors échecs, qui a le
/// sien déjà en place). Comme pour les échecs : pas de fichiers audio
/// réels disponibles ici, donc on s'appuie sur les sons système + retour
/// haptique en attendant que de vrais fichiers soient déposés dans
/// `assets/sounds/` — tous les appels passent déjà par [AppSoundService.play]
/// donc brancher un vrai lecteur (`audioplayers`) ne touchera qu'un seul
/// endroit du code.
///
/// Gère aussi la préférence son/musique on-off, persistée.
class AppSoundService {
  AppSoundService._();
  static final AppSoundService instance = AppSoundService._();

  bool soundEnabled = true;
  bool musicEnabled = true;
  bool _loaded = false;

  static const _soundKey = 'app_sound_enabled';
  static const _musicKey = 'app_music_enabled';

  Future<void> loadPrefs() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    soundEnabled = prefs.getBool(_soundKey) ?? true;
    musicEnabled = prefs.getBool(_musicKey) ?? true;
    _loaded = true;
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicKey, value);
  }

  Future<void> play(AppSfx sfx) async {
    if (!soundEnabled) return;
    switch (sfx) {
      case AppSfx.tap:
        await SystemSound.play(SystemSoundType.click);
        break;
      case AppSfx.move:
        await SystemSound.play(SystemSoundType.click);
        HapticFeedback.selectionClick();
        break;
      case AppSfx.capture:
      case AppSfx.powerUp:
        await SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
        break;
      case AppSfx.success:
      case AppSfx.win:
        await SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
        break;
      case AppSfx.whistle:
      case AppSfx.draw:
        await SystemSound.play(SystemSoundType.click);
        break;
      case AppSfx.lose:
      case AppSfx.danger:
      case AppSfx.explosion:
        await SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
        break;
    }
  }
}
