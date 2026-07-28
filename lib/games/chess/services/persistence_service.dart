import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chess_models.dart';

class ChessStats {
  final int wins;
  final int losses;
  final int draws;
  final int totalSecondsPlayed;

  const ChessStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalSecondsPlayed = 0,
  });

  int get gamesPlayed => wins + losses + draws;

  ChessStats copyWith({int? wins, int? losses, int? draws, int? totalSecondsPlayed}) {
    return ChessStats(
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      totalSecondsPlayed: totalSecondsPlayed ?? this.totalSecondsPlayed,
    );
  }

  Map<String, dynamic> toJson() => {
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'totalSecondsPlayed': totalSecondsPlayed,
      };

  factory ChessStats.fromJson(Map<String, dynamic> json) => ChessStats(
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        draws: json['draws'] as int? ?? 0,
        totalSecondsPlayed: json['totalSecondsPlayed'] as int? ?? 0,
      );
}

class SavedGame {
  final Map<String, dynamic> engineJson;
  /// null = partie locale à 2 joueurs (pas d'IA).
  final Difficulty? difficulty;
  final PieceColor playerColor;
  final int whiteSeconds;
  final int blackSeconds;
  final List<String> moveHistorySan;

  const SavedGame({
    required this.engineJson,
    required this.difficulty,
    required this.playerColor,
    required this.whiteSeconds,
    required this.blackSeconds,
    required this.moveHistorySan,
  });

  Map<String, dynamic> toJson() => {
        'engine': engineJson,
        'difficulty': difficulty?.name,
        'playerColor': playerColor.name,
        'whiteSeconds': whiteSeconds,
        'blackSeconds': blackSeconds,
        'history': moveHistorySan,
      };

  factory SavedGame.fromJson(Map<String, dynamic> json) => SavedGame(
        engineJson: Map<String, dynamic>.from(json['engine'] as Map),
        difficulty: json['difficulty'] == null
            ? null
            : Difficulty.values.firstWhere((d) => d.name == json['difficulty']),
        playerColor: json['playerColor'] == 'white' ? PieceColor.white : PieceColor.black,
        whiteSeconds: json['whiteSeconds'] as int? ?? 0,
        blackSeconds: json['blackSeconds'] as int? ?? 0,
        moveHistorySan: (json['history'] as List<dynamic>? ?? []).cast<String>(),
      );
}

/// Sauvegarde automatique de la partie en cours + statistiques persistées
/// (victoires / défaites / nulles / temps de jeu total).
class PersistenceService {
  PersistenceService._();
  static final PersistenceService instance = PersistenceService._();

  static const _gameKey = 'chess_saved_game_v1';
  static const _statsKey = 'chess_stats_v1';

  Future<void> saveGame(SavedGame game) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gameKey, jsonEncode(game.toJson()));
  }

  Future<SavedGame?> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_gameKey);
    if (raw == null) return null;
    try {
      return SavedGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gameKey);
  }

  Future<ChessStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_statsKey);
    if (raw == null) return const ChessStats();
    try {
      return ChessStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ChessStats();
    }
  }

  Future<void> _saveStats(ChessStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  Future<ChessStats> recordResult({
    required GameResult result,
    required PieceColor playerColor,
    required int secondsPlayed,
  }) async {
    final current = await loadStats();
    final playerWon = (result == GameResult.whiteWins && playerColor == PieceColor.white) ||
        (result == GameResult.blackWins && playerColor == PieceColor.black);
    final playerLost = (result == GameResult.whiteWins && playerColor == PieceColor.black) ||
        (result == GameResult.blackWins && playerColor == PieceColor.white);

    final updated = current.copyWith(
      wins: current.wins + (playerWon ? 1 : 0),
      losses: current.losses + (playerLost ? 1 : 0),
      draws: current.draws + (result == GameResult.draw ? 1 : 0),
      totalSecondsPlayed: current.totalSecondsPlayed + secondsPlayed,
    );
    await _saveStats(updated);
    return updated;
  }
}
