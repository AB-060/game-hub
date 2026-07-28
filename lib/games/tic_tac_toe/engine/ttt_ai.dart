import 'dart:isolate';
import 'dart:math';

import '../models/ttt_models.dart';
import 'ttt_engine.dart';

/// IA du Morpion : 3 niveaux de difficulté, du hasard presque total
/// (Débutant) au Minimax + élagage alpha-bêta (Expert), en passant par une
/// heuristique de blocage/attaque (Intermédiaire). La recherche Expert
/// tourne dans un isolate dédié pour ne jamais bloquer l'UI, y compris sur
/// les grilles 4x4/5x5 où une recherche complète serait trop coûteuse
/// (profondeur limitée + évaluation heuristique en coupure).
class TicTacToeAi {
  static const int _winScore = 100000;
  final Random _rand = Random();

  Future<int> findBestMove(TicTacToeEngine engine, TttDifficulty difficulty) async {
    final empties = engine.emptyCells;
    if (empties.isEmpty) return -1;

    switch (difficulty) {
      case TttDifficulty.beginner:
        if (_rand.nextDouble() < 0.85) {
          return empties[_rand.nextInt(empties.length)];
        }
        return _heuristicMove(engine) ?? empties[_rand.nextInt(empties.length)];

      case TttDifficulty.intermediate:
        return _heuristicMove(engine) ?? _bestByScore(engine);

      case TttDifficulty.expert:
        final json = _encode(engine);
        final depth = _depthFor(engine.size, empties.length);
        final index = await Isolate.run(() => _searchBestMove(json, depth));
        return index ?? empties[_rand.nextInt(empties.length)];
    }
  }

  /// Coup immédiat évident : gagner si possible, sinon bloquer l'adversaire.
  int? _heuristicMove(TicTacToeEngine engine) {
    final me = engine.turn;
    final opponent = me.opposite;

    for (final i in engine.emptyCells) {
      engine.board[i] = me;
      final wins = engine._wouldWinAt(i, me);
      engine.board[i] = null;
      if (wins) return i;
    }
    for (final i in engine.emptyCells) {
      engine.board[i] = opponent;
      final wins = engine._wouldWinAt(i, opponent);
      engine.board[i] = null;
      if (wins) return i;
    }
    return null;
  }

  int _bestByScore(TicTacToeEngine engine) {
    final empties = engine.emptyCells;
    final lines = engine.allWinLines();
    int bestScore = -1 << 30;
    final bestMoves = <int>[];

    for (final i in empties) {
      engine.board[i] = engine.turn;
      final score = _evaluateLines(engine, lines, engine.turn);
      engine.board[i] = null;
      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(i);
      } else if (score == bestScore) {
        bestMoves.add(i);
      }
    }
    return bestMoves[_rand.nextInt(bestMoves.length)];
  }

  static int _evaluateLines(TicTacToeEngine engine, List<List<int>> lines, PlayerMark forMark) {
    int score = 0;
    for (final line in lines) {
      int mine = 0, theirs = 0;
      for (final sq in line) {
        final v = engine.board[sq];
        if (v == forMark) mine++;
        if (v == forMark.opposite) theirs++;
      }
      if (mine > 0 && theirs > 0) continue; // ligne bloquée par les deux
      if (mine > 0) score += _lineWeight(mine);
      if (theirs > 0) score -= _lineWeight(theirs);
    }
    return score;
  }

  static int _lineWeight(int count) => count * count * count;

  static int _depthFor(int size, int emptyCount) {
    if (size == 3) return emptyCount; // recherche complète, toujours rapide
    if (size == 4) return min(emptyCount, 5);
    return min(emptyCount, 4);
  }

  static Map<String, dynamic> _encode(TicTacToeEngine engine) => {
        'size': engine.size,
        'winLength': engine.winLength,
        'board': engine.board.map((m) => m?.name).toList(),
        'turn': engine.turn.name,
      };

  static int? _searchBestMove(Map<String, dynamic> json, int depth) {
    final size = json['size'] as int;
    final winLength = json['winLength'] as int;
    final board = (json['board'] as List<dynamic>)
        .map<PlayerMark?>((v) => v == null ? null : (v == 'x' ? PlayerMark.x : PlayerMark.o))
        .toList();
    final turn = json['turn'] == 'x' ? PlayerMark.x : PlayerMark.o;

    final engine = TicTacToeEngine.fromBoard(
      size: size,
      winLength: winLength,
      board: board,
      turn: turn,
    );

    final empties = engine.emptyCells;
    if (empties.isEmpty) return null;

    final lines = engine.allWinLines();
    int bestScore = -_winScore - 1;
    int bestMove = empties.first;

    for (final i in empties) {
      final result = engine.play(i);
      final score = -_negamax(engine, lines, depth - 1, -_winScore - 1, _winScore + 1, 1, result);
      engine.undo();
      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }
    return bestMove;
  }

  static int _negamax(
    TicTacToeEngine engine,
    List<List<int>> lines,
    int depth,
    int alpha,
    int beta,
    int ply,
    TttResult lastResult,
  ) {
    if (lastResult != TttResult.ongoing) {
      if (lastResult == TttResult.draw) return 0;
      // La dernière personne à avoir joué (le camp opposé à `engine.turn`
      // actuel) vient de gagner : mauvais pour celui qui doit jouer maintenant.
      return -_winScore + ply;
    }
    if (depth <= 0) {
      return _evaluateLines(engine, lines, engine.turn);
    }

    final empties = engine.emptyCells;
    int best = -_winScore - 1;
    for (final i in empties) {
      final result = engine.play(i);
      final score = -_negamax(engine, lines, depth - 1, -beta, -alpha, ply + 1, result);
      engine.undo();
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }
}

extension on TicTacToeEngine {
  bool _wouldWinAt(int index, PlayerMark mark) {
    final row = rowOf(index), col = colOf(index);
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];
    for (final d in dirs) {
      int count = 1;
      int r = row + d[0], c = col + d[1];
      while (inBounds(r, c) && board[indexOf(r, c)] == mark) {
        count++;
        r += d[0];
        c += d[1];
      }
      r = row - d[0];
      c = col - d[1];
      while (inBounds(r, c) && board[indexOf(r, c)] == mark) {
        count++;
        r -= d[0];
        c -= d[1];
      }
      if (count >= winLength) return true;
    }
    return false;
  }
}
