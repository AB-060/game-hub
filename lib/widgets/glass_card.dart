import 'dart:ui';

import 'package:flutter/material.dart';


/// Carte "verre dépoli" réutilisable (fond translucide + flou + bordure
/// lumineuse), utilisée dans tout le hub pour garder un langage visuel
/// cohérent entre les jeux.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;
  final double borderRadius;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = Colors.white12,
    this.borderRadius = 16,
    this.blur = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}
