import 'dart:math';

/// Banque de commentaires dynamiques piochés selon le type d'évènement.
class Commentary {
  static final Random _rand = Random();

  static const List<String> goals = [
    "BUUUT !",
    "Quelle frappe !",
    "But exceptionnel !",
    "Magnifique but !",
    "Il ne pouvait rien faire !",
    "Le gardien est battu !",
  ];

  static const List<String> saves = [
    "Magnifique arrêt !",
    "Incroyable parade !",
    "Le gardien sauve son équipe !",
    "Quel réflexe !",
    "Il repousse le danger !",
  ];

  static const List<String> misses = [
    "Ça passe juste à côté !",
    "Il manque le cadre !",
    "Quelle occasion manquée !",
    "Ça survole la barre !",
  ];

  static const List<String> yellowCards = [
    "Carton jaune, l'arbitre sévit.",
    "Faute sanctionnée d'un avertissement.",
  ];

  static const List<String> redCards = [
    "Carton rouge ! Expulsion !",
    "C'est terminé pour lui, exclusion directe !",
  ];

  static const List<String> kickoff = [
    "Coup d'envoi de la rencontre !",
    "C'est parti pour ce match !",
  ];

  static const List<String> halfTime = ["Fin de la première période."];

  static const List<String> fullTime = [
    "Fin du match !",
    "L'arbitre siffle la fin de la rencontre !",
  ];

  static String pick(List<String> pool) => pool[_rand.nextInt(pool.length)];
}
