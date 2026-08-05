class_name Goal
extends Node2D

# Phase 6: confetti "goal celebration" VFX, built entirely from the existing
# white-circle.png particle texture (no new art) - a handful of small
# Sprite2D "pieces" tinted per-instance via modulate, tweened to fall/rotate/
# fade, then queue_free'd. Gated by Settings.particles_enabled like every
# other particle effect in this project.
const CONFETTI_TEXTURE := preload("res://assets/art/particles/white-circle.png")
const CONFETTI_COLORS := [
	Color(1.0, 0.85, 0.2), Color(0.2, 0.7, 1.0), Color(1.0, 0.3, 0.3),
	Color(0.3, 1.0, 0.4), Color(1.0, 1.0, 1.0),
]
const CONFETTI_PIECE_COUNT := 10
const CONFETTI_FALL_DISTANCE := 40.0
const CONFETTI_DURATION := 0.7
# Phase 9: pool sized to 2x a single celebration's piece count so a second
# goal scored while the first goal's confetti is still fading (back-to-back
# goals) doesn't have to fall back to allocating extra pieces.
const CONFETTI_POOL_SIZE := CONFETTI_PIECE_COUNT * 2

@onready var back_net_area := %BackNetArea
@onready var scoring_area := %ScoringArea
@onready var targets := %Targets

var country := ""

# Phase 9: pre-built, reusable confetti pieces (perf) - see spawn_confetti()/
# _acquire_confetti_piece()/_release_confetti_piece() below. Built unconditionally
# in _ready() (cheap: a handful of hidden Sprite2D nodes) even if particles are
# currently disabled, since Settings.particles_enabled can be toggled live from
# the Settings screen mid-match and the pool should already be ready to use.
var confetti_pool : Array[Sprite2D] = []

func _ready() -> void:
	back_net_area.body_entered.connect(on_ball_enter_back_net.bind())
	scoring_area.body_entered.connect(on_ball_enter_scoring_area.bind())
	_build_confetti_pool()

func initialize(context_country: String) -> void:
	country = context_country

func on_ball_enter_back_net(ball: Ball) -> void:
	ball.stop()

func on_ball_enter_scoring_area(_ball: Ball) -> void:
	# Phase 8: host-authoritative scoring. On a networked CLIENT this Area2D
	# is watching the client's own replicated (network-delayed, unsmoothed)
	# copy of the ball, which can trip the goal at a slightly different
	# moment than the host - or miss it entirely if a jittery position
	# update skips past the area between sync ticks - so the client must not
	# independently decide a goal happened here. Only the host (or a
	# non-networked local match, where this whole branch is moot since
	# is_networked() is false) detects goals from its own authoritative
	# ball, then explicitly tells the client via RPC below. The client's own
	# GameEvents.team_scored listeners (GameStateInPlay, Player.on_team_scored,
	# UI, etc.) still run exactly as before, just triggered by that RPC
	# (see NetworkManager._rpc_team_scored) instead of by local detection.
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	SoundPlayer.play(SoundPlayer.Sound.WHISTLE)
	spawn_confetti()
	# `country` here is the Goal's own country (whose net the ball just hit,
	# i.e. the conceding side) - the scoring side is the other one. A goal
	# is inherently "on target", so this counts toward shots-on-target for
	# whichever country actually scored, same real definition documented on
	# GameEvents.shot_on_target.
	var scoring_country := GameManager.current_match.country_home if country == GameManager.current_match.country_away else GameManager.current_match.country_away
	GameEvents.shot_on_target.emit(scoring_country)
	GameEvents.team_scored.emit(country)
	if NetworkManager.is_networked() and NetworkManager.is_host():
		NetworkManager.rpc_team_scored(country)
	_maybe_apply_goal_slow_motion()

const SLOW_MOTION_TIME_SCALE := 0.3
const SLOW_MOTION_DURATION_SEC := 0.5

# New this pass: a brief slow-motion hold right after a goal. Guarded to
# local (non-networked) play only - Engine.time_scale affects every
# _process(delta) in the whole game (physics, AI ticks, animations), and if
# applied on a networked match it would desync from the host-authoritative
# clock/score sync built in an earlier networking phase (GameStateInPlay's
# _sync_clock_if_due, NetworkManager's RPCs, etc.), none of which expect
# their own timing to suddenly slow down independently on one peer. The
# restore timer below deliberately uses `ignore_time_scale = true` (the 4th
# arg to create_tree().create_timer()) - a normal Timer/SceneTreeTimer
# would itself run in slowed-down time while Engine.time_scale is 0.3,
# meaning it would take 1 / 0.3 times longer in real wall-clock time to
# fire and restore time_scale back to 1.0. This one intentionally always
# ticks at real speed so it reliably restores time_scale after
# SLOW_MOTION_DURATION_SEC of real time, not scaled time.
func _maybe_apply_goal_slow_motion() -> void:
	if NetworkManager.is_networked():
		return
	if not Settings.slow_motion_enabled:
		return
	Engine.time_scale = SLOW_MOTION_TIME_SCALE
	var timer := get_tree().create_timer(SLOW_MOTION_DURATION_SEC, true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
	)

func _build_confetti_pool() -> void:
	for i in range(CONFETTI_POOL_SIZE):
		var piece := Sprite2D.new()
		piece.texture = CONFETTI_TEXTURE
		piece.visible = false
		add_child(piece)
		confetti_pool.append(piece)

# Returns an idle (invisible) pooled piece, or - if every pooled piece is
# currently mid-animation (e.g. an unusually fast string of goals) - grows
# the pool with one more piece rather than skipping the effect. Growth is
# rare in practice given CONFETTI_POOL_SIZE already covers 2 overlapping
# celebrations.
func _acquire_confetti_piece() -> Sprite2D:
	for piece in confetti_pool:
		if not piece.visible:
			return piece
	var piece := Sprite2D.new()
	piece.texture = CONFETTI_TEXTURE
	add_child(piece)
	confetti_pool.append(piece)
	return piece

func _release_confetti_piece(piece: Sprite2D) -> void:
	piece.visible = false

func spawn_confetti() -> void:
	if not Settings.particles_enabled:
		return
	for i in range(CONFETTI_PIECE_COUNT):
		var piece := _acquire_confetti_piece()
		# A reused piece may still have a live tween from a previous
		# celebration (pool-growth fallback aside, this shouldn't normally
		# happen since a piece is only reacquired once idle/invisible, but
		# kill defensively before reconfiguring it - same "kill existing
		# tween before starting a new one" rule used elsewhere in this
		# project, e.g. touch_controls.gd's `_run_scale_tween`).
		if piece.has_meta("confetti_tween"):
			var old_tween : Tween = piece.get_meta("confetti_tween")
			if old_tween != null and old_tween.is_valid():
				old_tween.kill()
		piece.modulate = CONFETTI_COLORS[i % CONFETTI_COLORS.size()]
		piece.scale = Vector2(0.3, 0.3)
		piece.rotation = 0.0
		# piece is a child of this Goal node, so its position is already
		# relative to Goal's own origin - adding Goal's own `position` here
		# would double-count that offset and spawn confetti far outside the
		# pitch (Goal nodes sit at substantial non-zero local positions, e.g.
		# (818, 220) for the away goal in world_screen.tscn).
		piece.position = Vector2(randf_range(-20.0, 20.0), randf_range(-60.0, -20.0))
		piece.visible = true
		var tween := create_tween()
		piece.set_meta("confetti_tween", tween)
		tween.set_parallel(true)
		var end_position := piece.position + Vector2(randf_range(-15.0, 15.0), CONFETTI_FALL_DISTANCE)
		tween.tween_property(piece, "position", end_position, CONFETTI_DURATION)
		tween.tween_property(piece, "rotation", randf_range(-4.0, 4.0), CONFETTI_DURATION)
		tween.tween_property(piece, "modulate:a", 0.0, CONFETTI_DURATION).set_delay(CONFETTI_DURATION * 0.4)
		tween.chain().tween_callback(_release_confetti_piece.bind(piece))

func get_random_target_position() -> Vector2:
	return targets.get_child(randi_range(0, targets.get_child_count() - 1)).global_position

func get_center_target_position() -> Vector2:
	return targets.get_child(int(targets.get_child_count() / 2.0)).global_position

func get_top_target_position() -> Vector2:
	return targets.get_child(0).global_position

func get_bottom_target_position() -> Vector2:
	return targets.get_child(targets.get_child_count() - 1).global_position

func get_scoring_area() -> Area2D:
	return scoring_area
