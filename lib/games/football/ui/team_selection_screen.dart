import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/particle_background.dart';
import '../../../theme/app_colors.dart';
import '../models/team.dart';
import '../models/teams_database.dart';
import '../widgets/team_card.dart';

/// Sélection Continent → Pays, réutilisée pour choisir sa propre équipe ou
/// l'adversaire. [excludeTeamId] évite qu'une équipe affronte elle-même.
/// [restrictedContinent] limite le vivier (ex: CAN = Afrique uniquement).
class TeamSelectionScreen extends StatefulWidget {
  final String title;
  final String? excludeTeamId;
  final Continent? restrictedContinent;

  const TeamSelectionScreen({
    super.key,
    required this.title,
    this.excludeTeamId,
    this.restrictedContinent,
  });

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen> {
  Continent? _continent;

  @override
  void initState() {
    super.initState();
    _continent = widget.restrictedContinent;
  }

  List<Continent> get _availableContinents {
    if (widget.restrictedContinent != null) return [widget.restrictedContinent!];
    return Continent.values;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _continent != null && widget.restrictedContinent == null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _continent = null),
              )
            : null,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: _continent == null ? _buildContinentPicker() : _buildCountryGrid(_continent!),
          ),
        ],
      ),
    );
  }

  Widget _buildContinentPicker() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Choisis un continent",
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.3,
              ),
              itemCount: _availableContinents.length,
              itemBuilder: (context, i) {
                final continent = _availableContinents[i];
                final count = TeamsDatabase.byContinent(continent).length;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _continent = continent),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(continent.emoji, style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 8),
                        Text(continent.label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text("$count sélections",
                            style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryGrid(Continent continent) {
    final teams = TeamsDatabase.byContinent(continent)
        .where((t) => t.id != widget.excludeTeamId)
        .toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            continent.label,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.62,
              ),
              itemCount: teams.length,
              itemBuilder: (context, i) {
                final team = teams[i];
                return TeamCard(
                  team: team,
                  onTap: () => Navigator.of(context).pop(team),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
