import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/particle_background.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../models/team.dart';
import '../models/teams_database.dart';
import '../models/tournament_models.dart';
import 'tournament_bracket_screen.dart';

/// Choix de la compétition (Coupe du Monde, CAN, Euro, Copa América,
/// Coupe d'Asie, tournoi personnalisé) et de la taille du tableau. Le
/// vivier de participants est automatiquement filtré par confédération
/// pour les compétitions continentales, et l'équipe du joueur y est
/// toujours incluse.
class TournamentSetupScreen extends StatefulWidget {
  final Team playerTeam;

  const TournamentSetupScreen({super.key, required this.playerTeam});

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  CompetitionType _type = CompetitionType.worldCup;
  int _size = 8;

  List<Team> _buildParticipants() {
    final continent = _type.restrictedContinent;
    var pool = continent == null
        ? List<Team>.of(TeamsDatabase.all)
        : TeamsDatabase.byContinent(continent);
    pool = List.of(pool)..shuffle(Random());
    pool.removeWhere((t) => t.id == widget.playerTeam.id);
    final opponentCount = min(_size - 1, pool.length);
    final participants = [widget.playerTeam, ...pool.take(opponentCount)];
    participants.shuffle(Random());
    return participants; // TournamentEngine se charge d'arrondir à la puissance de 2 inférieure.
  }

  void _start() {
    final participants = _buildParticipants();
    if (participants.length < 2) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TournamentBracketScreen(type: _type, participants: participants),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Compétitions"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Choisis une compétition",
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  ...CompetitionType.values.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _competitionTile(t),
                      )),
                  const SizedBox(height: 16),
                  Text(
                    "Taille du tableau",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: kMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [4, 8].map((s) {
                      final selected = _size == s;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: s == 8 ? 0 : 8),
                          child: SelectableChip(
                            selected: selected,
                            label: "$s équipes",
                            onTap: () => setState(() => _size = s),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.emoji_events_rounded),
                    label: const Text("Lancer le tournoi"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _competitionTile(CompetitionType type) {
    final selected = _type == type;
    return GlassCard(
      borderColor: selected ? kAccent : Colors.white12,
      child: InkWell(
        onTap: () => setState(() => _type = type),
        child: Row(
          children: [
            Text(type.trophy, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(type.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? kAccent : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}
