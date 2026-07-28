import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/particle_background.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../models/match_models.dart';
import '../models/penalty_models.dart';
import '../models/team.dart';
import '../models/teams_database.dart';
import '../models/tournament_models.dart';
import '../services/team_selection_service.dart';
import '../widgets/team_card.dart';
import 'quick_match_screen.dart';
import 'shootout_screen.dart';
import 'team_selection_screen.dart';
import 'tournament_bracket_screen.dart';
import 'tournament_setup_screen.dart';

const _shootoutStats = GameStatsService('penalty');
const _matchStats = GameStatsService('football_match');
const _tournamentSave = GameSaveService('football_tournament');
const _teamSelectionService = TeamSelectionService();

class FootballHomeScreen extends StatefulWidget {
  const FootballHomeScreen({super.key});

  @override
  State<FootballHomeScreen> createState() => _FootballHomeScreenState();
}

class _FootballHomeScreenState extends State<FootballHomeScreen>
    with SingleTickerProviderStateMixin {
  late Team _playerTeam;
  Team? _opponent;
  PenaltyDifficulty _difficulty = PenaltyDifficulty.medium;
  PenaltyMode _shootoutMode = PenaltyMode.practice;
  Weather _weather = Weather.sun;

  GameStats _shootoutStatsData = const GameStats();
  GameStats _matchStatsData = const GameStats();
  Map<String, dynamic>? _savedTournament;
  bool _loading = true;

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _playerTeam = await _teamSelectionService.loadSelectedTeam();
    _opponent = TeamsDatabase.all.firstWhere((t) => t.id != _playerTeam.id);
    final shootout = await _shootoutStats.load();
    final match = await _matchStats.load();
    final tournament = await _tournamentSave.loadState();
    if (!mounted) return;
    setState(() {
      _shootoutStatsData = shootout;
      _matchStatsData = match;
      _savedTournament = tournament;
      _loading = false;
    });
    _entrance.forward();
  }

  Future<void> _changeTeam() async {
    final selected = await Navigator.of(context).push<Team>(MaterialPageRoute(
      builder: (_) => const TeamSelectionScreen(title: "Choisis ta sélection"),
    ));
    if (selected == null) return;
    await _teamSelectionService.saveSelectedTeam(selected);
    setState(() {
      _playerTeam = selected;
      if (_opponent?.id == selected.id) {
        _opponent = TeamsDatabase.all.firstWhere((t) => t.id != selected.id);
      }
    });
  }

  Future<void> _chooseOpponent() async {
    final selected = await Navigator.of(context).push<Team>(MaterialPageRoute(
      builder: (_) => TeamSelectionScreen(title: "Choisis l'adversaire", excludeTeamId: _playerTeam.id),
    ));
    if (selected == null) return;
    setState(() => _opponent = selected);
  }

  void _startShootout() {
    if (_opponent == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ShootoutScreen(
        difficulty: _difficulty,
        mode: _shootoutMode,
        homeTeam: _playerTeam,
        awayTeam: _opponent,
      ),
    )).then((_) => _load());
  }

  void _startQuickMatch() {
    if (_opponent == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuickMatchScreen(home: _playerTeam, away: _opponent!, weather: _weather),
    )).then((_) => _load());
  }

  void _openTournaments() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TournamentSetupScreen(playerTeam: _playerTeam)))
        .then((_) => _load());
  }

  Future<void> _resumeTournament() async {
    final saved = _savedTournament;
    if (saved == null) return;
    final type = CompetitionType.values.firstWhere((t) => t.name == saved['type']);
    final participantIds = (saved['participantIds'] as List<dynamic>).cast<String>();
    final participants = participantIds.map(TeamsDatabase.byId).toList();
    final winnerIds = (saved['resolvedWinnerIds'] as List<dynamic>).cast<String>();

    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => TournamentBracketScreen(
            type: type,
            participants: participants,
            resumeWinnerIds: winnerIds,
          ),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Football"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                          child: FadeTransition(
                            opacity: _entrance,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _statsCard(),
                                const SizedBox(height: 20),
                                if (_savedTournament != null && _savedTournament!['complete'] != true) ...[
                                  _resumeTournamentCard(),
                                  const SizedBox(height: 20),
                                ],
                                _sectionLabel("Ta sélection"),
                                const SizedBox(height: 8),
                                TeamCard(team: _playerTeam, selected: true, onTap: _changeTeam),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _changeTeam,
                                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                    label: const Text("Changer d'équipe"),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _sectionLabel("Adversaire"),
                                const SizedBox(height: 8),
                                _opponent == null
                                    ? OutlinedButton.icon(
                                        onPressed: _chooseOpponent,
                                        icon: const Icon(Icons.person_search_rounded),
                                        label: const Text("Choisir l'adversaire"),
                                      )
                                    : TeamCard(
                                        team: _opponent!,
                                        compact: true,
                                        onTap: _chooseOpponent,
                                      ),
                                const SizedBox(height: 20),
                                _sectionLabel("Niveau du gardien (tirs au but)"),
                                const SizedBox(height: 8),
                                _difficultyPicker(),
                                const SizedBox(height: 20),
                                _sectionLabel("Mode (tirs au but)"),
                                const SizedBox(height: 8),
                                _shootoutModePicker(),
                                const SizedBox(height: 20),
                                _sectionLabel("Météo (match rapide)"),
                                const SizedBox(height: 8),
                                _weatherPicker(),
                                const SizedBox(height: 28),
                                ElevatedButton.icon(
                                  onPressed: _startQuickMatch,
                                  icon: const Icon(Icons.sports_soccer_rounded),
                                  label: const Text("Match rapide"),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _startShootout,
                                  icon: const Icon(Icons.sports_rounded),
                                  label: const Text("Tirs au but"),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _openTournaments,
                                  icon: const Icon(Icons.emoji_events_rounded),
                                  label: const Text("Compétitions"),
                                ),
                              ],
                            ),
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

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: kMuted),
    );
  }

  Widget _statsCard() {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              _statItem("Buts (T.A.B)", "${_shootoutStatsData.wins}", Colors.greenAccent),
              _statItem("Victoires match", "${_matchStatsData.wins}", kAccent),
              _statItem("Nuls", "${_matchStatsData.draws}", Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _resumeTournamentCard() {
    return GlassCard(
      borderColor: kAccent.withOpacity(0.4),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: kAccent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Un tournoi est en cours", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(onPressed: _resumeTournament, child: const Text("Reprendre")),
        ],
      ),
    );
  }

  Widget _difficultyPicker() {
    return Row(
      children: PenaltyDifficulty.values.map((d) {
        final selected = _difficulty == d;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: d == PenaltyDifficulty.values.last ? 0 : 6),
            child: SelectableChip(
              selected: selected,
              label: d.label,
              onTap: () => setState(() => _difficulty = d),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _shootoutModePicker() {
    return Row(
      children: PenaltyMode.values.map((m) {
        final selected = _shootoutMode == m;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: m == PenaltyMode.values.last ? 0 : 8),
            child: SelectableChip(
              selected: selected,
              label: m.label,
              subtitle: m.description,
              onTap: () => setState(() => _shootoutMode = m),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _weatherPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Weather.values.map((w) {
        final selected = _weather == w;
        return ChoiceChip(
          label: Text("${w.emoji} ${w.label}"),
          selected: selected,
          onSelected: (_) => setState(() => _weather = w),
          selectedColor: kAccent.withOpacity(0.25),
          backgroundColor: Colors.white.withOpacity(0.05),
        );
      }).toList(),
    );
  }
}
