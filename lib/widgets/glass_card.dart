import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

/// Bouton "chip" sélectionnable (utilisé pour les choix de difficulté,
/// thème, taille de plateau, etc.) avec un état visuel cohérent partout.
class SelectableChip extends StatelessWidget {
  final bool selected;
  final IconData? icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const SelectableChip({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kAccent.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kAccent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: selected ? kAccent : Colors.white38),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                ],
              ),
            ),
            if (icon == null)
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? kAccent : Colors.white38,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
