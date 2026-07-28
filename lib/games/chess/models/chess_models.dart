/// Modèles de données pour le moteur d'échecs.
///
/// Le plateau est représenté par une liste de 64 cases (index 0..63),
/// index = row * 8 + col, avec row 0 = rangée du haut (noirs par défaut)
/// et col 0 = colonne 'a'.
library chess_models;

enum PieceType { pawn, knight, bishop, rook, queen, king }

enum PieceColor { white, black }

extension PieceColorX on PieceColor {
  PieceColor get opposite => this == PieceColor.white ? PieceColor.black : PieceColor.white;
}

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  const ChessPiece(this.type, this.color);

  ChessPiece copyWith({PieceType? type}) => ChessPiece(type ?? this.type, color);

  @override
  bool operator ==(Object other) =>
      other is ChessPiece && other.type == type && other.color == color;

  @override
  int get hashCode => Object.hash(type, color);
}

/// Représente un coup joué, avec assez d'informations pour être annulé
/// (undo) et pour être affiché en notation algébrique simplifiée.
class ChessMove {
  final int from;
  final int to;
  final ChessPiece piece;
  final ChessPiece? captured;
  final PieceType? promotion;
  final bool isCastleKingSide;
  final bool isCastleQueenSide;
  final bool isEnPassant;
  final int? enPassantCapturedSquare;

  // Informations nécessaires pour annuler le coup (remplies par le moteur).
  final bool prevWhiteKingSideCastle;
  final bool prevWhiteQueenSideCastle;
  final bool prevBlackKingSideCastle;
  final bool prevBlackQueenSideCastle;
  final int? prevEnPassantTarget;
  final int prevHalfmoveClock;

  bool isCheck = false;
  bool isCheckmate = false;
  bool isStalemate = false;

  ChessMove({
    required this.from,
    required this.to,
    required this.piece,
    this.captured,
    this.promotion,
    this.isCastleKingSide = false,
    this.isCastleQueenSide = false,
    this.isEnPassant = false,
    this.enPassantCapturedSquare,
    required this.prevWhiteKingSideCastle,
    required this.prevWhiteQueenSideCastle,
    required this.prevBlackKingSideCastle,
    required this.prevBlackQueenSideCastle,
    required this.prevEnPassantTarget,
    required this.prevHalfmoveClock,
  });

  bool get isCapture => captured != null || isEnPassant;

  static String squareName(int square) {
    final col = square % 8;
    final row = square ~/ 8;
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = 8 - row;
    return "$file$rank";
  }

  /// Notation algébrique simplifiée (pas de désambiguïsation complète).
  String toAlgebraic() {
    if (isCastleKingSide) return isCheckmate ? "O-O#" : (isCheck ? "O-O+" : "O-O");
    if (isCastleQueenSide) return isCheckmate ? "O-O-O#" : (isCheck ? "O-O-O+" : "O-O-O");

    const symbols = {
      PieceType.king: "R",
      PieceType.queen: "D",
      PieceType.rook: "T",
      PieceType.bishop: "F",
      PieceType.knight: "C",
      PieceType.pawn: "",
    };

    final buffer = StringBuffer();
    buffer.write(symbols[piece.type]);
    if (piece.type == PieceType.pawn && isCapture) {
      buffer.write(String.fromCharCode('a'.codeUnitAt(0) + (from % 8)));
    }
    if (isCapture) buffer.write("x");
    buffer.write(squareName(to));
    if (promotion != null) {
      buffer.write("=${symbols[promotion]}");
    }
    if (isCheckmate) {
      buffer.write("#");
    } else if (isCheck) {
      buffer.write("+");
    }
    return buffer.toString();
  }
}

enum GameResult { ongoing, whiteWins, blackWins, draw }

enum DrawReason { none, stalemate, insufficientMaterial, fiftyMoveRule, threefoldRepetition }

enum Difficulty { beginner, intermediate, expert }

extension DifficultyX on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.beginner:
        return "Débutant";
      case Difficulty.intermediate:
        return "Intermédiaire";
      case Difficulty.expert:
        return "Expert";
    }
  }

  String get description {
    switch (this) {
      case Difficulty.beginner:
        return "Coups aléatoires occasionnels, idéal pour apprendre";
      case Difficulty.intermediate:
        return "Recherche à profondeur moyenne, bon niveau";
      case Difficulty.expert:
        return "Minimax + élagage alpha-bêta en profondeur";
    }
  }
}
