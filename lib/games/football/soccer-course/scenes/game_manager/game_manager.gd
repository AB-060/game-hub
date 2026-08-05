extends Node

const DURATION_IMPACT_PAUSE := 100
const DURATION_GAME_SEC := 2 * 60

enum State {IN_PLAY, SCORED, RESET, KICKOFF, OVERTIME, GAMEOVER}

var current_match : Match = null
var current_state : GameState = null
var player_setup : Array[String] = ["FRANCE", ""]
var state_factory := GameStateFactory.new()
var time_left : float
var time_since_paused := Time.get_ticks_msec()

# New this pass: real shot-on-target tracking (see GameEvents.shot_taken/
# shot_on_target and Match.record_shot/record_shot_on_target). last_shot_*
# is a short-lived window used by ball_state_freeform.gd to decide whether
# a goalkeeper catch/parry counts as "reached the keeper shortly after a
# shot" (on target) versus an unrelated loose-ball pickup - real time
# (Time.get_ticks_msec()), unaffected by the goal slow-motion Engine.time_scale
# change below since that only affects _process(delta)'s delta, not this.
const SHOT_ON_TARGET_WINDOW_MSEC := 1500
var last_shot_country := ""
var last_shot_time_msec := -1000000

# New this pass: same short-real-time-window pattern as last_shot_*/
# SHOT_ON_TARGET_WINDOW_MSEC above, reused for pass completion and assist
# detection. PASS_COMPLETION_WINDOW_MSEC is short (a pass in flight reaches
# a teammate quickly); ASSIST_WINDOW_MSEC is longer (a genuine goal-leading
# pass can be followed by a dribble/shot buildup before the goal), both are
# reasonable, documented heuristics, not measured/tuned values.
const PASS_COMPLETION_WINDOW_MSEC := 2000
const ASSIST_WINDOW_MSEC := 4000
var last_pass_country := ""
var last_pass_player_name := ""
var last_pass_time_msec := -1000000

func _init() -> void:
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS

func _ready() -> void:
	GameEvents.impact_received.connect(on_impact_received.bind())
	GameEvents.shot_taken.connect(on_shot_taken.bind())
	GameEvents.shot_on_target.connect(on_shot_on_target.bind())
	GameEvents.save_made.connect(on_save_made.bind())
	GameEvents.pass_attempted.connect(on_pass_attempted.bind())
	GameEvents.pass_completed.connect(on_pass_completed.bind())
	GameEvents.tackle_attempted.connect(on_tackle_attempted.bind())

func _process(_delta: float) -> void:
	if get_tree().paused and Time.get_ticks_msec() - time_since_paused > DURATION_IMPACT_PAUSE:
		get_tree().paused = false

func start_game() -> void:
	# DURATION_GAME_SEC remains the hardcoded default that Settings.
	# match_duration_sec itself initializes to; Settings is the live source
	# of truth once the player has (or hasn't) changed it in the Settings
	# screen, so matches pick up the persisted duration here.
	time_left = Settings.match_duration_sec
	switch_state(State.RESET)

func switch_state(state: State, data: GameStateData = GameStateData.new()) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, data)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "GameStateMachine: " + str(state)
	call_deferred("add_child", current_state)
	
func is_coop() -> bool:
	return player_setup[0] == player_setup[1]

func is_single_player() -> bool:
	return player_setup[1].is_empty()

func is_time_up() -> bool:
	return time_left <= 0

func get_winner_country() -> String:
	assert(not current_match.is_tied())
	return current_match.winner

func increase_score(country_scored_on: String) -> void:
	current_match.increase_score(country_scored_on)
	GameEvents.score_changed.emit()

func on_impact_received(_impact_position: Vector2, is_high_impact: bool) -> void:
	if is_high_impact:
		time_since_paused = Time.get_ticks_msec()
		get_tree().paused = true

func on_shot_taken(country: String) -> void:
	if current_match != null:
		current_match.record_shot(country)
	last_shot_country = country
	last_shot_time_msec = Time.get_ticks_msec()

func on_shot_on_target(country: String) -> void:
	if current_match != null:
		current_match.record_shot_on_target(country)

func is_within_shot_on_target_window(country: String) -> bool:
	return country == last_shot_country and Time.get_ticks_msec() - last_shot_time_msec <= SHOT_ON_TARGET_WINDOW_MSEC

func on_save_made(country: String) -> void:
	if current_match != null:
		current_match.record_save(country)

func on_pass_attempted(country: String, player_name: String) -> void:
	if current_match != null:
		current_match.record_pass_attempted(country)
	last_pass_country = country
	last_pass_player_name = player_name
	last_pass_time_msec = Time.get_ticks_msec()

func on_pass_completed(country: String) -> void:
	if current_match != null:
		current_match.record_pass_completed(country)

func on_tackle_attempted(country: String) -> void:
	if current_match != null:
		current_match.record_tackle(country)

func is_within_pass_completion_window(country: String) -> bool:
	return country == last_pass_country and Time.get_ticks_msec() - last_pass_time_msec <= PASS_COMPLETION_WINDOW_MSEC

func is_within_assist_window(country: String) -> bool:
	return country == last_pass_country and Time.get_ticks_msec() - last_pass_time_msec <= ASSIST_WINDOW_MSEC
