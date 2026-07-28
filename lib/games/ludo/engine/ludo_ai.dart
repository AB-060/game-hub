import 'dart:math';

import '../models/ludo_board.dart';
import 'ludo_engine.dart';

/// IA du Ludo : choisit quel pion déplacer parmi les coups légaux.
/// Sait sortir les pions de la cour, capturer, se mettre à l'abri et
/// terminer rapidement, avec un niveau de prudence croissant selon la
/// difficulté.
class LudoAi {
  final Random _rand = Random();

  int chooseMove(LudoEngine engine, List<int> legalPawns, int dice, LudoDifficulty difficulty) {
    if (legalPawns.length == 1) return legalPawns.first;

    if (difficulty == LudoDifficulty.easy && _rand.nextDouble() < 0.7) {
      return legalPawns[_rand.nextInt(legalPawns.length)];
    }

    final color = engine.currentPlayer;
    int bestScore = -1 << 30;
    final bestMoves = <int>[];

    for (final pawnIndex in legalPawns) {
      final pawn = engine.pawns[color]!.firstWhere((p) => p.index == pawnIndex);
      final to = pawn.isHome ? 1 : pawn.position + dice;
      int score = to; // progresser est toujours un peu positif

      if (pawn.isHome) score += 25;
      if (to == LudoBoard.finishPosition) score += 300;

      final absolute = LudoBoard.absoluteRingIndex(color, to);
      if (absolute != null) {
        final captures = _capturesAt(engine, color, absolute);
        score += captures * 150;

        if (!LudoBoard.isSafeRingSquare(absolute)) {
          if (difficulty == LudoDifficulty.expert) {
            final danger = _dangerAt(engine, color, absolute);
            score -= danger * 40;
          } else if (difficulty == LudoDifficulty.medium) {
            final danger = _dangerAt(engine, color, absolute);
            score -= danger * 15;
          }
        } else {
          score += 10;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(pawnIndex);
      } else if (score == bestScore) {
        bestMoves.add(pawnIndex);
      }
    }

    return bestMoves[_rand.nextInt(bestMoves.length)];
  }

  int _capturesAt(LudoEngine engine, PawnColor mover, int absoluteRing) {
    int count = 0;
    for (final other in engine.activeColors) {
      if (other == mover) continue;
      for (final pawn in engine.pawns[other]!) {
        if (pawn.isHome || pawn.isFinished) continue;
        if (LudoBoard.absoluteRingIndex(other, pawn.position) == absoluteRing) count++;
      }
    }
    return count;
  }

  /// Nombre d'adversaires capables d'atteindre [absoluteRing] avec un
  /// simple lancer de dé (1 à 6) depuis leur position actuelle.
  int _dangerAt(LudoEngine engine, PawnColor mover, int absoluteRing) {
    int danger = 0;
    for (final other in engine.activeColors) {
      if (other == mover) continue;
      for (final pawn in engine.pawns[other]!) {
        if (pawn.isHome || pawn.isFinished) continue;
        final otherAbsolute = LudoBoard.absoluteRingIndex(other, pawn.position);
        if (otherAbsolute == null) continue;
        for (int d = 1; d <= 6; d++) {
          final reachPos = pawn.position + d;
          if (reachPos > LudoBoard.finishPosition) continue;
          final reachAbsolute = LudoBoard.absoluteRingIndex(other, reachPos);
          if (reachAbsolute == absoluteRing) {
            danger++;
            break;
          }
        }
      }
    }
    return danger;
  }
}
