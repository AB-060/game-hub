class_name BallStateFreeform
extends BallState

const MAX_CAPTURE_HEIGHT := 25

# NOTE (uncertain, could not verify feel in Editor): thresholds below are a
# conservative "feel" choice, not measured from actual gameplay. Shot speeds
# in this project range roughly ~100 (a tapped, unhurried shot from a low
# power stat) up to ~380 (a fully charged shot from a high power stat, see
# player_state_prepping_shot.gd's shot_power bonus curve and the power
# stats in assets/json/squads.json, which range ~100-188). MAX_CATCH_SPEED
# is set comfortably below the top of that range so only firmly-struck
# shots get parried instead of caught, and MAX_CATCH_HEIGHT is tighter than
# MAX_CAPTURE_HEIGHT so a goalkeeper diving/reaching for a ball that is too
# high in the air spills it rather than pulling off an improbable grab.
const MAX_CATCH_SPEED := 220.0
const MAX_CATCH_HEIGHT := 15.0
const PARRY_SPEED_RETAINED := 0.45

var time_since_freeform := Time.get_ticks_msec()

func _enter_tree() -> void:
	player_detection_area.body_entered.connect(on_player_enter.bind())
	time_since_freeform = Time.get_ticks_msec()

func on_player_enter(body: Player) -> void:
	if not body.can_carry_ball() or ball.height >= MAX_CAPTURE_HEIGHT:
		return
	if body.role == Player.Role.GOALIE:
		_maybe_record_shot_on_target(body)
		if not is_clean_catch(body):
			parry(body)
			return
	ball.carrier = body
	body.control_ball()
	transition_state(Ball.State.CARRIED)

# "Shot on target" = a shot that reaches a goalkeeper's hands (catch or
# parry) shortly after being taken, per the definition documented on
# GameEvents.shot_on_target. GameManager.last_shot_country/
# last_shot_time_msec (set from player_state_shooting.gd's shoot_ball())
# provide a short real-time window so a goalie simply picking up a loose
# ball long after the last shot doesn't get miscounted as a save. Only
# counts when the shot came from the OPPOSING country to this keeper -
# a keeper's own teammate's misdirected pass back to them is not a shot.
func _maybe_record_shot_on_target(goalie: Player) -> void:
	var attacking_country := GameManager.last_shot_country
	if attacking_country == "" or attacking_country == goalie.country:
		return
	if GameManager.is_within_shot_on_target_window(attacking_country):
		GameEvents.shot_on_target.emit(attacking_country)
		# A "save" is this exact same event (goalkeeper catch/parry of an
		# on-target shot), attributed to the goalkeeper's own country.
		GameEvents.save_made.emit(goalie.country)

# A goalkeeper "catches" cleanly whenever the ball is coming in slow/low
# enough to be controlled (whether picking up a loose/rolling ball or
# gathering a soft shot). A fast/high ball reaching the keeper's hands
# during a dive specifically is treated as a save attempt under pressure,
# which raises the bar further (tighter speed/height thresholds) since a
# diving save is inherently less controlled than a routine gather - see
# parry() below for what happens when either bar isn't met.
func is_clean_catch(body: Player) -> bool:
	var is_diving := body.current_state != null and body.current_state is PlayerStateDiving
	var speed_limit : float = MAX_CATCH_SPEED * 0.6 if is_diving else MAX_CATCH_SPEED
	var height_limit : float = MAX_CATCH_HEIGHT * 0.6 if is_diving else MAX_CATCH_HEIGHT
	return ball.velocity.length() <= speed_limit and ball.height <= height_limit

# A hard/high shot that reaches the keeper is spilled rather than caught:
# the ball rebounds away from the goal at a shallow random angle instead of
# stopping dead in the keeper's hands, mirroring a real parried save that
# can lead to a rebound chance. Distinct from move_and_bounce()'s generic
# physical bounce (used for posts/ground/etc.) because this is specifically
# a goalkeeper contact event, not a collision with static geometry.
func parry(body: Player) -> void:
	var away_from_goal := body.position.direction_to(body.own_goal.get_center_target_position()) * -1
	var deflection := away_from_goal.rotated(randf_range(-0.6, 0.6))
	ball.velocity = deflection * ball.velocity.length() * PARRY_SPEED_RETAINED
	SoundPlayer.play(SoundPlayer.Sound.BOUNCE)

func _process(delta: float) -> void:
	player_detection_area.monitoring = (Time.get_ticks_msec() - time_since_freeform > state_data.lock_duration)
	set_ball_animation_from_velocity()
	var friction := ball.friction_air if ball.height > 0 else ball.friction_ground
	ball.velocity = ball.velocity.move_toward(Vector2.ZERO, friction * delta)
	process_gravity(delta, ball.BOUNCINESS)
	move_and_bounce(delta)

func can_air_interact() -> bool:
	return true
