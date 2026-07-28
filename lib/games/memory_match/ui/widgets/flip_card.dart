import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Carte qui se retourne en 3D (rotation Y) entre une face dos et une
/// face avant, selon [showFront].
class FlipCard extends StatefulWidget {
  final bool showFront;
  final Widget front;
  final Widget back;

  const FlipCard({
    super.key,
    required this.showFront,
    required this.front,
    required this.back,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.showFront ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showFront != oldWidget.showFront) {
      if (widget.showFront) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * math.pi;
        final isFrontVisible = angle >= math.pi / 2;
        final displayAngle = isFrontVisible ? angle - math.pi : angle;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(displayAngle),
          child: isFrontVisible ? widget.front : widget.back,
        );
      },
    );
  }
}
