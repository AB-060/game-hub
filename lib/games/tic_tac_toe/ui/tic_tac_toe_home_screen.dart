import 'package:flutter/material.dart';

import '../../../home/particle_background.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/setup_wizard.dart';
import '../models/ttt_models.dart';
import 'tic_tac_toe_game_screen.dart';

const _statsService = GameStatsService('tictactoe');
const _saveService = GameSaveService('tictactoe');

/// Écran d'accueil du Morpion : statistiques, reprise de partie et accès au
/// formulaire de configuration (une question par page).
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

  /// Les étapes du formulaire. La difficulté et le symbole n'ont de sens que
  /// face à l'IA : les questions disparaissent en mode 2 joueurs.
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
      WizardStep(
        title: "Taille de la grille",
        hint: _boardSize == TttBoardSize.size3
            ? "3 symboles alignés pour gagner."
            : "4 symboles alignés pour gagner.",
        options: TttBoardSize.values
            .map(
              (s) => WizardOption(
                label: s.label,
                subtitle: "${s.winLength} alignés pour gagner",
                icon: Icons.grid_on_rounded,
                selected: _boardSize == s,
                onSelect: () => setState(() => _boardSize = s),
              ),
            )
            .toList(),
      ),
      if (_vsAi) ...[
        WizardStep(
          title: "Niveau de l'IA",
          options: TttDifficulty.values
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
          title: "Ton symbole",
          hint: "X commence toujours la partie.",
          options: [
            WizardOption(
              label: "X",
              subtitle: "Tu commences",
              icon: Icons.close_rounded,
              selected: _mark == PlayerMark.x,
              onSelect: () => setState(() => _mark = PlayerMark.x),
            ),
            WizardOption(
              label: "O",
              subtitle: "L'IA commence",
              icon: Icons.circle_outlined,
              selected: _mark == PlayerMark.o,
              onSelect: () => setState(() => _mark = PlayerMark.o),
            ),
          ],
        ),
      ],
    ];
  }

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetupWizard(
          gameTitle: "Morpion",
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
}
