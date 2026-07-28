import 'package:flutter/material.dart';

import '../../models/chess_models.dart';

/// Pièces dessinées entièrement en vectoriel (silhouettes façon Staunton),
/// nettes à n'importe quelle taille — pas de dépendance à des assets.
class ChessPieceIcon extends StatelessWidget {
  final ChessPiece piece;
  final double size;

  const ChessPieceIcon({super.key, required this.piece, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PiecePainter(piece: piece),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  final ChessPiece piece;
  _PiecePainter({required this.piece});

  @override
  void paint(Canvas canvas, Size size) {
    final isWhite = piece.color == PieceColor.white;
    final fill = Paint()
      ..color = isWhite ? const Color(0xFFF4F1EA) : const Color(0xFF23222A)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = isWhite ? const Color(0xFF6B6558) : const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final path = _pathFor(piece.type);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    canvas.restore();
  }

  Path _pathFor(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return _pawnPath();
      case PieceType.rook:
        return _rookPath();
      case PieceType.knight:
        return _knightPath();
      case PieceType.bishop:
        return _bishopPath();
      case PieceType.queen:
        return _queenPath();
      case PieceType.king:
        return _kingPath();
    }
  }

  Path _base() {
    return Path()
      ..moveTo(22, 88)
      ..lineTo(78, 88)
      ..lineTo(72, 78)
      ..lineTo(28, 78)
      ..close();
  }

  Path _pawnPath() {
    final p = Path();
    p.addOval(const Rect.fromLTWH(38, 22, 24, 24));
    p.addPath(_trapezoid(32, 50, 68, 78, 44, 78), Offset.zero);
    p.addPath(_base(), Offset.zero);
    return p;
  }

  Path _trapezoid(double xTopL, double yTop, double xTopR, double yBot, double width, double _) {
    return Path()
      ..moveTo(xTopL + 4, yTop)
      ..lineTo(xTopR - 4, yTop)
      ..lineTo(xTopR, yBot)
      ..lineTo(xTopL, yBot)
      ..close();
  }

  Path _rookPath() {
    final p = Path();
    // Créneaux.
    p.addRect(const Rect.fromLTWH(28, 18, 8, 12));
    p.addRect(const Rect.fromLTWH(46, 18, 8, 12));
    p.addRect(const Rect.fromLTWH(64, 18, 8, 12));
    p.addRect(const Rect.fromLTWH(28, 18, 44, 6));
    // Corps.
    p.addPath(
      Path()
        ..moveTo(32, 30)
        ..lineTo(68, 30)
        ..lineTo(66, 62)
        ..lineTo(34, 62)
        ..close(),
      Offset.zero,
    );
    p.addPath(_base(), Offset.zero);
    p.addRect(const Rect.fromLTWH(28, 62, 44, 10));
    return p;
  }

  Path _knightPath() {
    final p = Path()
      ..moveTo(30, 88)
      ..lineTo(30, 74)
      ..cubicTo(28, 60, 34, 52, 30, 42)
      ..cubicTo(28, 32, 38, 22, 52, 20)
      ..cubicTo(64, 19, 74, 26, 76, 36)
      ..cubicTo(78, 44, 72, 46, 68, 42)
      ..cubicTo(65, 39, 60, 40, 62, 45)
      ..cubicTo(64, 50, 70, 52, 70, 60)
      ..lineTo(70, 74)
      ..lineTo(70, 88)
      ..close();
    // Œil.
    p.addOval(const Rect.fromLTWH(52, 30, 5, 5));
    return p;
  }

  Path _bishopPath() {
    final p = Path();
    p.addOval(const Rect.fromLTWH(46, 16, 8, 8));
    p.addPath(
      Path()
        ..moveTo(50, 26)
        ..cubicTo(66, 34, 70, 50, 60, 62)
        ..cubicTo(58, 66, 60, 68, 64, 70)
        ..lineTo(36, 70)
        ..cubicTo(40, 68, 42, 66, 40, 62)
        ..cubicTo(30, 50, 34, 34, 50, 26)
        ..close(),
      Offset.zero,
    );
    p.addPath(_trapezoid(30, 70, 70, 80, 0, 0), Offset.zero);
    p.addPath(_base(), Offset.zero);
    return p;
  }

  Path _queenPath() {
    final p = Path();
    for (final cx in [26.0, 38.0, 50.0, 62.0, 74.0]) {
      p.addOval(Rect.fromCircle(center: Offset(cx, 22), radius: 5));
    }
    p.addPath(
      Path()
        ..moveTo(26, 24)
        ..lineTo(74, 24)
        ..lineTo(66, 60)
        ..lineTo(34, 60)
        ..close(),
      Offset.zero,
    );
    p.addPath(_trapezoid(28, 60, 72, 78, 0, 0), Offset.zero);
    p.addPath(_base(), Offset.zero);
    return p;
  }

  Path _kingPath() {
    final p = Path();
    // Croix.
    p.addRect(const Rect.fromLTWH(47, 10, 6, 16));
    p.addRect(const Rect.fromLTWH(41, 16, 18, 6));
    p.addPath(
      Path()
        ..moveTo(30, 32)
        ..lineTo(70, 32)
        ..lineTo(64, 62)
        ..lineTo(36, 62)
        ..close(),
      Offset.zero,
    );
    p.addPath(_trapezoid(28, 62, 72, 80, 0, 0), Offset.zero);
    p.addPath(_base(), Offset.zero);
    return p;
  }

  @override
  bool shouldRepaint(covariant _PiecePainter oldDelegate) =>
      oldDelegate.piece != piece;
}
