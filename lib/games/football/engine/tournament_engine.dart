import 'dart:math';

import '../models/team.dart';
import '../models/tournament_models.dart';

/// Bracket à élimination directe générique, réutilisé pour toutes les
/// compétitions (Coupe du Monde, CAN, Euro, Copa América, Coupe d'Asie,
/// tournoi personnalisé) — seul le vivier de participants change.
/// La simulation des matchs eux-mêmes est déléguée à l'appelant (UI),
/// qui rapporte le résultat via [resolveFixture].
class TournamentEngine {
  final CompetitionType type;
  final List<TournamentRound> rounds = [];
  Team? champion;
  Team? runnerUp;

  TournamentEngine({required this.type, required List<Team> participants, bool shuffleSeed = true}) {
    var pool = List<Team>.of(participants);
    if (shuffleSeed) pool.shuffle(Random());
    int size = 1;
    while (size * 2 <= pool.length) {
      size *= 2;
    }
    pool = pool.take(size).toList();
    rounds.add(TournamentRound(
      _roundName(pool.length),
      [for (int i = 0; i < pool.length; i += 2) Fixture(home: pool[i], away: pool[i + 1])],
    ));
  }

  static String _roundName(int teamsInRound) {
    switch (teamsInRound) {
      case 2:
        return "Finale";
      case 4:
        return "Demi-finales";
      case 8:
        return "Quarts de finale";
      case 16:
        return "Huitièmes de finale";
      default:
        return "Tour préliminaire";
    }
  }

  TournamentRound get currentRound => rounds.last;
  bool get isRoundComplete => currentRound.fixtures.every((f) => f.isResolved);
  bool get isComplete => champion != null;

  /// Enregistre le vainqueur d'un match (départagé au préalable par
  /// l'appelant en cas d'égalité, ex: tirs au but).
  void resolveFixture(Fixture fixture, String winnerId) {
    fixture.winnerId = winnerId;
    if (isRoundComplete) _advanceRound();
  }

  void _advanceRound() {
    final winners = currentRound.fixtures.map((f) => f.winner).toList();
    if (winners.length == 1) {
      champion = winners.first;
      runnerUp = currentRound.fixtures.first.loser;
      return;
    }
    final nextFixtures = [
      for (int i = 0; i < winners.length; i += 2) Fixture(home: winners[i], away: winners[i + 1]),
    ];
    rounds.add(TournamentRound(_roundName(winners.length), nextFixtures));
  }
}

class ShootoutTieBreakResult {
  final int goalsA;
  final int goalsB;
  final bool aWins;
  const ShootoutTieBreakResult({required this.goalsA, required this.goalsB, required this.aWins});
}

/// Simule une séance de tirs au but entre deux équipes pour départager un
/// match nul en phase à élimination directe (5 tirs chacun, puis mort
/// subite si nécessaire).
ShootoutTieBreakResult simulateShootoutTieBreak(Team a, Team b, [Random? random]) {
  final rand = random ?? Random();

  bool takeShot(Team shooter, Team keeper) {
    final chance = (0.78 + (shooter.shooting - keeper.goalkeeper) * 0.004).clamp(0.45, 0.92);
    return rand.nextDouble() < chance;
  }

  int goalsA = 0, goalsB = 0;
  for (int round = 0; round < 5; round++) {
    if (takeShot(a, b)) goalsA++;
    if (takeShot(b, a)) goalsB++;
  }

  int extraRounds = 0;
  while (goalsA == goalsB && extraRounds < 5) {
    if (takeShot(a, b)) goalsA++;
    if (takeShot(b, a)) goalsB++;
    extraRounds++;
  }

  if (goalsA == goalsB) {
    // Départage ultime très improbable : léger avantage au mieux classé.
    final aWins = a.overall + rand.nextInt(10) >= b.overall + rand.nextInt(10);
    return ShootoutTieBreakResult(goalsA: goalsA, goalsB: goalsB, aWins: aWins);
  }
  return ShootoutTieBreakResult(goalsA: goalsA, goalsB: goalsB, aWins: goalsA > goalsB);
}
