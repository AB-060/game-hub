import '../models/chess_models.dart';

/// Moteur d'échecs complet : génération de coups légaux, roque, prise en
/// passant, promotion, détection d'échec / échec et mat / pat / nulles.
///
/// Le plateau est une liste de 64 cases, index = row * 8 + col.
/// row 0 = 8e rangée (noirs), row 7 = 1re rangée (blancs). col 0 = colonne a.
class ChessEngine {
  List<ChessPiece?> board;
  PieceColor turn;

  bool whiteKingSideCastle;
  bool whiteQueenSideCastle;
  bool blackKingSideCastle;
  bool blackQueenSideCastle;

  int? enPassantTarget;
  int halfmoveClock;
  int fullmoveNumber;

  final List<ChessMove> history = [];
  final Map<String, int> _repetition = {};

  ChessEngine._({
    required this.board,
    required this.turn,
    required this.whiteKingSideCastle,
    required this.whiteQueenSideCastle,
    required this.blackKingSideCastle,
    required this.blackQueenSideCastle,
    required this.enPassantTarget,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  });

  factory ChessEngine.newGame() {
    final board = List<ChessPiece?>.filled(64, null);
    const backRank = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];
    for (int c = 0; c < 8; c++) {
      board[c] = ChessPiece(backRank[c], PieceColor.black);
      board[8 + c] = const ChessPiece(PieceType.pawn, PieceColor.black);
      board[48 + c] = const ChessPiece(PieceType.pawn, PieceColor.white);
      board[56 + c] = ChessPiece(backRank[c], PieceColor.white);
    }
    return ChessEngine._(
      board: board,
      turn: PieceColor.white,
      whiteKingSideCastle: true,
      whiteQueenSideCastle: true,
      blackKingSideCastle: true,
      blackQueenSideCastle: true,
      enPassantTarget: null,
      halfmoveClock: 0,
      fullmoveNumber: 1,
    );
  }

  /// Sérialisation en types primitifs uniquement, pour pouvoir traverser
  /// la frontière d'un isolate (utilisé par la recherche de l'IA).
  Map<String, dynamic> toJson() {
    return {
      'board': board.map((p) => p == null ? null : '${p.color.name[0]}${_typeCode(p.type)}').toList(),
      'turn': turn.name,
      'wk': whiteKingSideCastle,
      'wq': whiteQueenSideCastle,
      'bk': blackKingSideCastle,
      'bq': blackQueenSideCastle,
      'ep': enPassantTarget,
      'halfmove': halfmoveClock,
      'fullmove': fullmoveNumber,
    };
  }

  factory ChessEngine.fromJson(Map<String, dynamic> json) {
    final rawBoard = json['board'] as List<dynamic>;
    final board = rawBoard.map<ChessPiece?>((code) {
      if (code == null) return null;
      final s = code as String;
      final color = s[0] == 'w' ? PieceColor.white : PieceColor.black;
      return ChessPiece(_codeType(s[1]), color);
    }).toList();

    return ChessEngine._(
      board: board,
      turn: json['turn'] == 'white' ? PieceColor.white : PieceColor.black,
      whiteKingSideCastle: json['wk'] as bool,
      whiteQueenSideCastle: json['wq'] as bool,
      blackKingSideCastle: json['bk'] as bool,
      blackQueenSideCastle: json['bq'] as bool,
      enPassantTarget: json['ep'] as int?,
      halfmoveClock: json['halfmove'] as int,
      fullmoveNumber: json['fullmove'] as int,
    );
  }

  static String _typeCode(PieceType t) {
    switch (t) {
      case PieceType.pawn: return 'P';
      case PieceType.knight: return 'N';
      case PieceType.bishop: return 'B';
      case PieceType.rook: return 'R';
      case PieceType.queen: return 'Q';
      case PieceType.king: return 'K';
    }
  }

  static PieceType _codeType(String c) {
    switch (c) {
      case 'P': return PieceType.pawn;
      case 'N': return PieceType.knight;
      case 'B': return PieceType.bishop;
      case 'R': return PieceType.rook;
      case 'Q': return PieceType.queen;
      default: return PieceType.king;
    }
  }

  ChessEngine clone() {
    return ChessEngine._(
      board: List<ChessPiece?>.of(board),
      turn: turn,
      whiteKingSideCastle: whiteKingSideCastle,
      whiteQueenSideCastle: whiteQueenSideCastle,
      blackKingSideCastle: blackKingSideCastle,
      blackQueenSideCastle: blackQueenSideCastle,
      enPassantTarget: enPassantTarget,
      halfmoveClock: halfmoveClock,
      fullmoveNumber: fullmoveNumber,
    );
  }

  static int rowOf(int sq) => sq ~/ 8;
  static int colOf(int sq) => sq % 8;
  static int square(int row, int col) => row * 8 + col;
  static bool inBounds(int row, int col) => row >= 0 && row < 8 && col >= 0 && col < 8;

  int kingSquareOf(PieceColor color) {
    for (int i = 0; i < 64; i++) {
      final p = board[i];
      if (p != null && p.type == PieceType.king && p.color == color) return i;
    }
    return -1;
  }

  bool get isInCheck => isSquareAttacked(kingSquareOf(turn), turn.opposite);

  bool isColorInCheck(PieceColor color) =>
      isSquareAttacked(kingSquareOf(color), color.opposite);

  bool isSquareAttacked(int square, PieceColor byColor) {
    if (square < 0) return false;
    final row = rowOf(square), col = colOf(square);

    // Pions.
    final pawnDir = byColor == PieceColor.white ? -1 : 1;
    for (final dc in [-1, 1]) {
      final r = row - pawnDir, c = col + dc;
      if (inBounds(r, c)) {
        final p = board[square_(r, c)];
        if (p != null && p.color == byColor && p.type == PieceType.pawn) return true;
      }
    }

    // Cavaliers.
    const knightDeltas = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1],
    ];
    for (final d in knightDeltas) {
      final r = row + d[0], c = col + d[1];
      if (inBounds(r, c)) {
        final p = board[square_(r, c)];
        if (p != null && p.color == byColor && p.type == PieceType.knight) return true;
      }
    }

    // Roi adverse (adjacence).
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr, c = col + dc;
        if (inBounds(r, c)) {
          final p = board[square_(r, c)];
          if (p != null && p.color == byColor && p.type == PieceType.king) return true;
        }
      }
    }

    // Pièces glissantes : fous/tours/dame.
    const diagDirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    const straightDirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final d in diagDirs) {
      int r = row + d[0], c = col + d[1];
      while (inBounds(r, c)) {
        final p = board[square_(r, c)];
        if (p != null) {
          if (p.color == byColor && (p.type == PieceType.bishop || p.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        r += d[0];
        c += d[1];
      }
    }
    for (final d in straightDirs) {
      int r = row + d[0], c = col + d[1];
      while (inBounds(r, c)) {
        final p = board[square_(r, c)];
        if (p != null) {
          if (p.color == byColor && (p.type == PieceType.rook || p.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        r += d[0];
        c += d[1];
      }
    }

    return false;
  }

  static int square_(int r, int c) => r * 8 + c;

  List<ChessMove> _pseudoMovesForSquare(int from) {
    final piece = board[from];
    if (piece == null) return [];
    final moves = <ChessMove>[];
    final row = rowOf(from), col = colOf(from);

    void addMove(
      int to, {
      ChessPiece? captured,
      PieceType? promotion,
      bool isCastleK = false,
      bool isCastleQ = false,
      bool isEnPassant = false,
      int? epCapSq,
    }) {
      moves.add(ChessMove(
        from: from,
        to: to,
        piece: piece,
        captured: captured,
        promotion: promotion,
        isCastleKingSide: isCastleK,
        isCastleQueenSide: isCastleQ,
        isEnPassant: isEnPassant,
        enPassantCapturedSquare: epCapSq,
        prevWhiteKingSideCastle: whiteKingSideCastle,
        prevWhiteQueenSideCastle: whiteQueenSideCastle,
        prevBlackKingSideCastle: blackKingSideCastle,
        prevBlackQueenSideCastle: blackQueenSideCastle,
        prevEnPassantTarget: enPassantTarget,
        prevHalfmoveClock: halfmoveClock,
      ));
    }

    switch (piece.type) {
      case PieceType.pawn:
        final dir = piece.color == PieceColor.white ? -1 : 1;
        final startRow = piece.color == PieceColor.white ? 6 : 1;
        final promoRow = piece.color == PieceColor.white ? 0 : 7;
        final oneRow = row + dir;

        if (inBounds(oneRow, col) && board[square_(oneRow, col)] == null) {
          if (oneRow == promoRow) {
            for (final promo in [
              PieceType.queen,
              PieceType.rook,
              PieceType.bishop,
              PieceType.knight,
            ]) {
              addMove(square_(oneRow, col), promotion: promo);
            }
          } else {
            addMove(square_(oneRow, col));
          }
          final twoRow = row + 2 * dir;
          if (row == startRow &&
              inBounds(twoRow, col) &&
              board[square_(twoRow, col)] == null) {
            addMove(square_(twoRow, col));
          }
        }

        for (final dc in [-1, 1]) {
          final r = row + dir, c = col + dc;
          if (!inBounds(r, c)) continue;
          final targetSq = square_(r, c);
          final target = board[targetSq];
          if (target != null && target.color != piece.color) {
            if (r == promoRow) {
              for (final promo in [
                PieceType.queen,
                PieceType.rook,
                PieceType.bishop,
                PieceType.knight,
              ]) {
                addMove(targetSq, captured: target, promotion: promo);
              }
            } else {
              addMove(targetSq, captured: target);
            }
          } else if (target == null && enPassantTarget == targetSq) {
            final capturedPawnSq = square_(row, c);
            final capturedPawn = board[capturedPawnSq];
            if (capturedPawn != null &&
                capturedPawn.type == PieceType.pawn &&
                capturedPawn.color != piece.color) {
              addMove(targetSq, captured: capturedPawn, isEnPassant: true, epCapSq: capturedPawnSq);
            }
          }
        }
        break;

      case PieceType.knight:
        const knightDeltas = [
          [-2, -1], [-2, 1], [-1, -2], [-1, 2],
          [1, -2], [1, 2], [2, -1], [2, 1],
        ];
        for (final d in knightDeltas) {
          final r = row + d[0], c = col + d[1];
          if (!inBounds(r, c)) continue;
          final target = board[square_(r, c)];
          if (target == null || target.color != piece.color) {
            addMove(square_(r, c), captured: target);
          }
        }
        break;

      case PieceType.bishop:
      case PieceType.rook:
      case PieceType.queen:
        final dirs = <List<int>>[];
        if (piece.type != PieceType.rook) {
          dirs.addAll([[-1, -1], [-1, 1], [1, -1], [1, 1]]);
        }
        if (piece.type != PieceType.bishop) {
          dirs.addAll([[-1, 0], [1, 0], [0, -1], [0, 1]]);
        }
        for (final d in dirs) {
          int r = row + d[0], c = col + d[1];
          while (inBounds(r, c)) {
            final target = board[square_(r, c)];
            if (target == null) {
              addMove(square_(r, c));
            } else {
              if (target.color != piece.color) addMove(square_(r, c), captured: target);
              break;
            }
            r += d[0];
            c += d[1];
          }
        }
        break;

      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final r = row + dr, c = col + dc;
            if (!inBounds(r, c)) continue;
            final target = board[square_(r, c)];
            if (target == null || target.color != piece.color) {
              addMove(square_(r, c), captured: target);
            }
          }
        }

        // Roque.
        final isWhite = piece.color == PieceColor.white;
        final homeRow = isWhite ? 7 : 0;
        if (row == homeRow && col == 4) {
          final opponent = piece.color.opposite;
          final canKing = isWhite ? whiteKingSideCastle : blackKingSideCastle;
          final canQueen = isWhite ? whiteQueenSideCastle : blackQueenSideCastle;
          final kingSq = square_(homeRow, 4);

          if (canKing &&
              board[square_(homeRow, 5)] == null &&
              board[square_(homeRow, 6)] == null &&
              board[square_(homeRow, 7)]?.type == PieceType.rook &&
              !isSquareAttacked(kingSq, opponent) &&
              !isSquareAttacked(square_(homeRow, 5), opponent) &&
              !isSquareAttacked(square_(homeRow, 6), opponent)) {
            addMove(square_(homeRow, 6), isCastleK: true);
          }
          if (canQueen &&
              board[square_(homeRow, 1)] == null &&
              board[square_(homeRow, 2)] == null &&
              board[square_(homeRow, 3)] == null &&
              board[square_(homeRow, 0)]?.type == PieceType.rook &&
              !isSquareAttacked(kingSq, opponent) &&
              !isSquareAttacked(square_(homeRow, 3), opponent) &&
              !isSquareAttacked(square_(homeRow, 2), opponent)) {
            addMove(square_(homeRow, 2), isCastleQ: true);
          }
        }
        break;
    }

    return moves;
  }

  /// Coups légaux (qui ne laissent pas son propre roi en échec).
  List<ChessMove> legalMoves({PieceColor? forColor, int? fromSquare}) {
    final color = forColor ?? turn;
    final pseudo = <ChessMove>[];
    for (int sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == null || p.color != color) continue;
      if (fromSquare != null && sq != fromSquare) continue;
      pseudo.addAll(_pseudoMovesForSquare(sq));
    }

    final legal = <ChessMove>[];
    for (final m in pseudo) {
      makeMove(m, computeStatus: false);
      final kingSafe = !isSquareAttacked(kingSquareOf(color), color.opposite);
      unmakeMove();
      if (kingSafe) legal.add(m);
    }
    return legal;
  }

  /// Joue [m] sur le plateau. Si [computeStatus] est vrai (par défaut),
  /// calcule échec/échec et mat/pat sur le coup — coûteux (génère les coups
  /// légaux adverses), donc désactivé pendant la simulation de légalité et
  /// la recherche de l'IA qui font déjà ce travail elles-mêmes.
  void makeMove(ChessMove m, {bool computeStatus = true}) {
    if (m.isEnPassant && m.enPassantCapturedSquare != null) {
      board[m.enPassantCapturedSquare!] = null;
    }

    board[m.to] = m.promotion != null ? ChessPiece(m.promotion!, m.piece.color) : m.piece;
    board[m.from] = null;

    if (m.isCastleKingSide) {
      if (m.piece.color == PieceColor.white) {
        board[61] = board[63];
        board[63] = null;
      } else {
        board[5] = board[7];
        board[7] = null;
      }
    } else if (m.isCastleQueenSide) {
      if (m.piece.color == PieceColor.white) {
        board[59] = board[56];
        board[56] = null;
      } else {
        board[3] = board[0];
        board[0] = null;
      }
    }

    if (m.piece.type == PieceType.king) {
      if (m.piece.color == PieceColor.white) {
        whiteKingSideCastle = false;
        whiteQueenSideCastle = false;
      } else {
        blackKingSideCastle = false;
        blackQueenSideCastle = false;
      }
    }
    if (m.from == 56 || m.to == 56) whiteQueenSideCastle = false;
    if (m.from == 63 || m.to == 63) whiteKingSideCastle = false;
    if (m.from == 0 || m.to == 0) blackQueenSideCastle = false;
    if (m.from == 7 || m.to == 7) blackKingSideCastle = false;

    enPassantTarget = null;
    if (m.piece.type == PieceType.pawn && (m.from - m.to).abs() == 16) {
      enPassantTarget = (m.from + m.to) ~/ 2;
    }

    halfmoveClock = (m.piece.type == PieceType.pawn || m.isCapture) ? 0 : halfmoveClock + 1;
    if (m.piece.color == PieceColor.black) fullmoveNumber++;

    turn = turn.opposite;

    if (computeStatus) {
      m.isCheck = isSquareAttacked(kingSquareOf(turn), turn.opposite);
      final noMoves = legalMoves(forColor: turn).isEmpty;
      m.isCheckmate = m.isCheck && noMoves;
      m.isStalemate = !m.isCheck && noMoves;
    }

    history.add(m);
  }

  void unmakeMove() {
    if (history.isEmpty) return;
    final m = history.removeLast();

    turn = turn.opposite;

    board[m.from] = m.piece;
    if (m.isEnPassant) {
      board[m.to] = null;
      if (m.enPassantCapturedSquare != null) {
        board[m.enPassantCapturedSquare!] = ChessPiece(PieceType.pawn, m.piece.color.opposite);
      }
    } else {
      board[m.to] = m.captured;
    }

    if (m.isCastleKingSide) {
      if (m.piece.color == PieceColor.white) {
        board[63] = board[61];
        board[61] = null;
      } else {
        board[7] = board[5];
        board[5] = null;
      }
    } else if (m.isCastleQueenSide) {
      if (m.piece.color == PieceColor.white) {
        board[56] = board[59];
        board[59] = null;
      } else {
        board[0] = board[3];
        board[3] = null;
      }
    }

    whiteKingSideCastle = m.prevWhiteKingSideCastle;
    whiteQueenSideCastle = m.prevWhiteQueenSideCastle;
    blackKingSideCastle = m.prevBlackKingSideCastle;
    blackQueenSideCastle = m.prevBlackQueenSideCastle;
    enPassantTarget = m.prevEnPassantTarget;
    halfmoveClock = m.prevHalfmoveClock;

    if (m.piece.color == PieceColor.black) fullmoveNumber--;
  }

  bool get hasAnyLegalMove => legalMoves(forColor: turn).isNotEmpty;

  bool get isInsufficientMaterial {
    final pieces = board.whereType<ChessPiece>().toList();
    if (pieces.length <= 2) return true; // roi vs roi
    if (pieces.length == 3) {
      final hasMinor = pieces.any((p) => p.type == PieceType.bishop || p.type == PieceType.knight);
      final onlyKingsAndOneMinor = pieces.where((p) => p.type != PieceType.king).length == 1;
      if (hasMinor && onlyKingsAndOneMinor) return true;
    }
    return false;
  }

  bool get isFiftyMoveRule => halfmoveClock >= 100;

  String positionKey() {
    final buf = StringBuffer();
    for (final p in board) {
      buf.write(p == null ? '.' : '${p.color.name[0]}${p.type.name[0]}');
    }
    buf.write(turn.name);
    buf.write(whiteKingSideCastle ? 'K' : '');
    buf.write(whiteQueenSideCastle ? 'Q' : '');
    buf.write(blackKingSideCastle ? 'k' : '');
    buf.write(blackQueenSideCastle ? 'q' : '');
    buf.write(enPassantTarget ?? -1);
    return buf.toString();
  }

  /// À appeler après chaque coup réellement joué (pas pendant la recherche
  /// de l'IA) pour suivre la répétition de position.
  void recordPositionForRepetition() {
    final key = positionKey();
    _repetition[key] = (_repetition[key] ?? 0) + 1;
  }

  bool get isThreefoldRepetition => (_repetition[positionKey()] ?? 0) >= 3;

  GameResult get result {
    if (!hasAnyLegalMove) {
      if (isInCheck) {
        return turn == PieceColor.white ? GameResult.blackWins : GameResult.whiteWins;
      }
      return GameResult.draw;
    }
    if (isInsufficientMaterial || isFiftyMoveRule || isThreefoldRepetition) {
      return GameResult.draw;
    }
    return GameResult.ongoing;
  }

  DrawReason get drawReason {
    if (result != GameResult.draw) return DrawReason.none;
    if (!hasAnyLegalMove) return DrawReason.stalemate;
    if (isInsufficientMaterial) return DrawReason.insufficientMaterial;
    if (isFiftyMoveRule) return DrawReason.fiftyMoveRule;
    if (isThreefoldRepetition) return DrawReason.threefoldRepetition;
    return DrawReason.none;
  }
}
