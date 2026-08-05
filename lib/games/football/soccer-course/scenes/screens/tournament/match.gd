class_name Match

var country_home : String
var country_away : String
var goals_home : int
var goals_away : int
var final_score : String
var winner : String

# New this pass: real, cheaply-tracked stats for the Full-Time (and, if
# reached, Half-Time) screens. Match is instantiated fresh per-match
# (Match.new(...), see team_selection_screen.gd/pause_menu "Restart Match"/
# ui.gd's full-time "Play Again" flow) so these fields reset correctly
# between matches with no extra reset logic needed - same reasoning as
# goals_home/goals_away above.
var shots_home := 0
var shots_away := 0
var shots_on_target_home := 0
var shots_on_target_away := 0
# Each entry: {"country": String, "scorer": String}. "scorer" reuses the
# exact same last-ball-carrier name already shown by the existing
# "X SCORED!" toast in ui.gd - not a new attribution system.
var goals_scored : Array[Dictionary] = []

# New this pass: saves/passes/tackles/assists, same honest-heuristic
# real-event-hooked pattern as shots/shots_on_target above - see
# GameEvents.save_made/pass_attempted/pass_completed/tackle_attempted and
# GameManager's on_* handlers for exactly how/when each fires.
var saves_home := 0
var saves_away := 0
var passes_attempted_home := 0
var passes_attempted_away := 0
var passes_completed_home := 0
var passes_completed_away := 0
var tackles_home := 0
var tackles_away := 0
# Each entry: {"country": String, "player": String}. Recorded when a goal is
# scored within GameManager.ASSIST_WINDOW_MSEC of a completed pass to the
# scorer's team by a different player - see ui.gd's on_team_scored_record.
var assists : Array[Dictionary] = []

func _init(team_home: String, team_away: String) -> void:
	country_home = team_home
	country_away = team_away

func record_shot(country: String) -> void:
	if country == country_home:
		shots_home += 1
	elif country == country_away:
		shots_away += 1

func record_shot_on_target(country: String) -> void:
	if country == country_home:
		shots_on_target_home += 1
	elif country == country_away:
		shots_on_target_away += 1

func record_goal_scorer(country: String, scorer_name: String) -> void:
	goals_scored.append({"country": country, "scorer": scorer_name})

func record_save(country: String) -> void:
	if country == country_home:
		saves_home += 1
	elif country == country_away:
		saves_away += 1

func record_pass_attempted(country: String) -> void:
	if country == country_home:
		passes_attempted_home += 1
	elif country == country_away:
		passes_attempted_away += 1

func record_pass_completed(country: String) -> void:
	if country == country_home:
		passes_completed_home += 1
	elif country == country_away:
		passes_completed_away += 1

func record_tackle(country: String) -> void:
	if country == country_home:
		tackles_home += 1
	elif country == country_away:
		tackles_away += 1

func record_assist(country: String, player_name: String) -> void:
	assists.append({"country": country, "player": player_name})

# "Best player" heuristic, plainly labeled wherever it's displayed: no
# player-rating/MOTM system exists in this project, so this is only ever
# "whoever scored the most goals this match" - genuinely computed from
# goals_scored above, not a fabricated rating. Returns "" if nobody scored.
func get_best_player_name() -> String:
	var tally : Dictionary[String, int] = {}
	for entry in goals_scored:
		var scorer : String = entry["scorer"]
		if scorer.is_empty():
			continue
		tally[scorer] = tally.get(scorer, 0) + 1
	var best_name := ""
	var best_count := 0
	for scorer_name in tally.keys():
		if tally[scorer_name] > best_count:
			best_count = tally[scorer_name]
			best_name = scorer_name
	return best_name

func is_tied() -> bool:
	return goals_home == goals_away

func has_someone_scored() -> bool:
	return goals_home > 0 or goals_away > 0

func increase_score(country_scored_on: String) -> void:
	if country_scored_on == country_home:
		goals_away += 1
	else:
		goals_home += 1
	update_match_info()

func update_match_info() -> void:
	winner = country_home if goals_home > goals_away else country_away
	final_score = "%d - %d" % [max(goals_home, goals_away), min(goals_home, goals_away)]

func resolve() -> void:
	while is_tied():
		goals_home = randi_range(0, 5)
		goals_away = randi_range(0, 5)
	update_match_info()
		
