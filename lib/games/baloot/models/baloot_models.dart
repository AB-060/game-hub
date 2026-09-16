/// Modèles du compteur de Baloot (بلوت) : le jeu de cartes se joue à quatre,
/// deux contre deux, et se compte manche par manche jusqu'à la cible d'une
/// « صكة » — 152 points par défaut.
library baloot_models;

/// Les deux camps de la table.
enum BalootSide { us, them }

extension BalootSideX on BalootSide {
  String get label => this == BalootSide.us ? "Nous" : "Eux";
  BalootSide get other => this == BalootSide.us ? BalootSide.them : BalootSide.us;
}

/// Cibles usuelles d'une صكة.
const List<int> kBalootTargets = [101, 121, 152];
const int kDefaultBalootTarget = 152;

/// Le score d'une manche pour les deux camps.
class BalootRound {
  final int us;
  final int them;

  const BalootRound({required this.us, required this.them});

  Map<String, dynamic> toJson() => {'us': us, 'them': them};

  static BalootRound fromJson(Map<String, dynamic> json) => BalootRound(
        us: (json['us'] as num?)?.toInt() ?? 0,
        them: (json['them'] as num?)?.toInt() ?? 0,
      );
}

/// Une صكة en cours : la liste des manches jouées et la cible à atteindre.
class BalootGame {
  final List<BalootRound> rounds;
  final int target;

  const BalootGame({this.rounds = const [], this.target = kDefaultBalootTarget});

  int total(BalootSide side) => rounds.fold(
        0,
        (sum, r) => sum + (side == BalootSide.us ? r.us : r.them),
      );

  int get usTotal => total(BalootSide.us);
  int get themTotal => total(BalootSide.them);

  /// Le camp qui mène, `null` si les deux sont à égalité.
  BalootSide? get leader {
    if (usTotal == themTotal) return null;
    return usTotal > themTotal ? BalootSide.us : BalootSide.them;
  }

  /// Le vainqueur de la صكة : il faut atteindre la cible, et si les deux
  /// camps la franchissent dans la même manche c'est le plus haut total qui
  /// l'emporte. À égalité parfaite, la partie continue.
  BalootSide? get winner {
    final us = usTotal;
    final them = themTotal;
    final usReached = us >= target;
    final themReached = them >= target;
    if (!usReached && !themReached) return null;
    if (us == them) return null;
    return us > them ? BalootSide.us : BalootSide.them;
  }

  bool get isOver => winner != null;
  bool get isEmpty => rounds.isEmpty;

  BalootGame addRound(BalootRound round) =>
      BalootGame(rounds: [...rounds, round], target: target);

  BalootGame undo() => rounds.isEmpty
      ? this
      : BalootGame(rounds: rounds.sublist(0, rounds.length - 1), target: target);

  BalootGame reset() => BalootGame(target: target);

  BalootGame withTarget(int newTarget) =>
      BalootGame(rounds: rounds, target: newTarget);

  Map<String, dynamic> toJson() => {
        'target': target,
        'rounds': [for (final r in rounds) r.toJson()],
      };

  static BalootGame fromJson(Map<String, dynamic> json) => BalootGame(
        target: (json['target'] as num?)?.toInt() ?? kDefaultBalootTarget,
        rounds: [
          for (final r in (json['rounds'] as List? ?? []))
            BalootRound.fromJson((r as Map).cast<String, dynamic>()),
        ],
      );
}

/// Niveau du joueur, calculé sur le pourcentage de صكات gagnées.
class BalootLevel {
  final int value;
  final String label;

  const BalootLevel(this.value, this.label);

  factory BalootLevel.from({required int wins, required int losses}) {
    final played = wins + losses;
    if (played == 0) return const BalootLevel(0, "Nouveau");
    final value = (wins / played * 100).floor();
    if (value < 25) return BalootLevel(value, "Débutant");
    if (value < 50) return BalootLevel(value, "Amateur");
    if (value < 65) return BalootLevel(value, "Confirmé");
    if (value < 80) return BalootLevel(value, "Professionnel");
    return BalootLevel(value, "Maître");
  }
}
