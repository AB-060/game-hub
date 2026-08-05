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
import 'games/football/football_game_screen.dart';

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

  const GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Échecs et Football en premier, comme demandé.
  static final List<GameEntry> games = [
    GameEntry(
      title: "Échecs",
      subtitle: "2 joueurs",
      icon: Icons.castle_rounded,
      color: const Color(0xFF9FB4D9),
      builder: (_) => const ChessScreen(),
    ),
    GameEntry(
      title: "Football",
      subtitle: "Nations · Tournois",
      icon: Icons.sports_soccer_rounded,
      color: const Color(0xFF8CE05B),
      builder: (_) => const FootballGameScreen(),
    ),
    GameEntry(
      title: "Morpion",
      subtitle: "2 joueurs · vs IA",
      icon: Icons.close_rounded,
      color: const Color(0xFFFF5C5C),
      builder: (_) => const TicTacToeHomeScreen(),
    ),
    GameEntry(
      title: "Memory",
      subtitle: "Solo",
      icon: Icons.psychology_alt_rounded,
      color: const Color(0xFFC084FC),
      builder: (_) => const MemoryHomeScreen(),
    ),
    GameEntry(
      title: "Snake",
      subtitle: "Solo",
      icon: Icons.timeline_rounded,
      color: const Color(0xFF4BE38A),
      builder: (_) => const SnakeHomeScreen(),
    ),
    GameEntry(
      title: "Ludo",
      subtitle: "2 joueurs",
      icon: Icons.casino_rounded,
      color: kAccent,
      builder: (_) => const LudoHomeScreen(),
    ),
  ];

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width < 560 ? 2 : (width < 900 ? 3 : 4);
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Game Hub",
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Choisis ton jeu et lance la partie.",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: kMuted,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final start = (index / games.length) * 0.6;
                        final animation = CurvedAnimation(
                          parent: _entrance,
                          curve: Interval(
                            start,
                            (start + 0.4).clamp(0, 1),
                            curve: Curves.easeOutCubic,
                          ),
                        );
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: animation.value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - animation.value) * 24),
                                child: child,
                              ),
                            );
                          },
                          child: _GameCard(game: games[index]),
                        );
                      },
                      childCount: games.length,
                    ),
                  ),
                ),
              ],
            );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  final GameEntry game;
  const _GameCard({required this.game});

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: game.builder));
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                  ),
                  BoxShadow(
                    color: game.color.withOpacity(0.16),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: game.color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(game.icon, color: game.color, size: 26),
                      ),
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: game.color.withOpacity(0.85),
                        size: 22,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    game.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.subtitle,
                    style: GoogleFonts.poppins(fontSize: 12, color: kMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
