class_name AIBehaviorDefense
extends AIBehaviorField

# Phase 4: Defense is more conservative than the base outfield behavior -
# lower shot/higher tackle appetite, a stronger pull back toward spawn, and a
# new "marking" force that pulls toward the goal-side of the most dangerous
# nearby opponent when the opponent has the ball, instead of just drifting
# toward the ball itself like the generic on-duty force does.
const SHOT_PROBABILITY_DEFENSE := 0.05
const TACKLE_PROBABILITY_DEFENSE := 0.4
const ONDUTY_WEIGHT_SCALE := 0.6
const SPAWN_BIAS_WEIGHT := 0.4
const MARKING_WEIGHT := 0.8
# How far, as a 0..1 blend toward the own goal, a marker stands from the
# dangerous opponent it's tracking (0 = stand on the opponent, 1 = stand on
# the goal line). 0.3 keeps the marker goal-side without abandoning the mark.
const MARKING_GOAL_SIDE_BLEND := 0.3
const COUNTER_ATTACK_WEIGHT_DEFENSE := 0.2

func get_shot_probability() -> float:
	return clampf(SHOT_PROBABILITY_DEFENSE * Settings.get_difficulty_multiplier(), 0.0, 1.0)

func get_tackle_probability() -> float:
	return clampf(TACKLE_PROBABILITY_DEFENSE * Settings.get_difficulty_multiplier(), 0.0, 1.0)

func get_counter_attack_weight() -> float:
	return COUNTER_ATTACK_WEIGHT_DEFENSE

func get_onduty_steering_force() -> Vector2:
	var base := super.get_onduty_steering_force() * ONDUTY_WEIGHT_SCALE
	var marking := get_marking_steering_force() * MARKING_WEIGHT
	var spawn_bias := get_spawn_steering_force() * SPAWN_BIAS_WEIGHT
	return base + marking + spawn_bias

# Pulls toward the goal-side of the nearest dangerous opponent (rather than
# just toward the ball) whenever the opponent has possession, so a defender
# marks a run instead of ball-watching.
func get_marking_steering_force() -> Vector2:
	if not is_ball_possessed_by_opponent():
		return Vector2.ZERO
	var dangerous_opponent := get_nearest_dangerous_opponent()
	if dangerous_opponent == null:
		return Vector2.ZERO
	var own_goal_position := player.own_goal.get_center_target_position()
	var mark_position := dangerous_opponent.position.lerp(own_goal_position, MARKING_GOAL_SIDE_BLEND)
	var direction := player.position.direction_to(mark_position)
	var weight := get_bicircular_weight(player.position, mark_position, 20, 0.3, 150, 1)
	return weight * direction

# Picks the opponent closest to our own goal among those currently visible in
# opponent_detection_area (i.e. the most immediately dangerous attacker to
# track); falls back to the ball carrier itself if no opponent is in view yet.
func get_nearest_dangerous_opponent() -> Player:
	var opponents := opponent_detection_area.get_overlapping_bodies().filter(
		func(p: Player): return p.country != player.country
	)
	if opponents.is_empty():
		if ball.carrier != null and ball.carrier.country != player.country:
			return ball.carrier
		return null
	var own_goal_position := player.own_goal.get_center_target_position()
	opponents.sort_custom(func(a: Player, b: Player):
		return a.position.distance_squared_to(own_goal_position) < b.position.distance_squared_to(own_goal_position))
	return opponents[0]
