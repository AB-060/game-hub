# 🎮 Game Hub - Flutter

Une application Flutter regroupant 6 mini-jeux jouables, accessibles depuis un
écran d'accueil animé (fond de particules, cartes en verre dépoli), sans
moteur de jeu externe. Chaque jeu suit la même architecture en couches
(models / engine / services / ui) et partage une infrastructure commune :
statistiques persistées, sauvegarde automatique, système audio et widgets
de résultat/carte réutilisables.

## Jeux disponibles

| Jeu | Description |
|-----|--------------|
| ♟️ Échecs | Moteur complet (roque, en passant, promotion, échec/mat/pat, nulles) + IA (3 niveaux, minimax/alpha-bêta), mode 2 joueurs, historique, chrono, sauvegarde |
| ⚽ Football | Sélections nationales (Mauritanie par défaut), Match rapide simulé en direct, Tirs au but (IA du gardien à 4 niveaux), et Compétitions (Coupe du Monde/CAN/Euro/Copa América/Coupe d'Asie/tournoi personnalisé) |
| ❌ Morpion | Grilles 3x3/4x4/5x5, IA à 3 niveaux (aléatoire → heuristique → Minimax/alpha-bêta), ligne gagnante animée |
| 🧠 Memory | 6 thèmes (animaux, fruits, sports, pays, drapeaux, emoji), 4 niveaux, combo/score, confettis à la victoire |
| 🐍 Snake | 3 difficultés, 4 cartes d'obstacles, objets spéciaux (bouclier, boost, double score, bonus), pause |
| 🎲 Ludo | Plateau classique 15x15 (piste de 52 cases + couloirs privés), 2 à 4 joueurs, IA à 3 niveaux (capture/protection/sortie), mode IA contre IA |

Tous les jeux : sauvegarde automatique + reprise de partie, statistiques
persistées (parties, victoires, meilleur score, meilleure série), sons
(système, en attendant de vrais fichiers audio), écrans de victoire/défaite/
nul, et interface responsive (`LayoutBuilder`/`MediaQuery`, aucune taille
fixe) testée sur 5 tailles d'écran (téléphone étroit → tablette).

## Technologies utilisées

- Flutter / Dart, thème Material 3 avec la police Poppins (`google_fonts`)
- `StatefulWidget` + `setState` pour la logique de chaque jeu
- Fond animé à particules dessiné avec `CustomPainter` + `Ticker`
- Cartes "verre dépoli" (`BackdropFilter` + `ImageFilter.blur`)
- `GridView` / grilles positionnées pour les plateaux de jeu
- IA en isolate dédié (`Isolate.run`) pour les recherches coûteuses (échecs,
  morpion expert) afin de ne jamais bloquer l'UI
- `shared_preferences` pour la sauvegarde de partie et les statistiques
- `flutter_test` : 89 tests couvrant le hub et chaque jeu sur plusieurs
  tailles d'écran, avec capture de `FlutterError.onError` (les erreurs de
  mise en page ne passent pas inaperçues) et mock `SharedPreferences`

## Infrastructure partagée

- `lib/services/game_stats_service.dart` — statistiques génériques
  (parties, victoires/défaites/nulles, temps de jeu, meilleur score,
  meilleure série), namespacées par jeu.
- `lib/services/game_save_service.dart` — sauvegarde automatique générique
  de l'état d'une partie en cours, namespacée par jeu.
- `lib/services/app_sound_service.dart` — système audio commun (son/musique
  on-off persistés), sons système en attendant de vrais fichiers dans
  `assets/sounds/` (un seul point d'intégration à modifier).
- `lib/widgets/glass_card.dart` — carte "verre dépoli" et chip sélectionnable
  réutilisés par tous les écrans d'accueil.
- `lib/widgets/result_overlay.dart` — écran de fin de partie (victoire/
  défaite/nul) commun, avec actions Rejouer / Nouvelle partie / Retour.
- `lib/widgets/confetti_overlay.dart` — effet de confettis à la victoire.
- `lib/theme/app_colors.dart` — palette partagée (fond, accent, texte atténué).

### Échecs : architecture détaillée

Le module `lib/games/chess/` est découpé en couches indépendantes :

- `models/` — types de données purs (pièce, coup, résultat, difficulté).
- `engine/chess_engine.dart` — moteur de règles complet : génération de
  coups pseudo-légaux puis filtrage par légalité réelle, roque (avec toutes
  les conditions), prise en passant, promotion, détection d'échec / échec
  et mat / pat / nulles (matériel insuffisant, règle des 50 coups, triple
  répétition). Validé par `perft` (20 / 400 / 8902 / 197281 sur la position
  de départ, et la position "Kiwipete" pour le roque/en passant/promotion).
- `engine/ai_engine.dart` — IA Minimax + élagage alpha-bêta avec tables de
  position (PST), 3 niveaux de difficulté (profondeur + taux d'erreurs
  volontaires pour Débutant/Intermédiaire). La recherche tourne dans un
  isolate dédié (`Isolate.run`) pour ne jamais bloquer l'UI.
- `services/sound_service.dart` — hooks son propres aux échecs (distinct du
  système audio commun, pour ne pas toucher un module déjà stable).
- `services/persistence_service.dart` — sauvegarde automatique de la
  partie en cours et statistiques (victoires/défaites/nulles/temps de jeu).
- `ui/` — écran d'accueil (mode IA/2 joueurs, difficulté, couleur, reprise,
  stats) et écran de jeu (plateau responsive, historique des coups, pièces
  capturées, chronomètre par joueur, dialogues de promotion et de fin de
  partie).
- `ui/widgets/piece_painter.dart` — pièces dessinées en vectoriel pur
  (`CustomPainter`), nettes à toute taille, sans asset externe.

### Football : architecture détaillée

Le module `lib/games/football/` (ex-Penalty, conservé et étendu — aucune
fonctionnalité existante supprimée) est organisé en couches :

- `models/team.dart` + `models/teams_database.dart` — fiche complète par
  sélection (attaque, milieu, défense, gardien, vitesse, passes, tir,
  overall calculé) et base de ~39 équipes réparties sur les 6 continents.
  La Mauritanie est toujours en première position (`TeamsDatabase.defaultTeam`)
  et sélectionnée par défaut au premier lancement (`TeamSelectionService`).
- `engine/match_engine.dart` — simulation statistique minute par minute
  d'un match (probabilité de but pondérée par l'écart de niveau tir/gardien,
  avec un plancher pour qu'un outsider garde une vraie chance), stats
  (possession, tirs, tirs cadrés, fautes, cartons) et commentaires.
- `engine/tournament_engine.dart` — bracket à élimination directe générique
  (réutilisé pour Coupe du Monde/CAN/Euro/Copa América/Coupe d'Asie/tournoi
  personnalisé, seul le vivier de participants change), avec séance de tirs
  au but simulée pour départager les matchs nuls.
- `engine/penalty_engine.dart` + `models/penalty_models.dart` — IA du
  gardien à 4 niveaux (Facile → Expert) pour l'écran Tirs au but.
- `widgets/` — carte équipe, barres de stats, tableau de score, ticker de
  commentaires, fond de stade thématisé par confédération avec effet météo
  (pluie/brouillard/projecteurs en `CustomPainter`, sans assets externes).
- `ui/` — accueil (équipe/adversaire/mode), sélection Continent → Pays,
  Match rapide, Tirs au but, réglage puis déroulé de tournoi (podium + trophée).

### Ludo : géométrie du plateau

`lib/games/ludo/models/ludo_board.dart` définit un plateau classique en
grille 15x15 : piste commune de 52 cases (`ringCells`), couloir privé de
6 cases par couleur (`homeColumns`), 8 cases sûres, et 4 cours de départ.
La cohérence de cette géométrie (52 cases uniques, alignement de chaque
couleur avec son propre couloir) est vérifiée par des tests dédiés. Le
moteur (`engine/ludo_engine.dart`) et l'IA (`engine/ludo_ai.dart`) sont
validés par simulation IA-contre-IA complète (2 à 4 joueurs, 3 difficultés)
pour garantir qu'aucune partie ne boucle indéfiniment.

## Lancer le projet

```bash
flutter pub get
flutter run
```

## Lancer les tests

```bash
flutter test
```

## Structure du projet

```
lib/
  main.dart                       # Écran d'accueil (hub) et navigation
  home/
    particle_background.dart      # Fond animé de particules
  theme/
    app_colors.dart                # Palette partagée
  services/
    game_stats_service.dart        # Statistiques génériques par jeu
    game_save_service.dart         # Sauvegarde automatique générique
    app_sound_service.dart         # Système audio commun
  widgets/
    glass_card.dart                # Carte verre dépoli + chip sélectionnable
    result_overlay.dart            # Écran de fin de partie commun
    confetti_overlay.dart          # Effet de confettis
  games/
    chess/
      chess.dart                  # Point d'entrée (barrel)
      models/ engine/ services/ ui/
    tic_tac_toe/
      models/ engine/ ui/
    memory_match/
      models/ engine/ services/ ui/
    snake/
      models/ engine/ ui/
    football/
      models/ engine/ services/ widgets/ ui/ utils/
    ludo/
      models/ engine/ ui/
```

## Auteur

**AB-060** - [github.com/AB-060](https://github.com/AB-060)
