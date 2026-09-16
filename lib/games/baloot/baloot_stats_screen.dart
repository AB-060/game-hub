import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../home/particle_background.dart';
import '../../services/game_stats_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import 'models/baloot_models.dart';

const _statsService = GameStatsService('baloot');

/// Bilan des صكات jouées : victoires, défaites et niveau général.
class BalootStatsScreen extends StatefulWidget {
  const BalootStatsScreen({super.key});

  @override
  State<BalootStatsScreen> createState() => _BalootStatsScreenState();
}

class _BalootStatsScreenState extends State<BalootStatsScreen> {
  GameStats _stats = const GameStats();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await _statsService.load();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = BalootLevel.from(wins: _stats.wins, losses: _stats.losses);
    // Barres proportionnelles au total, pour comparer d'un coup d'œil.
    final maxValue = [_stats.wins, _stats.losses, _stats.gamesPlayed]
        .fold(1, (m, v) => v > m ? v : m);

    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Statistiques"),
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.style_rounded, size: 48, color: kAccent),
                        const SizedBox(height: 20),
                        _bar("Victoires", _stats.wins, maxValue, Colors.greenAccent),
                        const SizedBox(height: 18),
                        _bar("Défaites", _stats.losses, maxValue, Colors.redAccent),
                        const SizedBox(height: 18),
                        _bar("صكات jouées", _stats.gamesPlayed, maxValue, Colors.white54),
                        const SizedBox(height: 28),
                        _levelCard(level),
                        if (_stats.bestWinStreak > 0) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              "Meilleure série : ${_stats.bestWinStreak} victoire${_stats.bestWinStreak > 1 ? 's' : ''} d'affilée",
                              style: const TextStyle(fontSize: 12, color: kMuted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _bar(String label, int value, int max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                "$value",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kBg,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: max == 0 ? 0 : value / max,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.07),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _levelCard(BalootLevel level) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kAccent, width: 2),
            ),
            child: Text(
              "${level.value}",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Niveau général",
                  style: TextStyle(fontSize: 12, color: kMuted)),
              const SizedBox(height: 2),
              Text(
                level.label,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
