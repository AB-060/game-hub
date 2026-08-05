class_name MainMenuScreen
extends Screen

# UI/UX pass: menu grew from 2 baked items (1 Player / 2 Players, positioned
# in main_menu_screen.tscn) to up to 6 (+ Multiplayer, Tournament, Settings,
# Exit), all built programmatically like MULTIPLAYER_ICON already was, per
# the "no hand-edited .tscn for new items" convention. Keyboard nav
# (change_selected_index/KeyUtils) still works unchanged since it only reads
# selectable_menu_nodes.size(); touch/mouse selection is new (see
# _connect_item_input below) since these TextureRects previously had no
# input handling of their own at all, only keyboard-driven texture swaps.

const MENU_TEXTURES := [
	[preload("res://assets/art/ui/mainmenu/1-player.png"), preload("res://assets/art/ui/mainmenu/1-player-selected.png")],
	[preload("res://assets/art/ui/mainmenu/2-players.png"), preload("res://assets/art/ui/mainmenu/2-players-selected.png")],
]
# No dedicated art assets exist under assets/art/ui/mainmenu/ for Multiplayer,
# Tournament, Settings or Exit, so the existing "options" icon is reused
# (tinted via modulate, same as the pre-existing Multiplayer item) with a
# small text Label layered on top for each new item so they stay visually
# distinct from one another without fabricating new art.
const SHARED_ICON := preload("res://assets/art/ui/mainmenu/options.png")
const SHARED_ICON_SELECTED := preload("res://assets/art/ui/mainmenu/options-selected.png")

const PRESS_SCALE := 0.85
const PRESS_ANIM_DURATION := 0.08

# Parallel to selectable_menu_nodes: what submit_selection() should do for
# each index. Populated as items are added (baked "single"/"two" first, then
# whatever _add_extra_menu_items() appends).
enum ItemKind {SINGLE_PLAYER, TWO_PLAYERS, MULTIPLAYER, TOURNAMENT, SETTINGS, ABOUT, CREDITS, PROFILE, EXIT}

@onready var selectable_menu_nodes : Array[TextureRect] = [%SinglePlayerTexture, %TwoPlayersTexture]
@onready var selection_icon : TextureRect = %SelectionIcon

var current_selected_index := 0
var is_active := false
var _lobby : MultiplayerLobby = null
var _settings_screen : SettingsScreen = null
var _info_screen : InfoScreen = null
var _item_kinds : Array[ItemKind] = [ItemKind.SINGLE_PLAYER, ItemKind.TWO_PLAYERS]
var _item_tweens : Dictionary = {} # TextureRect -> Tween

func _ready() -> void:
	# The keyboard-hint illustrations (WASD/arrow diagrams) are hidden from
	# code rather than removed from the .tscn, per this project's established
	# "no hand-edited .tscn" convention - MenuAnimationPlayer's "start"
	# animation only touches their `modulate` alpha, never `visible`, so
	# setting visible = false here isn't fought by that animation.
	# unique_name_in_owner is only set on SinglePlayerTexture/TwoPlayersTexture/
	# SelectionIcon in the .tscn (checked directly), not on these two, so `%`
	# access isn't available for them - use the explicit node path instead.
	var player_one_controls := $Background/PlayerOneControls as TextureRect
	var player_two_controls := $Background/PlayerTwoControls as TextureRect
	if player_one_controls != null:
		player_one_controls.visible = false
	if player_two_controls != null:
		player_two_controls.visible = false

	# No config/version (or similar) key exists in project.godot, and no
	# version label exists anywhere in this screen today - rather than
	# fabricate a version string, this is simply skipped.

	_add_extra_menu_items()
	for i in range(selectable_menu_nodes.size()):
		_connect_item_input(selectable_menu_nodes[i], i)
	refresh_ui()

func _add_extra_menu_items() -> void:
	_add_icon_menu_item("Multiplayer", ItemKind.MULTIPLAYER)
	_add_icon_menu_item("Tournament", ItemKind.TOURNAMENT)
	_add_icon_menu_item("Settings", ItemKind.SETTINGS)
	_add_icon_menu_item("Profile", ItemKind.PROFILE)
	_add_icon_menu_item("About", ItemKind.ABOUT)
	_add_icon_menu_item("Credits", ItemKind.CREDITS)
	# OS.has_feature("pc") is the Godot 4 feature tag covering Windows/macOS/
	# Linux desktop export targets (as opposed to "mobile"/"web"). Using the
	# positive "pc" check rather than `not OS.has_feature("mobile")` since a
	# desktop-only Quit item should also stay off web exports, which are
	# neither "pc" nor "mobile".
	if OS.has_feature("pc"):
		_add_icon_menu_item("Exit", ItemKind.EXIT)

func _add_icon_menu_item(label_text: String, kind: ItemKind) -> void:
	var texture_rect := TextureRect.new()
	texture_rect.texture = SHARED_ICON
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var last := selectable_menu_nodes[selectable_menu_nodes.size() - 1]
	# Compact vertical spacing (new items only - the two baked items keep
	# their .tscn-authored 100/125 positions and are also driven by
	# MenuAnimationPlayer's "start" animation, so they aren't repositioned
	# here) so up to 4 extra items still fit the 280x180 logical viewport.
	# This is an approximate layout only verifiable visually in the Editor.
	texture_rect.position = last.position + Vector2(0, 15)
	texture_rect.scale = Vector2(0.8, 0.8)
	texture_rect.pivot_offset = Vector2(10, 10)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 6)
	label.position = Vector2(24, 4)
	texture_rect.add_child(label)

	last.get_parent().add_child(texture_rect)
	selectable_menu_nodes.append(texture_rect)
	_item_kinds.append(kind)

# TextureRect is Control-derived even though this scene's root ("MainMenuScreen")
# is a plain Node, so gui_input still fires normally - Godot's GUI dispatch is
# driven by the Viewport finding Controls under the pointer, not by walking a
# Control-only ancestor chain. This is the cheapest option here (no manual
# InputEventScreenTouch position math needed, unlike TouchControls, which
# has no Control ancestor tree to lean on at all).
func _connect_item_input(texture_rect: TextureRect, index: int) -> void:
	texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	texture_rect.set_meta("_base_scale", texture_rect.scale if texture_rect.scale != Vector2.ZERO else Vector2.ONE)
	# Center the scale/press-animation pivot on the item's own footprint
	# (baked items already have a real .tscn-authored size; the dynamically
	# added ones set theirs before this runs) so the press-scale shrinks
	# toward the middle of each icon, not its top-left corner.
	if texture_rect.pivot_offset == Vector2.ZERO and texture_rect.size != Vector2.ZERO:
		texture_rect.pivot_offset = texture_rect.size * 0.5
	texture_rect.gui_input.connect(_on_item_gui_input.bind(texture_rect, index))

func _on_item_gui_input(event: InputEvent, texture_rect: TextureRect, index: int) -> void:
	if not is_active:
		return
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
	if pressed:
		change_selected_index(index)
		_animate_item_press(texture_rect)
	elif released:
		_animate_item_release(texture_rect)
		submit_selection()

# Reuses TouchControls' exact scale-tween press/release pattern (kill any
# prior tween on this control before starting a new one, tween created from
# a node that outlives it - here the TextureRect itself, which persists for
# the whole menu's lifetime) rather than inventing a different animation
# style. Also brightens modulate briefly as a subtle "glow" on press, purely
# via Tween/CanvasItem.modulate - no new art, no StyleBoxFlat needed since
# these are textured icons, not code-drawn circles like TouchControls'.
func _animate_item_press(texture_rect: TextureRect) -> void:
	var base_scale : Vector2 = texture_rect.get_meta("_base_scale", Vector2.ONE)
	_run_item_tween(texture_rect, base_scale * PRESS_SCALE, Color(1.3, 1.3, 1.3))

func _animate_item_release(texture_rect: TextureRect) -> void:
	var base_scale : Vector2 = texture_rect.get_meta("_base_scale", Vector2.ONE)
	_run_item_tween(texture_rect, base_scale, Color(1, 1, 1))

func _run_item_tween(texture_rect: TextureRect, target_scale: Vector2, target_modulate: Color) -> void:
	var existing : Tween = _item_tweens.get(texture_rect)
	if existing != null and existing.is_valid():
		existing.kill()
	var tween := texture_rect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(texture_rect, "scale", target_scale, PRESS_ANIM_DURATION)
	tween.tween_property(texture_rect, "modulate", target_modulate, PRESS_ANIM_DURATION)
	_item_tweens[texture_rect] = tween

func _process(_delta: float) -> void:
	if is_active:
		if KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.UP):
			change_selected_index(current_selected_index - 1)
		elif KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.DOWN):
			change_selected_index(current_selected_index + 1)
		elif KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.SHOOT):
			submit_selection()

func refresh_ui() -> void:
	for i in range(selectable_menu_nodes.size()):
		var textures : Array = MENU_TEXTURES[i] if i < MENU_TEXTURES.size() else [SHARED_ICON, SHARED_ICON_SELECTED]
		if current_selected_index == i:
			selectable_menu_nodes[i].texture = textures[1]
			selection_icon.position = selectable_menu_nodes[i].position + Vector2.LEFT * 25
		else:
			selectable_menu_nodes[i].texture = textures[0]

func change_selected_index(new_index) -> void:
	current_selected_index = clamp(new_index, 0, selectable_menu_nodes.size() - 1)
	SoundPlayer.play(SoundPlayer.Sound.UI_NAV)
	refresh_ui()

func submit_selection() -> void:
	SoundPlayer.play(SoundPlayer.Sound.UI_SELECT)
	var kind := _item_kinds[current_selected_index]
	match kind:
		ItemKind.MULTIPLAYER:
			open_multiplayer_lobby()
		ItemKind.SETTINGS:
			open_settings_screen()
		ItemKind.ABOUT:
			open_about_screen()
		ItemKind.CREDITS:
			open_credits_screen()
		ItemKind.PROFILE:
			open_profile_screen()
		ItemKind.EXIT:
			get_tree().quit()
		ItemKind.TOURNAMENT:
			# Mirrors the existing "1 Player" setup exactly: a single flag
			# selector in team_selection_screen.gd (player_setup[1] left
			# empty) already funnels into Tournament.new() once the player
			# picks their country, via on_selector_selected()'s else branch -
			# that's the only Tournament entry point that exists anywhere in
			# this codebase today, so this item reuses it verbatim rather
			# than inventing a second one.
			var country_default := DataLoader.get_countries()[1]
			GameManager.player_setup = [country_default, ""]
			transition_screen(SoccerGame.ScreenType.TEAM_SELECTION)
		_:
			var country_default := DataLoader.get_countries()[1]
			var player_two := "" if kind == ItemKind.SINGLE_PLAYER else country_default
			GameManager.player_setup = [country_default, player_two]
			transition_screen(SoccerGame.ScreenType.TEAM_SELECTION)

func open_multiplayer_lobby() -> void:
	is_active = false
	_lobby = MultiplayerLobby.new()
	add_child(_lobby)
	_lobby.cancelled.connect(_on_lobby_cancelled)
	NetworkManager.remote_ready_to_play.connect(_on_remote_ready_to_play)

func open_settings_screen() -> void:
	if _settings_screen != null:
		return
	is_active = false
	_settings_screen = SettingsScreen.new()
	add_child(_settings_screen)
	_settings_screen.closed.connect(_on_settings_closed)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_screen):
		_settings_screen.queue_free()
	_settings_screen = null
	is_active = true

# --- About / Credits / Profile ---
# Simple text overlays, same "add as CanvasLayer child overlay, never leave
# the main menu" pattern as Settings. All three share InfoScreen and
# _on_info_closed() below since they're just static text.

func open_about_screen() -> void:
	if _info_screen != null:
		return
	is_active = false
	var engine_info := Engine.get_version_info()
	var engine_version := "%d.%d.%d" % [engine_info.get("major", 0), engine_info.get("minor", 0), engine_info.get("patch", 0)]
	var body := "Super Soccer is a 2D football game built in Godot %s. Originally based on nicolasbize/soccer-course (MIT-licensed), extended with touch controls, a sprint mechanic, local co-op, an 8-team tournament, and local network multiplayer.\n\nPlay 1 Player against the CPU, 2 Players on one device, host or join a LAN Multiplayer match, or run through a full Tournament bracket." % engine_version
	_open_info_screen(Settings.t("about"), body)

func open_credits_screen() -> void:
	if _info_screen != null:
		return
	is_active = false
	var body := "Based on nicolasbize/soccer-course, MIT License, Copyright (c) 2025 Nicolas Bize. See LICENSE for the full text.\n\nExtended for Game Hub with: mobile touch controls, settings/save system, audio & VFX, dynamic camera, LAN multiplayer, performance pooling, a UI/UX redesign pass, and match presentation (Lineup / Kickoff / Full-Time) with real shot tracking."
	_open_info_screen(Settings.t("credits"), body)

func open_profile_screen() -> void:
	if _info_screen != null:
		return
	is_active = false
	_open_info_screen(Settings.t("profile"), Settings.t("profile_coming_soon"))

func _open_info_screen(title: String, body: String) -> void:
	_info_screen = InfoScreen.new()
	_info_screen.info_title = title
	_info_screen.info_body = body
	add_child(_info_screen)
	_info_screen.closed.connect(_on_info_closed)

func _on_info_closed() -> void:
	if is_instance_valid(_info_screen):
		_info_screen.queue_free()
	_info_screen = null
	is_active = true

func _on_lobby_cancelled() -> void:
	is_active = true
	if NetworkManager.remote_ready_to_play.is_connected(_on_remote_ready_to_play):
		NetworkManager.remote_ready_to_play.disconnect(_on_remote_ready_to_play)

func _on_remote_ready_to_play(_host_country: String, _client_country: String) -> void:
	if NetworkManager.remote_ready_to_play.is_connected(_on_remote_ready_to_play):
		NetworkManager.remote_ready_to_play.disconnect(_on_remote_ready_to_play)
	# The host already knows both countries, so skip team selection for the
	# network flow and go straight into the match. Mirrors what
	# team_selection_screen.gd's on_selector_selected() does for the
	# equivalent local "versus" case.
	var country_p1 := GameManager.player_setup[0]
	var country_p2 := GameManager.player_setup[1]
	GameManager.current_match = Match.new(country_p2, country_p1)
	transition_screen(SoccerGame.ScreenType.IN_GAME)

func on_set_active() -> void:
	refresh_ui()
	is_active = true
	if screen_data != null and screen_data.reopen_multiplayer_lobby:
		screen_data.reopen_multiplayer_lobby = false
		open_multiplayer_lobby()
