import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../home/particle_background.dart';
import '../../../services/game_save_service.dart';
import '../../../services/game_stats_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_card.dart';
import '../models/ludo_board.dart';
import 'ludo_game_screen.dart';

const _statsService = GameStatsService('ludo');
const _saveService = GameSaveService('ludo');

class LudoHomeScreen extends StatefulWidget {
  const LudoHomeScreen({super.key});

  @override
  State<LudoHomeScreen> createState() => _LudoHomeScreenState();
}

class _LudoHomeScreenState extends State<LudoHomeScreen> {
  int _playerCount = 4;
  late Map<PawnColor, SeatType> _seats;
  LudoDifficulty _difficulty = LudoDifficulty.medium;

  GameStats _stats = const GameStats();
  Map<String, dynamic>? _savedGame;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resetSeats();
    _load();
  }

  void _resetSeats() {
    final colors = LudoBoard.playOrder.take(_playerCount).toList();
    _seats = {
      for (int i = 0; i < colors.length; i++) colors[i]: i == 0 ? SeatType.human : SeatType.ai,
    };
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
          builder: (_) => LudoGameScreen(
            activeColors: LudoBoard.playOrder.take(_playerCount).toList(),
            seats: Map.of(_seats),
            difficulty: _difficulty,
            resume: null,
          ),
        ))
        .then((_) => _load());
  }

  void _resumeGame() {
    final saved = _savedGame;
    if (saved == null) return;
    final colors = (saved['activeColors'] as List<dynamic>)
        .map((n) => PawnColor.values.firstWhere((c) => c.name == n))
        .toList();
    final seats = (saved['seats'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(
        PawnColor.values.firstWhere((c) => c.name == k),
        v == 'human' ? SeatType.human : SeatType.ai,
      ),
    );
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => LudoGameScreen(
            activeColors: colors,
            seats: seats,
            difficulty: LudoDifficulty.values.firstWhere((d) => d.name == saved['difficulty']),
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
        title: const Text("Ludo"),
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
                              _sectionLabel("Nombre de joueurs"),
                              const SizedBox(height: 8),
                              _playerCountPicker(),
                              const SizedBox(height: 20),
                              _sectionLabel("Sièges"),
                              const SizedBox(height: 8),
                              _seatsPicker(),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => setState(() {
                                    for (final c in _seats.keys) {
                                      _seats[c] = SeatType.ai;
                                    }
                                  }),
                                  icon: const Icon(Icons.smart_toy_rounded, size: 16),
                                  label: const Text("Tout en IA (spectateur)"),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel("Difficulté de l'IA"),
                              const SizedBox(height: 8),
                              _difficultyPicker(),
                              const SizedBox(height: 28),
                              ElevatedButton.icon(
                                onPressed: _startNewGame,
                                icon: const Icon(Icons.casino_rounded),
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
          _statItem("Victoires", "${_stats.wins}", Colors.greenAccent),
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

  Widget _playerCountPicker() {
    return Row(
      children: [2, 3, 4].map((n) {
        final selected = _playerCount == n;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: n == 4 ? 0 : 8),
            child: SelectableChip(
              selected: selected,
              label: "$n joueurs",
              onTap: () => setState(() {
                _playerCount = n;
                _resetSeats();
              }),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _seatsPicker() {
    return Column(
      children: _seats.keys.map((color) {
        final seat = _seats[color]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: color.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(color.label, style: const TextStyle(fontWeight: FontWeight.w600))),
              ToggleButtons(
                borderRadius: BorderRadius.circular(10),
                isSelected: [seat == SeatType.human, seat == SeatType.ai],
                onPressed: (i) => setState(() {
                  _seats[color] = i == 0 ? SeatType.human : SeatType.ai;
                }),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Humain")),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("IA")),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _difficultyPicker() {
    return Row(
      children: LudoDifficulty.values.map((d) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: d == LudoDifficulty.values.last ? 0 : 8),
            child: SelectableChip(
              selected: _difficulty == d,
              label: d.label,
              onTap: () => setState(() => _difficulty = d),
            ),
          ),
        );
      }).toList(),
    );
  }
}
