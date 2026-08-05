class_name WorldScreen
extends Screen

# TODO: crowd/stadium atmosphere requires crowd sprite sheets or a crowd
# sound loop, neither of which exist in assets/ (only assets/sfx/
# {bounce,hurt,pass,power-shot,shoot,tackle,ui-navigate,ui-select,whistle}.
# wav and assets/music/{gameplay,menu,tournament,win}.mp3 - none of the SFX
# are crowd-appropriate, and there is no crowd animation art anywhere in
# assets/art/). Revisit if/when such assets are added; do not fabricate
# crowd noise/movement from the existing SFX set.

@onready var game_over_timer := %GameOverTimer

func _ready() -> void:
	game_over_timer.timeout.connect(on_transition.bind())
	GameEvents.game_over.connect(on_game_over.bind())
	if NetworkManager.is_networked():
		# Phase 8: mid-match disconnect handling. Without this, a lost
		# connection during a networked match leaves world_screen running
		# forever with a frozen/absent remote player and no way back to a
		# menu - both signals fire on whichever side notices the loss (the
		# client via server_disconnected, the host via opponent_disconnected
		# once its sole peer drops).
		NetworkManager.server_disconnected.connect(on_network_disconnected)
		NetworkManager.opponent_disconnected.connect(on_network_disconnected)
	GameManager.start_game()

func on_game_over(_winner: String) -> void:
	# Previously: game_over_timer.start() -> an unconditional 3s auto-
	# transition with no stats and no player choice. Now: UI builds a real
	# FullTimeScreen (score/possession/shots/best-player, all genuinely
	# tracked - see Match.gd) and its own Continue/Play Again/Return to
	# Menu buttons drive on_transition()/restart/menu directly, so the old
	# blind timer is no longer used. game_over_timer itself is left in the
	# scene unused rather than edited out of the .tscn.
	pass

func on_network_disconnected() -> void:
	NetworkManager.disconnect_network()
	var ui := get_node_or_null("UI")
	if ui != null and ui.has_method("show_notification"):
		ui.show_notification(Settings.t("connection_lost"))
	get_tree().paused = false
	_show_reconnect_screen()

# Small, real addition: instead of unconditionally dumping the player back to
# the main menu on a mid-match disconnect, offer a choice - "Retry" reopens
# the Multiplayer lobby (host/join again) via the main menu's existing entry
# point, "Return to Menu" is the old unconditional behavior. Built entirely
# in code (no .tscn), same convention as every other overlay in this project.
func _show_reconnect_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 96
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.9)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(90, 60)
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	var label := Label.new()
	label.text = Settings.t("connection_lost")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var retry_button := Button.new()
	retry_button.text = Settings.t("retry")
	retry_button.custom_minimum_size = Vector2(120, 18)
	retry_button.pressed.connect(func() -> void:
		layer.queue_free()
		var data := ScreenData.new()
		data.reopen_multiplayer_lobby = true
		transition_screen(SoccerGame.ScreenType.MAIN_MENU, data)
	)
	vbox.add_child(retry_button)

	var menu_button := Button.new()
	menu_button.text = Settings.t("return_to_menu")
	menu_button.custom_minimum_size = Vector2(120, 18)
	menu_button.pressed.connect(func() -> void:
		layer.queue_free()
		transition_screen(SoccerGame.ScreenType.MAIN_MENU)
	)
	vbox.add_child(menu_button)

func on_transition() -> void:
	if screen_data.tournament != null and GameManager.current_match.winner == GameManager.player_setup[0]:
		screen_data.tournament.advance()
		transition_screen(SoccerGame.ScreenType.TOURNAMENT, screen_data)
	else:
		transition_screen(SoccerGame.ScreenType.MAIN_MENU)
