import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/ai_engine.dart';
import '../engine/chess_engine.dart';
import '../models/chess_models.dart';
import '../services/persistence_service.dart';
import '../services/sound_service.dart';
import 'widgets/board_view.dart';
import 'widgets/dialogs.dart';
import 'widgets/piece_painter.dart';

class ChessGameScreen extends StatefulWidget {
  /// null = partie locale à 2 joueurs sur le même appareil (pas d'IA).
  final Difficulty? difficulty;
  final PieceColor playerColor;
  final SavedGame? resume;

  const ChessGameScreen({
    super.key,
    required this.difficulty,
    required this.playerColor,
    required this.resume,
  });

  bool get vsAi => difficulty != null;

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  static const Map<PieceType, int> _standardCounts = {
    PieceType.pawn: 8,
    PieceType.knight: 2,
    PieceType.bishop: 2,
    PieceType.rook: 2,
    PieceType.queen: 1,
    PieceType.king: 1,
  };

  late ChessEngine engine;
  final List<TrackedPiece> tracked = [];
  int _nextId = 0;

  int? selectedSquare;
  List<int> legalTargets = [];
  int? lastMoveFrom;
  int? lastMoveTo;

  bool aiThinking = false;
  bool gameOver = false;
  bool soundEnabled = true;

  int whiteSeconds = 0;
  int blackSeconds = 0;
  Timer? _clockTimer;
  int _ticksSinceSave = 0;

  final List<String> sanHistory = [];

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      engine = ChessEngine.fromJson(resume.engineJson);
      whiteSeconds = resume.whiteSeconds;
      blackSeconds = resume.blackSeconds;
      sanHistory.addAll(resume.moveHistorySan);
    } else {
      engine = ChessEngine.newGame();
    }
    _initTracked();
    _startClock();

    if (!gameOver && widget.vsAi && engine.turn != widget.playerColor) {
      _scheduleAiMove();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _initTracked() {
    tracked.clear();
    _nextId = 0;
    for (int sq = 0; sq < 64; sq++) {
      final p = engine.board[sq];
      if (p != null) {
        tracked.add(TrackedPiece(id: _nextId++, square: sq, piece: p));
      }
    }
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (gameOver) return;
      setState(() {
        if (engine.turn == PieceColor.white) {
          whiteSeconds++;
        } else {
          blackSeconds++;
        }
      });
      _ticksSinceSave++;
      if (_ticksSinceSave >= 5) {
        _ticksSinceSave = 0;
        _saveGame();
      }
    });
  }

  Future<void> _saveGame() async {
    if (gameOver) return;
    await PersistenceService.instance.saveGame(SavedGame(
      engineJson: engine.toJson(),
      difficulty: widget.difficulty,
      playerColor: widget.playerColor,
      whiteSeconds: whiteSeconds,
      blackSeconds: blackSeconds,
      moveHistorySan: sanHistory,
    ));
  }

  TrackedPiece? _trackedAt(int square) {
    for (final t in tracked) {
      if (t.square == square) return t;
    }
    return null;
  }

  void _applyMove(ChessMove move) {
    if (move.isEnPassant && move.enPassantCapturedSquare != null) {
      final captured = _trackedAt(move.enPassantCapturedSquare!);
      if (captured != null) tracked.remove(captured);
    } else if (move.captured != null) {
      final captured = _trackedAt(move.to);
      if (captured != null) tracked.remove(captured);
    }

    final mover = _trackedAt(move.from);
    if (mover != null) {
      mover.square = move.to;
      if (move.promotion != null) {
        mover.piece = ChessPiece(move.promotion!, mover.piece.color);
      }
    }

    if (move.isCastleKingSide || move.isCastleQueenSide) {
      final isWhite = move.piece.color == PieceColor.white;
      final homeRow = isWhite ? 7 : 0;
      final rookFrom = move.isCastleKingSide
          ? ChessEngine.square(homeRow, 7)
          : ChessEngine.square(homeRow, 0);
      final rookTo = move.isCastleKingSide
          ? ChessEngine.square(homeRow, 5)
          : ChessEngine.square(homeRow, 3);
      final rook = _trackedAt(rookFrom);
      if (rook != null) rook.square = rookTo;
    }

    engine.makeMove(move);
    engine.recordPositionForRepetition();
    sanHistory.add(move.toAlgebraic());

    if (move.isCheckmate) {
      SoundService.instance.play(ChessSound.check);
    } else if (move.isCheck) {
      SoundService.instance.play(ChessSound.check);
    } else if (move.isCastleKingSide || move.isCastleQueenSide) {
      SoundService.instance.play(ChessSound.castle);
    } else if (move.isCapture) {
      SoundService.instance.play(ChessSound.capture);
    } else {
      SoundService.instance.play(ChessSound.move);
    }

    setState(() {
      lastMoveFrom = move.from;
      lastMoveTo = move.to;
      selectedSquare = null;
      legalTargets = [];
    });

    final result = engine.result;
    if (result != GameResult.ongoing) {
      _handleGameOver(result);
      return;
    }

    _saveGame();

    if (widget.vsAi && engine.turn != widget.playerColor) {
      _scheduleAiMove();
    }
  }

  void _scheduleAiMove() {
    setState(() => aiThinking = true);
    Future.delayed(const Duration(milliseconds: 350), () async {
      final move = await AiEngine.findBestMove(engine, widget.difficulty!);
      if (!mounted) return;
      setState(() => aiThinking = false);
      if (move != null) _applyMove(move);
    });
  }

  Future<void> _onSquareTap(int square) async {
    if (gameOver || aiThinking) return;
    if (widget.vsAi && engine.turn != widget.playerColor) return;

    if (selectedSquare != null && legalTargets.contains(square)) {
      final candidates =
          engine.legalMoves(fromSquare: selectedSquare).where((m) => m.to == square).toList();
      if (candidates.isEmpty) return;

      ChessMove move;
      if (candidates.length > 1) {
        final promotion = await showPromotionDialog(context, engine.turn);
        if (promotion == null) return;
        move = candidates.firstWhere((m) => m.promotion == promotion);
      } else {
        move = candidates.first;
      }
      _applyMove(move);
      return;
    }

    final piece = engine.board[square];
    if (piece != null && piece.color == engine.turn) {
      setState(() {
        selectedSquare = square;
        legalTargets = engine.legalMoves(fromSquare: square).map((m) => m.to).toList();
      });
    } else {
      setState(() {
        selectedSquare = null;
        legalTargets = [];
      });
    }
  }

  Future<void> _handleGameOver(GameResult result) async {
    setState(() => gameOver = true);
    _clockTimer?.cancel();

    String title;
    String subtitle;

    if (result == GameResult.draw) {
      title = "Partie nulle";
      subtitle = switch (engine.drawReason) {
        DrawReason.stalemate => "Pat : aucun coup légal, mais pas d'échec.",
        DrawReason.insufficientMaterial => "Matériel insuffisant pour mater.",
        DrawReason.fiftyMoveRule => "Règle des 50 coups sans capture ni poussée de pion.",
        DrawReason.threefoldRepetition => "Triple répétition de la position.",
        DrawReason.none => "Match nul.",
      };
      SoundService.instance.play(ChessSound.gameDraw);
    } else if (!widget.vsAi) {
      // Partie locale à 2 joueurs : pas de notion de victoire/défaite du
      // point de vue de l'appareil, juste qui a gagné.
      final winner = result == GameResult.whiteWins ? "Les Blancs" : "Les Noirs";
      title = "$winner gagnent !";
      subtitle = "Échec et mat.";
      SoundService.instance.play(ChessSound.gameWin);
    } else {
      final playerWon = (result == GameResult.whiteWins && widget.playerColor == PieceColor.white) ||
          (result == GameResult.blackWins && widget.playerColor == PieceColor.black);
      if (playerWon) {
        title = "Victoire !";
        subtitle = "Échec et mat.";
        SoundService.instance.play(ChessSound.gameWin);
      } else {
        title = "Défaite";
        subtitle = "Échec et mat.";
        SoundService.instance.play(ChessSound.gameLose);
      }
    }

    if (widget.vsAi) {
      await PersistenceService.instance.recordResult(
        result: result,
        playerColor: widget.playerColor,
        secondsPlayed: whiteSeconds + blackSeconds,
      );
    }
    await PersistenceService.instance.clearGame();

    if (!mounted) return;
    showGameOverDialog(
      context,
      title: title,
      subtitle: subtitle,
      onRematch: _restart,
      onHome: () => Navigator.of(context).pop(),
    );
  }

  void _restart() {
    setState(() {
      engine = ChessEngine.newGame();
      _initTracked();
      selectedSquare = null;
      legalTargets = [];
      lastMoveFrom = null;
      lastMoveTo = null;
      whiteSeconds = 0;
      blackSeconds = 0;
      sanHistory.clear();
      gameOver = false;
    });
    _startClock();
    if (widget.vsAi && engine.turn != widget.playerColor) {
      _scheduleAiMove();
    }
  }

  List<ChessPiece> _capturedPieces(PieceColor color) {
    final counts = {for (final t in PieceType.values) t: 0};
    for (final p in engine.board) {
      if (p != null && p.color == color) counts[p.type] = counts[p.type]! + 1;
    }
    const order = [
      PieceType.queen,
      PieceType.rook,
      PieceType.bishop,
      PieceType.knight,
      PieceType.pawn,
    ];
    final captured = <ChessPiece>[];
    for (final t in order) {
      final missing = _standardCounts[t]! - counts[t]!;
      for (int i = 0; i < missing; i++) {
        captured.add(ChessPiece(t, color));
      }
    }
    return captured;
  }

  String _formatClock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // En mode IA, le bas du plateau est toujours le joueur humain ; en
    // mode 2 joueurs locaux, le plateau garde une orientation fixe
    // (Blancs en bas) pour éviter une rotation animée déroutante à
    // chaque coup.
    final bottomColor = widget.vsAi ? widget.playerColor : PieceColor.white;
    final topColor = bottomColor.opposite;

    final String statusText;
    if (gameOver) {
      statusText = "Partie terminée";
    } else if (aiThinking) {
      statusText = "L'ordinateur réfléchit...";
    } else if (widget.vsAi) {
      statusText = engine.turn == widget.playerColor
          ? (engine.isInCheck ? "Échec ! À vous de jouer" : "À vous de jouer")
          : "Tour de l'adversaire";
    } else {
      final turnLabel = engine.turn == PieceColor.white ? "Blancs" : "Noirs";
      statusText = engine.isInCheck ? "Échec ! Tour des $turnLabel" : "Tour des $turnLabel";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Échecs · ${widget.difficulty?.label ?? '2 joueurs'}"),
        actions: [
          IconButton(
            tooltip: soundEnabled ? "Couper le son" : "Activer le son",
            icon: Icon(soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            onPressed: () {
              setState(() {
                soundEnabled = !soundEnabled;
                SoundService.instance.enabled = soundEnabled;
              });
            },
          ),
          IconButton(
            tooltip: "Nouvelle partie",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _restart,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _playerBar(
              color: topColor,
              seconds: topColor == PieceColor.white ? whiteSeconds : blackSeconds,
              captured: _capturedPieces(bottomColor),
              isActive: engine.turn == topColor && !gameOver,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: engine.isInCheck && !gameOver ? Colors.redAccent : Colors.white70,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: BoardView(
                  engine: engine,
                  trackedPieces: tracked,
                  orientation: bottomColor,
                  selectedSquare: selectedSquare,
                  legalTargets: legalTargets,
                  lastMoveFrom: lastMoveFrom,
                  lastMoveTo: lastMoveTo,
                  showCheck: engine.isInCheck && !gameOver,
                  onSquareTap: _onSquareTap,
                ),
              ),
            ),
            _playerBar(
              color: bottomColor,
              seconds: bottomColor == PieceColor.white ? whiteSeconds : blackSeconds,
              captured: _capturedPieces(topColor),
              isActive: engine.turn == bottomColor && !gameOver,
            ),
            _moveHistoryStrip(),
          ],
        ),
      ),
    );
  }

  Widget _playerBar({
    required PieceColor color,
    required int seconds,
    required List<ChessPiece> captured,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.indigo.withOpacity(0.16) : Colors.transparent,
      ),
      child: Row(
        children: [
          Icon(
            color == PieceColor.white ? Icons.circle_outlined : Icons.circle,
            size: 14,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: -6,
              children: [
                for (final p in captured) ChessPieceIcon(piece: p, size: 20),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF15152C),
              borderRadius: BorderRadius.circular(8),
              border: isActive ? Border.all(color: Colors.indigoAccent) : null,
            ),
            child: Text(
              _formatClock(seconds),
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moveHistoryStrip() {
    if (sanHistory.isEmpty) return const SizedBox(height: 8);
    final pairs = <String>[];
    for (int i = 0; i < sanHistory.length; i += 2) {
      final n = (i ~/ 2) + 1;
      final white = sanHistory[i];
      final black = i + 1 < sanHistory.length ? sanHistory[i + 1] : "";
      pairs.add("$n. $white${black.isNotEmpty ? '  $black' : ''}");
    }
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: pairs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: Text(
                pairs[index],
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
          );
        },
      ),
    );
  }
}
