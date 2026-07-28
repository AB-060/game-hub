import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/particle_background.dart';
import '../../../services/game_save_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/confetti_overlay.dart';
import '../../../widgets/glass_card.dart';
import '../engine/tournament_engine.dart';
import '../models/match_models.dart';
import '../models/team.dart';
import '../models/tournament_models.dart';
import 'quick_match_screen.dart';

const _saveService = GameSaveService('football_tournament');

/// Déroulé du tournoi : tableau (huitièmes/quarts/demies/finale), chaque
/// match jouable via une simulation Match rapide, et podium + trophée à
/// l'arrivée.
class TournamentBracketScreen extends StatefulWidget {
  final CompetitionType type;
  final List<Team> participants;

  /// Vainqueurs déjà résolus lors d'une session précédente (reprise de
  /// partie), rejoués dans l'ordre pour reconstituer l'état du tournoi.
  final List<String> resumeWinnerIds;

  const TournamentBracketScreen({
    super.key,
    required this.type,
    required this.participants,
    this.resumeWinnerIds = const [],
  });

  @override
  State<TournamentBracketScreen> createState() => _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> {
  late TournamentEngine _engine;
  String? _tieBreakMessage;

  @override
  void initState() {
    super.initState();
    _engine = TournamentEngine(
      type: widget.type,
      participants: widget.participants,
      shuffleSeed: false,
    );
    for (final winnerId in widget.resumeWinnerIds) {
      final fixture = _engine.currentRound.fixtures.firstWhere(
        (f) => !f.isResolved && (f.home.id == winnerId || f.away.id == winnerId),
      );
      _engine.resolveFixture(fixture, winnerId);
    }
    _saveProgress();
  }

  Future<void> _saveProgress() async {
    await _saveService.saveState({
      'type': widget.type.name,
      'participantIds': widget.participants.map((t) => t.id).toList(),
      'resolvedWinnerIds': [
        for (final round in _engine.rounds)
          for (final f in round.fixtures)
            if (f.isResolved) f.winnerId,
      ],
      'complete': _engine.isComplete,
    });
  }

  void _playFixture(Fixture fixture) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuickMatchScreen(
        home: fixture.home,
        away: fixture.away,
        weather: Weather.values[DateTime.now().millisecond % Weather.values.length],
        onFinished: (homeGoals, awayGoals) {
          fixture.homeGoals = homeGoals;
          fixture.awayGoals = awayGoals;
          String winnerId;
          if (homeGoals != awayGoals) {
            winnerId = homeGoals > awayGoals ? fixture.home.id : fixture.away.id;
          } else {
            final tie = simulateShootoutTieBreak(fixture.home, fixture.away);
            winnerId = tie.aWins ? fixture.home.id : fixture.away.id;
            _tieBreakMessage =
                "Tirs au but : ${fixture.home.name} ${tie.goalsA} - ${tie.goalsB} ${fixture.away.name}";
          }
          setState(() {
            _engine.resolveFixture(fixture, winnerId);
          });
          _saveProgress();
          if (_engine.isComplete) _saveService.clear();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("${widget.type.trophy} ${widget.type.label}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: _engine.isComplete ? _buildPodium() : _buildBracket(),
          ),
        ],
      ),
    );
  }

  Widget _buildBracket() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_tieBreakMessage != null) ...[
            GlassCard(
              borderColor: kAccent.withOpacity(0.5),
              child: Text(_tieBreakMessage!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
          ],
          for (final round in _engine.rounds) ...[
            Text(
              round.name,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            for (final fixture in round.fixtures) ...[
              _fixtureCard(fixture, isCurrentRound: round == _engine.currentRound),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _fixtureCard(Fixture fixture, {required bool isCurrentRound}) {
    final playable = isCurrentRound && !fixture.isResolved;
    return GlassCard(
      borderColor: fixture.isResolved ? Colors.white12 : kAccent.withOpacity(0.4),
      child: Row(
        children: [
          Expanded(child: _teamRow(fixture.home, isWinner: fixture.winnerId == fixture.home.id)),
          if (fixture.isResolved)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "${fixture.homeGoals} - ${fixture.awayGoals}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text("vs", style: TextStyle(color: Colors.white38)),
            ),
          Expanded(child: _teamRow(fixture.away, isWinner: fixture.winnerId == fixture.away.id, alignEnd: true)),
          if (playable)
            IconButton(
              tooltip: "Jouer le match",
              icon: const Icon(Icons.play_circle_fill_rounded, color: kAccent),
              onPressed: () => _playFixture(fixture),
            )
          else if (!fixture.isResolved)
            const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.lock_clock_rounded, size: 18, color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _teamRow(Team team, {required bool isWinner, bool alignEnd = false}) {
    final children = [
      Text(team.flag, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
            color: isWinner ? Colors.white : Colors.white70,
          ),
        ),
      ),
    ];
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd ? children.reversed.toList() : children,
    );
  }

  Widget _buildPodium() {
    final champion = _engine.champion!;
    final runnerUp = _engine.runnerUp;
    return Stack(
      children: [
        const Positioned.fill(child: ConfettiOverlay()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.type.trophy, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(
                  "${champion.flag} ${champion.name}",
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: kAccent),
                ),
                const Text("remporte le tournoi !", style: TextStyle(color: Colors.white70)),
                if (runnerUp != null) ...[
                  const SizedBox(height: 20),
                  Text("🥈 Finaliste : ${runnerUp.flag} ${runnerUp.name}",
                      style: const TextStyle(color: Colors.white54)),
                ],
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text("Retour à l'accueil"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
