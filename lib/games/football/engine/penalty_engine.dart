import 'dart:math';

import '../models/penalty_models.dart';

class ShotResult {
  final ShotZone shotZone;
  final ShotZone keeperZone;
  final bool isGoal;
  const ShotResult({required this.shotZone, required this.keeperZone, required this.isGoal});
}

/// Moteur du mini-jeu de tirs au but : IA du gardien uniquement (le tir
/// est choisi par le joueur). Pas d'état de "partie" ici — c'est l'écran
/// de jeu qui suit le score, les tirs restants, etc.
class PenaltyEngine {
  final PenaltyDifficulty difficulty;
  final Random _rand = Random();

  PenaltyEngine({required this.difficulty});

  ShotResult resolveShot(ShotZone shot) {
    final ShotZone keeperZone;
    if (_rand.nextDouble() < difficulty.guessChance) {
      keeperZone = shot;
    } else {
      final others = ShotZone.values.where((z) => z != shot).toList();
      keeperZone = others[_rand.nextInt(others.length)];
    }

    bool saved;
    if (keeperZone == shot) {
      saved = _rand.nextDouble() < difficulty.saveChanceOnCorrectGuess;
    } else {
      saved = _rand.nextDouble() < difficulty.saveChanceOnWrongGuess;
    }

    return ShotResult(shotZone: shot, keeperZone: keeperZone, isGoal: !saved);
  }
}
