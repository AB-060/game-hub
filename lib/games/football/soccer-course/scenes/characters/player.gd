class_name Player
extends CharacterBody2D

signal swap_requested(player: Player)

const BALL_CONTROL_HEIGHT_MAX := 10.0
const CONTROL_SCHEME_MAP : Dictionary = {
	ControlScheme.CPU: preload("res://assets/art/props/cpu.png"),
	ControlScheme.P1: preload("res://assets/art/props/1p.png"),
	ControlScheme.P2: preload("res://assets/art/props/2p.png"),
}
const GRAVITY := 8.0
const WALK_ANIM_THRESHOLD := 0.6

enum ControlScheme {CPU, P1, P2}
enum Role {GOALIE, DEFENSE, MIDFIELD, OFFENSE}
enum SkinColor {LIGHT, MEDIUM, DARK}
enum State {MOVING, TACKLING, RECOVERING, PREPPING_SHOT, SHOOTING, PASSING, HEADER, VOLLEY_KICK, BICYCLE_KICK, CHEST_CONTROL, HURT, DIVING, CELEBRATING, MOURNING, RESETING}

@export var ball : Ball
@export var control_scheme : ControlScheme
@export var own_goal : Goal
@export var power : float
@export var speed : float
@export var target_goal : Goal

@onready var animation_player : AnimationPlayer = %AnimationPlayer
@onready var ball_detection_area : Area2D = %BallDetectionArea
@onready var control_sprite : Sprite2D = %ControlSprite
@onready var goalie_hands_collider : CollisionShape2D = %GoalieHandsCollider
@onready var opponent_detection_area : Area2D = %OpponentDetectionArea
@onready var permanent_damage_emitter_area : Area2D = %PermanentDamageEmitterArea
@onready var player_sprite : Sprite2D = %PlayerSprite
@onready var root_particles : Node2D = %RootParticles
@onready var run_particles : GPUParticles2D = %RunParticles
@onready var tackle_damage_emitter_area : Area2D = %TackleDamageEmitterArea
@onready var teammate_detection_area : Area2D = %TeammateDetectionArea

var ai_behavior_factory := AIBehaviorFactory.new()
var country := ""
var current_ai_behavior : AIBehavior = null
var current_state: PlayerState = null
var fullname := ""
var heading := Vector2.RIGHT
var height := 0.0
var height_velocity := 0.0
var kickoff_position := Vector2.ZERO
var role := Player.Role.MIDFIELD
var skin_color := Player.SkinColor.MEDIUM
var spawn_position := Vector2.ZERO
var state_factory := PlayerStateFactory.new()
var weight_on_duty_steering := 0.0

# Phase 8: client-side interpolation target. The MultiplayerSynchronizer
# below replicates the host's authoritative position into THIS property
# (not into `position` directly), and only a networked, non-authority
# client lerps its own `position` toward it each frame in _process(). This
# is a simple "converge toward latest known state" smoothing, not full
# timestamped snapshot interpolation/extrapolation - it removes the old
# instant-teleport-on-sync-tick jitter without the complexity/risk of a
# buffered-snapshot approach that couldn't be verified without the Editor.
const INTERP_SPEED := 15.0
var network_target_position := Vector2.ZERO

func _ready() -> void:
	set_control_texture()
	setup_ai_behavior()
	set_shader_properties()
	setup_multiplayer_replication()
	permanent_damage_emitter_area.monitoring = role == Role.GOALIE
	goalie_hands_collider.disabled = role != Role.GOALIE
	tackle_damage_emitter_area.body_entered.connect(on_tackle_player.bind())
	permanent_damage_emitter_area.body_entered.connect(on_tackle_player.bind())
	spawn_position = position
	GameEvents.team_scored.connect(on_team_scored.bind())
	GameEvents.game_over.connect(on_game_over.bind())
	var initial_position := kickoff_position if country == GameManager.current_match.country_home else spawn_position
	switch_state(State.RESETING, PlayerStateData.build().set_reset_position(initial_position))

func _process(delta: float) -> void:
	flip_sprites()
	set_sprite_visibility()
	process_gravity(delta)
	# The host runs the authoritative physics for every player (both squads).
	# A networked client must not run its own move_and_slide for players it
	# doesn't own physics-authority over, since it would fight the values
	# replicated in from the host via the MultiplayerSynchronizer below.
	if not NetworkManager.is_networked() or is_multiplayer_authority():
		move_and_slide()
		if NetworkManager.is_networked() and is_multiplayer_authority():
			# Host side: keep the replicated target in lockstep with the
			# real, authoritative position every frame.
			network_target_position = position
	else:
		# Client side, non-authority: smooth toward the latest replicated
		# position instead of snapping to it (see network_target_position
		# above for the caveats on this approach).
		position = position.lerp(network_target_position, minf(1.0, INTERP_SPEED * delta))

# NOTE (uncertain, could not run the Editor to verify): this constructs a
# MultiplayerSynchronizer + SceneReplicationConfig purely in code. The
# property paths below assume NodePath(".") resolves to this Player node's
# own properties when the synchronizer is a direct child of it - this is the
# documented Godot 4 pattern but double check in the Editor that "position",
# "velocity" and "heading" replicate as expected, and that authority (peer 1,
# the host) is correctly recognized before relying on this for a real match.
func setup_multiplayer_replication() -> void:
	if not NetworkManager.is_networked():
		return
	var sync := MultiplayerSynchronizer.new()
	# Phase 16: see ball.gd's identical fix - an explicit, deterministic name
	# is required so the client's NodePath lookup for this synchronizer
	# matches the host's; without it, Godot's creation-order-dependent
	# auto-naming ("@MultiplayerSynchronizer@N") diverges between processes
	# and replication silently fails ("Node not found" on the client, found
	# via a real two-instance test, not by reading).
	sync.name = "NetworkSync"
	var config := SceneReplicationConfig.new()
	# Replicates into network_target_position, not position directly - see
	# that property's declaration above for why (client-side lerp target).
	config.add_property(NodePath(".:network_target_position"))
	config.add_property(NodePath(".:velocity"))
	config.add_property(NodePath(".:heading"))
	sync.replication_config = config
	sync.set_multiplayer_authority(1, false) # 1 == the host, Godot's server peer id
	add_child(sync)

func set_shader_properties() -> void:
	player_sprite.material.set_shader_parameter("skin_color", skin_color)
	var countries := DataLoader.get_countries()
	var country_color := countries.find(country)
	country_color = clampi(country_color, 0, countries.size() - 1)
	player_sprite.material.set_shader_parameter("team_color", country_color)

func initialize(context_position: Vector2, context_kickoff_position: Vector2, context_ball: Ball, context_own_goal: Goal, context_target_goal: Goal, context_player_data: PlayerResource, context_country: String) -> void:
	position = context_position
	# Avoids a one-frame lerp-toward-origin on a networked client before the
	# first replication packet arrives (see network_target_position above).
	network_target_position = context_position
	kickoff_position = context_kickoff_position
	ball = context_ball
	own_goal = context_own_goal
	target_goal = context_target_goal
	speed = context_player_data.speed
	power = context_player_data.power
	role = context_player_data.role
	skin_color = context_player_data.skin_color
	fullname = context_player_data.full_name
	heading = Vector2.LEFT if target_goal.position.x < position.x else Vector2.RIGHT
	country = context_country

func setup_ai_behavior() -> void:
	current_ai_behavior = ai_behavior_factory.get_ai_behavior(role)
	current_ai_behavior.setup(self, ball, opponent_detection_area, teammate_detection_area)
	current_ai_behavior.name = "AI Behavior"
	add_child(current_ai_behavior)

func switch_state(state: State, state_data: PlayerStateData = PlayerStateData.new()) -> void:
	if current_state != null:
		current_state.queue_free()
	current_state = state_factory.get_fresh_state(state)
	current_state.setup(self, state_data, animation_player, ball, teammate_detection_area, ball_detection_area, own_goal, target_goal, tackle_damage_emitter_area, current_ai_behavior)
	current_state.state_transition_requested.connect(switch_state.bind())
	current_state.name = "PlayerStateMachine: " + str(state)
	call_deferred("add_child", current_state)

func set_movement_animation() -> void:
	var vel_length := velocity.length()
	if vel_length < 1:
		animation_player.play("idle")
	elif vel_length < speed * WALK_ANIM_THRESHOLD:
		animation_player.play("walk")
	else:
		animation_player.play("run")

func process_gravity(delta: float) -> void:
	if height > 0:
		height_velocity -= GRAVITY * delta
		height += height_velocity
		if height <= 0:
			height = 0
	player_sprite.position = Vector2.UP * height

const HEADING_FLIP_THRESHOLD := 5.0

func set_heading() -> void:
	# Phase 2: a small deadzone around zero avoids the sprite flipping back
	# and forth when velocity.x oscillates near 0 (e.g. easing to a stop or
	# holding opposite inputs briefly) — below the threshold, keep the
	# current heading instead of flipping.
	if velocity.x > HEADING_FLIP_THRESHOLD:
		heading = Vector2.RIGHT
	elif velocity.x < -HEADING_FLIP_THRESHOLD:
		heading = Vector2.LEFT

func face_towards_target_goal() -> void:
	if not is_facing_target_goal():
		heading = heading * -1

func flip_sprites() -> void:
	if heading == Vector2.RIGHT:
		player_sprite.flip_h = false
		tackle_damage_emitter_area.scale.x = 1
		opponent_detection_area.scale.x = 1
		root_particles.scale.x = 1
	elif heading == Vector2.LEFT:
		player_sprite.flip_h = true
		tackle_damage_emitter_area.scale.x = -1
		opponent_detection_area.scale.x = -1
		root_particles.scale.x = -1

func set_control_scheme(scheme: ControlScheme) -> void:
	control_scheme = scheme
	set_control_texture()
	# Group membership lets UI (a sibling node with no direct reference to
	# any Player) cheaply find "the player P1 currently controls" for HUD
	# elements like the stamina bar, without threading a new reference
	# through ActorsContainer/WorldScreen/UI.
	if scheme == ControlScheme.P1:
		add_to_group("p1_controlled")
	else:
		if is_in_group("p1_controlled"):
			remove_from_group("p1_controlled")

func set_sprite_visibility() -> void:
	control_sprite.visible = has_ball() or not control_scheme == ControlScheme.CPU
	run_particles.emitting = Settings.particles_enabled and velocity.length() == speed

func get_hurt(hurt_origin: Vector2) -> void:
	switch_state(Player.State.HURT, PlayerStateData.build().set_hurt_direction(hurt_origin))

func has_ball() -> bool:
	return ball.carrier == self

func is_ready_for_kickoff() -> bool:
	return current_state != null and current_state.is_ready_for_kickoff()

func set_control_texture() -> void:
	control_sprite.texture = CONTROL_SCHEME_MAP[control_scheme]

func get_pass_request(player: Player) -> void:
	if ball.carrier == self and current_state != null and current_state.can_pass():
		switch_state(Player.State.PASSING, PlayerStateData.build().set_pass_target(player))

func is_facing_target_goal() -> bool:
	var direction_to_target_goal := position.direction_to(target_goal.position)
	return heading.dot(direction_to_target_goal) > 0

func can_carry_ball() -> bool:
	return current_state != null and current_state.can_carry_ball()

func on_tackle_player(player: Player) -> void:
	if player != self and player.country != country and player == ball.carrier:
		player.get_hurt(position.direction_to(player.position))

func on_animation_complete() -> void:
	if current_state != null:
		current_state.on_animation_complete()

func on_team_scored(team_scored_on: String) -> void:
	if country == team_scored_on:
		switch_state(Player.State.MOURNING)
	else:
		switch_state(Player.State.CELEBRATING)

func on_game_over(winning_team: String) -> void:
	if country == winning_team:
		switch_state(Player.State.CELEBRATING)
	else:
		switch_state(Player.State.MOURNING)

func control_ball() -> void:
	if ball.height > BALL_CONTROL_HEIGHT_MAX:
		switch_state(Player.State.CHEST_CONTROL)
