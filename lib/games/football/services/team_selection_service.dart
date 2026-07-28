import 'package:shared_preferences/shared_preferences.dart';

import '../models/team.dart';
import '../models/teams_database.dart';

/// Mémorise la dernière sélection nationale du joueur (Mauritanie par
/// défaut au tout premier lancement, comme demandé).
class TeamSelectionService {
  const TeamSelectionService();

  static const _key = 'football_selected_team_id';

  Future<Team> loadSelectedTeam() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (id == null) return TeamsDatabase.defaultTeam;
    return TeamsDatabase.byId(id);
  }

  Future<void> saveSelectedTeam(Team team) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, team.id);
  }
}
