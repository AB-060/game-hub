import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Fond animé de particules cyan flottantes, façon "aurora" —
/// inspiré d'un écran de connexion avec canvas animé.
class ParticleBackground extends StatefulWidget {
  final int particleCount;
  const ParticleBackground({super.key, this.particleCount = 70});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _Particle {
  double x, y, vx, vy, size, alpha;
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
  });

  factory _Particle.random(Random rand, Size bounds) {
    return _Particle(
      x: rand.nextDouble() * bounds.width,
      y: rand.nextDouble() * bounds.height,
      vx: (rand.nextDouble() - 0.5) * 26,
      vy: (rand.nextDouble() - 0.5) * 26,
      size: 0.6 + rand.nextDouble() * 2.2,
      alpha: 0.35 + rand.nextDouble() * 0.55,
    );
  }

  void update(double dt, Size bounds) {
    x += vx * dt;
    y += vy * dt;
    if (x < -30) x = bounds.width + 30;
    if (x > bounds.width + 30) x = -30;
    if (y < -30) y = bounds.height + 30;
    if (y > bounds.height + 30) y = -30;
  }
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  final Random _rand = Random();
  final List<_Particle> _particles = [];
  Size _bounds = Size.zero;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  void _ensureParticles(Size size) {
    if (_bounds == size) return;
    _bounds = size;
    if (_particles.isEmpty) {
      _particles.addAll(
        List.generate(widget.particleCount, (_) => _Particle.random(_rand, size)),
      );
      _ticker = createTicker(_tick)..start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (_last == Duration.zero) ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    for (final p in _particles) {
      p.update(dt, _bounds);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureParticles(size);
        return CustomPaint(
          size: size,
          painter: _ParticlePainter(_particles),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(p.x, p.y),
          p.size * 6,
          [
            Color(0xFF00DCFF).withOpacity(p.alpha),
            Color(0xFF00DCFF).withOpacity(p.alpha * 0.22),
            const Color(0x0000DCFF),
          ],
          const [0.0, 0.4, 1.0],
        );
      canvas.drawCircle(Offset(p.x, p.y), p.size * 6, glowPaint);

      final corePaint = Paint()..color = const Color(0xFFBFFFFF);
      canvas.drawCircle(Offset(p.x, p.y), p.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
