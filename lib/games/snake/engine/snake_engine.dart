import 'dart:math';

import '../models/snake_models.dart';

enum TickOutcome { moved, ateFood, ateItem, shieldBlocked, dead }

class SnakeTickResult {
  final TickOutcome outcome;
  final ItemType? item;
  const SnakeTickResult(this.outcome, [this.item]);
}

/// Moteur de Snake : plateau, déplacement, collisions, nourriture et
/// objets spéciaux (bouclier, boost de vitesse, double score, bonus).
/// Ne gère pas le temps lui-même : [tick] doit être appelé par un
/// `Timer.periodic` externe (l'intervalle dépend de la difficulté et du
/// boost de vitesse actif).
class SnakeEngine {
  final int gridSize;
  final Set<Point<int>> obstacles;
  final Random _rand = Random();

  List<Point<int>> snake;
  Point<int> direction = const Point(1, 0);
  Point<int> _nextDirection = const Point(1, 0);

  Point<int> food = const Point(-1, -1);
  Point<int>? itemPosition;
  ItemType? itemType;
  int _itemLifespan = 0;

  int score = 0;
  bool alive = true;
  int shieldCharges = 0;
  int speedTicksLeft = 0;
  int doubleScoreTicksLeft = 0;

  SnakeEngine({required this.gridSize, required this.obstacles})
      : snake = [Point(gridSize ~/ 2, gridSize ~/ 2)] {
    _placeFood();
  }

  bool get speedBoosted => speedTicksLeft > 0;
  bool get shielded => shieldCharges > 0;
  bool get doubleScoreActive => doubleScoreTicksLeft > 0;

  void setDirection(Point<int> d) {
    if (direction.x + d.x == 0 && direction.y + d.y == 0) return; // demi-tour interdit
    _nextDirection = d;
  }

  bool _isFree(Point<int> p) {
    return p != food && itemPosition != p && !snake.contains(p) && !obstacles.contains(p);
  }

  void _placeFood() {
    Point<int> p;
    do {
      p = Point(_rand.nextInt(gridSize), _rand.nextInt(gridSize));
    } while (!_isFree(p) && p != food);
    food = p;
  }

  void _maybeSpawnItem() {
    if (itemPosition != null) return;
    if (_rand.nextDouble() > 0.06) return;
    Point<int> p;
    int attempts = 0;
    do {
      p = Point(_rand.nextInt(gridSize), _rand.nextInt(gridSize));
      attempts++;
    } while (!_isFree(p) && attempts < 30);
    if (!_isFree(p)) return;
    itemPosition = p;
    final types = ItemType.values;
    itemType = types[_rand.nextInt(types.length)];
    _itemLifespan = 60;
  }

  SnakeTickResult tick() {
    if (!alive) return const SnakeTickResult(TickOutcome.dead);

    direction = _nextDirection;
    final head = snake.first;
    final newHead = Point(head.x + direction.x, head.y + direction.y);

    final outOfBounds =
        newHead.x < 0 || newHead.x >= gridSize || newHead.y < 0 || newHead.y >= gridSize;
    final hitsBody = !outOfBounds && snake.contains(newHead) && newHead != snake.last;
    final hitsObstacle = !outOfBounds && obstacles.contains(newHead);
    final collision = outOfBounds || hitsBody || hitsObstacle;

    if (collision) {
      if (shieldCharges > 0) {
        shieldCharges--;
        return const SnakeTickResult(TickOutcome.shieldBlocked);
      }
      alive = false;
      return const SnakeTickResult(TickOutcome.dead);
    }

    snake.insert(0, newHead);

    TickOutcome outcome = TickOutcome.moved;
    ItemType? consumedItem;

    if (newHead == food) {
      final points = doubleScoreActive ? 20 : 10;
      score += points;
      _placeFood();
      outcome = TickOutcome.ateFood;
    } else if (itemPosition != null && newHead == itemPosition) {
      consumedItem = itemType;
      _applyItemEffect(itemType!);
      itemPosition = null;
      itemType = null;
      outcome = TickOutcome.ateItem;
      snake.removeLast(); // les objets spéciaux ne font pas grandir le serpent
    } else {
      snake.removeLast();
    }

    if (speedTicksLeft > 0) speedTicksLeft--;
    if (doubleScoreTicksLeft > 0) doubleScoreTicksLeft--;
    if (itemPosition != null) {
      _itemLifespan--;
      if (_itemLifespan <= 0) {
        itemPosition = null;
        itemType = null;
      }
    }
    _maybeSpawnItem();

    return SnakeTickResult(outcome, consumedItem);
  }

  void _applyItemEffect(ItemType type) {
    switch (type) {
      case ItemType.speedBoost:
        speedTicksLeft = 40;
        break;
      case ItemType.shield:
        shieldCharges++;
        break;
      case ItemType.doubleScore:
        doubleScoreTicksLeft = 60;
        break;
      case ItemType.bonusFood:
        score += doubleScoreActive ? 60 : 30;
        break;
    }
  }
}
