import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../home/particle_background.dart';
import '../../services/game_save_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/glass_card.dart';

const _saveService = GameSaveService('baloot_players');

/// « دق الولد » : on saisit les joueurs présents et le tirage forme les deux
/// équipes au hasard.
class BalootDrawScreen extends StatefulWidget {
  const BalootDrawScreen({super.key});

  @override
  State<BalootDrawScreen> createState() => _BalootDrawScreenState();
}

class _BalootDrawScreenState extends State<BalootDrawScreen> {
  final _controller = TextEditingController();
  List<String> _players = [];
  List<List<String>>? _teams;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await _saveService.loadState();
    if (!mounted) return;
    setState(() {
      final list = saved?['players'] as List?;
      if (list != null) _players = list.cast<String>();
      _loading = false;
    });
  }

  Future<void> _save() =>
      _saveService.saveState({'players': _players});

  void _addPlayer() {
    final name = _controller.text.trim();
    // Les doublons rendraient les équipes ambiguës à la lecture.
    if (name.isEmpty || _players.contains(name)) return;
    setState(() {
      _players = [..._players, name];
      _controller.clear();
      _teams = null;
    });
    _save();
  }

  void _removePlayer(String name) {
    setState(() {
      _players = _players.where((p) => p != name).toList();
      _teams = null;
    });
    _save();
  }

  void _draw() {
    if (_players.length < 4) return;
    final shuffled = [..._players]..shuffle(Random());
    // On garde quatre joueurs : le Baloot se joue deux contre deux.
    final chosen = shuffled.take(4).toList();
    setState(() {
      _teams = [chosen.sublist(0, 2), chosen.sublist(2, 4)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Tirage des équipes"),
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _addRow(),
                        const SizedBox(height: 20),
                        if (_players.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              "Ajoute au moins 4 joueurs",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white24, fontSize: 13),
                            ),
                          )
                        else
                          for (final player in _players) _playerTile(player),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _players.length < 4 ? null : _draw,
                          icon: const Icon(Icons.shuffle_rounded),
                          label: Text(
                            _players.length < 4
                                ? "Encore ${4 - _players.length} joueur${4 - _players.length > 1 ? 's' : ''}"
                                : "Tirer les équipes",
                          ),
                        ),
                        if (_teams != null) ...[
                          const SizedBox(height: 24),
                          _teamCard("Nous", _teams![0], kAccent),
                          const SizedBox(height: 12),
                          _teamCard("Eux", _teams![1], Colors.orangeAccent),
                        ],
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _addRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            maxLength: 16,
            onSubmitted: (_) => _addPlayer(),
            decoration: InputDecoration(
              hintText: "Nom du joueur",
              counterText: "",
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _addPlayer,
          child: const Text("Ajouter"),
        ),
      ],
    );
  }

  Widget _playerTile(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            InkWell(
              onTap: () => _removePlayer(name),
              child: const Icon(Icons.close_rounded, size: 18, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamCard(String title, List<String> members, Color color) {
    return GlassCard(
      borderColor: color.withOpacity(0.5),
      child: Row(
        children: [
          Icon(Icons.group_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: color)),
                const SizedBox(height: 2),
                Text(
                  members.join("  ·  "),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
