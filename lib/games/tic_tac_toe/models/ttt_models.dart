/// Modèles de données pour le Morpion (grilles 3x3, 4x4 ou 5x5).
library ttt_models;

enum PlayerMark { x, o }

extension PlayerMarkX on PlayerMark {
  PlayerMark get opposite => this == PlayerMark.x ? PlayerMark.o : PlayerMark.x;
  String get label => this == PlayerMark.x ? "X" : "O";
}

enum TttDifficulty { beginner, intermediate, expert }

extension TttDifficultyX on TttDifficulty {
  String get label {
    switch (this) {
      case TttDifficulty.beginner:
        return "Débutant";
      case TttDifficulty.intermediate:
        return "Intermédiaire";
      case TttDifficulty.expert:
        return "Expert";
    }
  }

  String get description {
    switch (this) {
      case TttDifficulty.beginner:
        return "Joue presque au hasard";
      case TttDifficulty.intermediate:
        return "Bloque et prépare des combinaisons";
      case TttDifficulty.expert:
        return "Minimax — ne perd presque jamais";
    }
  }
}

enum TttBoardSize { size3, size4, size5 }

extension TttBoardSizeX on TttBoardSize {
  int get dimension {
    switch (this) {
      case TttBoardSize.size3:
        return 3;
      case TttBoardSize.size4:
        return 4;
      case TttBoardSize.size5:
        return 5;
    }
  }

  /// Nombre de symboles alignés nécessaires pour gagner.
  int get winLength => dimension == 3 ? 3 : 4;

  String get label => "${dimension}x$dimension";
}

enum TttResult { ongoing, xWins, oWins, draw }
