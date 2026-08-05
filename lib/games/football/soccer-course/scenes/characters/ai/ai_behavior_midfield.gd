class_name AIBehaviorMidfield
extends AIBehaviorField

# Phase 4: Midfield keeps the base outfield behavior (it was already closest
# to right for this role) and layers on two things: pressing the ball
# carrier/loose ball when this player is one of the nearest teammates to it,
# and picking the most open teammate to pass to instead of just the nearest
# one in view.
const PRESS_INNER_RADIUS := 40.0
const PRESS_INNER_WEIGHT := 1.0
const PRESS_OUTER_RADIUS := 120.0
const PRESS_OUTER_WEIGHT := 0.0
const PRESS_WEIGHT := 0.7

func get_onduty_steering_force() -> Vector2:
	var base := super.get_onduty_steering_force()
	return base + get_pressing_steering_force()

# Self-contained "am I one of the pressers" check: rather than reusing/
# extending ActorsContainer's weight_on_duty_steering ranking (which would
# require touching actors_container.gd), this reuses the same
# get_bicircular_weight helper the rest of the steering system already uses,
# just at a tighter radius centered on the ball/opponent carrier. Players far
# from the ball naturally get ~0 weight here, so only the players already
# closest to the ball press aggressively - no extra ranking pass needed.
func get_pressing_steering_force() -> Vector2:
	if ball.carrier != null and ball.carrier.country == player.country:
		return Vector2.ZERO
	var press_weight := get_bicircular_weight(player.position, ball.position, PRESS_INNER_RADIUS, PRESS_INNER_WEIGHT, PRESS_OUTER_RADIUS, PRESS_OUTER_WEIGHT)
	var direction := player.position.direction_to(ball.position)
	return PRESS_WEIGHT * press_weight * direction

func perform_pass(_pass_target: Player = null) -> void:
	super.perform_pass(get_open_pass_target())

# Cheap passing-lane approximation: among teammates currently in view, prefer
# whichever has the fewest opponents in ITS OWN opponent_detection_area
# (opponent_detection_area is a public @onready var on Player, so this is
# reachable without a large new system). Falls back to null (nearest-in-view,
# handled by PlayerStatePassing) if no teammates are in view.
func get_open_pass_target() -> Player:
	var teammates_in_view : Array = teammate_detection_area.get_overlapping_bodies().filter(
		func(p: Player): return p != player and p.country == player.country
	)
	if teammates_in_view.is_empty():
		return null
	teammates_in_view.sort_custom(func(a: Player, b: Player):
		return count_nearby_opponents(a) < count_nearby_opponents(b))
	return teammates_in_view[0]

func count_nearby_opponents(teammate: Player) -> int:
	if teammate.opponent_detection_area == null:
		return 0
	var nearby := teammate.opponent_detection_area.get_overlapping_bodies()
	return nearby.filter(func(p: Player): return p.country != teammate.country).size()
