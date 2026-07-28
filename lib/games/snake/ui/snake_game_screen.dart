import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/app_sound_service.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../widgets/result_overlay.dart';
import '../engine/snake_engine.dart';
import '../models/snake_models.dart';

const _statsService = GameStatsService('snake');
const _saveService = GameSaveService('snake');
const int _gridSize = 15;

class SnakeGameScreen extends StatefulWidget {
  final SnakeDifficulty difficulty;
  final int mapIndex;
  final Map<String, dynamic>? resume;

  const SnakeGameScreen({
    super.key,
    required this.difficulty,
    required this.mapIndex,
    required this.resume,
  });

  @override
  State<SnakeGameScreen> createState() => _SnakeGameScreenState();
}

class _SnakeGameScreenState extends State<SnakeGameScreen>
    with SingleTickerProviderStateMixin {
  late SnakeEngine _engine;
  Timer? _timer;
  bool _paused = false;
  bool _gameOver = false;
  int _bestScore = 0;
  int _elapsedSeconds = 0;
  Timer? _clock;
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final obstacles = SnakeMaps.all[widget.mapIndex].obstacles(_gridSize);
    _engine = SnakeEngine(gridSize: _gridSize, obstacles: obstacles);

    final resume = widget.resume;
    if (resume != null) {
      final body = (resume['snake'] as List<dynamic>)
          .map((p) => Point<int>((p as List)[0] as int, p[1] as int))
          .toList();
      _engine.snake = body;
      _engine.direction = Point((resume['dx'] as int), resume['dy'] as int);
      _engine.setDirection(_engine.direction);
      _engine.score = resume['score'] as int? ?? 0;
      _elapsedSeconds = resume['seconds'] as int? ?? 0;
    }

    _statsService.load().then((s) {
      if (mounted) setState(() => _bestScore = s.bestScore);
    });

    _startTimer();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused && !_gameOver) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock?.cancel();
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.difficulty.tickInterval, (_) => _step());
  }

  void _step() {
    if (_paused || _gameOver) return;
    _runTick();
    if (!_gameOver && _engine.speedBoosted) {
      _runTick();
    }
  }

  void _runTick() {
    if (_gameOver) return;
    final result = _engine.tick();
    switch (result.outcome) {
      case TickOutcome.ateFood:
        AppSoundService.instance.play(AppSfx.success);
        break;
      case TickOutcome.ateItem:
        AppSoundService.instance.play(AppSfx.powerUp);
        break;
      case TickOutcome.shieldBlocked:
        AppSoundService.instance.play(AppSfx.danger);
        break;
      case TickOutcome.dead:
        _onGameOver();
        return;
      case TickOutcome.moved:
        break;
    }
    setState(() {});
    _saveGame();
  }

  Future<void> _onGameOver() async {
    _timer?.cancel();
    _clock?.cancel();
    AppSoundService.instance.play(AppSfx.explosion);
    _shakeController.forward(from: 0);
    final updated = await _statsService.recordGameEnd(
      score: _engine.score,
      secondsPlayed: _elapsedSeconds,
      difficulty: widget.difficulty.name,
    );
    await _saveService.clear();
    if (!mounted) return;
    setState(() {
      _gameOver = true;
      _bestScore = updated.bestScore;
    });
  }

  Future<void> _saveGame() async {
    if (_gameOver) return;
    await _saveService.saveState({
      'difficulty': widget.difficulty.name,
      'mapIndex': widget.mapIndex,
      'snake': _engine.snake.map((p) => [p.x, p.y]).toList(),
      'dx': _engine.direction.x,
      'dy': _engine.direction.y,
      'score': _engine.score,
      'seconds': _elapsedSeconds,
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  void _restart() {
    setState(() {
      final obstacles = SnakeMaps.all[widget.mapIndex].obstacles(_gridSize);
      _engine = SnakeEngine(gridSize: _gridSize, obstacles: obstacles);
      _paused = false;
      _gameOver = false;
      _elapsedSeconds = 0;
    });
    _startTimer();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused && !_gameOver) setState(() => _elapsedSeconds++);
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) _engine.setDirection(const Point(0, -1));
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) _engine.setDirection(const Point(0, 1));
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _engine.setDirection(const Point(-1, 0));
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) _engine.setDirection(const Point(1, 0));
    if (event.logicalKey == LogicalKeyboardKey.space) _togglePause();
  }

  Color _cellColor(int x, int y) {
    final p = Point(x, y);
    if (_engine.obstacles.contains(p)) return const Color(0xFF4A4A4A);
    if (_engine.snake.isNotEmpty && _engine.snake.first == p) {
      return _engine.shielded ? Colors.cyanAccent : Colors.greenAccent;
    }
    if (_engine.snake.contains(p)) return Colors.green.shade600;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Snake · ${widget.difficulty.label}"),
          actions: [
            IconButton(
              tooltip: _paused ? "Reprendre" : "Pause",
              icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              onPressed: _gameOver ? null : _togglePause,
            ),
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _statChip(Icons.star_rounded, "${_engine.score}"),
                        _statChip(Icons.emoji_events_rounded, "$_bestScore"),
                        if (_engine.shielded)
                          _statChip(Icons.shield_rounded, "x${_engine.shieldCharges}"),
                        if (_engine.speedBoosted) _statChip(Icons.bolt_rounded, "Boost"),
                        if (_engine.doubleScoreActive)
                          _statChip(Icons.auto_awesome_rounded, "x2"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GestureDetector(
                        onVerticalDragEnd: (d) {
                          if ((d.primaryVelocity ?? 0) < 0) {
                            _engine.setDirection(const Point(0, -1));
                          } else if ((d.primaryVelocity ?? 0) > 0) {
                            _engine.setDirection(const Point(0, 1));
                          }
                        },
                        onHorizontalDragEnd: (d) {
                          if ((d.primaryVelocity ?? 0) < 0) {
                            _engine.setDirection(const Point(-1, 0));
                          } else if ((d.primaryVelocity ?? 0) > 0) {
                            _engine.setDirection(const Point(1, 0));
                          }
                        },
                        child: AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final shake = sin(_shakeController.value * pi * 8) *
                                (1 - _shakeController.value) *
                                8;
                            return Transform.translate(offset: Offset(shake, 0), child: child);
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final side = min(constraints.maxWidth, constraints.maxHeight);
                              return Center(
                                child: Container(
                                  width: side,
                                  height: side,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    border: Border.all(color: Colors.greenAccent, width: 2),
                                  ),
                                  child: GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _gridSize * _gridSize,
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: _gridSize,
                                    ),
                                    itemBuilder: (context, i) {
                                      final x = i % _gridSize;
                                      final y = i ~/ _gridSize;
                                      final p = Point(x, y);
                                      final isFood = _engine.food == p;
                                      final isItem = _engine.itemPosition == p;
                                      return Container(
                                        margin: const EdgeInsets.all(0.5),
                                        decoration: BoxDecoration(
                                          color: _cellColor(x, y),
                                          boxShadow: isFood
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.redAccent.withOpacity(0.8),
                                                    blurRadius: 6,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: isFood
                                            ? const Center(
                                                child: Icon(Icons.circle,
                                                    color: Colors.redAccent, size: 8),
                                              )
                                            : isItem
                                                ? Center(
                                                    child: Text(
                                                      _engine.itemType?.emoji ?? "",
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                  )
                                                : null,
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Glisser ou flèches pour diriger • Espace pour pause",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_paused && !_gameOver) _buildPauseOverlay(),
              if (_gameOver) _buildResultOverlay(),
            ],
          ),
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

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("⏸", style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text("Pause", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _togglePause,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("Reprendre"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final isNewBest = _engine.score >= _bestScore && _engine.score > 0;
    return ResultOverlay(
      emoji: "💥",
      title: "Partie terminée",
      subtitle: isNewBest ? "Nouveau meilleur score !" : "Le serpent s'est écrasé.",
      accentColor: Colors.greenAccent,
      stats: [
        MapEntry("Score", "${_engine.score}"),
        MapEntry("Longueur", "${_engine.snake.length}"),
        MapEntry("Record", "$_bestScore"),
      ],
      onReplay: _restart,
      onNewGame: () => Navigator.of(context).pop(),
      onBack: () => Navigator.of(context).pop(),
    );
  }
}
