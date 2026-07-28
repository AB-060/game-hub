import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/particle_background.dart';
import '../../../theme/app_colors.dart';
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

  void _startNewGame() {
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _statsCard(),
                              const SizedBox(height: 24),
                              if (_savedGame != null) ...[
                                _resumeCard(),
                                const SizedBox(height: 24),
                              ],
                              Text(
                                "Nouvelle partie",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _modePicker(),
                              const SizedBox(height: 20),
                              if (_vsAi) ...[
                                _sectionLabel("Difficulté"),
                                const SizedBox(height: 8),
                                _difficultyPicker(),
                                const SizedBox(height: 20),
                              ],
                              _sectionLabel(_vsAi ? "Jouer avec" : "Blancs commencent"),
                              const SizedBox(height: 8),
                              _colorPicker(),
                              const SizedBox(height: 28),
                              ElevatedButton.icon(
                                onPressed: _startNewGame,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text("Nouvelle partie"),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: kMuted),
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

  Widget _modePicker() {
    return Row(
      children: [
        Expanded(
          child: _modeOption(
            selected: _vsAi,
            icon: Icons.smart_toy_rounded,
            label: "Contre l'IA",
            onTap: () => setState(() => _vsAi = true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _modeOption(
            selected: !_vsAi,
            icon: Icons.people_alt_rounded,
            label: "2 joueurs",
            onTap: () => setState(() => _vsAi = false),
          ),
        ),
      ],
    );
  }

  Widget _modeOption({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? kAccent.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kAccent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? kAccent : Colors.white38, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyPicker() {
    return Column(
      children: Difficulty.values.map((d) {
        final selected = _difficulty == d;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _difficulty = d),
            child: Container(
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
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? kAccent : Colors.white38,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          d.description,
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _colorPicker() {
    return Row(
      children: [
        Expanded(child: _colorOption(PieceColor.white, "Blancs")),
        const SizedBox(width: 12),
        Expanded(child: _colorOption(PieceColor.black, "Noirs")),
      ],
    );
  }

  Widget _colorOption(PieceColor color, String label) {
    final selected = _color == color;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _color = color),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? kAccent.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kAccent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            ChessPieceIcon(piece: ChessPiece(PieceType.king, color), size: 40),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
