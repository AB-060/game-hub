class_name PauseMenu
extends CanvasLayer

# Built entirely in code (no .tscn), same convention as TouchControls /
# MultiplayerLobby. Instantiated by UI on a pause request (touch button or
# the ui_cancel/Escape key) and freed on resume/restart/quit.

signal resumed
signal restart_requested
signal quit_requested

var _root : Control
var _settings_screen : SettingsScreen = null

func _ready() -> void:
	layer = 90
	# GameManager itself already uses PROCESS_MODE_ALWAYS so its own state
	# machine keeps ticking through short impact-pauses; this overlay needs
	# the same treatment so its buttons keep receiving input while
	# get_tree().paused is true, without fighting GameManager's own brief
	# auto-unpause in _process().
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.75)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(90, 55)
	vbox.add_theme_constant_override("separation", 6)
	_root.add_child(vbox)

	var title := Label.new()
	title.text = Settings.t("paused")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_button := _make_button(Settings.t("resume"))
	resume_button.pressed.connect(func() -> void:
		resumed.emit()
		queue_free()
	)
	vbox.add_child(resume_button)

	# Phase 8: "Restart Match" unilaterally rebuilding a fresh Match object
	# only makes sense for a single local process - in a networked match
	# both sides run their own GameManager instance, so one peer "restarting"
	# would desync scores/state from the other peer immediately. Hide it
	# entirely rather than let it produce a confusing half-restarted match.
	if not NetworkManager.is_networked():
		var restart_button := _make_button(Settings.t("restart_match"))
		restart_button.pressed.connect(func() -> void:
			restart_requested.emit()
			queue_free()
		)
		vbox.add_child(restart_button)

	var settings_button := _make_button(Settings.t("settings_button"))
	settings_button.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_button)

	var quit_button := _make_button(Settings.t("quit_match"))
	quit_button.pressed.connect(func() -> void:
		quit_requested.emit()
		queue_free()
	)
	vbox.add_child(quit_button)

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 18)
	button.focus_mode = Control.FOCUS_NONE
	return button

func _on_settings_pressed() -> void:
	if _settings_screen != null:
		return
	_settings_screen = SettingsScreen.new()
	add_child(_settings_screen)
	_settings_screen.closed.connect(_on_settings_closed)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_screen):
		_settings_screen.queue_free()
	_settings_screen = null
