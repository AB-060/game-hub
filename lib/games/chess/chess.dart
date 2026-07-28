export 'ui/chess_home_screen.dart' show ChessHomeScreen;

import 'package:flutter/material.dart';
import 'ui/chess_home_screen.dart';

/// Point d'entrée du jeu d'échecs depuis le hub — alias vers l'écran
/// d'accueil (choix de la difficulté / couleur / reprise de partie).
class ChessScreen extends StatelessWidget {
  const ChessScreen({super.key});

  @override
  Widget build(BuildContext context) => const ChessHomeScreen();
}
