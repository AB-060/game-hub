/// Modèles pour Memory : thèmes, difficultés et carte de jeu.
library memory_models;

enum MemoryTheme { animals, fruits, sports, countries, flags, emoji }

extension MemoryThemeX on MemoryTheme {
  String get label {
    switch (this) {
      case MemoryTheme.animals:
        return "Animaux";
      case MemoryTheme.fruits:
        return "Fruits";
      case MemoryTheme.sports:
        return "Sports";
      case MemoryTheme.countries:
        return "Pays";
      case MemoryTheme.flags:
        return "Drapeaux";
      case MemoryTheme.emoji:
        return "Emoji";
    }
  }

  String get icon {
    switch (this) {
      case MemoryTheme.animals:
        return "🐶";
      case MemoryTheme.fruits:
        return "🍎";
      case MemoryTheme.sports:
        return "⚽";
      case MemoryTheme.countries:
        return "🌍";
      case MemoryTheme.flags:
        return "🏳️";
      case MemoryTheme.emoji:
        return "😀";
    }
  }

  List<String> get symbols {
    switch (this) {
      case MemoryTheme.animals:
        return const [
          "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼",
          "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔",
        ];
      case MemoryTheme.fruits:
        return const [
          "🍎", "🍌", "🍇", "🍒", "🍉", "🍓", "🍍", "🥝",
          "🍑", "🍋", "🍐", "🥥", "🍈", "🫐", "🍏", "🥭",
        ];
      case MemoryTheme.sports:
        return const [
          "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏉", "🎱",
          "🏓", "🏸", "🥊", "🥋", "⛳", "🏹", "🎳", "🛹",
        ];
      case MemoryTheme.countries:
        return const [
          "FR", "US", "JP", "BR", "DE", "IT", "ES", "CA",
          "MX", "EG", "IN", "CN", "RU", "AU", "KR", "MA",
        ];
      case MemoryTheme.flags:
        return const [
          "🇫🇷", "🇺🇸", "🇯🇵", "🇧🇷", "🇩🇪", "🇮🇹", "🇪🇸", "🇨🇦",
          "🇲🇽", "🇪🇬", "🇮🇳", "🇨🇳", "🇷🇺", "🇦🇺", "🇰🇷", "🇲🇦",
        ];
      case MemoryTheme.emoji:
        return const [
          "😀", "😂", "😍", "😎", "🤩", "🥳", "😴", "🤯",
          "👻", "👽", "🤖", "🎃", "❤️", "⭐", "🔥", "💧",
        ];
    }
  }
}

enum MemoryDifficulty { easy, medium, hard, expert }

extension MemoryDifficultyX on MemoryDifficulty {
  String get label {
    switch (this) {
      case MemoryDifficulty.easy:
        return "Facile";
      case MemoryDifficulty.medium:
        return "Moyen";
      case MemoryDifficulty.hard:
        return "Difficile";
      case MemoryDifficulty.expert:
        return "Expert";
    }
  }

  int get columns {
    switch (this) {
      case MemoryDifficulty.easy:
        return 3;
      case MemoryDifficulty.medium:
        return 4;
      case MemoryDifficulty.hard:
        return 4;
      case MemoryDifficulty.expert:
        return 5;
    }
  }

  int get rows {
    switch (this) {
      case MemoryDifficulty.easy:
        return 4;
      case MemoryDifficulty.medium:
        return 4;
      case MemoryDifficulty.hard:
        return 5;
      case MemoryDifficulty.expert:
        return 6;
    }
  }

  int get pairCount => (columns * rows) ~/ 2;
}

class MemoryCard {
  final int id;
  final String symbol;
  bool revealed;
  bool matched;

  MemoryCard({
    required this.id,
    required this.symbol,
    this.revealed = false,
    this.matched = false,
  });
}
