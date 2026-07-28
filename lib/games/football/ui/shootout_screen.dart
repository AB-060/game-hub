import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/app_sound_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../widgets/confetti_overlay.dart';
import '../../../widgets/result_overlay.dart';
import '../engine/penalty_engine.dart';
import '../models/penalty_models.dart';
import '../models/team.dart';

const _statsService = GameStatsService('penalty');
const int _practiceShots = 5;

/// Écran des tirs au but. [homeTeam]/[awayTeam] sont optionnels : quand
/// fournis (venant du sélecteur d'équipes), leurs drapeaux/couleurs
/// habillent l'écran ; sinon le mode fonctionne de façon générique comme
/// avant.
class ShootoutScreen extends StatefulWidget {
  final PenaltyDifficulty difficulty;
  final PenaltyMode mode;
  final Team? homeTeam;
  final Team? awayTeam;

  const ShootoutScreen({
    super.key,
    required this.difficulty,
    required this.mode,
    this.homeTeam,
    this.awayTeam,
  });

  @override
  State<ShootoutScreen> createState() => _ShootoutScreenState();
}

class _ShootoutScreenState extends State<ShootoutScreen> {
  late final PenaltyEngine _engine;

  int _round = 0;
  int _goals = 0;
  int _bestScore = 0;

  ShotZone? _shotZone;
  ShotZone? _keeperZone;
  String? _resultText;
  bool _animating = false;
  bool _finished = false;
  bool _lastWasGoal = false;

  @override
  void initState() {
    super.initState();
    _engine = PenaltyEngine(difficulty: widget.difficulty);
    _statsService.load().then((s) {
      if (mounted) setState(() => _bestScore = s.bestScore);
    });
  }

  bool get _isLastPracticeShot =>
      widget.mode == PenaltyMode.practice && _round >= _practiceShots;

  Future<void> _shoot(ShotZone zone) async {
    if (_animating || _finished) return;
    setState(() {
      _animating = true;
      _shotZone = zone;
      _keeperZone = null;
      _resultText = null;
    });
    AppSoundService.instance.play(AppSfx.tap);

    await Future.delayed(widget.difficulty.reactionDelay);
    if (!mounted) return;

    final result = _engine.resolveShot(zone);
    setState(() => _keeperZone = result.keeperZone);

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    _round++;
    _lastWasGoal = result.isGoal;
    if (result.isGoal) {
      _goals++;
      AppSoundService.instance.play(AppSfx.success);
    } else {
      AppSoundService.instance.play(AppSfx.danger);
    }

    final updated = await _statsService.recordGameEnd(
      won: result.isGoal,
      lost: !result.isGoal,
      score: _goals,
      difficulty: widget.difficulty.name,
    );

    setState(() {
      _resultText = result.isGoal ? "⚽ BUT !" : "🧤 Arrêté !";
      _animating = false;
      _bestScore = updated.bestScore;
    });

    final over = widget.mode == PenaltyMode.suddenDeath ? !result.isGoal : _isLastPracticeShot;
    if (over) {
      AppSoundService.instance.play(AppSfx.whistle);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _finished = true);
    }
  }

  void _restart() {
    setState(() {
      _round = 0;
      _goals = 0;
      _shotZone = null;
      _keeperZone = null;
      _resultText = null;
      _animating = false;
      _finished = false;
    });
  }

  double _zoneAlignment(ShotZone z) {
    switch (z) {
      case ShotZone.left:
        return -0.8;
      case ShotZone.center:
        return 0;
      case ShotZone.right:
        return 0.8;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextShotNumber = (_round + 1).clamp(1, _practiceShots);
    final shotsLabel = widget.mode == PenaltyMode.practice
        ? "Tir ${_finished ? _practiceShots : nextShotNumber} / $_practiceShots"
        : "Série : $_goals";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.homeTeam != null && widget.awayTeam != null
              ? "${widget.homeTeam!.flag} vs ${widget.awayTeam!.flag} · Tirs au but"
              : "Foot · ${widget.difficulty.label}",
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.homeTeam != null && widget.awayTeam != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        "${widget.homeTeam!.name} tire contre ${widget.awayTeam!.name} (${widget.difficulty.label})",
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _statChip(Icons.sports_soccer_rounded, shotsLabel),
                      _statChip(Icons.star_rounded, "$_goals buts"),
                      _statChip(Icons.emoji_events_rounded, "$_bestScore"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final pitchWidth = constraints.maxWidth > 320 ? 320.0 : constraints.maxWidth;
                        final pitchHeight = pitchWidth * (200 / 320);
                        return Container(
                          width: pitchWidth,
                          height: pitchHeight,
                          decoration: BoxDecoration(
                            color: Colors.green.shade800,
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              // Filet.
                              Align(
                                alignment: const Alignment(0, -0.88),
                                child: Container(
                                  width: pitchWidth * (280 / 320),
                                  height: pitchHeight * (70 / 200),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: CustomPaint(painter: _NetPainter()),
                                ),
                              ),
                              // Gardien.
                              if (_keeperZone != null)
                                AnimatedAlign(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOut,
                                  alignment: Alignment(_zoneAlignment(_keeperZone!), -0.62),
                                  child: Text(
                                    _resultText == "🧤 Arrêté !" ? "🧤" : "🧍",
                                    style: const TextStyle(fontSize: 34),
                                  ),
                                )
                              else
                                const Align(
                                  alignment: Alignment(0, -0.62),
                                  child: Text("🧍", style: TextStyle(fontSize: 34)),
                                ),
                              // Ballon.
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 550),
                                curve: Curves.easeOutQuart,
                                alignment: Alignment(
                                  _shotZone != null ? _zoneAlignment(_shotZone!) : 0,
                                  _shotZone != null ? -0.7 : 0.85,
                                ),
                                child: const Text("⚽", style: TextStyle(fontSize: 26)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_resultText != null)
                    Text(_resultText!,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  if (!_finished)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _shootButton("Gauche", ShotZone.left),
                        _shootButton("Centre", ShotZone.center),
                        _shootButton("Droite", ShotZone.right),
                      ],
                    ),
                ],
              ),
            ),
            if (_finished) ...[
              if (_goals > 0) const Positioned.fill(child: ConfettiOverlay()),
              _buildResultOverlay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF15152C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _shootButton(String label, ShotZone zone) {
    return ElevatedButton(
      onPressed: _animating || _finished ? null : () => _shoot(zone),
      child: Text(label),
    );
  }

  Widget _buildResultOverlay() {
    final title = widget.mode == PenaltyMode.suddenDeath
        ? "Série terminée !"
        : (_goals >= 4 ? "Excellent tireur !" : (_goals >= 2 ? "Bien joué !" : "Réessaie !"));
    return ResultOverlay(
      emoji: _lastWasGoal || _goals > 0 ? "🏆" : "🧤",
      title: title,
      subtitle: widget.mode == PenaltyMode.suddenDeath
          ? "$_goals but(s) marqué(s) d'affilée."
          : "$_goals but(s) sur $_practiceShots tirs.",
      stats: [
        MapEntry("Buts", "$_goals"),
        MapEntry("Record", "$_bestScore"),
      ],
      onReplay: _restart,
      onNewGame: () => Navigator.of(context).pop(),
      onBack: () => Navigator.of(context).pop(),
    );
  }
}

class _NetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1;
    const step = 10.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetPainter oldDelegate) => false;
}
