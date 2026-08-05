class_name Camera
extends Camera2D

const DISTANCE_TARGET := 100.0
const DURATION_SHAKE := 120
const SHAKE_INTENSITY := 5
const SMOOTHING_BALL_CARRIED := 2
const SMOOTHING_BALL_DEFAULT := 8

# Phase 7: dynamic zoom. Applied as a multiplier on top of the player's own
# Settings.camera_zoom baseline (zoom = base * dynamic multiplier) so this
# never fights the user's stored preference - it only nudges around it.
const ZOOM_MULTIPLIER_DEFAULT := 1.0
const ZOOM_MULTIPLIER_NEAR_GOAL := 1.15
const DISTANCE_ZOOM_NEAR_GOAL := 150.0
const ZOOM_EASE_SPEED := 0.6 # multiplier units per second, via move_toward

# Phase 7: goal celebration camera hold. GameStateScored holds the
# celebration for 3000ms before emitting GameEvents.team_reset (see
# game_state_scored.gd), so a ~1.4s camera hold comfortably finishes and
# resumes normal ball-follow well before team_reset fires - team_reset is
# only kept as a safety-net release in case that timing ever changes.
const DURATION_CELEBRATION_CAMERA_MS := 1400
const ZOOM_MULTIPLIER_CELEBRATION := 1.3
const SMOOTHING_CELEBRATION := 3

var is_shaking := false
var time_start_shake := Time.get_ticks_msec()
var dynamic_zoom_multiplier := ZOOM_MULTIPLIER_DEFAULT

var is_celebrating := false
var time_start_celebration := Time.get_ticks_msec()
var celebration_goal : Goal = null

@export var ball : Ball

# Fetched by relative path in code (not wired via .tscn export) - Camera's
# parent is WorldScreen, and ActorsContainer/PitchObjects/GoalHome|GoalAway
# is the exact path already used for ActorsContainer's own goal_home/
# goal_away NodePath exports in world_screen.tscn.
var goal_home : Goal
var goal_away : Goal

func _init() -> void:
	GameEvents.impact_received.connect(on_impact_received.bind())
	GameEvents.team_scored.connect(on_team_scored.bind())
	GameEvents.team_reset.connect(on_team_reset.bind())

func _ready() -> void:
	# Phase 5: simple camera zoom preference. Camera2D.zoom is a real,
	# directly-supported property - applied once here rather than every
	# frame in _process() since nothing else drives zoom in this game yet.
	zoom = Vector2.ONE * Settings.camera_zoom
	goal_home = get_node("../ActorsContainer/PitchObjects/GoalHome")
	goal_away = get_node("../ActorsContainer/PitchObjects/GoalAway")

func _process(delta: float) -> void:
	if is_celebrating:
		process_celebration(delta)
	else:
		process_ball_follow(delta)

	if is_shaking and Time.get_ticks_msec() - time_start_shake < DURATION_SHAKE:
		offset = Vector2(randf_range(-SHAKE_INTENSITY, SHAKE_INTENSITY), randf_range(-SHAKE_INTENSITY, SHAKE_INTENSITY))
	else:
		is_shaking = false
		offset = Vector2.ZERO

func process_ball_follow(delta: float) -> void:
	if ball.carrier != null:
		position = ball.carrier.position + ball.carrier.heading * DISTANCE_TARGET
		position_smoothing_speed = SMOOTHING_BALL_CARRIED * Settings.camera_follow_speed
	else:
		position = ball.position
		position_smoothing_speed = SMOOTHING_BALL_DEFAULT * Settings.camera_follow_speed

	var target_multiplier := ZOOM_MULTIPLIER_NEAR_GOAL if is_ball_near_a_goal() else ZOOM_MULTIPLIER_DEFAULT
	dynamic_zoom_multiplier = move_toward(dynamic_zoom_multiplier, target_multiplier, ZOOM_EASE_SPEED * delta)
	zoom = Vector2.ONE * Settings.camera_zoom * dynamic_zoom_multiplier

func process_celebration(delta: float) -> void:
	position_smoothing_speed = SMOOTHING_CELEBRATION
	position = celebration_goal.get_center_target_position()
	dynamic_zoom_multiplier = move_toward(dynamic_zoom_multiplier, ZOOM_MULTIPLIER_CELEBRATION, ZOOM_EASE_SPEED * delta)
	zoom = Vector2.ONE * Settings.camera_zoom * dynamic_zoom_multiplier

	if Time.get_ticks_msec() - time_start_celebration > DURATION_CELEBRATION_CAMERA_MS:
		is_celebrating = false
		celebration_goal = null

func is_ball_near_a_goal() -> bool:
	var distance_home := ball.position.distance_to(goal_home.get_center_target_position())
	var distance_away := ball.position.distance_to(goal_away.get_center_target_position())
	return minf(distance_home, distance_away) < DISTANCE_ZOOM_NEAR_GOAL

func on_impact_received(_impact_position: Vector2, is_high_impact: bool) -> void:
	if is_high_impact and Settings.camera_shake_enabled:
		is_shaking = true
		time_start_shake = Time.get_ticks_msec()

func on_team_scored(country_scored_on: String) -> void:
	var scored_goal : Goal = goal_home if goal_home.country == country_scored_on else goal_away
	is_celebrating = true
	time_start_celebration = Time.get_ticks_msec()
	celebration_goal = scored_goal

func on_team_reset() -> void:
	# Safety-net release in case celebration timing and GameStateScored's
	# DURATION_CELEBRATION ever drift out of sync (see const comment above).
	is_celebrating = false
	celebration_goal = null
