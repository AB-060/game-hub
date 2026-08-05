class_name AIBehaviorOffense
extends AIBehaviorField

# Phase 4: Offense adds forward runs into space (instead of the generic
# mirrored-spawn "assist formation" position), a higher shot appetite, and a
# simple crossing decision when carrying the ball near the byline/sideline.
const SHOT_PROBABILITY_OFFENSE := 0.45
const FEW_MARKERS_THRESHOLD := 1
const THROUGH_RUN_DEPTH := 0.55

# NOTE (uncertain, could not verify in Editor): there's no exposed pitch-width/
# sideline constant reachable from AI code (grepped for "pitch"/boundary nodes,
# found none) - only goal geometry (Goal.get_center_target_position/top/bottom)
# is available. This approximates "wide, near the byline" using the target
# goal's own center as a stand-in for the pitch's horizontal center line at
# that end, rather than true sideline distance. If the pitch is asymmetric or
# goals aren't centered on the pitch width, this heuristic will be off -
# recommend verifying against actual pitch/camera bounds in the Editor and
# tightening/loosening CROSSING_BYLINE_DISTANCE / CROSSING_WIDE_DISTANCE below.
const CROSSING_BYLINE_DISTANCE := 120.0
const CROSSING_WIDE_DISTANCE := 80.0

func get_shot_probability() -> float:
	return clampf(SHOT_PROBABILITY_OFFENSE * Settings.get_difficulty_multiplier(), 0.0, 1.0)

func decide_on_ball_action() -> void:
	if is_in_crossing_position():
		var cross_target := get_cross_target()
		if cross_target != null:
			perform_pass(cross_target)
			return
	super.decide_on_ball_action()

func is_in_crossing_position() -> bool:
	var target := player.target_goal.get_center_target_position()
	var horizontal_distance_to_byline := absf(player.position.x - target.x)
	var vertical_distance_from_center := absf(player.position.y - target.y)
	return horizontal_distance_to_byline < CROSSING_BYLINE_DISTANCE and vertical_distance_from_center > CROSSING_WIDE_DISTANCE

# Prefers whichever visible teammate stands most centrally near goal - i.e.
# a realistic cross target - over the nearest-in-view default.
func get_cross_target() -> Player:
	var target_goal_center := player.target_goal.get_center_target_position()
	var teammates_in_view : Array = teammate_detection_area.get_overlapping_bodies().filter(
		func(p: Player): return p != player and p.country == player.country
	)
	if teammates_in_view.is_empty():
		return null
	teammates_in_view.sort_custom(func(a: Player, b: Player):
		return a.position.distance_squared_to(target_goal_center) < b.position.distance_squared_to(target_goal_center))
	return teammates_in_view[0]

func get_assist_formation_steering_force() -> Vector2:
	if has_few_markers_nearby():
		return get_forward_run_steering_force()
	return super.get_assist_formation_steering_force()

func has_few_markers_nearby() -> bool:
	var opponents := opponent_detection_area.get_overlapping_bodies().filter(
		func(p: Player): return p.country != player.country
	)
	return opponents.size() <= FEW_MARKERS_THRESHOLD

# Runs into space ahead of the ball toward target_goal (a "through run"),
# rather than holding the mirrored-spawn assist-formation slot.
func get_forward_run_steering_force() -> Vector2:
	var target := player.target_goal.get_center_target_position()
	var run_target := ball.position.lerp(target, THROUGH_RUN_DEPTH)
	var direction := player.position.direction_to(run_target)
	var weight := get_bicircular_weight(player.position, run_target, 20, 0.2, 200, 1)
	return weight * direction
