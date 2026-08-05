class_name AIBehaviorGoalie
extends AIBehavior

const PROXIMITY_CONCERN := 10.0

# Phase 4: two small decision-making additions. Neither touches the
# catch/parry mechanic itself (that's Phase 3's BallStateFreeform logic,
# untouched here) - this only changes when the keeper leaves the goal line and
# what they do once they already have the ball in hand.
# How far out the keeper is willing to consider rushing a loose ball at all -
# keeps this an "sweeper-keeper coming for a clearly loose ball" behavior, not
# a keeper randomly wandering upfield.
const RUSH_OUT_MAX_DISTANCE := 200.0
# After gaining possession (a save/catch, or picking up a loose ball), how
# long the keeper holds it before auto-distributing to a nearby teammate,
# mirroring a real keeper releasing the ball quickly rather than standing on it.
const DISTRIBUTION_DELAY_MSEC := 800

var time_possession_started_msec := 0

func perform_ai_movement() -> void:
	var total_steering_force := Vector2.ZERO
	if player.has_ball():
		total_steering_force = Vector2.ZERO
	elif ball.carrier == null and should_rush_out():
		total_steering_force = get_rush_out_steering_force()
	else:
		total_steering_force = get_goalie_steering_force()
	total_steering_force = total_steering_force.limit_length(1.0)
	target_velocity = total_steering_force * player.speed

func perform_ai_decisions() -> void:
	if ball.is_headed_for_scoring_area(player.own_goal.get_scoring_area()):
		player.switch_state(Player.State.DIVING)
		return
	if player.has_ball():
		if time_possession_started_msec == 0:
			time_possession_started_msec = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - time_possession_started_msec > DISTRIBUTION_DELAY_MSEC:
			distribute()
	else:
		time_possession_started_msec = 0

func get_goalie_steering_force() -> Vector2:
	var top := player.own_goal.get_top_target_position()
	var bottom := player.own_goal.get_bottom_target_position()
	var center := player.spawn_position
	var target_y := clampf(ball.position.y, top.y, bottom.y)
	var destination := Vector2(center.x, target_y)
	var direction := player.position.direction_to(destination)
	var distance_to_destination := player.position.distance_to(destination)
	var weight := clampf(distance_to_destination / PROXIMITY_CONCERN, 0, 1)
	return weight * direction

# Comes off the line for a loose ball only when the keeper is strictly closer
# to it than every visible opponent - i.e. genuinely first to it, not a risky
# 50/50 - and it's within RUSH_OUT_MAX_DISTANCE so this doesn't turn into the
# keeper sprinting the length of the pitch.
func should_rush_out() -> bool:
	var distance_to_ball := player.position.distance_to(ball.position)
	if distance_to_ball > RUSH_OUT_MAX_DISTANCE:
		return false
	var opponents := opponent_detection_area.get_overlapping_bodies().filter(
		func(p: Player): return p.country != player.country
	)
	for opponent: Player in opponents:
		if opponent.position.distance_to(ball.position) <= distance_to_ball:
			return false
	return true

func get_rush_out_steering_force() -> Vector2:
	return player.position.direction_to(ball.position)

func distribute() -> void:
	time_possession_started_msec = 0
	var target := find_open_teammate()
	var data := PlayerStateData.build()
	if target != null:
		data = data.set_pass_target(target)
	player.switch_state(Player.State.PASSING, data)

func find_open_teammate() -> Player:
	var teammates_in_view : Array = teammate_detection_area.get_overlapping_bodies().filter(
		func(p: Player): return p != player and p.country == player.country
	)
	if teammates_in_view.is_empty():
		return null
	teammates_in_view.sort_custom(func(a: Player, b: Player):
		return a.position.distance_squared_to(player.position) < b.position.distance_squared_to(player.position))
	return teammates_in_view[0]
