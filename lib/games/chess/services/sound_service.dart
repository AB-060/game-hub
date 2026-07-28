import 'package:flutter/services.dart';

enum ChessSound { move, capture, check, castle, gameWin, gameLose, gameDraw }

/// Service audio centralisé. Utilise pour l'instant les sons système comme
/// retour immédiat (clic / alerte) : il suffit de déposer de vrais fichiers
/// dans `assets/sounds/` et de brancher un lecteur (ex: `audioplayers`) dans
/// [_play] pour obtenir de vrais effets sonores, sans toucher au reste du
/// code — tous les appels passent déjà par [SoundService.play].
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool enabled = true;

  Future<void> play(ChessSound sound) async {
    if (!enabled) return;
    switch (sound) {
      case ChessSound.move:
      case ChessSound.castle:
        await SystemSound.play(SystemSoundType.click);
        break;
      case ChessSound.capture:
        await SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
        break;
      case ChessSound.check:
        await SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
        break;
      case ChessSound.gameWin:
        await SystemSound.play(SystemSoundType.click);
        HapticFeedback.heavyImpact();
        break;
      case ChessSound.gameLose:
        await SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
        break;
      case ChessSound.gameDraw:
        await SystemSound.play(SystemSoundType.click);
        break;
    }
  }
}
