import 'dart:isolate';
import 'dart:math';

import '../models/chess_models.dart';
import 'chess_engine.dart';

/// IA d'échecs : Minimax + élagage alpha-bêta, avec 3 niveaux de
/// difficulté. La recherche tourne dans un isolate dédié pour ne jamais
/// bloquer l'interface.
class AiEngine {
  static const int _mateScore = 1000000;

  static int depthFor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 1;
      case Difficulty.intermediate:
        return 2;
      case Difficulty.expert:
        return 3;
    }
  }

  /// Calcule le meilleur coup pour la position courante de [engine]
  /// (c'est au tour de `engine.turn` de jouer), pour le niveau [difficulty].
  static Future<ChessMove?> findBestMove(ChessEngine engine, Difficulty difficulty) async {
    final legalNow = engine.legalMoves();
    if (legalNow.isEmpty) return null;
    if (legalNow.length == 1) return legalNow.first;

    final json = engine.toJson();
    final resultCode = await Isolate.run(() => _searchBestMoveCode(json, difficulty));
    if (resultCode == null) {
      return legalNow[Random().nextInt(legalNow.length)];
    }

    for (final m in legalNow) {
      if (m.from == resultCode.from &&
          m.to == resultCode.to &&
          m.promotion == resultCode.promotion) {
        return m;
      }
    }
    return legalNow[Random().nextInt(legalNow.length)];
  }

  static _MoveCode? _searchBestMoveCode(Map<String, dynamic> json, Difficulty difficulty) {
    final engine = ChessEngine.fromJson(json);
    final moves = engine.legalMoves();
    if (moves.isEmpty) return null;

    final rand = Random();

    // Débutant : quelques coups aléatoires pour rester battable.
    if (difficulty == Difficulty.beginner && rand.nextDouble() < 0.35) {
      final m = moves[rand.nextInt(moves.length)];
      return _MoveCode(m.from, m.to, m.promotion);
    }

    final depth = depthFor(difficulty);
    _orderMoves(moves, engine);

    final scored = <MapEntry<ChessMove, int>>[];
    int alpha = -_mateScore - 1;
    const beta = _mateScore + 1;

    for (final m in moves) {
      engine.makeMove(m, computeStatus: false);
      final score = -_negamax(engine, depth - 1, -beta, -alpha, 1);
      engine.unmakeMove();
      scored.add(MapEntry(m, score));
      if (score > alpha) alpha = score;
    }

    scored.sort((a, b) => b.value.compareTo(a.value));

    ChessMove chosen;
    if (difficulty == Difficulty.intermediate && scored.length > 1 && rand.nextDouble() < 0.15) {
      // Intermédiaire : parfois un coup parmi les meilleurs, pas toujours LE meilleur.
      final poolSize = min(3, scored.length);
      chosen = scored[rand.nextInt(poolSize)].key;
    } else {
      chosen = scored.first.key;
    }

    return _MoveCode(chosen.from, chosen.to, chosen.promotion);
  }

  static int _negamax(ChessEngine engine, int depth, int alpha, int beta, int ply) {
    final moves = engine.legalMoves();
    if (moves.isEmpty) {
      if (engine.isInCheck) return -_mateScore + ply;
      return 0;
    }
    if (depth <= 0) {
      return _evaluateForSideToMove(engine);
    }

    _orderMoves(moves, engine);

    int best = -_mateScore - 1;
    for (final m in moves) {
      engine.makeMove(m, computeStatus: false);
      final score = -_negamax(engine, depth - 1, -beta, -alpha, ply + 1);
      engine.unmakeMove();
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  static void _orderMoves(List<ChessMove> moves, ChessEngine engine) {
    moves.sort((a, b) {
      final aScore = _moveOrderingScore(a);
      final bScore = _moveOrderingScore(b);
      return bScore.compareTo(aScore);
    });
  }

  static int _moveOrderingScore(ChessMove m) {
    var score = 0;
    if (m.isCapture) {
      final capturedValue = m.captured != null ? _pieceValue(m.captured!.type) : 100;
      final attackerValue = _pieceValue(m.piece.type);
      score += 1000 + capturedValue - (attackerValue ~/ 10);
    }
    if (m.promotion != null) score += 800;
    if (m.isCastleKingSide || m.isCastleQueenSide) score += 50;
    return score;
  }

  static int _pieceValue(PieceType t) {
    switch (t) {
      case PieceType.pawn: return 100;
      case PieceType.knight: return 320;
      case PieceType.bishop: return 330;
      case PieceType.rook: return 500;
      case PieceType.queen: return 900;
      case PieceType.king: return 20000;
    }
  }

  /// Évalue la position du point de vue du camp qui doit jouer
  /// (convention negamax) : positif = avantage pour `engine.turn`.
  static int _evaluateForSideToMove(ChessEngine engine) {
    final whiteScore = _evaluateForWhite(engine);
    return engine.turn == PieceColor.white ? whiteScore : -whiteScore;
  }

  static int _evaluateForWhite(ChessEngine engine) {
    int score = 0;
    for (int sq = 0; sq < 64; sq++) {
      final p = engine.board[sq];
      if (p == null) continue;
      final value = _pieceValue(p.type);
      final pst = _pstValue(p.type, sq, p.color);
      score += (p.color == PieceColor.white) ? (value + pst) : -(value + pst);
    }
    return score;
  }

  static int _pstValue(PieceType type, int square, PieceColor color) {
    final table = _pstFor(type);
    // Les tables sont écrites du point de vue des blancs (rangée 0 = rang 8).
    // Pour les noirs, on retourne verticalement.
    final index = color == PieceColor.white ? square : (63 - square);
    return table[index];
  }

  static List<int> _pstFor(PieceType type) {
    switch (type) {
      case PieceType.pawn: return _pawnTable;
      case PieceType.knight: return _knightTable;
      case PieceType.bishop: return _bishopTable;
      case PieceType.rook: return _rookTable;
      case PieceType.queen: return _queenTable;
      case PieceType.king: return _kingTable;
    }
  }

  // Tables de position simplifiées (valeurs en centipions), point de vue blanc.
  static const List<int> _pawnTable = [
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ];

  static const List<int> _knightTable = [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ];

  static const List<int> _bishopTable = [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ];

  static const List<int> _rookTable = [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ];

  static const List<int> _queenTable = [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ];

  static const List<int> _kingTable = [
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  ];
}

class _MoveCode {
  final int from;
  final int to;
  final PieceType? promotion;
  const _MoveCode(this.from, this.to, this.promotion);
}
