import 'dart:math';

import '../models/memory_models.dart';

/// Moteur de Memory : génère le plateau, retourne les cartes, détecte
/// les paires et calcule le score avec multiplicateur de combo.
class MemoryEngine {
  final List<MemoryCard> cards;
  final List<int> _selected = [];

  int moves = 0;
  int combo = 0;
  int maxCombo = 0;
  int score = 0;

  MemoryEngine({required MemoryTheme theme, required MemoryDifficulty difficulty})
      : cards = _generate(theme, difficulty);

  static List<MemoryCard> _generate(MemoryTheme theme, MemoryDifficulty difficulty) {
    final symbols = List<String>.of(theme.symbols)..shuffle(Random());
    final chosen = symbols.take(difficulty.pairCount).toList();
    final deck = [...chosen, ...chosen];
    deck.shuffle(Random());
    return [
      for (int i = 0; i < deck.length; i++) MemoryCard(id: i, symbol: deck[i]),
    ];
  }

  bool get isComplete => cards.every((c) => c.matched);
  bool get isBusy => _selected.length >= 2;

  /// Retourne une carte. Si c'est la 2e carte sélectionnée, indique s'il y a
  /// match via le champ [MemoryFlipResult.isMatch] ; sinon [pending].
  MemoryFlipResult flip(int index) {
    final card = cards[index];
    if (card.revealed || card.matched || isBusy) {
      return const MemoryFlipResult(pending: true, isMatch: false);
    }

    card.revealed = true;
    _selected.add(index);

    if (_selected.length < 2) {
      return const MemoryFlipResult(pending: true, isMatch: false);
    }

    moves++;
    final a = cards[_selected[0]];
    final b = cards[_selected[1]];
    final isMatch = a.symbol == b.symbol;

    if (isMatch) {
      a.matched = true;
      b.matched = true;
      combo++;
      if (combo > maxCombo) maxCombo = combo;
      final multiplier = 1 + combo * 0.5;
      score += (10 * multiplier).round();
    } else {
      combo = 0;
    }

    return MemoryFlipResult(pending: false, isMatch: isMatch, indices: List.of(_selected));
  }

  /// À appeler après le délai d'affichage, pour refermer les cartes non
  /// appariées et vider la sélection.
  void resolvePending() {
    if (_selected.length < 2) return;
    final a = cards[_selected[0]];
    final b = cards[_selected[1]];
    if (a.symbol != b.symbol) {
      a.revealed = false;
      b.revealed = false;
    }
    _selected.clear();
  }
}

class MemoryFlipResult {
  final bool pending;
  final bool isMatch;
  final List<int> indices;
  const MemoryFlipResult({
    required this.pending,
    required this.isMatch,
    this.indices = const [],
  });
}
