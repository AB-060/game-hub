import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../services/app_sound_service.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../widgets/result_overlay.dart';
import '../engine/memory_engine.dart';
import '../models/memory_models.dart';
import '../services/memory_records_service.dart';
import '../../../widgets/confetti_overlay.dart';
import 'widgets/flip_card.dart';

const _statsService = GameStatsService('memory');
const _saveService = GameSaveService('memory');
const _recordsService = MemoryRecordsService();

class MemoryGameScreen extends StatefulWidget {
  final MemoryTheme theme;
  final MemoryDifficulty difficulty;
  final Map<String, dynamic>? resume;

  const MemoryGameScreen({
    super.key,
    required this.theme,
    required this.difficulty,
    required this.resume,
  });

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  late MemoryEngine _engine;
  int _seconds = 0;
  Timer? _timer;
  bool _finished = false;
  bool _isNewRecord = false;

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    _engine = MemoryEngine(theme: widget.theme, difficulty: widget.difficulty);
    if (resume != null) {
      final symbols = (resume['symbols'] as List<dynamic>).cast<String>();
      final revealedOrMatched = (resume['matched'] as List<dynamic>).cast<bool>();
      for (int i = 0; i < _engine.cards.length && i < symbols.length; i++) {
        _engine.cards[i].matched = revealedOrMatched[i];
      }
      _engine.moves = resume['moves'] as int? ?? 0;
      _seconds = resume['seconds'] as int? ?? 0;
    }
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_finished) setState(() => _seconds++);
    });
  }

  Future<void> _onCardTap(int index) async {
    if (_finished || _engine.isBusy) return;
    final card = _engine.cards[index];
    if (card.revealed || card.matched) return;

    final result = _engine.flip(index);
    AppSoundService.instance.play(AppSfx.tap);
    setState(() {});

    if (result.pending) return;

    if (result.isMatch) {
      AppSoundService.instance.play(AppSfx.success);
      await Future.delayed(const Duration(milliseconds: 250));
      _engine.resolvePending();
      setState(() {});
      if (_engine.isComplete) {
        _onGameComplete();
        return;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 700));
      _engine.resolvePending();
      setState(() {});
    }

    _saveGame();
  }

  Future<void> _onGameComplete() async {
    _timer?.cancel();
    AppSoundService.instance.play(AppSfx.win);
    final isRecord = await _recordsService.recordTime(widget.difficulty.name, _seconds);
    await _statsService.recordGameEnd(
      won: true,
      score: _engine.score,
      secondsPlayed: _seconds,
      difficulty: widget.difficulty.name,
    );
    await _saveService.clear();
    if (!mounted) return;
    setState(() {
      _finished = true;
      _isNewRecord = isRecord;
    });
  }

  Future<void> _saveGame() async {
    if (_finished) return;
    await _saveService.saveState({
      'theme': widget.theme.name,
      'difficulty': widget.difficulty.name,
      'symbols': _engine.cards.map((c) => c.symbol).toList(),
      'matched': _engine.cards.map((c) => c.matched).toList(),
      'moves': _engine.moves,
      'seconds': _seconds,
    });
  }

  void _restart() {
    setState(() {
      _engine = MemoryEngine(theme: widget.theme, difficulty: widget.difficulty);
      _seconds = 0;
      _finished = false;
      _isNewRecord = false;
    });
    _startTimer();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Memory · ${widget.difficulty.label}"),
        actions: [
          IconButton(
            tooltip: "Nouvelle partie",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _restart,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _statChip(Icons.timer_rounded, _formatTime(_seconds)),
                      _statChip(Icons.touch_app_rounded, "${_engine.moves} coups"),
                      _statChip(Icons.bolt_rounded, "x${_engine.combo}"),
                      _statChip(Icons.star_rounded, "${_engine.score} pts"),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = widget.difficulty.columns;
                        final rows = widget.difficulty.rows;
                        final cellFromWidth = constraints.maxWidth / cols;
                        final cellFromHeight = constraints.maxHeight / rows;
                        final cell = min(cellFromWidth, cellFromHeight);
                        final boardWidth = cell * cols;
                        final boardHeight = cell * rows;
                        return Center(
                          child: SizedBox(
                            width: boardWidth,
                            height: boardHeight,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _engine.cards.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                              itemBuilder: (context, i) {
                                final card = _engine.cards[i];
                                final showFront = card.revealed || card.matched;
                                return GestureDetector(
                                  onTap: () => _onCardTap(i),
                                  child: FlipCard(
                                    showFront: showFront,
                                    back: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF3A3A6E), Color(0xFF1D1B4B)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.help_outline_rounded,
                                            color: Colors.white24, size: 22),
                                      ),
                                    ),
                                    front: Container(
                                      decoration: BoxDecoration(
                                        color: card.matched
                                            ? Colors.green.withOpacity(0.25)
                                            : const Color(0xFF1A1A2E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: card.matched
                                              ? Colors.greenAccent
                                              : Colors.white12,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          card.symbol,
                                          style: TextStyle(fontSize: cell * 0.42),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (_finished) ...[
              const Positioned.fill(child: ConfettiOverlay()),
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

  Widget _buildResultOverlay() {
    return ResultOverlay(
      emoji: "🎉",
      title: "Bravo !",
      subtitle: _isNewRecord
          ? "Nouveau record de temps !"
          : "Toutes les paires trouvées en ${_formatTime(_seconds)}.",
      stats: [
        MapEntry("Temps", _formatTime(_seconds)),
        MapEntry("Coups", "${_engine.moves}"),
        MapEntry("Score", "${_engine.score}"),
      ],
      onReplay: _restart,
      onNewGame: () => Navigator.of(context).pop(),
      onBack: () => Navigator.of(context).pop(),
    );
  }
}
