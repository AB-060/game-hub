import 'dart:math';

import '../models/ludo_board.dart';

class LudoPawn {
  final PawnColor color;
  final int index;
  int position; // 0=cour, 1..51=piste, 52..57=couloir privé, 58=arrivé

  LudoPawn({required this.color, required this.index, this.position = 0});

  bool get isHome => position == 0;
  bool get isFinished => position == LudoBoard.finishPosition;
}

class LudoMoveResult {
  final PawnColor mover;
  final int pawnIndex;
  final int from;
  final int to;
  final List<LudoPawn> captured;
  final bool finished;
  const LudoMoveResult({
    required this.mover,
    required this.pawnIndex,
    required this.from,
    required this.to,
    required this.captured,
    required this.finished,
  });
}

/// Moteur de Ludo : positions des pions de chaque couleur active, coups
/// légaux, capture, et détection de victoire. Les règles de blocage à deux
/// pions ne sont pas implémentées (simplification assumée).
class LudoEngine {
  final List<PawnColor> activeColors;
  final Map<PawnColor, List<LudoPawn>> pawns;
  final Random _rand = Random();

  int currentPlayerIndex = 0;
  int? lastDice;
  int consecutiveSixes = 0;
  PawnColor? winner;

  LudoEngine({required this.activeColors})
      : pawns = {
          for (final c in activeColors)
            c: List.generate(4, (i) => LudoPawn(color: c, index: i)),
        };

  PawnColor get currentPlayer => activeColors[currentPlayerIndex];

  int rollDice() {
    lastDice = _rand.nextInt(6) + 1;
    return lastDice!;
  }

  List<int> legalMovesFor(PawnColor color, int dice) {
    final result = <int>[];
    for (final pawn in pawns[color]!) {
      if (pawn.isFinished) continue;
      if (pawn.isHome) {
        if (dice == 6) result.add(pawn.index);
        continue;
      }
      if (pawn.position + dice <= LudoBoard.finishPosition) {
        result.add(pawn.index);
      }
    }
    return result;
  }

  LudoMoveResult applyMove(PawnColor color, int pawnIndex, int dice) {
    final pawn = pawns[color]!.firstWhere((p) => p.index == pawnIndex);
    final from = pawn.position;
    final to = pawn.isHome ? 1 : pawn.position + dice;
    pawn.position = to;

    final captured = <LudoPawn>[];
    final absoluteRing = LudoBoard.absoluteRingIndex(color, to);
    if (absoluteRing != null && !LudoBoard.isSafeRingSquare(absoluteRing)) {
      for (final otherColor in activeColors) {
        if (otherColor == color) continue;
        for (final other in pawns[otherColor]!) {
          if (other.isHome || other.isFinished) continue;
          final otherAbsolute = LudoBoard.absoluteRingIndex(otherColor, other.position);
          if (otherAbsolute == absoluteRing) {
            other.position = 0;
            captured.add(other);
          }
        }
      }
    }

    final finished = pawn.isFinished;
    if (finished && pawns[color]!.every((p) => p.isFinished)) {
      winner = color;
    }

    return LudoMoveResult(
      mover: color,
      pawnIndex: pawnIndex,
      from: from,
      to: to,
      captured: captured,
      finished: finished,
    );
  }

  /// Passe la main au joueur actif suivant (ceux qui ont déjà fini sont
  /// ignorés puisqu'ils n'ont plus de pions à jouer).
  void nextTurn() {
    consecutiveSixes = 0;
    if (activeColors.length <= 1) return;
    var next = (currentPlayerIndex + 1) % activeColors.length;
    var guard = 0;
    while (pawns[activeColors[next]]!.every((p) => p.isFinished) && guard < activeColors.length) {
      next = (next + 1) % activeColors.length;
      guard++;
    }
    currentPlayerIndex = next;
  }

  bool get currentPlayerHasFinished =>
      pawns[currentPlayer]!.every((p) => p.isFinished);
}
