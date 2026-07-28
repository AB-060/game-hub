import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/particle_background.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
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

  void _startNewGame() {
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
                              Text(
                                "Nouvelle partie",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel("Thème"),
                              const SizedBox(height: 8),
                              _themePicker(),
                              const SizedBox(height: 20),
                              _sectionLabel("Difficulté"),
                              const SizedBox(height: 8),
                              _difficultyPicker(),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.emoji_events_rounded,
                                      size: 16, color: kAccent),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Record : ${_formatTime(_bestTime)}",
                                    style: const TextStyle(color: kMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
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

  Widget _themePicker() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: MemoryTheme.values.map((t) {
        final selected = _theme == t;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _theme = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected ? kAccent.withOpacity(0.16) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? kAccent : Colors.white12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _difficultyPicker() {
    return Row(
      children: MemoryDifficulty.values.map((d) {
        final selected = _difficulty == d;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: d == MemoryDifficulty.values.last ? 0 : 8),
            child: SelectableChip(
              selected: selected,
              label: d.label,
              onTap: () => _onDifficultyChanged(d),
            ),
          ),
        );
      }).toList(),
    );
  }
}
