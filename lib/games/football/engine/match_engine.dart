import 'dart:math';

import '../models/match_models.dart';
import '../models/team.dart';
import '../utils/commentary.dart';

/// Simule un match minute par minute à partir des statistiques des deux
/// équipes. Pensé pour être piloté par un `Timer` côté UI via
/// [advanceMinute], qui retourne les évènements survenus pendant cette
/// minute (souvent aucun).
class MatchEngine {
  final Team home;
  final Team away;
  final Weather weather;
  final Random _rand = Random();

  int minute = 0;
  int homeGoals = 0;
  int awayGoals = 0;
  bool finished = false;
  late final MatchStats stats;
  final List<MatchEvent> allEvents = [];

  MatchEngine({required this.home, required this.away, required this.weather}) {
    final homeWeight = home.midfield + home.passing + 5; // léger avantage du terrain
    final awayWeight = away.midfield + away.passing;
    final total = homeWeight + awayWeight;
    final possessionHome = (homeWeight / total * 100).round().clamp(30, 70);
    stats = MatchStats(possessionHome: possessionHome, possessionAway: 100 - possessionHome);
  }

  List<MatchEvent> start() {
    final event = MatchEvent(
      minute: 0,
      type: MatchEventType.kickoff,
      teamId: '',
      text: Commentary.pick(Commentary.kickoff),
    );
    allEvents.add(event);
    return [event];
  }

  List<MatchEvent> advanceMinute() {
    if (finished) return const [];
    minute++;
    final events = <MatchEvent>[];

    if (minute == 45) {
      events.add(_record(MatchEventType.halfTime, '', Commentary.pick(Commentary.halfTime)));
    }

    // Chance d'occasion notable ce tour-ci.
    if (_rand.nextDouble() < 0.09) {
      final attackingHome = _rand.nextDouble() < _homeAttackShare();
      events.addAll(_resolveChance(attackingHome));
    }

    // Chance de faute indépendante.
    if (_rand.nextDouble() < 0.05) {
      final offendingHome = _rand.nextBool();
      events.addAll(_resolveFoul(offendingHome));
    }

    if (minute >= 90) {
      finished = true;
      events.add(_record(MatchEventType.fullTime, '', Commentary.pick(Commentary.fullTime)));
    }

    allEvents.addAll(events);
    return events;
  }

  double _homeAttackShare() {
    final homeStrength = home.attack + home.midfield * 0.5 + 5;
    final awayStrength = away.attack + away.midfield * 0.5;
    return homeStrength / (homeStrength + awayStrength);
  }

  List<MatchEvent> _resolveChance(bool homeAttacking) {
    final attacker = homeAttacking ? home : away;
    final defender = homeAttacking ? away : home;

    if (homeAttacking) {
      stats.shotsHome++;
    } else {
      stats.shotsAway++;
    }

    // Probabilité de but pondérée par l'écart de niveau, avec un plancher
    // pour qu'un outsider garde toujours une chance réaliste de marquer.
    final diff = attacker.shooting - defender.goalkeeper - weather.shotPenalty;
    final goalProbability = (0.30 + diff * 0.012).clamp(0.06, 0.65);
    final onTargetProbability = goalProbability + 0.32;
    final roll = _rand.nextDouble();

    final events = <MatchEvent>[];
    if (roll < goalProbability) {
      if (homeAttacking) {
        homeGoals++;
        stats.shotsOnTargetHome++;
      } else {
        awayGoals++;
        stats.shotsOnTargetAway++;
      }
      events.add(_record(MatchEventType.goal, attacker.id, Commentary.pick(Commentary.goals)));
    } else if (roll < onTargetProbability) {
      if (homeAttacking) {
        stats.shotsOnTargetHome++;
      } else {
        stats.shotsOnTargetAway++;
      }
      events.add(_record(MatchEventType.saved, defender.id, Commentary.pick(Commentary.saves)));
    } else {
      events.add(_record(MatchEventType.missed, attacker.id, Commentary.pick(Commentary.misses)));
    }
    return events;
  }

  List<MatchEvent> _resolveFoul(bool homeOffending) {
    if (homeOffending) {
      stats.foulsHome++;
    } else {
      stats.foulsAway++;
    }
    final offender = homeOffending ? home : away;
    final severity = _rand.nextDouble();
    if (severity < 0.03) {
      if (homeOffending) {
        stats.redHome++;
      } else {
        stats.redAway++;
      }
      return [_record(MatchEventType.redCard, offender.id, Commentary.pick(Commentary.redCards))];
    } else if (severity < 0.22) {
      if (homeOffending) {
        stats.yellowHome++;
      } else {
        stats.yellowAway++;
      }
      return [
        _record(MatchEventType.yellowCard, offender.id, Commentary.pick(Commentary.yellowCards)),
      ];
    }
    return const [];
  }

  MatchEvent _record(MatchEventType type, String teamId, String text) {
    return MatchEvent(minute: minute, type: type, teamId: teamId, text: text);
  }
}
