import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../services/app_sound_service.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../widgets/result_overlay.dart';
import '../engine/ttt_ai.dart';
import '../engine/ttt_engine.dart';
import '../models/ttt_models.dart';
import 'widgets/winning_line_painter.dart';

const _statsService = GameStatsService('tictactoe');
const _saveService = GameSaveService('tictactoe');

class TicTacToeGameScreen extends StatefulWidget {
  final bool vsAi;
  final TttDifficulty difficulty;
  final TttBoardSize boardSize;
  final PlayerMark humanMark;
  final Map<String, dynamic>? resume;

  const TicTacToeGameScreen({
    super.key,
    required this.vsAi,
    required this.difficulty,
    required this.boardSize,
    required this.humanMark,
    required this.resume,
  });

  @override
  State<TicTacToeGameScreen> createState() => _TicTacToeGameScreenState();
}

class _TicTacToeGameScreenState extends State<TicTacToeGameScreen>
    with SingleTickerProviderStateMixin {
  static const Color xColor = Color(0xFFFF5C5C);
  static const Color oColor = Color(0xFF4BD4E3);

  late TicTacToeEngine engine;
  final TicTacToeAi _ai = TicTacToeAi();
  final List<String> _moveHistory = [];

  bool aiThinking = false;
  bool gameOver = false;
  TttResult _lastResult = TttResult.ongoing;

  int scoreX = 0;
  int scoreO = 0;
  int scoreDraw = 0;

  int _secondsPlayed = 0;
  Timer? _clock;

  late final AnimationController _lineController;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    final resume = widget.resume;
    if (resume != null) {
      final boardCodes = (resume['board'] as List<dynamic>);
      final board = boardCodes
          .map<PlayerMark?>((v) => v == null ? null : (v == 'x' ? PlayerMark.x : PlayerMark.o))
          .toList();
      engine = TicTacToeEngine.fromBoard(
        size: widget.boardSize.dimension,
        winLength: widget.boardSize.winLength,
        board: board,
        turn: resume['turn'] == 'x' ? PlayerMark.x : PlayerMark.o,
      );
      _moveHistory.addAll((resume['history'] as List<dynamic>? ?? []).cast<String>());
    } else {
      engine = TicTacToeEngine(
        size: widget.boardSize.dimension,
        winLength: widget.boardSize.winLength,
      );
    }

    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!gameOver) setState(() => _secondsPlayed++);
    });

    if (!gameOver && widget.vsAi && engine.turn != widget.humanMark) {
      _scheduleAiMove();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _lineController.dispose();
    super.dispose();
  }

  bool get _isHumanTurn => !widget.vsAi || engine.turn == widget.humanMark;

  void _onCellTap(int index) {
    if (gameOver || aiThinking || !_isHumanTurn) return;
    if (engine.board[index] != null) return;
    _playMove(index);
  }

  void _playMove(int index) {
    final mover = engine.turn;
    final result = engine.play(index);
    _moveHistory.add("${mover.label}${_squareLabel(index)}");

    if (result == TttResult.ongoing) {
      AppSoundService.instance.play(AppSfx.move);
    }

    setState(() {});

    if (result != TttResult.ongoing) {
      _handleGameOver(result);
      return;
    }

    _saveGame();

    if (widget.vsAi && engine.turn != widget.humanMark) {
      _scheduleAiMove();
    }
  }

  String _squareLabel(int index) {
    final r = engine.rowOf(index) + 1;
    final c = engine.colOf(index) + 1;
    return "($r,$c)";
  }

  void _scheduleAiMove() {
    setState(() => aiThinking = true);
    Future.delayed(const Duration(milliseconds: 300), () async {
      final move = await _ai.findBestMove(engine, widget.difficulty);
      if (!mounted) return;
      setState(() => aiThinking = false);
      if (move >= 0) _playMove(move);
    });
  }

  Future<void> _saveGame() async {
    if (gameOver) return;
    await _saveService.saveState({
      'board': engine.board.map((m) => m?.name).toList(),
      'turn': engine.turn.name,
      'history': _moveHistory,
      'vsAi': widget.vsAi,
      'difficulty': widget.difficulty.name,
      'boardSize': widget.boardSize.name,
      'humanMark': widget.humanMark.name,
    });
  }

  Future<void> _handleGameOver(TttResult result) async {
    _lastResult = result;
    _clock?.cancel();

    if (result == TttResult.draw) {
      scoreDraw++;
      AppSoundService.instance.play(AppSfx.draw);
    } else {
      _lineController.forward(from: 0);
      final winner = result == TttResult.xWins ? PlayerMark.x : PlayerMark.o;
      if (winner == PlayerMark.x) {
        scoreX++;
      } else {
        scoreO++;
      }

      if (widget.vsAi) {
        final humanWon = winner == widget.humanMark;
        await _statsService.recordGameEnd(
          won: humanWon,
          lost: !humanWon,
          secondsPlayed: _secondsPlayed,
          difficulty: widget.difficulty.name,
        );
        AppSoundService.instance.play(humanWon ? AppSfx.win : AppSfx.lose);
      } else {
        AppSoundService.instance.play(AppSfx.win);
      }
    }

    await _saveService.clear();
    if (!mounted) return;
    setState(() => gameOver = true);
  }

  void _restart() {
    setState(() {
      engine = TicTacToeEngine(
        size: widget.boardSize.dimension,
        winLength: widget.boardSize.winLength,
      );
      _moveHistory.clear();
      gameOver = false;
      _secondsPlayed = 0;
      _lineController.reset();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!gameOver) setState(() => _secondsPlayed++);
    });
    if (widget.vsAi && engine.turn != widget.humanMark) {
      _scheduleAiMove();
    }
  }

  Widget _scorePill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String statusText;
    if (gameOver) {
      statusText = "Partie terminée";
    } else if (aiThinking) {
      statusText = "L'ordinateur réfléchit...";
    } else if (widget.vsAi) {
      statusText = _isHumanTurn ? "À toi de jouer (${widget.humanMark.label})" : "Tour de l'IA";
    } else {
      statusText = "Tour de : ${engine.turn.label}";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Morpion · ${widget.boardSize.label}"),
        actions: [
          IconButton(
            tooltip: "Nouvelle manche",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _restart,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _scorePill("X", scoreX, xColor),
                      _scorePill("Nul", scoreDraw, Colors.white70),
                      _scorePill("O", scoreO, oColor),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      statusText,
                      key: ValueKey(statusText),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardPx = min(constraints.maxWidth, 420.0);
                        return SizedBox(
                          width: boardPx,
                          height: boardPx,
                          child: Stack(
                            children: [
                              GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: engine.board.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: engine.size,
                                  mainAxisSpacing: 6,
                                  crossAxisSpacing: 6,
                                ),
                                itemBuilder: (context, i) {
                                  final isWinningCell = engine.winningLine?.contains(i) ?? false;
                                  final value = engine.board[i];
                                  final color = value == PlayerMark.x ? xColor : oColor;
                                  return GestureDetector(
                                    onTap: () => _onCellTap(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: isWinningCell
                                            ? color.withOpacity(0.28)
                                            : const Color(0xFF1A1A2E),
                                        borderRadius: BorderRadius.circular(12),
                                        border: isWinningCell
                                            ? Border.all(color: color, width: 2)
                                            : null,
                                      ),
                                      child: Center(
                                        child: AnimatedScale(
                                          scale: value == null ? 0 : 1,
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeOutBack,
                                          child: Text(
                                            value?.label ?? "",
                                            style: TextStyle(
                                              fontSize: boardPx / engine.size * 0.42,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (engine.winningLine != null)
                                IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _lineController,
                                    builder: (context, _) => CustomPaint(
                                      size: Size(boardPx, boardPx),
                                      painter: WinningLinePainter(
                                        line: engine.winningLine!,
                                        boardSize: engine.size,
                                        progress: _lineController.value,
                                        color: engine.board[engine.winningLine!.first] ==
                                                PlayerMark.x
                                            ? xColor
                                            : oColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_moveHistory.isNotEmpty)
                    SizedBox(
                      height: 30,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _moveHistory.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Center(
                            child: Text(
                              _moveHistory[i],
                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (gameOver) _buildResultOverlay(),
        ],
      ),
    );
  }

  Widget _buildResultOverlay() {
    final String emoji;
    final String title;
    final String subtitle;
    final Color accent;

    if (_lastResult == TttResult.draw) {
      emoji = "🤝";
      title = "Match nul !";
      subtitle = "Personne ne gagne cette manche.";
      accent = Colors.white70;
    } else {
      final winner = _lastResult == TttResult.xWins ? PlayerMark.x : PlayerMark.o;
      accent = winner == PlayerMark.x ? xColor : oColor;
      if (widget.vsAi) {
        final humanWon = winner == widget.humanMark;
        emoji = humanWon ? "🏆" : "🤖";
        title = humanWon ? "Victoire !" : "Défaite";
        subtitle = humanWon ? "Tu as battu l'IA." : "L'IA a gagné cette manche.";
      } else {
        emoji = "🏆";
        title = "${winner.label} gagne !";
        subtitle = "Alignement de ${engine.winLength} en ligne.";
      }
    }

    return ResultOverlay(
      emoji: emoji,
      title: title,
      subtitle: subtitle,
      accentColor: accent,
      stats: [
        MapEntry("X", "$scoreX"),
        MapEntry("Nul", "$scoreDraw"),
        MapEntry("O", "$scoreO"),
      ],
      onReplay: _restart,
      onNewGame: () => Navigator.of(context).pop(),
      onBack: () => Navigator.of(context).pop(),
    );
  }
}
