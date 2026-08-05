class_name BallStateCarried
extends BallState

const DRIBBLE_FREQUENCY := 10.0
const DRIBBLE_INTENSITY := 3.0
const OFFSET_FROM_PLAYER := Vector2(10, 4)

var dribble_time := 0.0

func _enter_tree() -> void:
	assert(carrier != null)
	GameEvents.ball_possessed.emit(carrier.fullname)
	GameEvents.ball_possessed_by_country.emit(carrier.country)
	# Pass-completion detection: best-effort proxy, see GameEvents.
	# pass_completed's doc comment - a different player than the passer, same
	# country, taking possession shortly after a pass was attempted.
	if GameManager.is_within_pass_completion_window(carrier.country) and carrier.fullname != GameManager.last_pass_player_name:
		GameEvents.pass_completed.emit(carrier.country)

func _process(delta: float) -> void:
	var vx := 0.0
	dribble_time += delta

	if carrier.velocity != Vector2.ZERO:
		# Phase 2: scale the dribble wobble with how fast the carrier is
		# actually moving (relative to their base speed, so sprinting -
		# which can exceed 1.0 via player_state_moving's sprint multiplier -
		# reads as a faster, slightly tighter dribble rather than the same
		# wobble regardless of pace).
		var speed_ratio := clampf(carrier.velocity.length() / max(carrier.speed, 1.0), 0.0, 1.4)
		if carrier.velocity.x != 0:
			var frequency := DRIBBLE_FREQUENCY * (0.7 + 0.3 * speed_ratio)
			var intensity := DRIBBLE_INTENSITY * (0.6 + 0.4 * speed_ratio)
			vx = cos(dribble_time * frequency) * intensity
		if carrier.heading.x >= 0:
			animation_player.play("roll")
			animation_player.advance(0)
		else:
			animation_player.play_backwards("roll")
			animation_player.advance(0)
	else:
		animation_player.play("idle")
	process_gravity(delta)
	# Phase 8: only the authoritative side snaps the ball to the carrier -
	# on a non-authority client, ball.position is instead lerped toward the
	# replicated network_target_position in Ball._process(), so writing it
	# here too would fight that every frame (see ball_state.gd's
	# move_and_bounce()/process_gravity() for the equivalent guard).
	if NetworkManager.is_networked() and not ball.is_multiplayer_authority():
		return
	ball.position = carrier.position + Vector2(vx + carrier.heading.x * OFFSET_FROM_PLAYER.x, OFFSET_FROM_PLAYER.y)

func _exit_tree() -> void:
	GameEvents.ball_released.emit()
