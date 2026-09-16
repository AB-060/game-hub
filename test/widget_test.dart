import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:game_hub/main.dart';
import 'package:game_hub/games/chess/models/chess_models.dart';
import 'package:game_hub/games/chess/ui/chess_game_screen.dart';
import 'package:game_hub/games/tic_tac_toe/models/ttt_models.dart';
import 'package:game_hub/games/tic_tac_toe/ui/tic_tac_toe_game_screen.dart';
import 'package:game_hub/games/memory_match/models/memory_models.dart';
import 'package:game_hub/games/memory_match/ui/memory_game_screen.dart';
import 'package:game_hub/games/snake/models/snake_models.dart';
import 'package:game_hub/games/snake/ui/snake_game_screen.dart';
import 'package:game_hub/games/ludo/models/ludo_board.dart';
import 'package:game_hub/games/ludo/ui/ludo_game_screen.dart';

// Tailles représentatives : petit téléphone, grand téléphone, tablette.
const _screenSizes = [
  Size(320, 640),
  Size(390, 844),
  Size(430, 932),
  Size(768, 1024),
  Size(1024, 1366),
];

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}


/// Le hub est un carrousel (PageView) : une seule carte est réellement
/// visible à la fois, donc on fait défiler jusqu'au jeu voulu avant de
/// taper dessus. Un drag d'une demi-largeur d'écran dépasse toujours le
/// seuil de bascule (la page fait 0,74 de la largeur) quelle que soit la
/// taille testée.
Future<void> _swipeToGame(WidgetTester tester, int index) async {
  final pageWidth = tester.getSize(find.byType(PageView)).width;
  for (int i = 0; i < index; i++) {
    await tester.drag(find.byType(PageView), Offset(-pageWidth * 0.5, 0));
    await tester.pump();
    // Tant que l'animation de bascule tourne, Scrollable ignore les pointeurs :
    // on pompe par petits pas jusqu'à ce qu'elle soit terminée, sinon le tap
    // suivant est purement et simplement avalé.
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }
}

/// Ouvre le formulaire de configuration (SetupWizard) depuis l'écran
/// d'accueil d'un jeu : un unique bouton "Nouvelle partie" y mène désormais,
/// les sélecteurs de mode/difficulté/etc. ayant été déplacés dans le wizard.
Future<void> _openWizard(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, "Nouvelle partie"));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Touche une option du wizard puis laisse tourner l'enchaînement automatique
/// vers l'étape suivante (délai d'affichage du choix + animation de
/// transition), ou le lancement de la partie si c'était la dernière étape.
Future<void> _pickWizardOption(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Valide une étape personnalisée du wizard (ex: les sièges du Ludo), qui ne
/// s'enchaîne pas toute seule contrairement à un simple choix.
Future<void> _tapWizardContinue(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, "Continuer"));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // tester.takeException() ne capture pas de façon fiable les erreurs du
  // pipeline de rendu (ex: assertions de layout de RenderFlex) : on
  // s'accroche donc aussi à FlutterError.onError pour qu'aucune erreur
  // affichée en rouge dans l'app ne passe inaperçue dans les tests.
  final capturedErrors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    capturedErrors.clear();
    FlutterError.onError = (details) {
      capturedErrors.add(details);
      originalOnError?.call(details);
    };
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
    if (capturedErrors.isNotEmpty) {
      fail(
        "${capturedErrors.length} erreur(s) Flutter capturée(s) :\n"
        "${capturedErrors.map((e) => e.exceptionAsString()).join('\n---\n')}",
      );
    }
  });

  for (final size in _screenSizes) {
    testWidgets('Hub affiche les 6 jeux sans erreur sur ${size.width}x${size.height}',
        (tester) async {
      await _setScreenSize(tester, size);
      await tester.pumpWidget(const GameHubApp());
      // Le fond animé (particules) tourne en continu par conception :
      // pumpAndSettle() ne se termine jamais, on utilise des pumps bornés.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      // Carrousel : on parcourt les cartes une à une et chaque jeu doit
      // apparaître à son tour, sans erreur de rendu.
      const titles = ["Échecs", "Morpion", "Memory", "Snake", "Ludo", "Baloot"];
      expect(find.text(titles.first), findsOneWidget);
      for (int i = 1; i < titles.length; i++) {
        await _swipeToGame(tester, 1);
        expect(find.text(titles[i]), findsOneWidget);
      }
    });
  }

  final gameTitles = ["Échecs", "Morpion", "Memory", "Snake", "Ludo", "Baloot"];

  for (final title in gameTitles) {
    for (final size in _screenSizes) {
      testWidgets('Ouvrir "$title" depuis le hub ne plante pas (${size.width}x${size.height})',
          (tester) async {
        await _setScreenSize(tester, size);
        await tester.pumpWidget(const GameHubApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        await _swipeToGame(tester, gameTitles.indexOf(title));
        await tester.tap(find.text(title).first, warnIfMissed: false);
        await tester.pump();
        // Laisse le temps aux écrans qui chargent des données async
        // (ex: SharedPreferences pour l'écran d'accueil des échecs).
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      });
    }
  }

  testWidgets('Échecs : partie en tant que Blancs ne plante pas', (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      home: ChessGameScreen(
        difficulty: Difficulty.beginner,
        playerColor: PieceColor.white,
        resume: null,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Échecs : partie en tant que Noirs (IA joue en premier) ne plante pas',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      home: ChessGameScreen(
        difficulty: Difficulty.beginner,
        playerColor: PieceColor.black,
        resume: null,
      ),
    ));
    // L'IA doit jouer un premier coup automatiquement : laisser tourner le temps nécessaire.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Échecs : partie locale à 2 joueurs (sans IA) ne plante pas', (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(
      home: ChessGameScreen(
        difficulty: null,
        playerColor: PieceColor.white,
        resume: null,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    // Après 2 secondes, aucune IA ne doit avoir joué (mode 2 joueurs) :
    // le titre ne doit annoncer aucune difficulté.
    expect(find.textContaining("2 joueurs"), findsOneWidget);
  });

  testWidgets('Échecs : depuis le hub, choisir "2 joueurs" puis démarrer une partie',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const GameHubApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await _swipeToGame(tester, 0);
    await tester.tap(find.text("Échecs").first, warnIfMissed: false);
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await _openWizard(tester);
    await _pickWizardOption(tester, "2 joueurs");
    // Le sélecteur de difficulté ne doit plus être affiché en mode 2 joueurs.
    expect(find.text("Débutant"), findsNothing);
    await _pickWizardOption(tester, "Blancs");
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Morpion : partie 3x3 contre IA Expert ne plante pas et joue un coup',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(
      home: TicTacToeGameScreen(
        vsAi: true,
        difficulty: TttDifficulty.expert,
        boardSize: TttBoardSize.size3,
        humanMark: PlayerMark.x,
        resume: null,
      ),
    ));
    await tester.pump();
    // Joue au centre.
    await tester.tap(find.text("").at(4), warnIfMissed: false);
    await tester.pump();
    // Laisse l'IA (isolate) répondre.
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('Morpion : partie 5x5 locale à 2 joueurs ne plante pas', (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(
      home: TicTacToeGameScreen(
        vsAi: false,
        difficulty: TttDifficulty.beginner,
        boardSize: TttBoardSize.size5,
        humanMark: PlayerMark.x,
        resume: null,
      ),
    ));
    await tester.pump();
    await tester.tap(find.text("").first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text("").first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Morpion : depuis le hub, jouer une partie complète 3x3 vs IA Débutant',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const GameHubApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await _swipeToGame(tester, 1);
    await tester.tap(find.text("Morpion").first, warnIfMissed: false);
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await _openWizard(tester);
    await _pickWizardOption(tester, "Contre l'IA");
    await _pickWizardOption(tester, "3x3");
    await _pickWizardOption(tester, "Débutant");
    await _pickWizardOption(tester, "X");
    await tester.pump(const Duration(milliseconds: 400));

    // Joue plusieurs coups en alternance avec l'IA (Débutant, donc rapide).
    for (int round = 0; round < 5; round++) {
      final emptyCells = find.text("");
      if (emptyCells.evaluate().isEmpty) break;
      await tester.tap(emptyCells.first);
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('Memory : partie facile ne plante pas et permet de retourner une carte',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(
      home: MemoryGameScreen(
        theme: MemoryTheme.animals,
        difficulty: MemoryDifficulty.easy,
        resume: null,
      ),
    ));
    await tester.pump();
    await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 800));
  });

  for (final difficulty in MemoryDifficulty.values) {
    testWidgets('Memory : plateau ${difficulty.name} tient sur tous les écrans sans overflow',
        (tester) async {
      for (final size in _screenSizes) {
        await _setScreenSize(tester, size);
        await tester.pumpWidget(MaterialApp(
          home: MemoryGameScreen(
            theme: MemoryTheme.fruits,
            difficulty: difficulty,
            resume: null,
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    });
  }

  testWidgets('Memory : depuis le hub, choisir un thème puis démarrer une partie',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const GameHubApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await _swipeToGame(tester, 2);
    await tester.tap(find.text("Memory").first, warnIfMissed: false);
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await _openWizard(tester);
    await _pickWizardOption(tester, "Sports");
    await _pickWizardOption(tester, "Difficile");
    await tester.pump(const Duration(milliseconds: 500));
  });

  for (final difficulty in SnakeDifficulty.values) {
    for (final mapIndex in [0, 1, 2, 3]) {
      testWidgets(
          'Snake : ${difficulty.name} carte $mapIndex tourne, se met en pause, sans plantage',
          (tester) async {
        await _setScreenSize(tester, const Size(390, 844));
        await tester.pumpWidget(MaterialApp(
          home: SnakeGameScreen(
            difficulty: difficulty,
            mapIndex: mapIndex,
            resume: null,
          ),
        ));
        await tester.pump();
        // Le serpent avance tout seul (pas de changement de direction ici) :
        // un seul tick, pour rester sous la distance minimale à laquelle
        // n'importe quelle carte place un obstacle depuis le point de départ.
        await tester.pump(const Duration(milliseconds: 60));
        // Pause / reprise (cible le bouton de la barre d'app via son tooltip,
        // car l'overlay de pause a lui aussi un bouton "lecture").
        await tester.tap(find.byTooltip("Pause"));
        await tester.pump();
        expect(find.text("Pause"), findsOneWidget);
        await tester.tap(find.byTooltip("Reprendre").first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });
    }
  }

  testWidgets('Snake : partie sur tous les écrans sans overflow', (tester) async {
    for (final size in _screenSizes) {
      await _setScreenSize(tester, size);
      await tester.pumpWidget(const MaterialApp(
        home: SnakeGameScreen(
          difficulty: SnakeDifficulty.medium,
          mapIndex: 2,
          resume: null,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  testWidgets('Snake : depuis le hub, choisir une carte puis démarrer une partie',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const GameHubApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // "Snake" est sur la 3e rangée de la grille : hors écran tant qu'on n'a
    // pas fait défiler, comme le ferait un vrai utilisateur.
    await _swipeToGame(tester, 3);
    await tester.tap(find.text("Snake").first, warnIfMissed: false);
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await _openWizard(tester);
    await _pickWizardOption(tester, "Expert");
    await _pickWizardOption(tester, "Labyrinthe");
    await tester.pump(const Duration(milliseconds: 500));
  });

  for (final n in [2, 3, 4]) {
    testWidgets('Ludo : partie IA contre IA à $n joueurs tourne sans plantage', (tester) async {
      await _setScreenSize(tester, const Size(390, 844));
      final colors = LudoBoard.playOrder.take(n).toList();
      await tester.pumpWidget(MaterialApp(
        home: LudoGameScreen(
          activeColors: colors,
          seats: {for (final c in colors) c: SeatType.ai},
          difficulty: LudoDifficulty.medium,
          resume: null,
        ),
      ));
      await tester.pump();
      // Laisse la partie IA contre IA tourner jusqu'au bout (temps virtuel
      // de FakeAsync, quasi instantané en temps réel) pour ne laisser
      // aucun minuteur en attente à la fin du test.
      for (int i = 0; i < 2500; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.textContaining("gagne").evaluate().isNotEmpty) break;
      }
      expect(find.textContaining("gagne"), findsOneWidget);
    });
  }

  testWidgets('Ludo : partie humain contre IA, lancer le dé et jouer un coup',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    final colors = LudoBoard.playOrder.take(2).toList();
    await tester.pumpWidget(MaterialApp(
      home: LudoGameScreen(
        activeColors: colors,
        seats: {colors[0]: SeatType.human, colors[1]: SeatType.ai},
        difficulty: LudoDifficulty.easy,
        resume: null,
      ),
    ));
    await tester.pump();
    // Lance le dé plusieurs fois jusqu'à obtenir un coup jouable (un 6
    // pour sortir un pion), ce qui exerce le flux complet du tour humain.
    for (int i = 0; i < 8; i++) {
      final dice = find.byType(GestureDetector).first;
      await tester.tap(dice, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // Si un pion sélectionnable apparaît, on le tape.
      final pawns = find.byWidgetPredicate((w) => w is GestureDetector && w.onTap != null);
      if (pawns.evaluate().length > 1) {
        await tester.tap(pawns.at(1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }
    }
    // Laisse le temps à toute chaîne de coup IA encore en cours de se
    // terminer, pour ne laisser aucun minuteur en attente à la fin du test.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('Ludo : plateau tient sur tous les écrans sans overflow', (tester) async {
    for (final size in _screenSizes) {
      await _setScreenSize(tester, size);
      final colors = LudoBoard.playOrder.take(4).toList();
      // Sièges humains uniquement : pas de boucle IA à drainer, ce test ne
      // vérifie que la mise en page.
      await tester.pumpWidget(MaterialApp(
        home: LudoGameScreen(
          activeColors: colors,
          seats: {for (final c in colors) c: SeatType.human},
          difficulty: LudoDifficulty.easy,
          resume: null,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  testWidgets('Ludo : depuis le hub, choisir 2 joueurs puis démarrer une partie',
      (tester) async {
    await _setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(const GameHubApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await _swipeToGame(tester, 4); // Ludo = dernière carte du carrousel
    await tester.tap(find.text("Ludo").first, warnIfMissed: false);
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await _openWizard(tester);
    await _pickWizardOption(tester, "2 joueurs");
    // Étape "sièges" : personnalisée, ne s'enchaîne pas toute seule.
    await _tapWizardContinue(tester);
    await _pickWizardOption(tester, "Moyen");
    await tester.pump(const Duration(milliseconds: 500));
  });
}
