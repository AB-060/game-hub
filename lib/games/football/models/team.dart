import 'package:flutter/material.dart';

enum Continent { africa, europe, southAmerica, northAmerica, asia, oceania }

extension ContinentX on Continent {
  String get label {
    switch (this) {
      case Continent.africa:
        return "Afrique";
      case Continent.europe:
        return "Europe";
      case Continent.southAmerica:
        return "Amérique du Sud";
      case Continent.northAmerica:
        return "Amérique du Nord";
      case Continent.asia:
        return "Asie";
      case Continent.oceania:
        return "Océanie";
    }
  }

  String get emoji {
    switch (this) {
      case Continent.africa:
        return "🌍";
      case Continent.europe:
        return "🌍";
      case Continent.southAmerica:
        return "🌎";
      case Continent.northAmerica:
        return "🌎";
      case Continent.asia:
        return "🌏";
      case Continent.oceania:
        return "🌏";
    }
  }
}

/// Fiche complète d'une sélection nationale.
class Team {
  final String id;
  final String name;
  final String nameEn;
  final Continent continent;
  final String confederation;
  final String flag;
  final String fifaCode;
  final List<Color> colors;
  final int attack;
  final int midfield;
  final int defense;
  final int goalkeeper;
  final int speed;
  final int passing;
  final int shooting;

  const Team({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.continent,
    required this.confederation,
    required this.flag,
    required this.fifaCode,
    required this.colors,
    required this.attack,
    required this.midfield,
    required this.defense,
    required this.goalkeeper,
    required this.speed,
    required this.passing,
    required this.shooting,
  });

  /// Note générale : moyenne des 4 attributs principaux.
  int get overall => ((attack + midfield + defense + goalkeeper) / 4).round();

  Color get primaryColor => colors.first;
}
