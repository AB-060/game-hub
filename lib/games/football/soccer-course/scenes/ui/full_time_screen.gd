class_name FullTimeScreen
extends CanvasLayer

# Built entirely in code (no .tscn), same convention as PauseMenu/
# TouchControls/MultiplayerLobby. Shown by UI.on_game_over() in place of
# world_screen's old blind 3-second auto-timer. Every stat shown here is
# genuinely tracked (see Match.gd's shots_home/shots_away/
# shots_on_target_home/shots_on_target_away/goals_scored/saves_*/
# passes_attempted_*/passes_completed_*/tackles_*/assists and ui.gd's
# possession accumulators) - nothing fabricated. Saves/passes/tackles/
# assists are best-effort heuristics hooked to real game events, documented
# exactly where they're recorded (GameEvents.save_made/pass_attempted/
# pass_completed/tackle_attempted, GameManager's on_* handlers, ui.gd's
# on_team_scored_record). Explicitly NOT shown: fouls/cards (no
# foul-detection system exists at all).

signal continue_requested
signal play_again_requested
signal menu_requested

var _root : Control

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	# CanvasLayer itself has no modulate/position - _root (a Control) is
	# what everything below is parented under and animated on.
	_root.modulate.a = 0.0
	add_child(_root)

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.82)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(70, 18)
	vbox.add_theme_constant_override("separation", 3)
	_root.add_child(vbox)

	var title := Label.new()
	title.text = "FULL TIME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var current_match := GameManager.current_match
	if current_match != null:
		_add_label(vbox, "%s %d - %d %s" % [current_match.country_home, current_match.goals_home, current_match.goals_away, current_match.country_away])
		if not current_match.is_tied():
			_add_label(vbox, "WINNER: %s" % current_match.winner)
		else:
			_add_label(vbox, "MATCH TIED")
		_add_label(vbox, "SHOTS  %d - %d" % [current_match.shots_home, current_match.shots_away])
		_add_label(vbox, "ON TARGET  %d - %d" % [current_match.shots_on_target_home, current_match.shots_on_target_away])
		_add_label(vbox, "SAVES  %d - %d" % [current_match.saves_home, current_match.saves_away])
		_add_label(vbox, "PASSES  %d - %d" % [current_match.passes_completed_home, current_match.passes_completed_away])
		_add_label(vbox, "TACKLES (attempts)  %d - %d" % [current_match.tackles_home, current_match.tackles_away])
		if not current_match.assists.is_empty():
			var assist_lines : PackedStringArray = []
			for entry in current_match.assists:
				assist_lines.append("%s - %s" % [entry["country"], entry["player"]])
			_add_label(vbox, "ASSISTS\n" + "\n".join(assist_lines))
		var best_player := current_match.get_best_player_name()
		if not best_player.is_empty():
			_add_label(vbox, "BEST PLAYER (most goals): %s" % best_player)
		if not current_match.goals_scored.is_empty():
			var scorer_lines : PackedStringArray = []
			for entry in current_match.goals_scored:
				scorer_lines.append("%s - %s" % [entry["country"], entry["scorer"]])
			_add_label(vbox, "\n".join(scorer_lines))

	vbox.add_child(HSeparator.new())

	# "Continue" only makes sense (and only appears) mid-tournament - it
	# reuses world_screen.on_transition()'s existing tournament-advance
	# logic rather than duplicating it.
	if screen_data_has_tournament():
		var continue_button := _make_button("Continue")
		continue_button.pressed.connect(func() -> void:
			continue_requested.emit()
			queue_free()
		)
		vbox.add_child(continue_button)
	else:
		# Play Again mirrors pause_menu.gd's exact "Restart Match" pattern
		# (rebuild a fresh 0-0 Match for the same two countries) and, same
		# as that button, is hidden entirely in a networked match - one
		# peer unilaterally restarting would desync from the other peer's
		# GameManager instance.
		if not NetworkManager.is_networked():
			var play_again_button := _make_button("Play Again")
			play_again_button.pressed.connect(func() -> void:
				play_again_requested.emit()
				queue_free()
			)
			vbox.add_child(play_again_button)

	var menu_button := _make_button("Return to Menu")
	menu_button.pressed.connect(func() -> void:
		menu_requested.emit()
		queue_free()
	)
	vbox.add_child(menu_button)

	var tween := _root.create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.25)

func screen_data_has_tournament() -> bool:
	# FullTimeScreen is added as a child of UI, which is itself a child of
	# WorldScreen - grandparent, not parent (see UI._open_full_time_screen()
	# adding this as a child of UI, and UI itself living under WorldScreen).
	var ui_node := get_parent()
	var world_screen : Screen = ui_node.get_parent() as Screen if ui_node != null else null
	return world_screen != null and world_screen.screen_data != null and world_screen.screen_data.tournament != null

func _add_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 8)
	parent.add_child(label)

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 16)
	button.focus_mode = Control.FOCUS_NONE
	return button
