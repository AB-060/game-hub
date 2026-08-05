class_name Ball
extends AnimatableBody2D

const BOUNCINESS := 0.8
const DISTANCE_HIGH_PASS := 90
const DURATION_TUMBLE_LOCK := 200
const DURATION_PASS_LOCK := 500
const KICKOFF_PASS_DISTANCE := 30.0
const TUMBLE_HEIGHT_VELOCITY := 3.0

enum State {CARRIED, FREEFORM, SHOT}

@export var friction_air : float
@export var friction_ground : float

@onready var animation_player : AnimationPlayer = %AnimationPlayer
@onready var ball_sprite : Sprite2D = %BallSprite
@onready var player_detection_area : Area2D = %PlayerDetectionArea
@onready var player_proximity_area : Area2D = %PlayerProximityArea
@onready var scoring_raycast : RayCast2D = %ScoringRaycast
@onready var shot_particles : GPUParticles2D = %ShotParticles

var carrier : Player = null
var current_state : BallState = null
var height := 0.0
var height_velocity := 0.0
var spawn_position := Vector2.ZERO
var state_factory := BallStateFactory.new()
var velocity := Vector2.ZERO

# Phase 8: same client-side interpolation approach as Player - see
# Player.network_target_position for the full explanation. The
# MultiplayerSynchronizer replicates into this property, and a networked,
# non-authority client lerps `position` toward it in _process() instead of
# snapping. Ball's own BallState subclasses (ball_state.gd's
# move_and_bounce()/process_gravity()) are additionally guarded there to
# stop moving position/height locally on a non-authority client, since
# unlike Player there's no single move_and_slide() call to gate.
const INTERP_SPEED := 15.0
var network_target_position := Vector2.ZERO

func _ready() -> void:
	switch_state(State.FREEFORM)
	spawn_position = position
	GameEvents.team_reset.connect(on_team_reset.bind())
	GameEvents.kickoff_started.connect(on_kickoff_started.bind())
	setup_multiplayer_replication()

# NOTE (uncertain, could not run the Editor to verify): same programmatic
# MultiplayerSynchronizer pattern as Player. Unlike Player, Ball's physics is
# driven entirely from its BallState subclasses (out of scope to modify per
# task constraints), not from a move_and_slide() call in this file, so there
# is no equivalent authority guard added here - on a networked client the
# ball's own BallState logic keeps running locally alongside the replicated
# position/velocity from the host. This could fight the replicated values
# and needs a real playtest; if it visibly jitters, the fix is to gate
# BallState's position/velocity writes the same way Player.move_and_slide()
# is gated above.
func setup_multiplayer_replication() -> void:
	if not NetworkManager.is_networked():
		return
	var sync := MultiplayerSynchronizer.new()
	# Phase 16: a real two-instance test found replication silently failing
	# ("Node not found" for every MultiplayerSynchronizer on the client) -
	# without an explicit name, Godot auto-generates one like
	# "@MultiplayerSynchronizer@62" using a creation-order-dependent global
	# counter, which is NOT guaranteed to match between the host's and
	# client's independently-built scene trees (they don't reach this point
	# through identical node-creation histories). An explicit, deterministic
	# name makes the resulting NodePath identical on both sides regardless
	# of creation-order timing.
	sync.name = "NetworkSync"
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:network_target_position"))
	config.add_property(NodePath(".:velocity"))
	config.add_property(NodePath(".:height"))
	sync.replication_config = config
	sync.set_multiplayer_authority(1, false)
	add_child(sync)
	network_target_position = position

func _process(delta: float) -> void:
	if NetworkManager.is_networked():
		if is_multiplayer_authority():
			network_target_position = position
		else:
			position = position.lerp(network_target_position, minf(1.0, INTERP_SPEED * delta))
	ball_sprite.position = Vector2.UP * height
	scoring_raycast.rotation = velocity.angle()
	
func switch_state(state: Ball.State, data: BallStateData = BallStateData.new()) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, data, player_detection_area, carrier, animation_player, ball_sprite, shot_particles)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "BallStateMachine"
	call_deferred("add_child", current_state)

func shoot(shot_velocity : Vector2, spin: float = 0.0) -> void:
	velocity = shot_velocity
	carrier = null
	switch_state(Ball.State.SHOT, BallStateData.build().set_spin(spin))

func tumble(tumble_velocity: Vector2) -> void:
	velocity = tumble_velocity
	carrier = null
	height_velocity = TUMBLE_HEIGHT_VELOCITY
	switch_state(Ball.State.FREEFORM, BallStateData.build().set_lock_duration(DURATION_TUMBLE_LOCK))

func pass_to(destination: Vector2, lock_duration: int = DURATION_PASS_LOCK) -> void:
	var direction := position.direction_to(destination)
	var distance := position.distance_to(destination)
	var intensity := sqrt(2 * distance * friction_ground)
	velocity = intensity * direction
	if distance > DISTANCE_HIGH_PASS:
		height_velocity = BallState.GRAVITY * distance / (1.85 * intensity)
	carrier = null
	switch_state(Ball.State.FREEFORM, BallStateData.build().set_lock_duration(lock_duration))

func stop() -> void:
	velocity = Vector2.ZERO

func can_air_interact() -> bool:
	return current_state != null and current_state.can_air_interact()

func can_air_connect(air_connect_min_height: float, air_connect_max_height: float) -> bool:
	return height >= air_connect_min_height and height <= air_connect_max_height

func is_headed_for_scoring_area(scoring_area: Area2D) -> bool:
	if not scoring_raycast.is_colliding():
		return false
	return scoring_raycast.get_collider() == scoring_area

func get_proximity_teammates_count(country: String) -> int:
	var players := player_proximity_area.get_overlapping_bodies()
	return players.filter(func(p: Player): return p.country == country).size()

func on_team_reset() -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	height = 0
	switch_state(State.FREEFORM)

func on_kickoff_started() -> void:
	pass_to(spawn_position + Vector2.DOWN * KICKOFF_PASS_DISTANCE, 0)
