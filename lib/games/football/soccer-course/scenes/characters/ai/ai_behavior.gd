class_name AIBehavior
extends Node

const DURATION_AI_TICK_FREQUENCY := 200
# Phase 2: same accel/decel feel as human-controlled players (see
# MovementTuning), applied on top of the AI's existing 200ms decision tick
# so CPU players don't visually "snap" to a new velocity every tick while
# still reacting at the same cadence as before.

var ball : Ball = null
var opponent_detection_area : Area2D = null
var player : Player = null
var teammate_detection_area : Area2D = null
var time_since_last_ai_tick := Time.get_ticks_msec()
# Steering target computed by perform_ai_movement(); subclasses should set
# this instead of assigning player.velocity directly so the smoothing below
# applies uniformly every frame, not just on AI decision ticks.
var target_velocity := Vector2.ZERO

func _ready() -> void:
	time_since_last_ai_tick = Time.get_ticks_msec() + randi_range(0, DURATION_AI_TICK_FREQUENCY)

func setup(context_player: Player, context_ball: Ball, context_opponent_detection_area: Area2D, context_teammate_detection_area: Area2D) -> void:
	player = context_player
	ball = context_ball
	opponent_detection_area = context_opponent_detection_area
	teammate_detection_area = context_teammate_detection_area

func process_ai(delta: float) -> void:
	if Time.get_ticks_msec() - time_since_last_ai_tick > DURATION_AI_TICK_FREQUENCY:
		time_since_last_ai_tick = Time.get_ticks_msec()
		perform_ai_movement()
		perform_ai_decisions()
	apply_steering(delta)

func apply_steering(delta: float) -> void:
	var rate: float
	if target_velocity != Vector2.ZERO:
		rate = player.speed / MovementTuning.ACCEL_TIME_TO_MAX
	else:
		rate = player.speed / MovementTuning.DECEL_TIME_TO_STOP
	player.velocity = player.velocity.move_toward(target_velocity, rate * delta)

func perform_ai_movement() -> void:
	pass

func perform_ai_decisions() -> void:
	pass

func get_bicircular_weight(position: Vector2, center_target: Vector2, inner_circle_radius: float, inner_circle_weight: float, outer_circle_radius: float, outer_circle_weight: float) -> float:
	var distance_to_center := position.distance_to(center_target)
	if distance_to_center > outer_circle_radius:
		return outer_circle_weight
	elif distance_to_center < inner_circle_radius:
		return inner_circle_weight
	else:
		var distance_to_inner_radius := distance_to_center - inner_circle_radius
		var close_range_distance := outer_circle_radius - inner_circle_radius
		return lerpf(inner_circle_weight, outer_circle_weight, distance_to_inner_radius / close_range_distance)

func is_ball_possessed_by_opponent() -> bool:
	return ball.carrier != null and ball.carrier.country != player.country

func is_ball_carried_by_teammate() -> bool:
	return ball.carrier != null and ball.carrier != player and ball.carrier.country == player.country

func has_opponents_nearby() -> bool:
	var players := opponent_detection_area.get_overlapping_bodies()
	return players.find_custom(func(p: Player): return p.country != player.country) > -1
