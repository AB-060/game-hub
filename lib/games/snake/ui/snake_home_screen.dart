import 'package:flutter/material.dart';

import '../../../home/particle_background.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/setup_wizard.dart';
import '../models/snake_models.dart';
import 'snake_game_screen.dart';

const _statsService = GameStatsService('snake');
const _saveService = GameSaveService('snake');

class SnakeHomeScreen extends StatefulWidget {
  const SnakeHomeScreen({super.key});

  @override
  State<SnakeHomeScreen> createState() => _SnakeHomeScreenState();
}

class _SnakeHomeScreenState extends State<SnakeHomeScreen> {
  SnakeDifficulty _difficulty = SnakeDifficulty.medium;
  int _mapIndex = 0;

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

  List<WizardStep> _buildSteps() {
    return [
      WizardStep(
        title: "Quelle vitesse ?",
        hint: "Plus le niveau est élevé, plus le serpent va vite.",
        options: SnakeDifficulty.values
            .map(
              (d) => WizardOption(
                label: d.label,
                subtitle: "${d.tickInterval.inMilliseconds} ms par case",
                icon: Icons.speed_rounded,
                selected: _difficulty == d,
                onSelect: () => setState(() => _difficulty = d),
              ),
            )
            .toList(),
      ),
      WizardStep(
        title: "Choisis ta carte",
        options: List.generate(
          SnakeMaps.all.length,
          (i) => WizardOption(
            label: SnakeMaps.all[i].name,
            icon: Icons.map_rounded,
            selected: _mapIndex == i,
            onSelect: () => setState(() => _mapIndex = i),
          ),
        ),
      ),
    ];
  }

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetupWizard(
          gameTitle: "Snake",
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
          builder: (_) => SnakeGameScreen(
            difficulty: _difficulty,
            mapIndex: _mapIndex,
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
          builder: (_) => SnakeGameScreen(
            difficulty: SnakeDifficulty.values.firstWhere((d) => d.name == saved['difficulty']),
            mapIndex: saved['mapIndex'] as int? ?? 0,
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
        title: const Text("Snake"),
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
                              ElevatedButton.icon(
                                onPressed: _openSetup,
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

  Widget _statsCard() {
    return GlassCard(
      child: Row(
        children: [
          _statItem("Parties", "${_stats.gamesPlayed}", Colors.white70),
          _statItem("Meilleur score", "${_stats.bestScore}", kAccent),
          _statItem("Série", "${_stats.bestWinStreak}", Colors.amberAccent),
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
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
              textAlign: TextAlign.center),
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
