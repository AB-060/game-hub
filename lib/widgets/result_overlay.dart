import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Overlay de fin de partie réutilisable : titre animé, sous-titre,
/// statistiques optionnelles, et jusqu'à 3 actions (Rejouer, Nouvelle
/// partie, Retour). Utilisé par tous les mini-jeux pour garder un même
/// écran de victoire/défaite/nul.
class ResultOverlay extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<MapEntry<String, String>> stats;
  final VoidCallback? onReplay;
  final VoidCallback? onNewGame;
  final VoidCallback? onBack;

  const ResultOverlay({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.accentColor = kAccent,
    this.stats = const [],
    this.onReplay,
    this.onNewGame,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.72),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF15152C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accentColor.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: accentColor.withOpacity(0.25), blurRadius: 30),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final s in stats)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            children: [
                              Text(
                                s.value,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                s.key,
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (onReplay != null)
                      ElevatedButton.icon(
                        onPressed: onReplay,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Rejouer"),
                      ),
                    if (onNewGame != null)
                      OutlinedButton.icon(
                        onPressed: onNewGame,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text("Nouvelle partie"),
                      ),
                    if (onBack != null)
                      TextButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.home_rounded),
                        label: const Text("Retour"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
