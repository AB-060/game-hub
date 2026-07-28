import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Statistiques génériques d'un jeu (parties jouées, victoires, défaites,
/// nulles, temps de jeu, meilleur score, plus longue série de victoires).
/// Un jeu peut ignorer les champs qui ne le concernent pas (ex: Memory n'a
/// pas de "défaites").
class GameStats {
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final int totalSecondsPlayed;
  final int bestScore;
  final int bestWinStreak;
  final int currentWinStreak;
  final String lastDifficulty;

  const GameStats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalSecondsPlayed = 0,
    this.bestScore = 0,
    this.bestWinStreak = 0,
    this.currentWinStreak = 0,
    this.lastDifficulty = '',
  });

  GameStats copyWith({
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
    int? totalSecondsPlayed,
    int? bestScore,
    int? bestWinStreak,
    int? currentWinStreak,
    String? lastDifficulty,
  }) {
    return GameStats(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      totalSecondsPlayed: totalSecondsPlayed ?? this.totalSecondsPlayed,
      bestScore: bestScore ?? this.bestScore,
      bestWinStreak: bestWinStreak ?? this.bestWinStreak,
      currentWinStreak: currentWinStreak ?? this.currentWinStreak,
      lastDifficulty: lastDifficulty ?? this.lastDifficulty,
    );
  }

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'totalSecondsPlayed': totalSecondsPlayed,
        'bestScore': bestScore,
        'bestWinStreak': bestWinStreak,
        'currentWinStreak': currentWinStreak,
        'lastDifficulty': lastDifficulty,
      };

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
        gamesPlayed: json['gamesPlayed'] as int? ?? 0,
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        draws: json['draws'] as int? ?? 0,
        totalSecondsPlayed: json['totalSecondsPlayed'] as int? ?? 0,
        bestScore: json['bestScore'] as int? ?? 0,
        bestWinStreak: json['bestWinStreak'] as int? ?? 0,
        currentWinStreak: json['currentWinStreak'] as int? ?? 0,
        lastDifficulty: json['lastDifficulty'] as String? ?? '',
      );
}

/// Service de statistiques générique, namespacé par jeu (ex: "tictactoe",
/// "memory", "snake"...). Chaque jeu instancie le sien avec sa propre clé.
class GameStatsService {
  final String gameKey;
  const GameStatsService(this.gameKey);

  String get _key => 'stats_$gameKey';

  Future<GameStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const GameStats();
    try {
      return GameStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const GameStats();
    }
  }

  Future<void> save(GameStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(stats.toJson()));
  }

  /// Enregistre la fin d'une partie et met à jour les compteurs dérivés
  /// (série de victoires, meilleur score, temps total).
  Future<GameStats> recordGameEnd({
    bool won = false,
    bool lost = false,
    bool draw = false,
    int score = 0,
    int secondsPlayed = 0,
    String? difficulty,
  }) async {
    final current = await load();
    final newStreak = won ? current.currentWinStreak + 1 : 0;
    final updated = current.copyWith(
      gamesPlayed: current.gamesPlayed + 1,
      wins: current.wins + (won ? 1 : 0),
      losses: current.losses + (lost ? 1 : 0),
      draws: current.draws + (draw ? 1 : 0),
      totalSecondsPlayed: current.totalSecondsPlayed + secondsPlayed,
      bestScore: score > current.bestScore ? score : current.bestScore,
      currentWinStreak: newStreak,
      bestWinStreak: newStreak > current.bestWinStreak ? newStreak : current.bestWinStreak,
      lastDifficulty: difficulty ?? current.lastDifficulty,
    );
    await save(updated);
    return updated;
  }
}
