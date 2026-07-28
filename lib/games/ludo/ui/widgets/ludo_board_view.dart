import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/ludo_engine.dart';
import '../../models/ludo_board.dart';

class _CellInfo {
  final int? ringIndex;
  final PawnColor? homeOwner;
  const _CellInfo({this.ringIndex, this.homeOwner});
}

Map<Point<int>, _CellInfo>? _cellLookupCache;

Map<Point<int>, _CellInfo> _buildCellLookup() {
  final map = <Point<int>, _CellInfo>{};
  for (int i = 0; i < LudoBoard.ringCells.length; i++) {
    map[LudoBoard.ringCells[i]] = _CellInfo(ringIndex: i);
  }
  for (final color in PawnColor.values) {
    for (final cell in LudoBoard.homeColumns[color]!) {
      map[cell] = _CellInfo(homeOwner: color);
    }
  }
  return map;
}

/// Plateau de Ludo classique (grille 15x15) : cours colorées, piste
/// commune, couloirs privés, cases sûres, et pions animés.
class LudoBoardView extends StatelessWidget {
  final LudoEngine engine;
  final List<int> selectablePawns;
  final void Function(PawnColor color, int pawnIndex) onPawnTap;

  const LudoBoardView({
    super.key,
    required this.engine,
    required this.selectablePawns,
    required this.onPawnTap,
  });

  @override
  Widget build(BuildContext context) {
    _cellLookupCache ??= _buildCellLookup();
    final lookup = _cellLookupCache!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final cell = side / 15;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: [
                Column(
                  children: List.generate(15, (r) {
                    return Row(
                      children: List.generate(15, (c) {
                        final p = Point(r, c);
                        final info = lookup[p];
                        final yardColor = _yardColorAt(r, c);
                        Color bg;
                        Widget? overlay;

                        if (p == LudoBoard.center) {
                          bg = const Color(0xFF15152C);
                          overlay = const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 18);
                        } else if (info?.homeOwner != null) {
                          bg = info!.homeOwner!.color.withOpacity(0.55);
                        } else if (info?.ringIndex != null) {
                          final isSafe = LudoBoard.isSafeRingSquare(info!.ringIndex!);
                          bg = isSafe ? const Color(0xFFFFF3C4) : const Color(0xFFF5F0E6);
                          if (isSafe) {
                            overlay = const Icon(Icons.star_rounded, color: Colors.orange, size: 12);
                          }
                        } else if (yardColor != null) {
                          bg = yardColor.withOpacity(0.28);
                        } else {
                          bg = const Color(0xFF0D0D1A);
                        }

                        return Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border.all(color: Colors.black12, width: 0.4),
                          ),
                          child: overlay == null ? null : Center(child: overlay),
                        );
                      }),
                    );
                  }),
                ),
                for (final color in engine.activeColors)
                  for (final pawn in engine.pawns[color]!)
                    _buildPawn(context, pawn, cell),
              ],
            ),
          ),
        );
      },
    );
  }

  Color? _yardColorAt(int r, int c) {
    if (r <= 5 && c <= 5) return PawnColor.red.color;
    if (r <= 5 && c >= 9) return PawnColor.green.color;
    if (r >= 9 && c >= 9) return PawnColor.yellow.color;
    if (r >= 9 && c <= 5) return PawnColor.blue.color;
    return null;
  }

  Widget _buildPawn(BuildContext context, LudoPawn pawn, double cell) {
    final point = LudoBoard.cellFor(pawn.color, pawn.position, pawn.index);
    final isSelectable =
        pawn.color == engine.currentPlayer && selectablePawns.contains(pawn.index);

    return AnimatedPositioned(
      key: ValueKey('${pawn.color.name}-${pawn.index}'),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      left: point.y * cell,
      top: point.x * cell,
      width: cell,
      height: cell,
      child: GestureDetector(
        onTap: isSelectable ? () => onPawnTap(pawn.color, pawn.index) : null,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: cell * (isSelectable ? 0.78 : 0.64),
            height: cell * (isSelectable ? 0.78 : 0.64),
            decoration: BoxDecoration(
              color: pawn.color.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelectable ? Colors.white : Colors.black38,
                width: isSelectable ? 2.4 : 1,
              ),
              boxShadow: isSelectable
                  ? [BoxShadow(color: pawn.color.color.withOpacity(0.8), blurRadius: 8)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
