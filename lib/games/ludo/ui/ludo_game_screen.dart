import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/app_sound_service.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../widgets/confetti_overlay.dart';
import '../../../widgets/result_overlay.dart';
import '../engine/ludo_ai.dart';
import '../engine/ludo_engine.dart';
import '../models/ludo_board.dart';
import 'widgets/dice_widget.dart';
import 'widgets/ludo_board_view.dart';

const _statsService = GameStatsService('ludo');
const _saveService = GameSaveService('ludo');

class LudoGameScreen extends StatefulWidget {
  final List<PawnColor> activeColors;
  final Map<PawnColor, SeatType> seats;
  final LudoDifficulty difficulty;
  final Map<String, dynamic>? resume;

  const LudoGameScreen({
    super.key,
    required this.activeColors,
    required this.seats,
    required this.difficulty,
    required this.resume,
  });

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends State<LudoGameScreen> {
  late LudoEngine _engine;
  final LudoAi _ai = LudoAi();
  final List<String> _history = [];

  int? _dice;
  bool _rolling = false;
  bool _busy = false;
  List<int> _selectablePawns = [];
  String _message = "";
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _engine = LudoEngine(activeColors: widget.activeColors);

    final resume = widget.resume;
    if (resume != null) {
      final positions = resume['positions'] as Map<String, dynamic>;
      for (final color in widget.activeColors) {
        final list = (positions[color.name] as List<dynamic>).cast<int>();
        for (int i = 0; i < 4; i++) {
          _engine.pawns[color]![i].position = list[i];
        }
      }
      _engine.currentPlayerIndex = resume['currentPlayerIndex'] as int? ?? 0;
      _history.addAll((resume['history'] as List<dynamic>? ?? []).cast<String>());
    }

    _message = _isCurrentHuman ? "À toi de lancer le dé !" : "";
    if (!_isCurrentHuman) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPlayLoop());
    }
  }

  bool get _isCurrentHuman => widget.seats[_engine.currentPlayer] == SeatType.human;

  Future<void> _saveGame() async {
    if (_gameOver) return;
    await _saveService.saveState({
      'activeColors': widget.activeColors.map((c) => c.name).toList(),
      'seats': widget.seats.map((k, v) => MapEntry(k.name, v.name)),
      'difficulty': widget.difficulty.name,
      'currentPlayerIndex': _engine.currentPlayerIndex,
      'positions': {
        for (final color in widget.activeColors)
          color.name: _engine.pawns[color]!.map((p) => p.position).toList(),
      },
      'history': _history,
    });
  }

  void _addHistory(String text) {
    _history.insert(0, text);
    if (_history.length > 30) _history.removeLast();
  }

  Future<void> _humanRoll() async {
    if (_busy || _gameOver || !_isCurrentHuman) return;
    await _rollAndResolve();
  }

  Future<void> _rollAndResolve() async {
    setState(() {
      _busy = true;
      _rolling = true;
      _selectablePawns = [];
    });
    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;

    final color = _engine.currentPlayer;
    final dice = _engine.rollDice();
    AppSoundService.instance.play(AppSfx.tap);
    setState(() {
      _dice = dice;
      _rolling = false;
    });

    final legal = _engine.legalMovesFor(color, dice);
    if (legal.isEmpty) {
      setState(() => _message = "${color.label} ne peut pas jouer ($dice).");
      _addHistory("${color.label} passe (dé $dice)");
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _engine.nextTurn();
      setState(() => _busy = false);
      await _saveGame();
      _continueGameLoop();
      return;
    }

    if (!_isCurrentHuman) {
      final chosen = _ai.chooseMove(_engine, legal, dice, widget.difficulty);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _applyMove(color, chosen, dice);
      return;
    }

    if (legal.length == 1) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await _applyMove(color, legal.first, dice);
      return;
    }

    setState(() {
      _selectablePawns = legal;
      _message = "Choisis le pion à déplacer.";
      _busy = false;
    });
  }

  Future<void> _onPawnTap(PawnColor color, int pawnIndex) async {
    if (!_isCurrentHuman || _dice == null || !_selectablePawns.contains(pawnIndex)) return;
    await _applyMove(color, pawnIndex, _dice!);
  }

  Future<void> _applyMove(PawnColor color, int pawnIndex, int dice) async {
    setState(() {
      _busy = true;
      _selectablePawns = [];
    });

    final result = _engine.applyMove(color, pawnIndex, dice);
    AppSoundService.instance.play(result.captured.isNotEmpty ? AppSfx.capture : AppSfx.move);

    var text = "${color.label} avance un pion ($dice).";
    if (result.captured.isNotEmpty) {
      text = "${color.label} capture ${result.captured.map((p) => p.color.label).join(', ')} !";
      AppSoundService.instance.play(AppSfx.capture);
    }
    if (result.finished) {
      text = "${color.label} ramène un pion à la maison !";
      AppSoundService.instance.play(AppSfx.success);
    }
    _addHistory(text);
    setState(() => _message = text);

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (_engine.winner != null) {
      await _handleGameOver(_engine.winner!);
      return;
    }

    final extraTurn = dice == 6 && !_engine.currentPlayerHasFinished;
    if (!extraTurn) {
      _engine.nextTurn();
    }
    setState(() {
      _busy = false;
      _dice = extraTurn ? null : _dice;
    });
    await _saveGame();
    _continueGameLoop();
  }

  void _continueGameLoop() {
    if (_gameOver) return;
    if (_isCurrentHuman) {
      setState(() => _message = "À ${_engine.currentPlayer.label} de lancer le dé !");
    } else {
      _autoPlayLoop();
    }
  }

  Future<void> _autoPlayLoop() async {
    while (mounted && !_gameOver && !_isCurrentHuman) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted || _gameOver) return;
      await _rollAndResolve();
      // _rollAndResolve chains into _applyMove which itself may loop back
      // here via _continueGameLoop for extra sixes / next AI player.
      return;
    }
  }

  Future<void> _handleGameOver(PawnColor winner) async {
    setState(() => _gameOver = true);
    final humanWon = widget.seats[winner] == SeatType.human;
    AppSoundService.instance.play(humanWon ? AppSfx.win : AppSfx.lose);
    await _statsService.recordGameEnd(
      won: humanWon,
      lost: !humanWon,
      difficulty: widget.difficulty.name,
    );
    await _saveService.clear();
  }

  void _restart() {
    setState(() {
      _engine = LudoEngine(activeColors: widget.activeColors);
      _dice = null;
      _rolling = false;
      _busy = false;
      _selectablePawns = [];
      _history.clear();
      _gameOver = false;
      _message = _isCurrentHuman ? "À toi de lancer le dé !" : "";
    });
    if (!_isCurrentHuman) _autoPlayLoop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ludo · ${widget.activeColors.length} joueurs"),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final color in widget.activeColors)
                              _seatChip(color),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LudoBoardView(
                      engine: _engine,
                      selectablePawns: _selectablePawns,
                      onPawnTap: _onPawnTap,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      DiceWidget(
                        value: _dice,
                        rolling: _rolling,
                        onTap: (_isCurrentHuman && !_busy && !_gameOver) ? _humanRoll : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isCurrentHuman && !_busy ? "Touche le dé pour lancer" : " ",
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                if (_history.isNotEmpty)
                  SizedBox(
                    height: 28,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _history.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Center(
                          child: Text(
                            _history[i],
                            style: const TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_gameOver) ...[
              const Positioned.fill(child: ConfettiOverlay()),
              _buildResultOverlay(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _seatChip(PawnColor color) {
    final isCurrent = _engine.currentPlayer == color;
    final seat = widget.seats[color]!;
    final finished = _engine.pawns[color]!.every((p) => p.isFinished);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? color.color.withOpacity(0.22) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCurrent ? color.color : Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            finished ? "🏁" : (seat == SeatType.ai ? "🤖" : "🧑"),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay() {
    final winner = _engine.winner!;
    final humanWon = widget.seats[winner] == SeatType.human;
    return ResultOverlay(
      emoji: humanWon ? "🏆" : "🤖",
      title: "${winner.label} gagne !",
      subtitle: humanWon ? "Bien joué !" : "L'IA l'emporte cette fois.",
      accentColor: winner.color,
      onReplay: _restart,
      onNewGame: () => Navigator.of(context).pop(),
      onBack: () => Navigator.of(context).pop(),
    );
  }
}
