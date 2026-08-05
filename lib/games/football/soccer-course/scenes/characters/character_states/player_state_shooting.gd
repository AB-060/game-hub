class_name PlayerStateShooting
extends PlayerState

func _enter_tree() -> void:
	animation_player.play("kick")

func on_animation_complete() -> void:
	if player.control_scheme == Player.ControlScheme.CPU:
		transition_state(Player.State.RECOVERING)
	else:
		transition_state(Player.State.MOVING)
	shoot_ball()

func shoot_ball() -> void:
	SoundPlayer.play(SoundPlayer.Sound.SHOT)
	# New this pass: real shot tracking for the Full-Time stats screen.
	# `player` is already in scope here (unlike BallStateShot, which never
	# receives a reference to who took the shot), so this is the cleanest
	# hook point - see GameEvents.shot_taken.
	GameEvents.shot_taken.emit(player.country)
	ball.shoot(state_data.shot_direction * state_data.shot_power, state_data.shot_spin)
