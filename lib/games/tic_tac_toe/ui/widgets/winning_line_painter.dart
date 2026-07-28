import 'package:flutter/material.dart';

/// Dessine une ligne animée traversant les cases gagnantes (progression
/// 0..1, de la première à la dernière case de la ligne).
class WinningLinePainter extends CustomPainter {
  final List<int> line;
  final int boardSize;
  final double progress;
  final Color color;

  WinningLinePainter({
    required this.line,
    required this.boardSize,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (line.length < 2) return;
    final cell = size.width / boardSize;

    Offset centerOf(int index) {
      final r = index ~/ boardSize;
      final c = index % boardSize;
      return Offset(c * cell + cell / 2, r * cell + cell / 2);
    }

    final start = centerOf(line.first);
    final end = centerOf(line.last);
    final current = Offset.lerp(start, end, progress)!;

    final paint = Paint()
      ..color = color
      ..strokeWidth = cell * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = cell * 0.22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(start, current, glowPaint);
    canvas.drawLine(start, current, paint);
  }

  @override
  bool shouldRepaint(covariant WinningLinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.line != line;
}
