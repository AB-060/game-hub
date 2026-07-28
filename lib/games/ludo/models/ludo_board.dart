import 'dart:math';

import 'package:flutter/material.dart';

enum PawnColor { red, green, yellow, blue }

extension PawnColorX on PawnColor {
  Color get color {
    switch (this) {
      case PawnColor.red:
        return const Color(0xFFE5484D);
      case PawnColor.green:
        return const Color(0xFF3DD68C);
      case PawnColor.yellow:
        return const Color(0xFFF5C518);
      case PawnColor.blue:
        return const Color(0xFF4C9AFF);
    }
  }

  String get label {
    switch (this) {
      case PawnColor.red:
        return "Rouge";
      case PawnColor.green:
        return "Vert";
      case PawnColor.yellow:
        return "Jaune";
      case PawnColor.blue:
        return "Bleu";
    }
  }
}

enum SeatType { human, ai }

enum LudoDifficulty { easy, medium, expert }

extension LudoDifficultyX on LudoDifficulty {
  String get label {
    switch (this) {
      case LudoDifficulty.easy:
        return "Facile";
      case LudoDifficulty.medium:
        return "Moyen";
      case LudoDifficulty.expert:
        return "Expert";
    }
  }
}

/// Géométrie du plateau de Ludo classique (grille 15x15, piste commune de
/// 52 cases + couloir privé de 6 cases par couleur menant au centre).
class LudoBoard {
  static const int ringLength = 52;
  static const int homeColumnLength = 6;
  static const int finishPosition = 1 + ringLength - 1 + homeColumnLength; // 58

  static const List<PawnColor> playOrder = [
    PawnColor.red,
    PawnColor.green,
    PawnColor.yellow,
    PawnColor.blue,
  ];

  static const Map<PawnColor, int> entryOffset = {
    PawnColor.red: 0,
    PawnColor.green: 13,
    PawnColor.yellow: 26,
    PawnColor.blue: 39,
  };

  static const Set<int> safeRingIndices = {0, 8, 13, 21, 26, 34, 39, 47};

  /// Les 52 cases de la piste commune, dans l'ordre (sens horaire),
  /// index 0 = juste à côté de l'entrée des Rouges.
  static final List<Point<int>> ringCells = [
    // Bras bas du quart rouge -> vers le haut.
    for (int c = 1; c <= 5; c++) Point(6, c),
    for (int r = 5; r >= 0; r--) Point(r, 6),
    Point(0, 7),
    Point(0, 8),
    for (int r = 1; r <= 5; r++) Point(r, 8),
    for (int c = 9; c <= 14; c++) Point(6, c),
    Point(7, 14),
    Point(8, 14),
    for (int c = 13; c >= 9; c--) Point(8, c),
    for (int r = 9; r <= 14; r++) Point(r, 8),
    Point(14, 7),
    Point(14, 6),
    for (int r = 13; r >= 9; r--) Point(r, 6),
    for (int c = 5; c >= 0; c--) Point(8, c),
    Point(7, 0),
    Point(6, 0),
  ];

  static final Map<PawnColor, List<Point<int>>> homeColumns = {
    PawnColor.red: [for (int c = 1; c <= 6; c++) Point(7, c)],
    PawnColor.green: [for (int r = 1; r <= 6; r++) Point(r, 7)],
    PawnColor.yellow: [for (int c = 13; c >= 8; c--) Point(7, c)],
    PawnColor.blue: [for (int r = 13; r >= 8; r--) Point(r, 7)],
  };

  static const Point<int> center = Point(7, 7);

  static final Map<PawnColor, List<Point<int>>> yardSlots = {
    PawnColor.red: const [Point(1, 1), Point(1, 4), Point(4, 1), Point(4, 4)],
    PawnColor.green: const [Point(1, 10), Point(1, 13), Point(4, 10), Point(4, 13)],
    PawnColor.yellow: const [Point(10, 10), Point(10, 13), Point(13, 10), Point(13, 13)],
    PawnColor.blue: const [Point(10, 1), Point(10, 4), Point(13, 1), Point(13, 4)],
  };

  /// Coordonnée (ligne, colonne) sur la grille 15x15 pour une position de
  /// pion donnée (0 = cour, 1..51 = piste commune, 52..57 = couloir privé,
  /// 58 = arrivé au centre).
  static Point<int> cellFor(PawnColor color, int position, int pawnIndex) {
    if (position <= 0) return yardSlots[color]![pawnIndex];
    if (position == finishPosition) return center;
    if (position <= ringLength - 1) {
      final absolute = (entryOffset[color]! + position - 1) % ringLength;
      return ringCells[absolute];
    }
    final homeIndex = position - ringLength;
    return homeColumns[color]![homeIndex];
  }

  /// Index absolu (0..51) sur la piste commune pour une position relative
  /// donnée (1..51 uniquement — nul pour la cour/le couloir privé/le centre).
  static int? absoluteRingIndex(PawnColor color, int position) {
    if (position < 1 || position > ringLength - 1) return null;
    return (entryOffset[color]! + position - 1) % ringLength;
  }

  static bool isSafeRingSquare(int absoluteIndex) => safeRingIndices.contains(absoluteIndex);
}
