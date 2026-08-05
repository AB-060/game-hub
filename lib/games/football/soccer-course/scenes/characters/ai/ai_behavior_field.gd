class_name AIBehaviorField
extends AIBehavior

# Phase 4: this class is now the SHARED BASE for the three outfield roles
# (Defense/Midfield/Offense - see ai_behavior_defense.gd, ai_behavior_midfield.gd,
# ai_behavior_offense.gd) rather than being used directly for all three like it
# was pre-Phase-4. It still holds everything genuinely common: the steering-force
# summation pattern, tackling, shooting/passing decisions, and the base movement
# forces (carrier/assist/on-duty/ball-proximity/spawn/density). Subclasses override
# the small "get_*_probability()" hooks and specific steering-force getters below
# rather than duplicating perform_ai_movement()/perform_ai_decisions() wholesale.
#
# NOTE: GDScript constants are resolved statically per-script, not virtually -
# a subclass redeclaring `const SHOT_PROBABILITY := x` would NOT change the
# value seen by code running in THIS base script. That's why probabilities are
# exposed via get_*_probability() virtual functions instead of plain consts
# being read directly in shared decision code - subclasses override the
# function, not the constant.
const PASS_PROBABILITY := 0.05
const SHOT_DISTANCE := 150
const SHOT_PROBABILITY := 0.3
const SPREAD_ASSIST_FACTOR := 0.8
const TACKLE_DISTANCE := 15
const TACKLE_PROBABILITY := 0.3

# Phase 4: counter-attack window. Kept here (rather than duplicated per
# subclass) since Offense/Midfield use it directly and Defense joins in with a
# reduced weight. Deliberately simple: ANY time our team gains possession
# (GameEvents.ball_possessed_by_country firing with our country) opens a short
# window during which off-the-ball players bias their steering forward. This
# is a broad approximation - it also fires on a kickoff pass or a teammate's
# own throw-in-style restart, not just a genuine take-away - but per the Phase
# 4 scope a full possession-phase state machine is explicitly out of scope, so
# this cheap timer-based version is intentional.
const COUNTER_ATTACK_WINDOW_MSEC := 4000
const COUNTER_ATTACK_BALL_PROXIMITY := 150.0
const COUNTER_ATTACK_PUSH_FACTOR := 0.6
const COUNTER_ATTACK_STEERING_WEIGHT := 0.6

var counter_attack_expires_at_msec := 0

func setup(context_player: Player, context_ball: Ball, context_opponent_detection_area: Area2D, context_teammate_detection_area: Area2D) -> void:
	super.setup(context_player, context_ball, context_opponent_detection_area, context_teammate_detection_area)
	GameEvents.ball_possessed_by_country.connect(on_ball_possessed_by_country.bind())

func on_ball_possessed_by_country(country: String) -> void:
	if country == player.country:
		counter_attack_expires_at_msec = Time.get_ticks_msec() + COUNTER_ATTACK_WINDOW_MSEC

func is_counter_attack_active() -> bool:
	return Time.get_ticks_msec() < counter_attack_expires_at_msec

func perform_ai_movement() -> void:
	var total_steering_force := Vector2.ZERO
	if player.has_ball():
		total_steering_force += get_carrier_steering_force()
	elif is_ball_carried_by_teammate():
		total_steering_force += get_assist_formation_steering_force()
	else:
		total_steering_force += get_onduty_steering_force()
		if total_steering_force.length_squared() < 1:
			if is_ball_possessed_by_opponent():
				total_steering_force += get_spawn_steering_force()
			elif ball.carrier == null:
				total_steering_force += get_ball_proximity_steering_force()
				total_steering_force += get_density_around_ball_steering_force()
		total_steering_force += get_counter_attack_steering_force()

	total_steering_force = total_steering_force.limit_length(1.0)
	target_velocity = total_steering_force * player.speed

func perform_ai_decisions() -> void:
	if is_ball_possessed_by_opponent() and player.position.distance_to(ball.position) < TACKLE_DISTANCE and randf() < get_tackle_probability():
		player.switch_state(Player.State.TACKLING)
	if ball.carrier == player:
		decide_on_ball_action()

# Split out of the old monolithic perform_ai_decisions() so subclasses (e.g.
# Offense's crossing decision) can intercept before falling back to the
# default shoot-or-pass logic via super.decide_on_ball_action().
func decide_on_ball_action() -> void:
	var target := player.target_goal.get_center_target_position()
	var shot_probability := get_shot_probability()
	if GameManager.player_setup[0] == player.country or GameManager.player_setup[1] == player.country:
		shot_probability = shot_probability / 10.0
	# Phase 4 fix: the pre-Phase-4 version computed this human-teammate-adjusted
	# shot_probability but then rolled against the raw SHOT_PROBABILITY constant
	# instead, so the 10x reduction never actually applied. Now rolls against
	# the adjusted local variable.
	if player.position.distance_to(target) < SHOT_DISTANCE and randf() < shot_probability:
		perform_shot()
	elif randf() < get_pass_probability() and has_opponents_nearby() and has_teammate_in_view():
		perform_pass()

func perform_shot() -> void:
	player.face_towards_target_goal()
	var shot_direction := player.position.direction_to(player.target_goal.get_random_target_position())
	var data := PlayerStateData.build().set_shot_power(player.power).set_shot_direction(shot_direction)
	player.switch_state(Player.State.SHOOTING, data)

# pass_target defaults to null, which leaves target selection to
# PlayerStatePassing.find_teammate_in_view() (nearest teammate in view).
# Subclasses (Midfield's passing-lane awareness, Offense's crossing) pass an
# explicit, deliberately-chosen target instead.
func perform_pass(pass_target: Player = null) -> void:
	var data := PlayerStateData.build()
	if pass_target != null:
		data = data.set_pass_target(pass_target)
	player.switch_state(Player.State.PASSING, data)

# Phase 5: Settings.get_difficulty_multiplier() scales the base constant
# (EASY 0.6x / NORMAL 1.0x / HARD 1.5x), surgically applied here and in each
# subclass's own get_*_probability() override rather than touching the
# underlying decision logic in perform_ai_decisions()/decide_on_ball_action().
func get_shot_probability() -> float:
	return clampf(SHOT_PROBABILITY * Settings.get_difficulty_multiplier(), 0.0, 1.0)

func get_pass_probability() -> float:
	return clampf(PASS_PROBABILITY * Settings.get_difficulty_multiplier(), 0.0, 1.0)

func get_tackle_probability() -> float:
	return clampf(TACKLE_PROBABILITY * Settings.get_difficulty_multiplier(), 0.0, 1.0)

func get_onduty_steering_force() -> Vector2:
	return player.weight_on_duty_steering * player.position.direction_to(ball.position)

func get_carrier_steering_force() -> Vector2:
	var target := player.target_goal.get_center_target_position()
	var direction := player.position.direction_to(target)
	var weight := get_bicircular_weight(player.position, target, 100, 0, 150, 1)
	return weight * direction

func get_assist_formation_steering_force() -> Vector2:
	var spawn_difference := ball.carrier.spawn_position - player.spawn_position
	var assist_destination := ball.carrier.position - spawn_difference * SPREAD_ASSIST_FACTOR
	var direction := player.position.direction_to(assist_destination)
	var weight := get_bicircular_weight(player.position, assist_destination, 30, 0.2, 60, 1)
	return weight * direction

func get_ball_proximity_steering_force() -> Vector2:
	var weight := get_bicircular_weight(player.position, ball.position, 50, 1, 120, 0)
	var direction := player.position.direction_to(ball.position)
	return weight * direction

func get_spawn_steering_force() -> Vector2:
	var weight := get_bicircular_weight(player.position, player.spawn_position, 30, 0, 100, 1)
	var direction := player.position.direction_to(player.spawn_position)
	return weight * direction

func get_density_around_ball_steering_force() -> Vector2:
	var nb_teammates_near_ball := ball.get_proximity_teammates_count(player.country)
	if nb_teammates_near_ball == 0:
		return Vector2.ZERO
	var weight := 1 - 1.0 / nb_teammates_near_ball
	var direction := ball.position.direction_to(player.position)
	return weight * direction

# Off-the-ball push during a counter-attack window (see counter_attack_expires_at_msec
# above). Only applies well away from the ball itself so it doesn't fight the
# ball-proximity/on-duty forces for players already involved in the phase of play.
func get_counter_attack_steering_force() -> Vector2:
	if not is_counter_attack_active():
		return Vector2.ZERO
	if player.position.distance_to(ball.position) < COUNTER_ATTACK_BALL_PROXIMITY:
		return Vector2.ZERO
	var push_target := player.spawn_position.lerp(player.target_goal.get_center_target_position(), COUNTER_ATTACK_PUSH_FACTOR)
	var direction := player.position.direction_to(push_target)
	return get_counter_attack_weight() * direction

# Overridden by Defense to join counter-attacks less eagerly than Offense/Midfield.
func get_counter_attack_weight() -> float:
	return COUNTER_ATTACK_STEERING_WEIGHT

func has_teammate_in_view() -> bool:
	var players_in_view := teammate_detection_area.get_overlapping_bodies()
	return players_in_view.find_custom(func(p: Player): return p != player and p.country == player.country) > -1
