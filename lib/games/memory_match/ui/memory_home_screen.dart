import 'package:flutter/material.dart';

import '../../../home/particle_background.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/setup_wizard.dart';
import '../models/memory_models.dart';
import '../services/memory_records_service.dart';
import 'memory_game_screen.dart';

const _statsService = GameStatsService('memory');
const _saveService = GameSaveService('memory');
const _recordsService = MemoryRecordsService();

class MemoryHomeScreen extends StatefulWidget {
  const MemoryHomeScreen({super.key});

  @override
  State<MemoryHomeScreen> createState() => _MemoryHomeScreenState();
}

class _MemoryHomeScreenState extends State<MemoryHomeScreen> {
  MemoryTheme _theme = MemoryTheme.animals;
  MemoryDifficulty _difficulty = MemoryDifficulty.medium;

  GameStats _stats = const GameStats();
  int? _bestTime;
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
    final bestTime = await _recordsService.bestTimeFor(_difficulty.name);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _savedGame = saved;
      _bestTime = bestTime;
      _loading = false;
    });
  }

  Future<void> _onDifficultyChanged(MemoryDifficulty d) async {
    final bestTime = await _recordsService.bestTimeFor(d.name);
    if (!mounted) return;
    setState(() {
      _difficulty = d;
      _bestTime = bestTime;
    });
  }

  List<WizardStep> _buildSteps() {
    return [
      WizardStep(
        title: "Choisis un thème",
        grid: true,
        options: MemoryTheme.values
            .map(
              (t) => WizardOption(
                label: t.label,
                emoji: t.icon,
                selected: _theme == t,
                onSelect: () => setState(() => _theme = t),
              ),
            )
            .toList(),
      ),
      WizardStep(
        title: "Quelle difficulté ?",
        options: MemoryDifficulty.values
            .map(
              (d) => WizardOption(
                label: d.label,
                subtitle: "Grille ${d.columns}x${d.rows}",
                icon: Icons.grid_view_rounded,
                selected: _difficulty == d,
                onSelect: () => _onDifficultyChanged(d),
              ),
            )
            .toList(),
      ),
    ];
  }

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetupWizard(
          gameTitle: "Memory",
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
          builder: (_) => MemoryGameScreen(
            theme: _theme,
            difficulty: _difficulty,
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
          builder: (_) => MemoryGameScreen(
            theme: MemoryTheme.values.firstWhere((t) => t.name == saved['theme']),
            difficulty: MemoryDifficulty.values.firstWhere((d) => d.name == saved['difficulty']),
            resume: saved,
          ),
        ))
        .then((_) => _load());
  }

  String _formatTime(int? seconds) {
    if (seconds == null) return "--:--";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Memory"),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.emoji_events_rounded,
                                      size: 16, color: kAccent),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      "Record ${_difficulty.label} : ${_formatTime(_bestTime)}",
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: kMuted, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
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
          _statItem("Meilleure série", "${_stats.bestWinStreak}", Colors.amberAccent),
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
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54), textAlign: TextAlign.center),
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
