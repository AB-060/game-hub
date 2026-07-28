/// Modèles pour le mini-jeu de tirs au but.
library penalty_models;

enum PenaltyDifficulty { easy, medium, hard, expert }

extension PenaltyDifficultyX on PenaltyDifficulty {
  String get label {
    switch (this) {
      case PenaltyDifficulty.easy:
        return "Facile";
      case PenaltyDifficulty.medium:
        return "Moyen";
      case PenaltyDifficulty.hard:
        return "Difficile";
      case PenaltyDifficulty.expert:
        return "Expert";
    }
  }

  String get description {
    switch (this) {
      case PenaltyDifficulty.easy:
        return "Gardien lent, mauvais réflexes";
      case PenaltyDifficulty.medium:
        return "Réactions normales";
      case PenaltyDifficulty.hard:
        return "Anticipe et se place bien";
      case PenaltyDifficulty.expert:
        return "Lit le jeu, quasi imparable";
    }
  }

  /// Probabilité que le gardien devine le bon côté.
  double get guessChance {
    switch (this) {
      case PenaltyDifficulty.easy:
        return 0.22;
      case PenaltyDifficulty.medium:
        return 0.42;
      case PenaltyDifficulty.hard:
        return 0.62;
      case PenaltyDifficulty.expert:
        return 0.78;
    }
  }

  /// Probabilité d'arrêt s'il a deviné le bon côté.
  double get saveChanceOnCorrectGuess {
    switch (this) {
      case PenaltyDifficulty.easy:
        return 0.45;
      case PenaltyDifficulty.medium:
        return 0.78;
      case PenaltyDifficulty.hard:
        return 0.92;
      case PenaltyDifficulty.expert:
        return 0.97;
    }
  }

  /// Probabilité d'arrêt malgré un mauvais côté deviné (bon placement).
  double get saveChanceOnWrongGuess {
    switch (this) {
      case PenaltyDifficulty.easy:
        return 0.0;
      case PenaltyDifficulty.medium:
        return 0.08;
      case PenaltyDifficulty.hard:
        return 0.22;
      case PenaltyDifficulty.expert:
        return 0.35;
    }
  }

  /// Délai de réaction du gardien (animation), plus lent = plus battable.
  Duration get reactionDelay {
    switch (this) {
      case PenaltyDifficulty.easy:
        return const Duration(milliseconds: 550);
      case PenaltyDifficulty.medium:
        return const Duration(milliseconds: 380);
      case PenaltyDifficulty.hard:
        return const Duration(milliseconds: 220);
      case PenaltyDifficulty.expert:
        return const Duration(milliseconds: 140);
    }
  }
}

enum ShotZone { left, center, right }

enum PenaltyMode { practice, suddenDeath }

extension PenaltyModeX on PenaltyMode {
  String get label => this == PenaltyMode.practice ? "Entraînement" : "Mort subite";
  String get description => this == PenaltyMode.practice
      ? "5 tirs, marque le plus possible"
      : "Tire jusqu'au premier arrêt";
}
