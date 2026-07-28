import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/app_sound_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../widgets/confetti_overlay.dart';
import '../../../widgets/result_overlay.dart';
import '../engine/match_engine.dart';
import '../models/match_models.dart';
import '../models/team.dart';
import '../widgets/commentary_ticker.dart';
import '../widgets/scoreboard.dart';
import '../widgets/stadium_background.dart';

const _statsService = GameStatsService('football_match');

/// Match rapide : simulation animée en direct (le joueur ne contrôle pas
/// les actions, il suit le match comme un vrai résumé en temps réel
/// accéléré), avec commentaires, stats et célébration de victoire.
class QuickMatchScreen extends StatefulWidget {
  final Team home;
  final Team away;
  final Weather weather;

  /// Appelé quand le match se termine (utilisé par l'écran Tournoi pour
  /// récupérer le résultat sans changer le comportement autonome de
  /// l'écran Match rapide).
  final void Function(int homeGoals, int awayGoals)? onFinished;

  const QuickMatchScreen({
    super.key,
    required this.home,
    required this.away,
    required this.weather,
    this.onFinished,
  });

  @override
  State<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

class _QuickMatchScreenState extends State<QuickMatchScreen> {
  late MatchEngine _engine;
  Timer? _timer;
  MatchEvent? _latestEvent;
  bool _finished = false;
  bool _paused = false;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _engine = MatchEngine(home: widget.home, away: widget.away, weather: widget.weather);
    _latestEvent = _engine.start().first;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: (220 / _speed).round()), (_) => _tick());
  }

  void _tick() {
    if (_paused || _finished) return;
    final events = _engine.advanceMinute();
    for (final e in events) {
      _onEvent(e);
    }
    setState(() {});
    if (_engine.finished) {
      _onMatchEnd();
    }
  }

  void _onEvent(MatchEvent e) {
    _latestEvent = e;
    switch (e.type) {
      case MatchEventType.goal:
        AppSoundService.instance.play(AppSfx.success);
        break;
      case MatchEventType.saved:
        AppSoundService.instance.play(AppSfx.danger);
        break;
      case MatchEventType.yellowCard:
      case MatchEventType.redCard:
        AppSoundService.instance.play(AppSfx.tap);
        break;
      case MatchEventType.kickoff:
      case MatchEventType.halfTime:
      case MatchEventType.fullTime:
        AppSoundService.instance.play(AppSfx.whistle);
        break;
      default:
        break;
    }
  }

  Future<void> _onMatchEnd() async {
    _timer?.cancel();
    final homeWon = _engine.homeGoals > _engine.awayGoals;
    final draw = _engine.homeGoals == _engine.awayGoals;
    await _statsService.recordGameEnd(
      won: homeWon,
      lost: !homeWon && !draw,
      draw: draw,
      score: _engine.homeGoals,
    );
    if (!mounted) return;
    setState(() => _finished = true);
    widget.onFinished?.call(_engine.homeGoals, _engine.awayGoals);
  }

  void _togglePause() => setState(() => _paused = !_paused);

  void _changeSpeed() {
    setState(() => _speed = _speed >= 3 ? 1 : _speed + 1);
    _startTimer();
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _engine = MatchEngine(home: widget.home, away: widget.away, weather: widget.weather);
      _latestEvent = _engine.start().first;
      _finished = false;
      _paused = false;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.home.flag} vs ${widget.away.flag}"),
        actions: [
          IconButton(
            tooltip: "Vitesse x${_speed.toInt()}",
            icon: Text("x${_speed.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _finished ? null : _changeSpeed,
          ),
          IconButton(
            tooltip: _paused ? "Reprendre" : "Pause",
            icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            onPressed: _finished ? null : _togglePause,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: StadiumBackground(continent: widget.home.continent, weather: widget.weather),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.weather.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(widget.weather.label,
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Scoreboard(
                    home: widget.home,
                    away: widget.away,
                    homeGoals: _engine.homeGoals,
                    awayGoals: _engine.awayGoals,
                    minute: _engine.minute,
                    finished: _finished,
                  ),
                  const SizedBox(height: 14),
                  CommentaryTicker(latest: _latestEvent),
                  const Spacer(),
                  _statsPanel(),
                ],
              ),
            ),
          ),
          if (_finished) ...[
            const Positioned.fill(child: ConfettiOverlay()),
            _buildResultOverlay(),
          ],
        ],
      ),
    );
  }

  Widget _statsPanel() {
    final s = _engine.stats;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _statRow("Possession", "${s.possessionHome}%", "${s.possessionAway}%"),
          _statRow("Tirs", "${s.shotsHome}", "${s.shotsAway}"),
          _statRow("Tirs cadrés", "${s.shotsOnTargetHome}", "${s.shotsOnTargetAway}"),
          _statRow("Fautes", "${s.foulsHome}", "${s.foulsAway}"),
          _statRow("Cartons 🟨", "${s.yellowHome}", "${s.yellowAway}"),
        ],
      ),
    );
  }

  Widget _statRow(String label, String home, String away) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(home, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ),
          SizedBox(width: 40, child: Text(away, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildResultOverlay() {
    final homeWon = _engine.homeGoals > _engine.awayGoals;
    final draw = _engine.homeGoals == _engine.awayGoals;
    final title = draw
        ? "Match nul !"
        : "${(homeWon ? widget.home : widget.away).flag} ${(homeWon ? widget.home : widget.away).name} gagne !";
    return ResultOverlay(
      emoji: draw ? "🤝" : "🏆",
      title: title,
      subtitle: "${_engine.homeGoals} - ${_engine.awayGoals}",
      accentColor: homeWon ? widget.home.primaryColor : widget.away.primaryColor,
      stats: [
        MapEntry("Tirs", "${_engine.stats.shotsHome + _engine.stats.shotsAway}"),
        MapEntry("Possession", "${_engine.stats.possessionHome}%"),
      ],
      onReplay: _restart,
      onNewGame: () => Navigator.of(context).pop(),
      onBack: () => Navigator.of(context).pop(),
    );
  }
}
