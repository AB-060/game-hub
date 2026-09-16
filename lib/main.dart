import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home/particle_background.dart';
import 'theme/app_colors.dart';
import 'games/tic_tac_toe/ui/tic_tac_toe_home_screen.dart';
import 'games/memory_match/ui/memory_home_screen.dart';
import 'games/snake/ui/snake_home_screen.dart';
import 'games/ludo/ui/ludo_home_screen.dart';
import 'games/chess/chess.dart';
import 'games/baloot/baloot_counter_screen.dart';

void main() {
  runApp(const GameHubApp());
}

class GameHubApp extends StatelessWidget {
  const GameHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.dark,
    );
    final baseTextTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return MaterialApp(
      title: "Game Hub",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: colorScheme,
        textTheme: baseTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: kBg,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: const Color(0xFF001018),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kMuted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      home: const HomeScreen(),
    );
  }
}

class GameEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  /// Miniature of the game itself, drawn inside the carousel card so each
  /// entry is recognisable by its board/shape rather than just an icon.
  final WidgetBuilder preview;

  const GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
    required this.preview,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final List<GameEntry> games = [
    GameEntry(
      title: "Échecs",
      subtitle: "2 joueurs",
      icon: Icons.castle_rounded,
      color: const Color(0xFF9FB4D9),
      builder: (_) => const ChessScreen(),
      preview: (_) => const _ChessPreview(),
    ),
    GameEntry(
      title: "Morpion",
      subtitle: "2 joueurs · vs IA",
      icon: Icons.close_rounded,
      color: const Color(0xFFFF5C5C),
      builder: (_) => const TicTacToeHomeScreen(),
      preview: (_) => const _TicTacToePreview(),
    ),
    GameEntry(
      title: "Memory",
      subtitle: "Solo",
      icon: Icons.psychology_alt_rounded,
      color: const Color(0xFFC084FC),
      builder: (_) => const MemoryHomeScreen(),
      preview: (_) => const _MemoryPreview(),
    ),
    GameEntry(
      title: "Snake",
      subtitle: "Solo",
      icon: Icons.timeline_rounded,
      color: const Color(0xFF4BE38A),
      builder: (_) => const SnakeHomeScreen(),
      preview: (_) => const _SnakePreview(),
    ),
    GameEntry(
      title: "Ludo",
      subtitle: "2 joueurs",
      icon: Icons.casino_rounded,
      color: kAccent,
      builder: (_) => const LudoHomeScreen(),
      preview: (_) => const _LudoPreview(),
    ),
    GameEntry(
      title: "Baloot",
      subtitle: "Compteur · 2 équipes",
      icon: Icons.calculate_rounded,
      color: const Color(0xFFFFB454),
      builder: (_) => const BalootCounterScreen(),
      preview: (_) => const _BalootPreview(),
    ),
  ];

  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.74);
    _controller.addListener(() {
      final page = _controller.page;
      if (page != null && page != _page) setState(() => _page = page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(GameEntry game) {
    Navigator.of(context).push(MaterialPageRoute(builder: game.builder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Game Hub",
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        "${_page.round() + 1}/${games.length}",
                        style: GoogleFonts.poppins(fontSize: 13, color: kMuted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      // 0 for the centred card, growing as it moves away.
                      final distance = (_page - index).abs().clamp(0.0, 1.0);
                      return _CarouselItem(
                        game: games[index],
                        distance: distance,
                        onTap: () => _open(games[index]),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(games.length, (i) {
                      final selected = _page.round() == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: selected ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: selected
                              ? games[i].color
                              : Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
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

/// One page of the switcher: the label sits above the card and travels with
/// it, and the card shrinks/fades as it moves off-centre so the neighbouring
/// games stay visible on both edges.
class _CarouselItem extends StatefulWidget {
  final GameEntry game;
  final double distance;
  final VoidCallback onTap;

  const _CarouselItem({
    required this.game,
    required this.distance,
    required this.onTap,
  });

  @override
  State<_CarouselItem> createState() => _CarouselItemState();
}

class _CarouselItemState extends State<_CarouselItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final distance = widget.distance;
    // The whole item - title label included - is the tap target, so tapping
    // the game's name works as naturally as tapping its card.
    final scale = (1 - distance * 0.12) * (_pressed ? 0.97 : 1);
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Column(
              children: [
                Opacity(
                  opacity: 1 - distance * 0.65,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          game.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: game.color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: game.color.withOpacity(0.45)),
                        ),
                        child: Icon(game.icon, color: game.color, size: 17),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: _GameCard(game: game)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameEntry game;
  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24),
              BoxShadow(color: game.color.withOpacity(0.14), blurRadius: 34),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: game.preview(context),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.07)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        game.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12.5, color: kMuted),
                      ),
                    ),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: game.color.withOpacity(0.9),
                      size: 26,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// ─────────────── Game miniatures ───────────────
/// Each preview is a cheap, purely decorative sketch of that game's board,
/// sized by its parent so it stays square-ish and never overflows.

class _Board extends StatelessWidget {
  final Widget child;
  const _Board({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      ),
    );
  }
}

class _ChessPreview extends StatelessWidget {
  const _ChessPreview();

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFCBD5E6);
    const dark = Color(0xFF54627D);
    return _Board(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6),
        itemCount: 36,
        itemBuilder: (context, i) {
          final row = i ~/ 6;
          final col = i % 6;
          final isLight = (row + col).isEven;
          return Container(
            color: isLight ? light : dark,
            alignment: Alignment.center,
            child: (i == 8 || i == 15)
                ? const Icon(Icons.castle_rounded, size: 13, color: Color(0xFF1B2331))
                : (i == 21 || i == 28)
                    ? const Icon(Icons.castle_rounded, size: 13, color: Colors.white)
                    : null,
          );
        },
      ),
    );
  }
}

class _TicTacToePreview extends StatelessWidget {
  const _TicTacToePreview();

  @override
  Widget build(BuildContext context) {
    const marks = ["X", "O", "X", "", "O", "", "X", "", "O"];
    return _Board(
      child: Container(
        color: Colors.white.withOpacity(0.05),
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: 9,
          itemBuilder: (context, i) {
            final mark = marks[i];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                mark,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: mark == "X"
                      ? const Color(0xFFFF5C5C)
                      : const Color(0xFF6FD3FF),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MemoryPreview extends StatelessWidget {
  const _MemoryPreview();

  @override
  Widget build(BuildContext context) {
    const faces = [null, "🍕", null, null, "🍕", null, null, null, "🐙", null, null, "🐙"];
    return _Board(
      child: Container(
        color: Colors.white.withOpacity(0.05),
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.82,
          ),
          itemCount: faces.length,
          itemBuilder: (context, i) {
            final face = faces[i];
            return Container(
              decoration: BoxDecoration(
                color: face == null
                    ? const Color(0xFFC084FC).withOpacity(0.22)
                    : Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: const Color(0xFFC084FC).withOpacity(face == null ? 0.35 : 0.15),
                ),
              ),
              alignment: Alignment.center,
              child: face == null
                  ? const Icon(Icons.question_mark_rounded,
                      size: 12, color: Color(0xFFC084FC))
                  : Text(face, style: const TextStyle(fontSize: 13)),
            );
          },
        ),
      ),
    );
  }
}

class _SnakePreview extends StatelessWidget {
  const _SnakePreview();

  @override
  Widget build(BuildContext context) {
    // Indices forming a short snake body on an 8x8 grid, plus the food cell.
    const body = [18, 19, 20, 28, 36, 44, 45];
    const head = 17;
    const food = 51;
    return _Board(
      child: Container(
        color: const Color(0xFF0E1A14),
        padding: const EdgeInsets.all(6),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: 64,
          itemBuilder: (context, i) {
            Color color = Colors.white.withOpacity(0.03);
            if (i == head) {
              color = const Color(0xFF8CFFB4);
            } else if (body.contains(i)) {
              color = const Color(0xFF4BE38A);
            } else if (i == food) {
              color = const Color(0xFFFF7A7A);
            }
            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(i == food ? 8 : 3),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LudoPreview extends StatelessWidget {
  const _LudoPreview();

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF5C5C);
    const green = Color(0xFF4BE38A);
    const blue = Color(0xFF6FD3FF);
    const yellow = Color(0xFFFFD166);

    Widget corner(Color c) => Container(
          decoration: BoxDecoration(
            color: c.withOpacity(0.22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withOpacity(0.55)),
          ),
          margin: const EdgeInsets.all(3),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          ),
        );

    return _Board(
      child: Container(
        color: Colors.white.withOpacity(0.05),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(
              child: Row(children: [
                Expanded(child: corner(red)),
                Expanded(child: corner(green)),
              ]),
            ),
            SizedBox(
              height: 22,
              child: Center(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.casino_rounded,
                      size: 15, color: Colors.white),
                ),
              ),
            ),
            Expanded(
              child: Row(children: [
                Expanded(child: corner(yellow)),
                Expanded(child: corner(blue)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniature du Baloot : les deux totaux face à face au-dessus de
/// l'historique des manches, pour qu'on reconnaisse un compteur de صكة
/// plutôt qu'un plateau de jeu.
class _BalootPreview extends StatelessWidget {
  const _BalootPreview();

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFB454);

    Widget bigNumber(String text, Color color) => Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1,
          ),
        );

    // Quelques manches déjà jouées, comme dans l'historique du compteur.
    const rounds = <List<String>>[
      ["15", "1"],
      ["22", "8"],
      ["10", "20"],
    ];

    return _Board(
      child: Container(
        color: Colors.white.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                bigNumber("93", amber),
                const Icon(Icons.arrow_back_rounded, size: 14, color: Colors.white38),
                bigNumber("61", Colors.white70),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 8),
            for (final r in rounds)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r[0],
                        style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    Text(r[1],
                        style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
