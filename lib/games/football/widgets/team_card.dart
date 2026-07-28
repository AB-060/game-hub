import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/team.dart';
import 'stat_bar.dart';

/// Carte premium présentant une sélection nationale : drapeau, nom, note
/// générale et attributs, avec un liseré aux couleurs nationales.
class TeamCard extends StatelessWidget {
  final Team team;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  const TeamCard({
    super.key,
    required this.team,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.all(compact ? 10 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              team.primaryColor.withOpacity(selected ? 0.32 : 0.14),
              const Color(0xFF15152C),
            ],
          ),
          border: Border.all(
            color: selected ? team.primaryColor : Colors.white12,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: team.primaryColor.withOpacity(0.35), blurRadius: 16)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(team.flag, style: TextStyle(fontSize: compact ? 26 : 32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        team.confederation,
                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${team.overall}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              StatBar(label: "Attaque", value: team.attack, color: const Color(0xFFFF5C5C)),
              const SizedBox(height: 6),
              StatBar(label: "Milieu", value: team.midfield, color: const Color(0xFFFFC24B)),
              const SizedBox(height: 6),
              StatBar(label: "Défense", value: team.defense, color: const Color(0xFF4BD4E3)),
              const SizedBox(height: 6),
              StatBar(label: "Gardien", value: team.goalkeeper, color: const Color(0xFF4BE38A)),
            ],
          ],
        ),
      ),
    );
  }
}
