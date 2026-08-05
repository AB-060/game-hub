extends Node

# Settings autoload (registered in project.godot as "Settings", no class_name
# - matching an autoload's registration name to a class_name is the one
# recurring mistake this codebase's autoloads deliberately avoid, see
# DataLoader/GameEvents/GameManager/SoundPlayer/MusicPlayer/NetworkManager).
#
# Persists via Godot's ConfigFile API to user://settings.cfg. Fields use the
# "setter pushes immediately" pattern: changing a value through the exposed
# set_*() methods both applies the effect live (audio bus volume, particles
# flag, etc.) and calls save() right away, so nothing else needs to listen
# for a signal to stay in sync. A settings_changed signal is still emitted
# for anything that wants to react generically (e.g. the Settings screen
# refreshing its own displayed values).

signal settings_changed

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

enum Difficulty {EASY, NORMAL, HARD}

const DIFFICULTY_MULTIPLIERS := {
	Difficulty.EASY: 0.6,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.5,
}

# --- Audio ---
var master_volume := 1.0
var music_volume := 0.8
var music_enabled := true
var sfx_volume := 1.0
var sfx_enabled := true

# --- Graphics ---
var fps_limit := 60 # 0 = uncapped
var particles_enabled := true

# --- Controls ---
var haptics_enabled := true
var joystick_scale := 1.0
var button_scale := 1.0
var controls_opacity := 1.0
var controls_swapped := false
var invert_movement_x := false
var invert_movement_y := false
var joystick_sensitivity := 1.0 # 0.5 .. 2.0

# --- Gameplay ---
var difficulty : Difficulty = Difficulty.NORMAL
var match_duration_sec : int = GameManager.DURATION_GAME_SEC
var auto_sprint_enabled := false
var camera_zoom := 1.0
var camera_follow_speed := 1.0 # multiplier on Camera's SMOOTHING_BALL_* constants, 0.5..2.0
var camera_shake_enabled := true
var slow_motion_enabled := true

# --- Language ---
var language := "en"

# --- Profile ---
# No account/profile system exists - this is just a plain, editable display
# name shown in the multiplayer lobby (and broadcast in the LAN discovery
# beacon), never derived from a device identifier (that would be a privacy-
# unfriendly default for something shown to other players on the network).
var player_name := "Player"

# ---------------------------------------------------------------------------
# Defaults, kept in one place so "Reset to defaults" (see reset_to_defaults()
# below) has a single source of truth to restore from, rather than
# duplicating literal values that could drift from the `var` declarations
# above.
# ---------------------------------------------------------------------------
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 0.8
const DEFAULT_MUSIC_ENABLED := true
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_SFX_ENABLED := true
const DEFAULT_FPS_LIMIT := 60
const DEFAULT_PARTICLES_ENABLED := true
const DEFAULT_HAPTICS_ENABLED := true
const DEFAULT_JOYSTICK_SCALE := 1.0
const DEFAULT_BUTTON_SCALE := 1.0
const DEFAULT_CONTROLS_OPACITY := 1.0
const DEFAULT_CONTROLS_SWAPPED := false
const DEFAULT_INVERT_MOVEMENT_X := false
const DEFAULT_INVERT_MOVEMENT_Y := false
const DEFAULT_JOYSTICK_SENSITIVITY := 1.0
const DEFAULT_DIFFICULTY := Difficulty.NORMAL
const DEFAULT_AUTO_SPRINT_ENABLED := false
const DEFAULT_CAMERA_ZOOM := 1.0
const DEFAULT_CAMERA_FOLLOW_SPEED := 1.0
const DEFAULT_CAMERA_SHAKE_ENABLED := true
const DEFAULT_SLOW_MOTION_ENABLED := true
const DEFAULT_LANGUAGE := "en"
const DEFAULT_PLAYER_NAME := "Player"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	load_settings()
	_apply_audio()

# ---------------------------------------------------------------------------
# Audio buses. Created at runtime (idempotent - safe to call every launch)
# rather than hand-editing default_bus_layout.tres, which is a structured
# resource we can't validate without the Editor. default_bus_layout.tres
# still only defines bus 0 ("Master"); Music/SFX are added on top of it here.
# ---------------------------------------------------------------------------
func _ensure_audio_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

func _apply_audio() -> void:
	_apply_master_volume()
	_apply_music_volume()
	_apply_sfx_volume()

func _apply_master_volume() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(master_volume, 0.0, 1.0)))

func _apply_music_volume() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(music_volume, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, not music_enabled)

func _apply_sfx_volume() -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(sfx_volume, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, not sfx_enabled)

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()
	save()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music_volume()
	save()

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	_apply_music_volume()
	save()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_sfx_volume()
	save()

func set_sfx_enabled(value: bool) -> void:
	sfx_enabled = value
	_apply_sfx_volume()
	save()

# ---------------------------------------------------------------------------
# Graphics
# ---------------------------------------------------------------------------
func set_fps_limit(value: int) -> void:
	fps_limit = value
	Engine.max_fps = value
	save()

func set_particles_enabled(value: bool) -> void:
	particles_enabled = value
	save()
	settings_changed.emit()

# ---------------------------------------------------------------------------
# Controls. Live-push to the current TouchControls instance (if any) via the
# "touch_controls" group, since TouchControls is constructed at runtime by
# UI, not something Settings holds a direct reference to.
# ---------------------------------------------------------------------------
func set_haptics_enabled(value: bool) -> void:
	haptics_enabled = value
	var tc := _get_touch_controls()
	if tc != null:
		tc.haptics_enabled = value
	save()

func set_joystick_scale(value: float) -> void:
	joystick_scale = value
	var tc := _get_touch_controls()
	if tc != null:
		tc.joystick_scale = value
	save()

func set_button_scale(value: float) -> void:
	button_scale = value
	var tc := _get_touch_controls()
	if tc != null:
		tc.button_scale = value
	save()

func set_controls_opacity(value: float) -> void:
	controls_opacity = value
	var tc := _get_touch_controls()
	if tc != null:
		tc.controls_opacity = value
	save()

# NOTE: controls_swapped changes which side the joystick/buttons are built
# on. TouchControls only lays this out once, in _ready(), so an in-flight
# TouchControls instance won't visually reposition until the next time one
# is constructed (e.g. next match/screen). The value itself still persists
# correctly and is picked up on the very next TouchControls._ready().
func set_controls_swapped(value: bool) -> void:
	controls_swapped = value
	save()

func set_invert_movement_x(value: bool) -> void:
	invert_movement_x = value
	save()

func set_invert_movement_y(value: bool) -> void:
	invert_movement_y = value
	save()

func set_joystick_sensitivity(value: float) -> void:
	joystick_sensitivity = clampf(value, 0.5, 2.0)
	save()

func _get_touch_controls() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("touch_controls")

# ---------------------------------------------------------------------------
# Gameplay
# ---------------------------------------------------------------------------
func get_difficulty_multiplier() -> float:
	return DIFFICULTY_MULTIPLIERS.get(difficulty, 1.0)

func set_difficulty(value: Difficulty) -> void:
	difficulty = value
	save()

func set_match_duration_sec(value: int) -> void:
	match_duration_sec = value
	save()

func set_auto_sprint_enabled(value: bool) -> void:
	auto_sprint_enabled = value
	save()

func set_camera_zoom(value: float) -> void:
	camera_zoom = value
	save()
	settings_changed.emit()

# camera.gd reads this directly (Settings.camera_follow_speed) as a
# multiplier on its SMOOTHING_BALL_CARRIED/SMOOTHING_BALL_DEFAULT constants -
# no live-push plumbing needed since Camera reads Settings every _process()
# frame already (process_ball_follow()), same as it already does for
# Settings.camera_zoom.
func set_camera_follow_speed(value: float) -> void:
	camera_follow_speed = clampf(value, 0.5, 2.0)
	save()

# camera.gd's on_impact_received() reads this directly before starting a
# shake, same "read live from Settings" pattern as camera_follow_speed.
func set_camera_shake_enabled(value: bool) -> void:
	camera_shake_enabled = value
	save()

# goal.gd's _maybe_apply_goal_slow_motion() reads this directly, in addition
# to its existing non-networked-only guard.
func set_slow_motion_enabled(value: bool) -> void:
	slow_motion_enabled = value
	save()

func set_player_name(value: String) -> void:
	var trimmed := value.strip_edges()
	player_name = trimmed if not trimmed.is_empty() else DEFAULT_PLAYER_NAME
	save()

# ---------------------------------------------------------------------------
# Presets. Each one is an honest shortcut that only calls the same real
# setters a player could click individually in the Settings screen - no new
# rendering/quality behavior is invented here, see README for the exact
# bundle each preset applies.
# "Performance Mode": disable particles, cap FPS at 30, disable camera shake.
# "Battery Saver": same as Performance Mode, plus also disabling haptics
# (vibration draws power too) - a strictly more conservative bundle.
# ---------------------------------------------------------------------------
func apply_performance_mode() -> void:
	set_particles_enabled(false)
	set_fps_limit(30)
	set_camera_shake_enabled(false)

func apply_battery_saver() -> void:
	apply_performance_mode()
	set_haptics_enabled(false)

# ---------------------------------------------------------------------------
# Reset to defaults. Goes through the same set_*() setters used elsewhere
# (rather than just assigning the raw fields and calling save() once) so
# every live-effect hookup (audio buses, Engine.max_fps, TouchControls group
# push, etc.) actually re-applies too, not just persists.
# ---------------------------------------------------------------------------
func reset_to_defaults() -> void:
	set_master_volume(DEFAULT_MASTER_VOLUME)
	set_music_volume(DEFAULT_MUSIC_VOLUME)
	set_music_enabled(DEFAULT_MUSIC_ENABLED)
	set_sfx_volume(DEFAULT_SFX_VOLUME)
	set_sfx_enabled(DEFAULT_SFX_ENABLED)
	set_fps_limit(DEFAULT_FPS_LIMIT)
	set_particles_enabled(DEFAULT_PARTICLES_ENABLED)
	set_haptics_enabled(DEFAULT_HAPTICS_ENABLED)
	set_joystick_scale(DEFAULT_JOYSTICK_SCALE)
	set_button_scale(DEFAULT_BUTTON_SCALE)
	set_controls_opacity(DEFAULT_CONTROLS_OPACITY)
	set_controls_swapped(DEFAULT_CONTROLS_SWAPPED)
	set_invert_movement_x(DEFAULT_INVERT_MOVEMENT_X)
	set_invert_movement_y(DEFAULT_INVERT_MOVEMENT_Y)
	set_joystick_sensitivity(DEFAULT_JOYSTICK_SENSITIVITY)
	set_difficulty(DEFAULT_DIFFICULTY)
	set_match_duration_sec(GameManager.DURATION_GAME_SEC)
	set_auto_sprint_enabled(DEFAULT_AUTO_SPRINT_ENABLED)
	set_camera_zoom(DEFAULT_CAMERA_ZOOM)
	set_camera_follow_speed(DEFAULT_CAMERA_FOLLOW_SPEED)
	set_camera_shake_enabled(DEFAULT_CAMERA_SHAKE_ENABLED)
	set_slow_motion_enabled(DEFAULT_SLOW_MOTION_ENABLED)
	set_language(DEFAULT_LANGUAGE)
	set_player_name(DEFAULT_PLAYER_NAME)

# ---------------------------------------------------------------------------
# Language. Named `t()` rather than `tr()` to avoid any confusion with
# GDScript's built-in global tr() (Godot's TranslationServer-driven
# translation function) - this is a small, self-authored lookup table, not
# a TranslationServer/.tres pipeline (see Localization.LOCALES for why).
# ---------------------------------------------------------------------------
func set_language(value: String) -> void:
	language = value
	save()
	settings_changed.emit()

func t(key: String) -> String:
	return Localization.get_text(key, language)

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return # no save yet, or unreadable - keep defaults
	master_volume = config.get_value(SECTION, "master_volume", master_volume)
	music_volume = config.get_value(SECTION, "music_volume", music_volume)
	music_enabled = config.get_value(SECTION, "music_enabled", music_enabled)
	sfx_volume = config.get_value(SECTION, "sfx_volume", sfx_volume)
	sfx_enabled = config.get_value(SECTION, "sfx_enabled", sfx_enabled)
	fps_limit = config.get_value(SECTION, "fps_limit", fps_limit)
	particles_enabled = config.get_value(SECTION, "particles_enabled", particles_enabled)
	haptics_enabled = config.get_value(SECTION, "haptics_enabled", haptics_enabled)
	joystick_scale = config.get_value(SECTION, "joystick_scale", joystick_scale)
	button_scale = config.get_value(SECTION, "button_scale", button_scale)
	controls_opacity = config.get_value(SECTION, "controls_opacity", controls_opacity)
	controls_swapped = config.get_value(SECTION, "controls_swapped", controls_swapped)
	invert_movement_x = config.get_value(SECTION, "invert_movement_x", invert_movement_x)
	invert_movement_y = config.get_value(SECTION, "invert_movement_y", invert_movement_y)
	joystick_sensitivity = config.get_value(SECTION, "joystick_sensitivity", joystick_sensitivity)
	difficulty = config.get_value(SECTION, "difficulty", difficulty) as Difficulty
	match_duration_sec = config.get_value(SECTION, "match_duration_sec", match_duration_sec)
	auto_sprint_enabled = config.get_value(SECTION, "auto_sprint_enabled", auto_sprint_enabled)
	camera_zoom = config.get_value(SECTION, "camera_zoom", camera_zoom)
	camera_follow_speed = config.get_value(SECTION, "camera_follow_speed", camera_follow_speed)
	camera_shake_enabled = config.get_value(SECTION, "camera_shake_enabled", camera_shake_enabled)
	slow_motion_enabled = config.get_value(SECTION, "slow_motion_enabled", slow_motion_enabled)
	language = config.get_value(SECTION, "language", language)
	player_name = config.get_value(SECTION, "player_name", player_name)
	Engine.max_fps = fps_limit

func save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "master_volume", master_volume)
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "music_enabled", music_enabled)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "sfx_enabled", sfx_enabled)
	config.set_value(SECTION, "fps_limit", fps_limit)
	config.set_value(SECTION, "particles_enabled", particles_enabled)
	config.set_value(SECTION, "haptics_enabled", haptics_enabled)
	config.set_value(SECTION, "joystick_scale", joystick_scale)
	config.set_value(SECTION, "button_scale", button_scale)
	config.set_value(SECTION, "controls_opacity", controls_opacity)
	config.set_value(SECTION, "controls_swapped", controls_swapped)
	config.set_value(SECTION, "invert_movement_x", invert_movement_x)
	config.set_value(SECTION, "invert_movement_y", invert_movement_y)
	config.set_value(SECTION, "joystick_sensitivity", joystick_sensitivity)
	config.set_value(SECTION, "difficulty", difficulty)
	config.set_value(SECTION, "match_duration_sec", match_duration_sec)
	config.set_value(SECTION, "auto_sprint_enabled", auto_sprint_enabled)
	config.set_value(SECTION, "camera_zoom", camera_zoom)
	config.set_value(SECTION, "camera_follow_speed", camera_follow_speed)
	config.set_value(SECTION, "camera_shake_enabled", camera_shake_enabled)
	config.set_value(SECTION, "slow_motion_enabled", slow_motion_enabled)
	config.set_value(SECTION, "language", language)
	config.set_value(SECTION, "player_name", player_name)
	config.save(SAVE_PATH)
	settings_changed.emit()
