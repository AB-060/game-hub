import 'dart:math';

/// Modèles pour Snake : difficultés, cartes (obstacles) et types d'objets
/// spéciaux.
enum SnakeDifficulty { easy, medium, expert }

extension SnakeDifficultyX on SnakeDifficulty {
  String get label {
    switch (this) {
      case SnakeDifficulty.easy:
        return "Facile";
      case SnakeDifficulty.medium:
        return "Moyen";
      case SnakeDifficulty.expert:
        return "Expert";
    }
  }

  Duration get tickInterval {
    switch (this) {
      case SnakeDifficulty.easy:
        return const Duration(milliseconds: 190);
      case SnakeDifficulty.medium:
        return const Duration(milliseconds: 130);
      case SnakeDifficulty.expert:
        return const Duration(milliseconds: 85);
    }
  }
}

enum ItemType { speedBoost, shield, doubleScore, bonusFood }

extension ItemTypeX on ItemType {
  String get emoji {
    switch (this) {
      case ItemType.speedBoost:
        return "⚡";
      case ItemType.shield:
        return "🛡️";
      case ItemType.doubleScore:
        return "✨";
      case ItemType.bonusFood:
        return "🍇";
    }
  }
}

class SnakeMap {
  final String name;
  final Set<Point<int>> Function(int gridSize) obstaclesBuilder;
  const SnakeMap(this.name, this.obstaclesBuilder);

  Set<Point<int>> obstacles(int gridSize) => obstaclesBuilder(gridSize);
}

/// Quelques cartes avec des dispositions d'obstacles différentes.
class SnakeMaps {
  static final List<SnakeMap> all = [
    SnakeMap("Classique", (size) => {}),
    SnakeMap("Croix", (size) {
      final c = size ~/ 2;
      final obstacles = <Point<int>>{};
      // Ne place rien à distance 1 du centre : le serpent y démarre et part
      // toujours vers la droite, un obstacle adjacent serait une mort assurée.
      for (final i in [-3, -2, 2, 3]) {
        obstacles.add(Point(c + i, c));
        obstacles.add(Point(c, c + i));
      }
      return obstacles;
    }),
    SnakeMap("Coins", (size) {
      final obstacles = <Point<int>>{};
      final offsets = [2, size - 3];
      for (final r in offsets) {
        for (final c in offsets) {
          obstacles.add(Point(r, c));
          obstacles.add(Point(r + 1, c));
          obstacles.add(Point(r, c + 1));
        }
      }
      return obstacles;
    }),
    SnakeMap("Labyrinthe", (size) {
      final obstacles = <Point<int>>{};
      for (int r = 3; r < size - 3; r += 3) {
        for (int c = 2; c < size - 2; c++) {
          if ((r ~/ 3).isEven ? c < size - 4 : c > 3) {
            obstacles.add(Point(r, c));
          }
        }
      }
      return obstacles;
    }),
  ];
}
