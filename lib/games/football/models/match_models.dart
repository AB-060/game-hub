enum Weather { sun, rain, night, clouds, fog }

extension WeatherX on Weather {
  String get emoji {
    switch (this) {
      case Weather.sun:
        return "☀️";
      case Weather.rain:
        return "🌧️";
      case Weather.night:
        return "🌙";
      case Weather.clouds:
        return "⛅";
      case Weather.fog:
        return "🌫️";
    }
  }

  String get label {
    switch (this) {
      case Weather.sun:
        return "Soleil";
      case Weather.rain:
        return "Pluie";
      case Weather.night:
        return "Nuit";
      case Weather.clouds:
        return "Nuages";
      case Weather.fog:
        return "Brouillard";
    }
  }

  /// Légère pénalité de précision de tir par mauvais temps (ambiance
  /// uniquement, effet volontairement discret sur la simulation).
  int get shotPenalty {
    switch (this) {
      case Weather.rain:
        return 6;
      case Weather.fog:
        return 8;
      case Weather.night:
        return 2;
      case Weather.clouds:
        return 0;
      case Weather.sun:
        return 0;
    }
  }
}

enum MatchEventType { kickoff, goal, saved, missed, yellowCard, redCard, halfTime, fullTime }

class MatchEvent {
  final int minute;
  final MatchEventType type;
  final String teamId;
  final String text;
  const MatchEvent({
    required this.minute,
    required this.type,
    required this.teamId,
    required this.text,
  });
}

class MatchStats {
  int possessionHome;
  int possessionAway;
  int shotsHome = 0;
  int shotsAway = 0;
  int shotsOnTargetHome = 0;
  int shotsOnTargetAway = 0;
  int foulsHome = 0;
  int foulsAway = 0;
  int yellowHome = 0;
  int yellowAway = 0;
  int redHome = 0;
  int redAway = 0;

  MatchStats({required this.possessionHome, required this.possessionAway});
}
