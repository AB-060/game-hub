class_name BallStateShot
extends BallState

const DURATION_SHOT := 1000
const SHOT_HEIGHT := 5
const SHOT_SPRITE_SCALE := 0.8

# Phase 6: a lightweight code-built Line2D trail behind fast-moving shots.
# No new art needed - just points sampled from the ball's own position each
# frame, capped in length and faded via width taper, gated by
# Settings.particles_enabled like the existing shot_particles.
const TRAIL_MAX_POINTS := 12
const TRAIL_WIDTH := 4.0
const TRAIL_COLOR := Color(1.0, 1.0, 1.0, 0.5)

var time_since_shot := Time.get_ticks_msec()
var trail : Line2D = null

func _enter_tree() -> void:
	set_ball_animation_from_velocity()
	sprite.scale.y = SHOT_SPRITE_SCALE
	ball.height = SHOT_HEIGHT
	time_since_shot = Time.get_ticks_msec()
	shot_particles.emitting = Settings.particles_enabled
	GameEvents.impact_received.emit(ball.position, true)
	if Settings.particles_enabled and ball.get_parent() != null:
		trail = Line2D.new()
		trail.width = TRAIL_WIDTH
		trail.default_color = TRAIL_COLOR
		trail.width_curve = Curve.new()
		trail.width_curve.add_point(Vector2(0, 0))
		trail.width_curve.add_point(Vector2(1, 1))
		trail.z_index = -1
		ball.get_parent().add_child(trail)

func _process(delta: float) -> void:
	var elapsed := Time.get_ticks_msec() - time_since_shot
	update_trail()
	if elapsed > DURATION_SHOT:
		transition_state(Ball.State.FREEFORM)
	else:
		apply_curve(delta, elapsed)
		move_and_bounce(delta)

func update_trail() -> void:
	if trail == null:
		return
	trail.add_point(ball.global_position)
	while trail.get_point_count() > TRAIL_MAX_POINTS:
		trail.remove_point(0)

# Bends the shot's velocity sideways over time to simulate a curved/spinning
# shot, without a full 3D Magnus-force simulation. state_data.spin (set via
# PlayerStateData.set_shot_spin in player_state_prepping_shot.gd) is a signed
# "curl" amount; it is applied as an acceleration perpendicular to the
# ball's current velocity, and fades out linearly across DURATION_SHOT so
# the ball settles onto a straight line again once the "kick" has worn off,
# rather than curving indefinitely.
func apply_curve(delta: float, elapsed: int) -> void:
	if state_data.spin == 0.0 or ball.velocity == Vector2.ZERO:
		return
	var decay := 1.0 - (float(elapsed) / DURATION_SHOT)
	var perpendicular := ball.velocity.normalized().orthogonal()
	ball.velocity += perpendicular * state_data.spin * decay * delta

func _exit_tree() -> void:
	sprite.scale.y = 1.0
	shot_particles.emitting = false
	fade_out_trail()

# Left in the scene tree (not a child of this state, which is about to be
# freed) so it can finish fading after the shot state ends; tweened to
# transparent then queue_free'd so it never lingers/leaks.
func fade_out_trail() -> void:
	if trail == null:
		return
	# Tween created from `trail` itself (not `self`, which is this BallState
	# node and is about to be freed right after _exit_tree) so the fade
	# isn't killed along with the state that spawned it.
	var tween := trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.25)
	tween.tween_callback(trail.queue_free)
