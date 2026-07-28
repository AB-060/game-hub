import 'package:flutter/material.dart';

import '../../engine/chess_engine.dart';
import '../../models/chess_models.dart';
import 'piece_painter.dart';

class TrackedPiece {
  final int id;
  int square;
  ChessPiece piece;
  TrackedPiece({required this.id, required this.square, required this.piece});
}

/// Plateau interactif, responsive (s'adapte à la largeur ET la hauteur
/// disponibles via [LayoutBuilder]), avec surbrillance des coups légaux,
/// du dernier coup joué, de l'échec en cours, et déplacement animé des
/// pièces (chaque pièce garde son identité via [TrackedPiece.id]).
class BoardView extends StatelessWidget {
  final ChessEngine engine;
  final List<TrackedPiece> trackedPieces;
  final PieceColor orientation;
  final int? selectedSquare;
  final List<int> legalTargets;
  final int? lastMoveFrom;
  final int? lastMoveTo;
  final bool showCheck;
  final void Function(int square) onSquareTap;

  const BoardView({
    super.key,
    required this.engine,
    required this.trackedPieces,
    required this.orientation,
    required this.selectedSquare,
    required this.legalTargets,
    required this.lastMoveFrom,
    required this.lastMoveTo,
    required this.showCheck,
    required this.onSquareTap,
  });

  static const Color lightSquare = Color(0xFFEDE6D6);
  static const Color darkSquare = Color(0xFF4B5D6B);

  int _displaySquare(int row, int col) {
    final r = orientation == PieceColor.white ? row : 7 - row;
    final c = orientation == PieceColor.white ? col : 7 - col;
    return ChessEngine.square(r, c);
  }

  Offset _displayOffsetForSquare(int square, double cell) {
    final row = ChessEngine.rowOf(square);
    final col = ChessEngine.colOf(square);
    final dr = orientation == PieceColor.white ? row : 7 - row;
    final dc = orientation == PieceColor.white ? col : 7 - col;
    return Offset(dc * cell, dr * cell);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final cell = side / 8;
        final kingSquare = showCheck ? engine.kingSquareOf(engine.turn) : null;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: [
                // Cases.
                Column(
                  children: List.generate(8, (row) {
                    return Row(
                      children: List.generate(8, (col) {
                        final square = _displaySquare(row, col);
                        final isLight = (row + col) % 2 == 0;
                        final isSelected = selectedSquare == square;
                        final isLegalTarget = legalTargets.contains(square);
                        final isLastMove = square == lastMoveFrom || square == lastMoveTo;
                        final isCheckSquare = square == kingSquare;

                        return GestureDetector(
                          onTap: () => onSquareTap(square),
                          child: Container(
                            width: cell,
                            height: cell,
                            color: isLight ? lightSquare : darkSquare,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isLastMove)
                                  Container(color: const Color(0x55E8C468)),
                                if (isCheckSquare)
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.red.withOpacity(0.75),
                                          Colors.red.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (isSelected)
                                  Container(color: const Color(0x6600DCFF)),
                                if (isLegalTarget && engine.board[square] == null)
                                  Container(
                                    width: cell * 0.32,
                                    height: cell * 0.32,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.22),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (isLegalTarget && engine.board[square] != null)
                                  Container(
                                    width: cell * 0.92,
                                    height: cell * 0.92,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black.withOpacity(0.35),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),

                // Pièces (animées, gardent leur identité entre les coups).
                for (final tp in trackedPieces)
                  AnimatedPositioned(
                    key: ValueKey(tp.id),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    left: _displayOffsetForSquare(tp.square, cell).dx,
                    top: _displayOffsetForSquare(tp.square, cell).dy,
                    width: cell,
                    height: cell,
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.all(cell * 0.08),
                        child: ChessPieceIcon(piece: tp.piece, size: cell * 0.84),
                      ),
                    ),
                  ),

                // Coordonnées (rangées et colonnes).
                Positioned.fill(
                  child: IgnorePointer(
                    child: _CoordinatesOverlay(orientation: orientation, cell: cell),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoordinatesOverlay extends StatelessWidget {
  final PieceColor orientation;
  final double cell;
  const _CoordinatesOverlay({required this.orientation, required this.cell});

  @override
  Widget build(BuildContext context) {
    final files = orientation == PieceColor.white
        ? ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
        : ['h', 'g', 'f', 'e', 'd', 'c', 'b', 'a'];
    final ranks = orientation == PieceColor.white
        ? [8, 7, 6, 5, 4, 3, 2, 1]
        : [1, 2, 3, 4, 5, 6, 7, 8];

    final textStyle = TextStyle(
      fontSize: cell * 0.18,
      fontWeight: FontWeight.bold,
      color: Colors.black.withOpacity(0.35),
    );

    return Stack(
      children: [
        for (int i = 0; i < 8; i++)
          Positioned(
            left: i * cell + 2,
            top: 8 * cell - cell + 2,
            child: Text(files[i], style: textStyle),
          ),
        for (int i = 0; i < 8; i++)
          Positioned(
            right: 2,
            top: i * cell + 2,
            child: Text('${ranks[i]}', style: textStyle),
          ),
      ],
    );
  }
}
