class_name UI
extends CanvasLayer

const STAMINA_BAR_WIDTH := 40.0
const STAMINA_DRAIN_RATE := 0.35 # fraction of bar per second while sprinting
const STAMINA_REGEN_RATE := 0.2
const TOAST_DURATION := 1.4

@onready var animation_player : AnimationPlayer = %AnimationPlayer
@onready var flag_textures : Array[TextureRect] = [%HomeFlagTexture, %AwayFlagTexture]
@onready var goal_scorer_label : Label = %GoalScorerLabel
@onready var player_label : Label = %PlayerLabel
@onready var score_info_label : Label = %ScoreInfoLabel
@onready var score_label : Label = %ScoreLabel
@onready var time_label : Label = %TimeLabel
@onready var ui_container : Control = $UIContainer

var last_ball_carrier := ""

# Possession tracking: cheapest correct hook available is
# GameEvents.ball_possessed_by_country (added this phase, emitted alongside
# the existing ball_possessed signal from BallStateCarried) rather than
# inventing a parallel possession system. Tracked as accumulated seconds per
# team while a country holds the ball; loose-ball time counts toward neither
# side, matching how real possession stats usually work.
var _possession_home_seconds := 0.0
var _possession_away_seconds := 0.0
var _possessing_country := ""
var _possession_bar_home : ColorRect = null
var _possession_bar_away : ColorRect = null
const POSSESSION_BAR_WIDTH := 50.0

# Stamina is purely visual for now (see task notes: gating sprint by
# stamina is a Phase 2-sized gameplay change). It reflects whatever Player
# is currently in the "p1_controlled" group (see Player.set_control_scheme).
var _stamina := 1.0
var _stamina_bar_fill : ColorRect = null
var _stamina_bar_bg : ColorRect = null

# Card indicators: no foul/tackle-card system exists anywhere in this
# codebase yet (checked GameEvents and the player_state_* scripts - tackling
# only ever triggers get_hurt(), nothing card-related). These stay hidden
# and are only here so a future foul-detection system (out of scope for a
# HUD-redesign phase) has somewhere to plug in.
var _yellow_card_icon : ColorRect = null
var _red_card_icon : ColorRect = null

var _toast_label : Label = null
var _pause_menu : PauseMenu = null
var _full_time_screen : FullTimeScreen = null
var _goal_scale_tween : Tween = null

func _ready() -> void:
	update_score()
	update_flags()
	update_clock()
	player_label.text = ""
	GameEvents.ball_possessed.connect(on_ball_possessed.bind())
	GameEvents.ball_possessed_by_country.connect(on_ball_possessed_by_country.bind())
	GameEvents.ball_released.connect(on_ball_released.bind())
	GameEvents.score_changed.connect(on_score_changed.bind())
	GameEvents.team_scored.connect(on_team_scored_record.bind())
	GameEvents.team_reset.connect(on_team_reset.bind())
	GameEvents.game_over.connect(on_game_over.bind())
	build_hud_extras()
	setup_touch_controls()
	setup_network_hud()

func setup_touch_controls() -> void:
	# Phase 1: always instantiate TouchControls (Android is the primary
	# target, and desktop testing wants full UI parity too) instead of only
	# on DisplayServer.is_touchscreen_available(). TouchControls only ever
	# drives Input actions, so keyboard input keeps working simultaneously -
	# nothing downstream cares which source pressed an action.
	var touch_controls := TouchControls.new()
	add_child(touch_controls)
	touch_controls.pause_requested.connect(open_pause_menu)

func build_hud_extras() -> void:
	_build_possession_bar()
	_build_stamina_bar()
	_build_card_icons()
	_build_toast_label()

func _build_possession_bar() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.position = Vector2(6, 6)
	bg.size = Vector2(POSSESSION_BAR_WIDTH, 4)
	ui_container.add_child(bg)

	_possession_bar_home = ColorRect.new()
	_possession_bar_home.color = Color(0.9, 0.85, 0.2, 0.9)
	_possession_bar_home.position = Vector2(6, 6)
	_possession_bar_home.size = Vector2(POSSESSION_BAR_WIDTH * 0.5, 4)
	ui_container.add_child(_possession_bar_home)

	_possession_bar_away = ColorRect.new()
	_possession_bar_away.color = Color(0.2, 0.6, 0.9, 0.9)
	_possession_bar_away.position = Vector2(6 + POSSESSION_BAR_WIDTH * 0.5, 6)
	_possession_bar_away.size = Vector2(POSSESSION_BAR_WIDTH * 0.5, 4)
	ui_container.add_child(_possession_bar_away)

func _build_stamina_bar() -> void:
	_stamina_bar_bg = ColorRect.new()
	_stamina_bar_bg.color = Color(0, 0, 0, 0.4)
	_stamina_bar_bg.position = Vector2(6, 14)
	_stamina_bar_bg.size = Vector2(STAMINA_BAR_WIDTH, 3)
	ui_container.add_child(_stamina_bar_bg)

	_stamina_bar_fill = ColorRect.new()
	_stamina_bar_fill.color = Color(0.3, 0.9, 0.4, 0.9)
	_stamina_bar_fill.position = Vector2(6, 14)
	_stamina_bar_fill.size = Vector2(STAMINA_BAR_WIDTH, 3)
	_stamina_bar_fill.visible = false
	ui_container.add_child(_stamina_bar_fill)

func _build_card_icons() -> void:
	_yellow_card_icon = ColorRect.new()
	_yellow_card_icon.color = Color(0.95, 0.85, 0.1, 1.0)
	_yellow_card_icon.size = Vector2(5, 7)
	_yellow_card_icon.position = Vector2(230, 6)
	_yellow_card_icon.visible = false # awaiting a future foul-detection system
	ui_container.add_child(_yellow_card_icon)

	_red_card_icon = ColorRect.new()
	_red_card_icon.color = Color(0.85, 0.1, 0.1, 1.0)
	_red_card_icon.size = Vector2(5, 7)
	_red_card_icon.position = Vector2(238, 6)
	_red_card_icon.visible = false # awaiting a future foul-detection system
	ui_container.add_child(_red_card_icon)

var _ping_label : Label = null

# Phase 8: tiny persistent corner label showing the custom-measured
# ping/pong RTT (see NetworkManager._rpc_ping/_rpc_pong) - only relevant,
# and only shown, during a networked match. Cheapest correct integration
# point: piggyback on ui_container like the other small HUD widgets above
# rather than building a dedicated scene/screen for one label.
func setup_network_hud() -> void:
	if not NetworkManager.is_networked():
		return
	_ping_label = Label.new()
	_ping_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ping_label.position = Vector2(-40, 6)
	_ping_label.size = Vector2(36, 10)
	_ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ping_label.add_theme_font_size_override("font_size", 8)
	_ping_label.text = ""
	ui_container.add_child(_ping_label)
	NetworkManager.ping_updated.connect(_on_ping_updated)

func _on_ping_updated(rtt_msec: int) -> void:
	if _ping_label != null:
		_ping_label.text = "%d ms" % rtt_msec

func _build_toast_label() -> void:
	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_label.position = Vector2(0, 20)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate = Color(1, 1, 1, 0)
	_toast_label.text = ""
	ui_container.add_child(_toast_label)

# Generic reusable toast/banner, e.g. show_notification("GOAL!", 1.5). Kept
# small and self-contained so later phases (cards, substitutions, half time,
# etc.) can reuse it without building their own popup each time.
func show_notification(text: String, duration: float = TOAST_DURATION) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	var tween := create_tween()
	tween.tween_property(_toast_label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(duration)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.3)

func _process(delta: float) -> void:
	update_clock()
	_update_possession(delta)
	_update_stamina(delta)

func update_score() -> void:
	score_label.text = ScoreHelper.get_score_text(GameManager.current_match)

func update_flags() -> void:
	for i in flag_textures.size():
		var countries := [GameManager.current_match.country_home, GameManager.current_match.country_away]
		flag_textures[i].texture = FlagHelper.get_texture(countries[i])

func update_clock() -> void:
	if GameManager.time_left < 0:
		time_label.modulate = Color.YELLOW
	time_label.text = TimeHelper.get_time_text(GameManager.time_left)

func _update_possession(delta: float) -> void:
	if _possessing_country == "":
		return
	if GameManager.current_match == null:
		return
	if _possessing_country == GameManager.current_match.country_home:
		_possession_home_seconds += delta
	elif _possessing_country == GameManager.current_match.country_away:
		_possession_away_seconds += delta
	var total := _possession_home_seconds + _possession_away_seconds
	var home_ratio := 0.5 if total <= 0.0 else _possession_home_seconds / total
	if _possession_bar_home != null:
		_possession_bar_home.size.x = POSSESSION_BAR_WIDTH * home_ratio
		_possession_bar_away.position.x = 6 + POSSESSION_BAR_WIDTH * home_ratio
		_possession_bar_away.size.x = POSSESSION_BAR_WIDTH * (1.0 - home_ratio)

func _update_stamina(delta: float) -> void:
	if _stamina_bar_fill == null:
		return
	var controlled_player : Player = get_tree().get_first_node_in_group("p1_controlled")
	if controlled_player == null:
		_stamina_bar_fill.visible = false
		return
	_stamina_bar_fill.visible = true
	var is_sprinting := KeyUtils.is_action_pressed(Player.ControlScheme.P1, KeyUtils.Action.SPRINT) and controlled_player.velocity.length() > 1.0
	if is_sprinting:
		_stamina = max(0.0, _stamina - STAMINA_DRAIN_RATE * delta)
	else:
		_stamina = min(1.0, _stamina + STAMINA_REGEN_RATE * delta)
	_stamina_bar_fill.size.x = STAMINA_BAR_WIDTH * _stamina
	_stamina_bar_fill.color = Color(0.9, 0.2, 0.2, 0.9) if _stamina < 0.25 else Color(0.3, 0.9, 0.4, 0.9)

func on_ball_possessed(player_name: String) -> void:
	player_label.text = player_name
	last_ball_carrier = player_name

func on_ball_possessed_by_country(country: String) -> void:
	_possessing_country = country

func on_ball_released() -> void:
	player_label.text = ""
	_possessing_country = ""

func on_score_changed() -> void:
	if not GameManager.is_time_up():
		goal_scorer_label.text = "%s SCORED!" % [last_ball_carrier]
		score_info_label.text = ScoreHelper.get_current_score_info(GameManager.current_match)
		animation_player.play("goal_appear")
		show_notification("GOAL!")
		_animate_goal_text()
	update_score()

# Real data recorder, not display: GameEvents.team_scored fires BEFORE
# score_changed (see GameStateScored._enter_tree -> GameManager.
# increase_score -> score_changed, itself triggered by GameStateInPlay's
# team_scored listener transitioning to SCORED), so last_ball_carrier is
# still the name of the player who just scored when this runs. `country`
# here is the conceding side (see goal.gd); the scoring side is the other
# team in the current Match.
func on_team_scored_record(country_scored_on: String) -> void:
	if GameManager.current_match == null:
		return
	var scoring_country := GameManager.current_match.country_home if country_scored_on == GameManager.current_match.country_away else GameManager.current_match.country_away
	GameManager.current_match.record_goal_scorer(scoring_country, last_ball_carrier)
	# Assist heuristic: a completed pass to this scoring team, by a different
	# player than the scorer, within GameManager.ASSIST_WINDOW_MSEC of the
	# goal. Best-effort, same honesty bar as shots-on-target - not a perfect
	# "led directly to the goal" classifier (e.g. an intervening tackle/
	# dribble between the pass and the goal isn't distinguished).
	if not GameManager.last_pass_player_name.is_empty() and GameManager.last_pass_player_name != last_ball_carrier and GameManager.is_within_assist_window(scoring_country):
		GameManager.current_match.record_assist(scoring_country, GameManager.last_pass_player_name)

# Small polish: a bigger/bolder scale-in for the existing goal_scorer_label
# on top of whatever the "goal_appear" AnimationPlayer clip already does,
# not a new notification system. Tween created from goal_scorer_label
# itself (the longest-lived relevant node - it's a permanent HUD label),
# killed before replacing so back-to-back goals don't stack tweens.
func _animate_goal_text() -> void:
	if _goal_scale_tween != null and _goal_scale_tween.is_valid():
		_goal_scale_tween.kill()
	goal_scorer_label.pivot_offset = goal_scorer_label.size * 0.5
	goal_scorer_label.scale = Vector2(1.6, 1.6)
	_goal_scale_tween = goal_scorer_label.create_tween()
	_goal_scale_tween.tween_property(goal_scorer_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_team_reset() -> void:
	if GameManager.current_match.has_someone_scored():
		animation_player.play("goal_hide")

func on_game_over(_country_winner: String) -> void:
	score_info_label.text = ScoreHelper.get_final_score_info(GameManager.current_match)
	animation_player.play("game_over")
	show_notification("FULL TIME")
	_open_full_time_screen()

func _open_full_time_screen() -> void:
	if _full_time_screen != null:
		return
	_full_time_screen = FullTimeScreen.new()
	add_child(_full_time_screen)
	_full_time_screen.continue_requested.connect(_on_full_time_continue)
	_full_time_screen.play_again_requested.connect(_on_full_time_play_again)
	_full_time_screen.menu_requested.connect(_on_full_time_menu)

func _on_full_time_continue() -> void:
	_full_time_screen = null
	var world_screen := get_parent() as WorldScreen
	if world_screen != null:
		world_screen.on_transition()

func _on_full_time_play_again() -> void:
	_full_time_screen = null
	if GameManager.current_match != null:
		GameManager.current_match = Match.new(GameManager.current_match.country_home, GameManager.current_match.country_away)
	var world_screen := get_parent() as Screen
	if world_screen != null:
		world_screen.transition_screen(SoccerGame.ScreenType.IN_GAME, world_screen.screen_data)

func _on_full_time_menu() -> void:
	_full_time_screen = null
	var world_screen := get_parent() as Screen
	if world_screen != null:
		world_screen.transition_screen(SoccerGame.ScreenType.MAIN_MENU)

func open_pause_menu() -> void:
	if _pause_menu != null:
		return
	get_tree().paused = true
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.resumed.connect(_on_pause_resumed)
	_pause_menu.restart_requested.connect(_on_pause_restart)
	_pause_menu.quit_requested.connect(_on_pause_quit)

func _on_pause_resumed() -> void:
	get_tree().paused = false
	_pause_menu = null

func _on_pause_restart() -> void:
	get_tree().paused = false
	_pause_menu = null
	# A plain re-transition to IN_GAME would reuse the same Match object
	# (via GameManager.current_match), carrying the old score over - build a
	# fresh 0-0 Match for the same two countries so "Restart Match" actually
	# restarts the score too, not just the clock/positions.
	if GameManager.current_match != null:
		GameManager.current_match = Match.new(GameManager.current_match.country_home, GameManager.current_match.country_away)
	var world_screen := get_parent() as Screen
	if world_screen != null:
		world_screen.transition_screen(SoccerGame.ScreenType.IN_GAME, world_screen.screen_data)

func _on_pause_quit() -> void:
	get_tree().paused = false
	_pause_menu = null
	# Phase 8: quitting a networked match should actually disconnect (ENet
	# peer torn down, discovery/broadcast stopped) rather than just
	# transitioning this side's screen while still technically connected -
	# which would leave the other side stuck with a peer that stopped
	# responding instead of a clean "opponent disconnected" notice.
	if NetworkManager.is_networked():
		NetworkManager.disconnect_network()
	var world_screen := get_parent() as Screen
	if world_screen != null:
		world_screen.transition_screen(SoccerGame.ScreenType.MAIN_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		open_pause_menu()
		get_viewport().set_input_as_handled()
