class_name InfoScreen
extends CanvasLayer

# Generic "read some text, press Back" overlay, built entirely in code (no
# .tscn), same convention as SettingsScreen/PauseMenu/MultiplayerLobby.
# Used by MainMenuScreen for About/Credits/Profile ("coming soon"). Content
# is set via `info_title`/`info_body` BEFORE add_child() (both are plain
# properties read by _ready(), so setting them right after `.new()` and
# before `add_child()` - this project's hard rule for any `setup()`-style
# call on a new screen - is naturally satisfied here since there's no
# separate setup() step to get the ordering wrong on).

signal closed

var info_title := ""
var info_body := ""

var _root : Control

func _ready() -> void:
	layer = 95 # same layer as SettingsScreen - only one of these is ever open at once
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.9)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var title := Label.new()
	title.text = info_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 4)
	_root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 20)
	scroll.size = Vector2(260, 130)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)

	var body := Label.new()
	body.text = info_body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.custom_minimum_size = Vector2(250, 0)
	scroll.add_child(body)

	var back_button := Button.new()
	back_button.text = Settings.t("back")
	back_button.custom_minimum_size = Vector2(80, 16)
	back_button.position = Vector2(100, 162)
	back_button.pressed.connect(func() -> void: closed.emit())
	_root.add_child(back_button)
