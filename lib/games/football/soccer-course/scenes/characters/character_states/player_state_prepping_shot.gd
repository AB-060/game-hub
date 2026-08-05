class_name PlayerStatePreppingShot
extends PlayerState

const DURATION_MAX_BONUS := 1000.0
const EASE_REWARD_FACTOR := 2.0
# How strongly sideways aim adjustment while charging translates into ball
# spin. Kept low on purpose (see ball_state_shot.gd for how spin bends the
# trajectory) - this is a "feel" tuning value chosen without playtesting,
# so it errs on the subtle side rather than risking an exaggerated curve.
const SPIN_SENSITIVITY := 4.0
const MAX_SPIN := 60.0

var initial_heading := Vector2.ZERO
var shot_direction := Vector2.ZERO
var time_start_shot := Time.get_ticks_msec()

func _enter_tree() -> void:
	animation_player.play("prep_kick")
	player.velocity = Vector2.ZERO
	time_start_shot = Time.get_ticks_msec()
	shot_direction = player.heading
	initial_heading = player.heading

func _process(delta: float) -> void:
	shot_direction += KeyUtils.get_input_vector(player.control_scheme) * delta
	if KeyUtils.is_action_just_released(player.control_scheme, KeyUtils.Action.SHOOT):
		var duration_press := clampf(Time.get_ticks_msec() - time_start_shot, 0.0, DURATION_MAX_BONUS)
		var ease_time := duration_press / DURATION_MAX_BONUS
		var bonus := ease(ease_time, EASE_REWARD_FACTOR)
		var shot_power := player.power * (1 + bonus)
		# Signed lateral drift accumulated while aiming (positive = the aim
		# was nudged clockwise relative to the initial heading, negative =
		# counter-clockwise). This becomes the shot's curve/spin, so tapping
		# the aim stick sideways while charging a shot bends its flight path
		# the same direction, similar to "curling" a shot.
		var lateral_drift := initial_heading.cross(shot_direction)
		var spin := clampf(lateral_drift * SPIN_SENSITIVITY, -MAX_SPIN, MAX_SPIN)
		shot_direction = shot_direction.normalized()
		var data = PlayerStateData.build().set_shot_power(shot_power).set_shot_direction(shot_direction).set_shot_spin(spin)
		transition_state(Player.State.SHOOTING, data)
		
func can_pass() -> bool:
	return true
