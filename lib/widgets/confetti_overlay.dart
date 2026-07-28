import 'dart:math';

import 'package:flutter/material.dart';

class _ConfettiPiece {
  final double x0;
  final double size;
  final double delay;
  final double speed;
  final double rotationSpeed;
  final Color color;

  _ConfettiPiece({
    required this.x0,
    required this.size,
    required this.delay,
    required this.speed,
    required this.rotationSpeed,
    required this.color,
  });

  factory _ConfettiPiece.random(Random rand) {
    const colors = [
      Color(0xFF00DCFF),
      Color(0xFFFF5C5C),
      Color(0xFFFFC24B),
      Color(0xFF4BE38A),
      Color(0xFFC084FC),
    ];
    return _ConfettiPiece(
      x0: rand.nextDouble(),
      size: 6 + rand.nextDouble() * 8,
      delay: rand.nextDouble() * 0.4,
      speed: 0.7 + rand.nextDouble() * 0.6,
      rotationSpeed: (rand.nextDouble() - 0.5) * 8,
      color: colors[rand.nextInt(colors.length)],
    );
  }
}

/// Petite explosion de confettis qui tombent, jouée une fois à la victoire.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_ConfettiPiece> _pieces =
      List.generate(70, (_) => _ConfettiPiece.random(Random()));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _controller.value),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final localT = ((t - p.delay) / p.speed).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final dy = localT * (size.height + 40) - 20;
      final dx = p.x0 * size.width + sin(localT * 6) * 14;
      final rotation = localT * p.rotationSpeed * pi;
      final opacity = (1 - localT).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(rotation);
      final paint = Paint()..color = p.color.withOpacity(opacity);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
