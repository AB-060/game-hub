import '../models/ttt_models.dart';

/// Moteur de Morpion générique : supporte les grilles 3x3, 4x4 et 5x5,
/// avec une longueur d'alignement gagnante adaptée à la taille du plateau.
class TicTacToeEngine {
  final int size;
  final int winLength;
  final List<PlayerMark?> board;
  PlayerMark turn;
  List<int>? winningLine;
  final List<int> history = [];

  TicTacToeEngine({required this.size, required this.winLength})
      : board = List<PlayerMark?>.filled(size * size, null),
        turn = PlayerMark.x;

  TicTacToeEngine.fromBoard({
    required this.size,
    required this.winLength,
    required List<PlayerMark?> board,
    required this.turn,
    this.winningLine,
  }) : board = List<PlayerMark?>.of(board);

  TicTacToeEngine clone() {
    final copy = TicTacToeEngine.fromBoard(
      size: size,
      winLength: winLength,
      board: board,
      turn: turn,
      winningLine: winningLine == null ? null : List.of(winningLine!),
    );
    copy.history.addAll(history);
    return copy;
  }

  int rowOf(int i) => i ~/ size;
  int colOf(int i) => i % size;
  int indexOf(int r, int c) => r * size + c;
  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  List<int> get emptyCells => [
        for (int i = 0; i < board.length; i++)
          if (board[i] == null) i,
      ];

  bool get isFull => !board.contains(null);

  /// Joue un coup et retourne le résultat de la partie après ce coup.
  TttResult play(int index) {
    if (board[index] != null) return _currentResult();
    final mover = turn;
    board[index] = mover;
    history.add(index);
    final line = _checkWinFrom(index);
    // `turn` doit toujours basculer après un coup joué (même gagnant),
    // pour rester symétrique avec undo() (utilisé par la recherche de l'IA).
    turn = turn.opposite;
    if (line != null) {
      winningLine = line;
      return mover == PlayerMark.x ? TttResult.xWins : TttResult.oWins;
    }
    if (isFull) return TttResult.draw;
    return TttResult.ongoing;
  }

  /// Annule le dernier coup joué (utilisé par la recherche de l'IA).
  void undo() {
    if (history.isEmpty) return;
    final last = history.removeLast();
    board[last] = null;
    winningLine = null;
    turn = turn.opposite;
  }

  TttResult _currentResult() {
    if (winningLine != null) {
      final mark = board[winningLine!.first];
      return mark == PlayerMark.x ? TttResult.xWins : TttResult.oWins;
    }
    if (isFull) return TttResult.draw;
    return TttResult.ongoing;
  }

  static const List<List<int>> _directions = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1],
  ];

  List<int>? _checkWinFrom(int index) {
    final mark = board[index];
    if (mark == null) return null;
    final row = rowOf(index), col = colOf(index);

    for (final d in _directions) {
      final line = <int>[index];
      int r = row + d[0], c = col + d[1];
      while (inBounds(r, c) && board[indexOf(r, c)] == mark) {
        line.add(indexOf(r, c));
        r += d[0];
        c += d[1];
      }
      r = row - d[0];
      c = col - d[1];
      while (inBounds(r, c) && board[indexOf(r, c)] == mark) {
        line.add(indexOf(r, c));
        r -= d[0];
        c -= d[1];
      }
      if (line.length >= winLength) return line;
    }
    return null;
  }

  /// Toutes les lignes possibles de longueur [winLength] du plateau
  /// (utilisé par l'heuristique de l'IA).
  List<List<int>> allWinLines() {
    final lines = <List<int>>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        for (final d in _directions) {
          final line = <int>[];
          int rr = r, cc = c;
          for (int k = 0; k < winLength; k++) {
            if (!inBounds(rr, cc)) break;
            line.add(indexOf(rr, cc));
            rr += d[0];
            cc += d[1];
          }
          if (line.length == winLength) lines.add(line);
        }
      }
    }
    return lines;
  }
}
