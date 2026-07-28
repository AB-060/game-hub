import 'dart:math';

import 'package:flutter/material.dart';

import '../models/match_models.dart';
import '../models/team.dart';

/// Fond de stade léger : dégradé thématisé par confédération + effet
/// météo (pluie/brouillard en particules, scintillement de projecteurs
/// la nuit). Pas d'assets externes, tout est dessiné.
class StadiumBackground extends StatefulWidget {
  final Continent continent;
  final Weather weather;

  const StadiumBackground({super.key, required this.continent, required this.weather});

  @override
  State<StadiumBackground> createState() => _StadiumBackgroundState();
}

class _StadiumBackgroundState extends State<StadiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _gradientFor(Continent c) {
    switch (c) {
      case Continent.africa:
        return const [Color(0xFF1B4332), Color(0xFF081C15)];
      case Continent.europe:
        return const [Color(0xFF1D3461), Color(0xFF0B1E3D)];
      case Continent.southAmerica:
        return const [Color(0xFF2D5D2A), Color(0xFF0E2611)];
      case Continent.northAmerica:
        return const [Color(0xFF223A5E), Color(0xFF0C1B2E)];
      case Continent.asia:
        return const [Color(0xFF4A235A), Color(0xFF1B0E22)];
      case Continent.oceania:
        return const [Color(0xFF145C6E), Color(0xFF06282F)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(widget.continent);
    final darker = widget.weather == Weather.night;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: darker ? [Colors.black, colors.last] : colors,
            ),
          ),
        ),
        if (widget.weather == Weather.rain || widget.weather == Weather.fog)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _WeatherPainter(widget.weather, _controller.value),
            ),
          ),
        if (widget.weather == Weather.night)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(painter: _FloodlightPainter(_controller.value)),
          ),
      ],
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final Weather weather;
  final double t;
  final Random _rand = Random(7);
  _WeatherPainter(this.weather, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (weather == Weather.rain) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..strokeWidth = 1.4;
      for (int i = 0; i < 60; i++) {
        final x = _rand.nextDouble() * size.width;
        final baseY = _rand.nextDouble() * size.height;
        final y = (baseY + t * size.height * 4) % size.height;
        canvas.drawLine(Offset(x, y), Offset(x - 4, y + 14), paint);
      }
    } else {
      final paint = Paint()..color = Colors.white.withOpacity(0.06);
      for (int i = 0; i < 4; i++) {
        final y = size.height * (0.2 + i * 0.2) + sin(t * 2 * pi + i) * 6;
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, 40), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) => oldDelegate.t != t;
}

class _FloodlightPainter extends CustomPainter {
  final double t;
  _FloodlightPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final flicker = 0.12 + sin(t * 2 * pi) * 0.03;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(flicker), Colors.white.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.15, 0), radius: size.width * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.4), paint);

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(flicker), Colors.white.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, 0), radius: size.width * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.4), paint2);
  }

  @override
  bool shouldRepaint(covariant _FloodlightPainter oldDelegate) => oldDelegate.t != t;
}
