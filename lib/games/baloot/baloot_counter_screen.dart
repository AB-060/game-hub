import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../home/particle_background.dart';
import '../../services/game_save_service.dart';
import '../../services/game_stats_service.dart';
import '../../theme/app_colors.dart';
import 'baloot_draw_screen.dart';
import 'baloot_stats_screen.dart';
import 'models/baloot_models.dart';

const _saveService = GameSaveService('baloot');
const _statsService = GameStatsService('baloot');

/// Compteur de صكة : on saisit le score des deux camps à chaque manche, le
/// compteur additionne et annonce le vainqueur dès que la cible est
/// atteinte.
class BalootCounterScreen extends StatefulWidget {
  const BalootCounterScreen({super.key});

  @override
  State<BalootCounterScreen> createState() => _BalootCounterScreenState();
}

class _BalootCounterScreenState extends State<BalootCounterScreen> {
  BalootGame _game = const BalootGame();
  final _usController = TextEditingController();
  final _themController = TextEditingController();
  bool _loading = true;

  /// Empêche d'annoncer deux fois la même صكة si l'écran est reconstruit.
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usController.dispose();
    _themController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await _saveService.loadState();
    if (!mounted) return;
    setState(() {
      if (saved != null) _game = BalootGame.fromJson(saved);
      _resultShown = _game.isOver;
      _loading = false;
    });
  }

  Future<void> _save() => _saveService.saveState(_game.toJson());

  /// Valide la manche saisie. Une case vide vaut 0, ce qui est fréquent
  /// quand un camp ne marque rien.
  void _submitRound() {
    final us = int.tryParse(_usController.text.trim()) ?? 0;
    final them = int.tryParse(_themController.text.trim()) ?? 0;
    if (us == 0 && them == 0) return;

    setState(() {
      _game = _game.addRound(BalootRound(us: us, them: them));
      _usController.clear();
      _themController.clear();
    });
    FocusScope.of(context).unfocus();
    _save();

    final winner = _game.winner;
    if (winner != null && !_resultShown) {
      _resultShown = true;
      _recordAndAnnounce(winner);
    }
  }

  Future<void> _recordAndAnnounce(BalootSide winner) async {
    await _statsService.recordGameEnd(
      won: winner == BalootSide.us,
      lost: winner == BalootSide.them,
      score: _game.total(winner),
    );
    if (!mounted) return;

    final weWon = winner == BalootSide.us;
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(
          weWon ? "Bravo, صكة gagnée ! 🎉" : "Ce sera pour la prochaine",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          "${_game.usTotal} — ${_game.themTotal}\n\nCommencer une nouvelle صكة ?",
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Non"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Oui"),
          ),
        ],
      ),
    );
    if (again == true) _newGame(confirm: false);
  }

  void _undo() {
    if (_game.isEmpty) return;
    setState(() {
      _game = _game.undo();
      _resultShown = _game.isOver;
    });
    _save();
  }

  Future<void> _newGame({bool confirm = true}) async {
    if (confirm && !_game.isEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: kSurface,
          title: const Text("Nouvelle صكة ?"),
          content: const Text("Les scores en cours seront effacés."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Effacer"),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _game = _game.reset();
      _resultShown = false;
      _usController.clear();
      _themController.clear();
    });
    _save();
  }

  Future<void> _pickTarget() async {
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text("Cible de la صكة"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in kBalootTargets)
              ListTile(
                title: Text("$t points"),
                trailing: _game.target == t
                    ? const Icon(Icons.check_rounded, color: kAccent)
                    : null,
                onTap: () => Navigator.of(context).pop(t),
              ),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    setState(() {
      _game = _game.withTarget(target);
      _resultShown = _game.isOver;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Baloot"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Cible : ${_game.target}",
            onPressed: _pickTarget,
            icon: const Icon(Icons.flag_rounded),
          ),
          IconButton(
            tooltip: "Statistiques",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BalootStatsScreen()),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Column(
                    children: [
                      _scores(),
                      const SizedBox(height: 18),
                      _entry(),
                      const SizedBox(height: 14),
                      _actions(),
                      const SizedBox(height: 14),
                      Expanded(child: _history()),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  /// Les deux totaux, avec une flèche qui désigne le camp en tête.
  Widget _scores() {
    final leader = _game.leader;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(child: _sideScore(BalootSide.us, leader == BalootSide.us)),
          SizedBox(
            width: 44,
            child: leader == null
                ? const Icon(Icons.remove_rounded, color: Colors.white24)
                : Icon(
                    leader == BalootSide.us
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    color: kAccent,
                    size: 28,
                  ),
          ),
          Expanded(child: _sideScore(BalootSide.them, leader == BalootSide.them)),
        ],
      ),
    );
  }

  Widget _sideScore(BalootSide side, bool leading) {
    final total = _game.total(side);
    return Column(
      children: [
        Text(
          side.label,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: leading ? kAccent : Colors.white70,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "$total",
          style: GoogleFonts.poppins(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        Text(
          "/ ${_game.target}",
          style: const TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  /// Saisie de la manche : un champ par camp, encadrant le bouton de calcul.
  Widget _entry() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _scoreField(_usController, "Nous")),
          const SizedBox(width: 14),
          _calculateButton(),
          const SizedBox(width: 14),
          Expanded(child: _scoreField(_themController, "Eux")),
        ],
      ),
    );
  }

  Widget _scoreField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      onSubmitted: (_) => _submitRound(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: kAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _calculateButton() {
    return InkWell(
      onTap: _submitRound,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
        child: Text(
          "Calculer",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: kBg,
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    // "Nouvelle صكة" est le plus long des trois libellés : chaque action est
    // Expanded pour que la rangée se comprime proprement sur les petits
    // écrans plutôt que de déborder.
    return Row(
      children: [
        Expanded(
          child: _action(
            icon: Icons.undo_rounded,
            label: "Annuler",
            color: _game.isEmpty ? Colors.white24 : Colors.redAccent,
            onTap: _game.isEmpty ? null : _undo,
          ),
        ),
        Expanded(
          child: _action(
            icon: Icons.casino_rounded,
            label: "Tirage",
            color: Colors.white70,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BalootDrawScreen()),
            ),
          ),
        ),
        Expanded(
          child: _action(
            icon: Icons.refresh_rounded,
            label: "Nouvelle صكة",
            color: Colors.greenAccent,
            onTap: _newGame,
          ),
        ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }

  /// L'historique des manches, la plus récente en haut.
  Widget _history() {
    if (_game.isEmpty) {
      return const Center(
        child: Text(
          "Saisis le score de la première manche",
          style: TextStyle(color: Colors.white24, fontSize: 13),
        ),
      );
    }

    final rounds = _game.rounds.reversed.toList();
    return Column(
      children: [
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: rounds.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, i) {
              final round = rounds[i];
              // Numéro réel de la manche, l'affichage étant inversé.
              final number = rounds.length - i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: _historyValue(round.us)),
                    SizedBox(
                      width: 44,
                      child: Text(
                        "$number",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: Colors.white24),
                      ),
                    ),
                    Expanded(child: _historyValue(round.them)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _historyValue(int value) {
    return Text(
      "$value",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: value == 0 ? Colors.white24 : Colors.white,
      ),
    );
  }
}
