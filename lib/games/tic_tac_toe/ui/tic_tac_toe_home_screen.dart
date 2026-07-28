import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/particle_background.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../models/ttt_models.dart';
import 'tic_tac_toe_game_screen.dart';

const _statsService = GameStatsService('tictactoe');
const _saveService = GameSaveService('tictactoe');

/// Écran d'accueil du Morpion : mode (IA ou 2 joueurs), difficulté, taille
/// de grille, symbole, reprise de partie et statistiques.
class TicTacToeHomeScreen extends StatefulWidget {
  const TicTacToeHomeScreen({super.key});

  @override
  State<TicTacToeHomeScreen> createState() => _TicTacToeHomeScreenState();
}

class _TicTacToeHomeScreenState extends State<TicTacToeHomeScreen> {
  bool _vsAi = true;
  TttDifficulty _difficulty = TttDifficulty.intermediate;
  TttBoardSize _boardSize = TttBoardSize.size3;
  PlayerMark _mark = PlayerMark.x;

  GameStats _stats = const GameStats();
  Map<String, dynamic>? _savedGame;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await _statsService.load();
    final saved = await _saveService.loadState();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _savedGame = saved;
      _loading = false;
    });
  }

  void _startNewGame() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => TicTacToeGameScreen(
            vsAi: _vsAi,
            difficulty: _difficulty,
            boardSize: _boardSize,
            humanMark: _mark,
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
          builder: (_) => TicTacToeGameScreen(
            vsAi: saved['vsAi'] as bool,
            difficulty: TttDifficulty.values.firstWhere((d) => d.name == saved['difficulty']),
            boardSize: TttBoardSize.values.firstWhere((s) => s.name == saved['boardSize']),
            humanMark: saved['humanMark'] == 'x' ? PlayerMark.x : PlayerMark.o,
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
        title: const Text("Morpion"),
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
                              _sectionLabel("Taille de la grille"),
                              const SizedBox(height: 8),
                              _sizePicker(),
                              const SizedBox(height: 20),
                              if (_vsAi) ...[
                                _sectionLabel("Difficulté"),
                                const SizedBox(height: 8),
                                _difficultyPicker(),
                                const SizedBox(height: 20),
                                _sectionLabel("Ton symbole"),
                                const SizedBox(height: 8),
                                _markPicker(),
                                const SizedBox(height: 28),
                              ],
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

  Widget _statsCard() {
    return GlassCard(
      child: Row(
        children: [
          _statItem("Victoires", "${_stats.wins}", Colors.greenAccent),
          _statItem("Défaites", "${_stats.losses}", Colors.redAccent),
          _statItem("Nulles", "${_stats.draws}", Colors.white70),
          _statItem("Série", "${_stats.bestWinStreak}", kAccent),
        ],
      ),
    );
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
    return GlassCard(
      borderColor: kAccent.withOpacity(0.4),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: kAccent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Une partie est en cours", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(onPressed: _resumeGame, child: const Text("Reprendre")),
        ],
      ),
    );
  }

  Widget _modePicker() {
    return Row(
      children: [
        Expanded(
          child: SelectableChip(
            selected: _vsAi,
            icon: Icons.smart_toy_rounded,
            label: "Contre l'IA",
            onTap: () => setState(() => _vsAi = true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableChip(
            selected: !_vsAi,
            icon: Icons.people_alt_rounded,
            label: "2 joueurs",
            onTap: () => setState(() => _vsAi = false),
          ),
        ),
      ],
    );
  }

  Widget _sizePicker() {
    return Row(
      children: TttBoardSize.values.map((s) {
        final selected = _boardSize == s;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: s == TttBoardSize.values.last ? 0 : 8),
            child: SelectableChip(
              selected: selected,
              label: s.label,
              onTap: () => setState(() => _boardSize = s),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _difficultyPicker() {
    return Column(
      children: TttDifficulty.values.map((d) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableChip(
            selected: _difficulty == d,
            label: d.label,
            subtitle: d.description,
            onTap: () => setState(() => _difficulty = d),
          ),
        );
      }).toList(),
    );
  }

  Widget _markPicker() {
    return Row(
      children: [
        Expanded(
          child: SelectableChip(
            selected: _mark == PlayerMark.x,
            label: "X",
            onTap: () => setState(() => _mark = PlayerMark.x),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableChip(
            selected: _mark == PlayerMark.o,
            label: "O",
            onTap: () => setState(() => _mark = PlayerMark.o),
          ),
        ),
      ],
    );
  }
}
