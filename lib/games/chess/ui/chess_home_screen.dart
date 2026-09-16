import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../home/particle_background.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/setup_wizard.dart';
import '../models/chess_models.dart';
import '../services/persistence_service.dart';
import 'chess_game_screen.dart';
import 'widgets/piece_painter.dart';

/// Écran d'accueil des échecs : reprise de partie, choix du mode (IA ou
/// 2 joueurs locaux), difficulté, couleur, statistiques. Reprend le même
/// habillage visuel que le hub (fond animé de particules, cartes en verre
/// dépoli) pour rester cohérent avec le reste de l'application.
class ChessHomeScreen extends StatefulWidget {
  const ChessHomeScreen({super.key});

  @override
  State<ChessHomeScreen> createState() => _ChessHomeScreenState();
}

class _ChessHomeScreenState extends State<ChessHomeScreen> {
  bool _vsAi = true;
  Difficulty _difficulty = Difficulty.intermediate;
  PieceColor _color = PieceColor.white;
  SavedGame? _savedGame;
  ChessStats _stats = const ChessStats();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await PersistenceService.instance.loadGame();
    final stats = await PersistenceService.instance.loadStats();
    if (!mounted) return;
    setState(() {
      _savedGame = saved;
      _stats = stats;
      _loading = false;
    });
  }

  /// Les étapes du formulaire. La difficulté ne concerne que le jeu contre
  /// l'IA : la question disparaît en mode 2 joueurs.
  List<WizardStep> _buildSteps() {
    return [
      WizardStep(
        title: "Comment veux-tu jouer ?",
        options: [
          WizardOption(
            label: "Contre l'IA",
            subtitle: "Affronte l'ordinateur",
            icon: Icons.smart_toy_rounded,
            selected: _vsAi,
            onSelect: () => setState(() => _vsAi = true),
          ),
          WizardOption(
            label: "2 joueurs",
            subtitle: "Sur le même appareil",
            icon: Icons.people_alt_rounded,
            selected: !_vsAi,
            onSelect: () => setState(() => _vsAi = false),
          ),
        ],
      ),
      if (_vsAi)
        WizardStep(
          title: "Niveau de l'IA",
          options: Difficulty.values
              .map(
                (d) => WizardOption(
                  label: d.label,
                  subtitle: d.description,
                  selected: _difficulty == d,
                  onSelect: () => setState(() => _difficulty = d),
                ),
              )
              .toList(),
        ),
      WizardStep(
        title: _vsAi ? "Tu joues avec quelle couleur ?" : "Qui es-tu ?",
        hint: "Les blancs commencent toujours.",
        options: [
          WizardOption(
            label: "Blancs",
            subtitle: "Tu commences",
            leading: const ChessPieceIcon(
              piece: ChessPiece(PieceType.king, PieceColor.white),
              size: 34,
            ),
            selected: _color == PieceColor.white,
            onSelect: () => setState(() => _color = PieceColor.white),
          ),
          WizardOption(
            label: "Noirs",
            subtitle: _vsAi ? "L'IA commence" : "Les blancs commencent",
            leading: const ChessPieceIcon(
              piece: ChessPiece(PieceType.king, PieceColor.black),
              size: 34,
            ),
            selected: _color == PieceColor.black,
            onSelect: () => setState(() => _color = PieceColor.black),
          ),
        ],
      ),
    ];
  }

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetupWizard(
          gameTitle: "Échecs",
          stepsBuilder: _buildSteps,
          onComplete: _startNewGame,
        ),
      ),
    );
  }

  void _startNewGame() {
    // Ferme le formulaire pour que le retour depuis la partie ramène ici.
    Navigator.of(context).pop();
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChessGameScreen(
            difficulty: _vsAi ? _difficulty : null,
            playerColor: _color,
            resume: null,
          ),
        ))
        .then((_) => _load());
  }

  void _resumeGame() {
    final saved = _savedGame;
    if (saved == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChessGameScreen(
            difficulty: saved.difficulty,
            playerColor: saved.playerColor,
            resume: saved,
          ),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Échecs"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _statsCard(),
                        const SizedBox(height: 24),
                        if (_savedGame != null) ...[
                          _resumeCard(),
                          const SizedBox(height: 24),
                        ],
                        ElevatedButton.icon(
                          onPressed: _openSetup,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text("Nouvelle partie"),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _glass({
    required Widget child,
    Color borderColor = Colors.white12,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _statsCard() {
    return _glass(
      child: Row(
        children: [
          _statItem("Victoires", "${_stats.wins}", Colors.greenAccent),
          _statItem("Défaites", "${_stats.losses}", Colors.redAccent),
          _statItem("Nulles", "${_stats.draws}", Colors.white70),
          _statItem("Temps", _formatDuration(_stats.totalSecondsPlayed), kAccent),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return "${h}h${m.toString().padLeft(2, '0')}";
    return "${m}min";
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _resumeCard() {
    return _glass(
      borderColor: kAccent.withOpacity(0.4),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: kAccent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Une partie est en cours", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: _resumeGame,
            child: const Text("Reprendre"),
          ),
        ],
      ),
    );
  }

}
