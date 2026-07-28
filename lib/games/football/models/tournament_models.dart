import 'team.dart';

enum CompetitionType { worldCup, afcon, euro, copaAmerica, asianCup, custom }

extension CompetitionTypeX on CompetitionType {
  String get label {
    switch (this) {
      case CompetitionType.worldCup:
        return "Coupe du Monde";
      case CompetitionType.afcon:
        return "Coupe d'Afrique des Nations";
      case CompetitionType.euro:
        return "Euro";
      case CompetitionType.copaAmerica:
        return "Copa América";
      case CompetitionType.asianCup:
        return "Coupe d'Asie";
      case CompetitionType.custom:
        return "Tournoi personnalisé";
    }
  }

  String get trophy => "🏆";

  /// Continent auquel restreindre le vivier de participants (null = toutes
  /// confédérations, comme la Coupe du Monde ou un tournoi personnalisé).
  Continent? get restrictedContinent {
    switch (this) {
      case CompetitionType.afcon:
        return Continent.africa;
      case CompetitionType.euro:
        return Continent.europe;
      case CompetitionType.copaAmerica:
        return Continent.southAmerica;
      case CompetitionType.asianCup:
        return Continent.asia;
      case CompetitionType.worldCup:
      case CompetitionType.custom:
        return null;
    }
  }
}

/// Un huitième/quart/demi/finale entre deux équipes.
class Fixture {
  final Team home;
  final Team away;
  int? homeGoals;
  int? awayGoals;
  String? winnerId;

  Fixture({required this.home, required this.away});

  bool get isResolved => winnerId != null;
  Team get winner => winnerId == home.id ? home : away;
  Team get loser => winnerId == home.id ? away : home;
}

class TournamentRound {
  final String name;
  final List<Fixture> fixtures;
  TournamentRound(this.name, this.fixtures);
}
