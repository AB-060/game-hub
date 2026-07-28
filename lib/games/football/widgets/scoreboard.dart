import 'package:flutter/material.dart';

import '../models/team.dart';

/// Tableau de score : drapeaux, noms, score et chronomètre.
class Scoreboard extends StatelessWidget {
  final Team home;
  final Team away;
  final int homeGoals;
  final int awayGoals;
  final int minute;
  final bool finished;

  const Scoreboard({
    super.key,
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.minute,
    this.finished = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF15152C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _teamLabel(home, alignLeft: true),
              Column(
                children: [
                  Text(
                    "$homeGoals - $awayGoals",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    finished ? "Terminé" : "$minute'",
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
              _teamLabel(away, alignLeft: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamLabel(Team team, {required bool alignLeft}) {
    final children = [
      Text(team.flag, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 6, height: 6),
      Flexible(
        child: Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ];
    return Expanded(
      child: Row(
        mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: alignLeft ? children : children.reversed.toList(),
      ),
    );
  }
}
