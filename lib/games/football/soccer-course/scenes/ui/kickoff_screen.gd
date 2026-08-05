class_name KickoffScreen
extends CanvasLayer

# Kickoff presentation screen: team names/flags in a "vs" layout, then a
# real 3-2-1 countdown, then signals ready to enter the match. Deliberately
# NOT a cinematic - no moving stadium camera, lighting animation, players
# walking onto the pitch, or referee model, since none of those have any
# supporting geometry/animation/crowd assets in this project (see the
# task's explicit decline list). This is the honest, achievable version:
# a static-but-animated (fade/slide via Tween) presentation screen. Built
# entirely in code (no .tscn), same convention as PauseMenu/TouchControls.

signal kickoff_finished

const COUNTDOWN_STEP_SEC := 0.8

var country_home := ""
var country_away := ""

var _root : Control
var _countdown_label : Label

func setup(context_country_home: String, context_country_away: String) -> void:
	country_home = context_country_home
	country_away = context_country_away

func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)

	var background := ColorRect.new()
	background.color = Color(0.03, 0.05, 0.03, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.position = Vector2(30, 40)
	hbox.add_theme_constant_override("separation", 24)
	_root.add_child(hbox)

	hbox.add_child(_build_side(country_home))

	var vs_label := Label.new()
	vs_label.text = "VS"
	vs_label.add_theme_font_size_override("font_size", 16)
	vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(vs_label)

	hbox.add_child(_build_side(country_away))

	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.position = Vector2(-10, 40)
	_countdown_label.add_theme_font_size_override("font_size", 28)
	_countdown_label.modulate.a = 0.0
	_root.add_child(_countdown_label)

	var fade_in := _root.create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, 0.3)
	fade_in.tween_callback(_start_countdown)

func _build_side(country: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var flag := TextureRect.new()
	flag.texture = FlagHelper.get_texture(country)
	flag.custom_minimum_size = Vector2(48, 30)
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var flag_center := CenterContainer.new()
	flag_center.add_child(flag)
	vbox.add_child(flag_center)
	var label := Label.new()
	label.text = country
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	return vbox

func _start_countdown() -> void:
	_run_countdown_step(3)

func _run_countdown_step(count: int) -> void:
	if count <= 0:
		_countdown_label.text = "KICK OFF!"
		SoundPlayer.play(SoundPlayer.Sound.WHISTLE)
		var tween := _countdown_label.create_tween()
		tween.tween_property(_countdown_label, "modulate:a", 1.0, 0.1)
		tween.tween_interval(0.5)
		tween.tween_callback(_finish)
		return
	_countdown_label.text = str(count)
	_countdown_label.modulate.a = 0.0
	_countdown_label.scale = Vector2(1.6, 1.6)
	SoundPlayer.play(SoundPlayer.Sound.UI_NAV)
	var tween := _countdown_label.create_tween()
	tween.tween_property(_countdown_label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_countdown_label, "scale", Vector2.ONE, 0.15)
	tween.tween_interval(COUNTDOWN_STEP_SEC - 0.15)
	tween.tween_callback(_run_countdown_step.bind(count - 1))

func _finish() -> void:
	kickoff_finished.emit()
	queue_free()
