class_name PlayerStateMoving
extends PlayerState

const SPRINT_MULTIPLIER := 1.4

func _process(delta: float) -> void:
	if player.control_scheme == Player.ControlScheme.CPU:
		ai_behavior.process_ai(delta)
	else:
		handle_human_movement(delta)
	player.set_movement_animation()
	player.set_heading()


func handle_human_movement(delta: float) -> void:
	var direction := KeyUtils.get_input_vector(player.control_scheme)
	var effective_speed := player.speed
	# Phase 5: "auto sprint" just treats sprint as always-held when enabled,
	# on top of the existing manual sprint-button check.
	if Settings.auto_sprint_enabled or KeyUtils.is_action_pressed(player.control_scheme, KeyUtils.Action.SPRINT):
		effective_speed *= SPRINT_MULTIPLIER
	var target_velocity := direction * effective_speed
	var rate: float
	if target_velocity != Vector2.ZERO:
		rate = effective_speed / MovementTuning.ACCEL_TIME_TO_MAX
	else:
		rate = player.speed / MovementTuning.DECEL_TIME_TO_STOP
	player.velocity = player.velocity.move_toward(target_velocity, rate * delta)
	if player.velocity != Vector2.ZERO:
		teammate_detection_area.rotation = player.velocity.angle()

	if KeyUtils.is_action_just_pressed(player.control_scheme, KeyUtils.Action.PASS):
		if player.has_ball():
			transition_state(Player.State.PASSING)
		elif can_teammate_pass_ball():
			ball.carrier.get_pass_request(player)
		else:
			player.swap_requested.emit(player)

	elif KeyUtils.is_action_just_pressed(player.control_scheme, KeyUtils.Action.SHOOT):
		if player.has_ball():
			transition_state(Player.State.PREPPING_SHOT)
		elif ball.can_air_interact():
			if player.velocity == Vector2.ZERO:
				if player.is_facing_target_goal():
					transition_state(Player.State.VOLLEY_KICK)
				else:
					transition_state(Player.State.BICYCLE_KICK)
			else:
				transition_state(Player.State.HEADER)
		elif player.velocity != Vector2.ZERO:
			state_transition_requested.emit(Player.State.TACKLING)

func can_carry_ball() -> bool:
	return player.role != Player.Role.GOALIE

func can_teammate_pass_ball() -> bool:
	return ball.carrier != null and ball.carrier.country == player.country and ball.carrier.control_scheme == Player.ControlScheme.CPU
	
func can_pass() -> bool:
	return true
