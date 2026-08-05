class_name SettingsScreen
extends CanvasLayer

# Built entirely in code (no .tscn), same convention as TouchControls /
# PauseMenu / MultiplayerLobby. A single scrollable Control-based menu
# (rather than MainMenuScreen's 3-item keyboard-driven texture list) since
# Settings has far more items than fit that pattern and needs to work with
# mouse/touch (sliders, toggles, dropdowns) as well as keyboard/gamepad
# focus navigation (Godot's default Control focus-traversal handles Tab/
# arrow-key movement between focusable controls for free once focus_mode is
# left at its default on these).
#
# Opened only from PauseMenu for this phase - see main_menu_screen.gd for
# why a main-menu entry point was left out (README "Settings" section notes
# this too).

signal closed

const ROW_HEIGHT := 16.0
const FPS_OPTIONS := [30, 60, 120, 0] # 0 = uncapped
const DURATION_OPTIONS := [60, 120, 180, 300]

var _root : Control

func _ready() -> void:
	layer = 95 # above PauseMenu (90)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

# Rebuilds the whole screen from current Settings values. Used after
# "Reset to defaults" / the Performance Mode / Battery Saver preset buttons,
# which change several fields' underlying values at once - simplest way to
# get every slider/toggle/option showing its new value without hand-tracking
# a reference to each individual widget.
func _rebuild() -> void:
	if _root != null:
		_root.queue_free()
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.9)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var title := Label.new()
	title.text = Settings.t("settings_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 4)
	_root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 18)
	scroll.size = Vector2(260, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(240, 0)
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)

	_build_audio_section(list)
	_build_graphics_section(list)
	_build_controls_section(list)
	_build_gameplay_section(list)
	_build_language_section(list)
	_build_reset_section(list)

	var back_button := Button.new()
	back_button.text = Settings.t("back")
	back_button.custom_minimum_size = Vector2(80, 16)
	back_button.position = Vector2(100, 162)
	back_button.pressed.connect(func() -> void: closed.emit())
	_root.add_child(back_button)

func _section_header(list: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	list.add_child(label)

func _row(list: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	list.add_child(row)
	return row

func _slider_row(list: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float, on_changed: Callable) -> HSlider:
	var row := _row(list, label_text)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(100, 0)
	slider.value_changed.connect(on_changed)
	row.add_child(slider)
	return slider

func _toggle_row(list: VBoxContainer, label_text: String, value: bool, on_changed: Callable) -> CheckButton:
	var row := _row(list, label_text)
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.toggled.connect(on_changed)
	row.add_child(toggle)
	return toggle

func _option_row(list: VBoxContainer, label_text: String, options: Array[String], selected_index: int, on_changed: Callable) -> OptionButton:
	var row := _row(list, label_text)
	var option_button := OptionButton.new()
	for option_text in options:
		option_button.add_item(option_text)
	option_button.selected = selected_index
	option_button.item_selected.connect(on_changed)
	row.add_child(option_button)
	return option_button

func _build_audio_section(list: VBoxContainer) -> void:
	_section_header(list, Settings.t("tab_audio"))
	_slider_row(list, Settings.t("master_volume"), 0.0, 1.0, 0.05, Settings.master_volume, Settings.set_master_volume)
	_slider_row(list, Settings.t("music_volume"), 0.0, 1.0, 0.05, Settings.music_volume, Settings.set_music_volume)
	_toggle_row(list, Settings.t("music_on"), Settings.music_enabled, Settings.set_music_enabled)
	_slider_row(list, Settings.t("sfx_volume"), 0.0, 1.0, 0.05, Settings.sfx_volume, Settings.set_sfx_volume)
	_toggle_row(list, Settings.t("sfx_on"), Settings.sfx_enabled, Settings.set_sfx_enabled)

func _build_graphics_section(list: VBoxContainer) -> void:
	_section_header(list, Settings.t("tab_graphics"))
	var fps_labels : Array[String] = ["30", "60", "120", "Uncapped"]
	var current_fps_index := FPS_OPTIONS.find(Settings.fps_limit)
	if current_fps_index == -1:
		current_fps_index = 1
	_option_row(list, Settings.t("fps_limit"), fps_labels, current_fps_index, _on_fps_selected)
	_toggle_row(list, Settings.t("particles"), Settings.particles_enabled, Settings.set_particles_enabled)
	_toggle_row(list, Settings.t("camera_shake"), Settings.camera_shake_enabled, Settings.set_camera_shake_enabled)
	_toggle_row(list, Settings.t("slow_motion"), Settings.slow_motion_enabled, Settings.set_slow_motion_enabled)
	_slider_row(list, Settings.t("camera_follow_speed"), 0.5, 2.0, 0.1, Settings.camera_follow_speed, Settings.set_camera_follow_speed)

	# Performance Mode / Battery Saver: honest shortcuts that just call the
	# same real setters above - see Settings.apply_performance_mode()/
	# apply_battery_saver() for the exact bundles.
	var perf_row := _row(list, Settings.t("performance_mode"))
	var perf_button := Button.new()
	perf_button.text = Settings.t("apply")
	perf_button.pressed.connect(func() -> void:
		Settings.apply_performance_mode()
		_rebuild()
	)
	perf_row.add_child(perf_button)

	var battery_row := _row(list, Settings.t("battery_saver"))
	var battery_button := Button.new()
	battery_button.text = Settings.t("apply")
	battery_button.pressed.connect(func() -> void:
		Settings.apply_battery_saver()
		_rebuild()
	)
	battery_row.add_child(battery_button)

func _on_fps_selected(index: int) -> void:
	Settings.set_fps_limit(FPS_OPTIONS[index])

func _build_controls_section(list: VBoxContainer) -> void:
	_section_header(list, Settings.t("tab_controls"))
	_slider_row(list, Settings.t("joystick_size"), 0.5, 2.0, 0.1, Settings.joystick_scale, Settings.set_joystick_scale)
	_slider_row(list, Settings.t("button_size"), 0.5, 2.0, 0.1, Settings.button_scale, Settings.set_button_scale)
	_slider_row(list, Settings.t("controls_opacity"), 0.2, 1.0, 0.05, Settings.controls_opacity, Settings.set_controls_opacity)
	_toggle_row(list, Settings.t("swap_controls"), Settings.controls_swapped, Settings.set_controls_swapped)
	_toggle_row(list, Settings.t("invert_y"), Settings.invert_movement_y, Settings.set_invert_movement_y)
	_toggle_row(list, Settings.t("invert_x"), Settings.invert_movement_x, Settings.set_invert_movement_x)
	_slider_row(list, Settings.t("sensitivity"), 0.5, 2.0, 0.1, Settings.joystick_sensitivity, Settings.set_joystick_sensitivity)
	_toggle_row(list, Settings.t("vibration"), Settings.haptics_enabled, Settings.set_haptics_enabled)

func _build_gameplay_section(list: VBoxContainer) -> void:
	_section_header(list, Settings.t("tab_gameplay"))
	var difficulty_labels : Array[String] = [Settings.t("difficulty_easy"), Settings.t("difficulty_normal"), Settings.t("difficulty_hard")]
	_option_row(list, Settings.t("difficulty"), difficulty_labels, Settings.difficulty, _on_difficulty_selected)

	var duration_labels : Array[String] = ["1:00", "2:00", "3:00", "5:00"]
	var current_duration_index := DURATION_OPTIONS.find(Settings.match_duration_sec)
	if current_duration_index == -1:
		current_duration_index = 1
	_option_row(list, Settings.t("match_duration"), duration_labels, current_duration_index, _on_duration_selected)

	_toggle_row(list, Settings.t("auto_sprint"), Settings.auto_sprint_enabled, Settings.set_auto_sprint_enabled)
	_slider_row(list, Settings.t("camera_zoom"), 0.75, 1.5, 0.05, Settings.camera_zoom, Settings.set_camera_zoom)

func _on_difficulty_selected(index: int) -> void:
	Settings.set_difficulty(index as Settings.Difficulty)

func _on_duration_selected(index: int) -> void:
	Settings.set_match_duration_sec(DURATION_OPTIONS[index])

func _build_language_section(list: VBoxContainer) -> void:
	_section_header(list, Settings.t("tab_language"))
	var locale_labels : Array[String] = []
	var current_index := 0
	for i in Localization.LOCALES.size():
		var locale : String = Localization.LOCALES[i]
		locale_labels.append(Localization.LOCALE_NAMES.get(locale, locale))
		if locale == Settings.language:
			current_index = i
	_option_row(list, Settings.t("tab_language"), locale_labels, current_index, _on_language_selected)

func _on_language_selected(index: int) -> void:
	Settings.set_language(Localization.LOCALES[index])

func _build_reset_section(list: VBoxContainer) -> void:
	_section_header(list, Settings.t("reset_section"))
	var row := _row(list, "")
	var reset_button := Button.new()
	reset_button.text = Settings.t("reset_to_defaults")
	reset_button.pressed.connect(func() -> void:
		Settings.reset_to_defaults()
		_rebuild()
	)
	row.add_child(reset_button)
