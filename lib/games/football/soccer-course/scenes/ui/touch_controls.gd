class_name TouchControls
extends CanvasLayer

# Constructed entirely at runtime (no .tscn) and always added by UI._ready()
# now (Phase 1: always-on controls for Android parity, no longer gated by
# DisplayServer.is_touchscreen_available()). Drives KeyUtils' existing P1
# input actions via Input.action_press/release so nothing downstream
# (KeyUtils, PlayerStateMoving, etc.) needs to know touch controls exist,
# and keyboard input keeps working interchangeably alongside touch since
# both just feed the same Input action state.

signal pause_requested

const JOYSTICK_RADIUS := 33.0 # further reduced this pass (was 38, before that 45); still >2x TOUCH grab radius below, comfortably tappable at this game's 280x180 logical viewport
const JOYSTICK_DEADZONE := 10.0
const JOYSTICK_MARGIN := 38.0 # distance from the bottom-left corner (was a flat 45)
const BUTTON_RADIUS := 18.0
const PAUSE_BUTTON_RADIUS := 10.0
const PRESS_SCALE := 0.85
const PRESS_ANIM_DURATION := 0.08
const RIPPLE_DURATION := 0.3
const RIPPLE_MAX_SCALE := 2.2

# Phase 5: read/written from the persisted Settings autoload. Settings'
# setters push live values here directly (via the "touch_controls" group)
# whenever the player changes a value in the Settings screen mid-session;
# these @export setters still do the actual re-apply work.
@export var joystick_scale := 1.0 :
	set(value):
		joystick_scale = value
		_apply_joystick_scale()
@export var button_scale := 1.0 :
	set(value):
		button_scale = value
		_apply_button_scale()
@export var controls_opacity := 1.0 :
	set(value):
		controls_opacity = value
		_apply_opacity()
@export var haptics_enabled := true

var _joystick_touch_index := -1
var _joystick_center := Vector2.ZERO
var _joystick_base : Control = null
var _joystick_knob : Control = null
var _joystick_knob_rest_position := Vector2.ZERO
var _joystick_group : Control = null

var _button_touch_index := {} # button_action_name -> touch index
var _buttons := {} # button_action_name -> Control
var _button_tweens := {} # Control -> Tween (press/release scale)
var _glow_tweens := {} # Control -> Tween (press glow, separate track from scale)
var _buttons_group : Control = null

var _pause_button : Control = null
var _pause_touch_index := -1
var _root : Control = null

func _ready() -> void:
	layer = 50 # render above the rest of the UI overlay
	add_to_group("touch_controls") # lets Settings push live value changes here
	joystick_scale = Settings.joystick_scale
	button_scale = Settings.button_scale
	controls_opacity = Settings.controls_opacity
	haptics_enabled = Settings.haptics_enabled

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_joystick_group = Control.new()
	_joystick_group.set_anchors_preset(Control.PRESET_FULL_RECT)
	_joystick_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_joystick_group)

	_buttons_group = Control.new()
	_buttons_group.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buttons_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_buttons_group)

	_build_joystick(_joystick_group)
	# Recolored this pass: A=blue (shoot), B=green (pass), C=orange (sprint) -
	# previously A=red/B=blue/C=green. Alpha baked in at 0.5 (idle ~50%,
	# comfortably in the requested 40-60% range) since Settings.
	# controls_opacity defaults to 1.0 and would otherwise leave these fully
	# opaque; _animate_press() bumps modulate:a up on press (see
	# _animate_press below) so pressed state reads as ~85%, in the
	# requested 80-90% range.
	_build_button("p1_shoot", "A", Color(0.2, 0.45, 0.9, 0.5), _buttons_group)
	_build_button("p1_pass", "B", Color(0.2, 0.75, 0.35, 0.5), _buttons_group)
	_build_button("p1_sprint", "C", Color(0.9, 0.55, 0.15, 0.5), _buttons_group)
	_build_pause_button(_root)

	_apply_joystick_scale()
	_apply_button_scale()
	_apply_opacity()

# Settings.controls_swapped mirrors the joystick to the right side and the
# action buttons to the left, around the viewport's horizontal center. The
# pause button (top-right) deliberately stays put either way - it's a
# single, corner-anchored control, not part of the "which hand" ergonomics
# swap being requested here.
func _mirror_x(x: float) -> float:
	if not Settings.controls_swapped:
		return x
	var viewport_width := get_viewport().get_visible_rect().size.x
	return viewport_width - x

# Idle/touched alpha values for the joystick (40-50% idle, 80-90% touched,
# per this pass's request), applied to _joystick_base/_joystick_knob's
# modulate:a in _update_joystick()/_reset_joystick() rather than baked only
# into the constructed colors below, so touch state can toggle between them.
const JOYSTICK_ALPHA_IDLE := 0.45
const JOYSTICK_ALPHA_TOUCHED := 0.85

func _build_joystick(root: Control) -> void:
	var joystick_x := _mirror_x(JOYSTICK_MARGIN)
	_joystick_center = Vector2(joystick_x, get_viewport().get_visible_rect().size.y - JOYSTICK_MARGIN)
	_joystick_base = _make_circle(JOYSTICK_RADIUS, Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.55), 2.0)
	_joystick_base.position = _joystick_center - Vector2(JOYSTICK_RADIUS, JOYSTICK_RADIUS)
	_joystick_base.modulate.a = JOYSTICK_ALPHA_IDLE
	root.add_child(_joystick_base)
	_joystick_knob = _make_circle(JOYSTICK_RADIUS * 0.5, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.85), 1.0)
	_joystick_knob.modulate.a = JOYSTICK_ALPHA_IDLE
	_joystick_knob_rest_position = _joystick_center - Vector2(JOYSTICK_RADIUS, JOYSTICK_RADIUS) * 0.5
	_joystick_knob.position = _joystick_knob_rest_position
	root.add_child(_joystick_knob)
	root.pivot_offset = _joystick_center

# FIFA-Mobile-style triangle cluster instead of a horizontal row: A (shoot,
# built first so index 0) sits top-center of the cluster, B (pass, index 1)
# bottom-left, C (sprint, index 2) bottom-right. Hit-testing in
# _handle_touch() reads each button's own .position/.size generically (not
# this row-formula), so only the position calculation needed to change here.
const BUTTON_TRIANGLE_OFFSETS := [Vector2(0, -26), Vector2(-26, 10), Vector2(26, 10)]

func _build_button(action_name: String, label_text: String, color: Color, root: Control) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var index := _buttons.size()
	var cluster_center := Vector2(viewport_size.x - 50, viewport_size.y - 50)
	var triangle_offset : Vector2 = BUTTON_TRIANGLE_OFFSETS[index] if index < BUTTON_TRIANGLE_OFFSETS.size() else Vector2.ZERO
	var base_pos := Vector2(_mirror_x(cluster_center.x + triangle_offset.x), cluster_center.y + triangle_offset.y)
	var circle := _make_circle(BUTTON_RADIUS, color, color.lightened(0.4), 2.0)
	circle.position = base_pos - Vector2(BUTTON_RADIUS, BUTTON_RADIUS)
	circle.pivot_offset = Vector2(BUTTON_RADIUS, BUTTON_RADIUS)
	var label := Label.new()
	label.text = label_text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(label)
	root.add_child(circle)
	_buttons[action_name] = circle

func _build_pause_button(root: Control) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_pause_button = _make_circle(PAUSE_BUTTON_RADIUS, Color(0.15, 0.15, 0.15, 0.6), Color(0.6, 0.6, 0.6, 0.8), 1.5)
	_pause_button.position = Vector2(viewport_size.x - PAUSE_BUTTON_RADIUS * 2 - 4, 4)
	_pause_button.pivot_offset = Vector2(PAUSE_BUTTON_RADIUS, PAUSE_BUTTON_RADIUS)
	var label := Label.new()
	label.text = "II"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pause_button.add_child(label)
	root.add_child(_pause_button)

# StyleBoxFlat's border/shadow/corner-radius properties let this look like a
# soft layered button (subtle drop shadow + light border ring) purely from
# code, no art assets needed.
func _make_circle(radius: float, fill_color: Color, border_color: Color, border_width: float) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2(radius, radius) * 2
	control.size = Vector2(radius, radius) * 2
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	# StyleBoxFlat's border_width_* properties are int (pixel widths), while
	# border_width is kept as a float parameter so callers can pass values
	# like 1.5 without an awkward int-only API - round explicitly here
	# rather than let it narrow implicitly, since rounding (vs. floor/ceil)
	# best preserves the visually-intended thickness callers asked for.
	var rounded_border_width := roundi(border_width)
	style.border_width_left = rounded_border_width
	style.border_width_right = rounded_border_width
	style.border_width_top = rounded_border_width
	style.border_width_bottom = rounded_border_width
	style.border_color = border_color
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel", style)
	control.add_child(panel)
	return control

func _apply_joystick_scale() -> void:
	if _joystick_group == null:
		return
	# _joystick_group's pivot is _joystick_center itself (set in
	# _build_joystick), so scaling the whole group leaves that center point
	# fixed on screen - safe to scale as one unit. Hit-testing below reads
	# joystick_scale directly so the tappable area matches what's drawn.
	_joystick_group.scale = Vector2.ONE * joystick_scale

func _apply_button_scale() -> void:
	# Scaling _buttons_group as a whole would need a single shared pivot,
	# which would visually drag B/C away from A instead of resizing each
	# button in place. Each button circle already has its own centered
	# pivot_offset (set in _build_button), so scale them individually instead
	# - every button grows/shrinks around its own center, formation intact.
	for button_control in _buttons.values():
		(button_control as Control).scale = Vector2.ONE * button_scale

func _apply_opacity() -> void:
	# CanvasLayer (what this node extends) has no `modulate` property at all -
	# that only exists on CanvasItem (Control/Node2D). Apply it to `_root`
	# (the Control everything else is parented under) instead; opacity
	# propagates visually to its children the normal CanvasItem way. Guarded
	# for null since this setter can fire from _ready()'s very first line
	# (controls_opacity = Settings.controls_opacity), before `_root` is built.
	if _root == null:
		return
	_root.modulate.a = controls_opacity

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _joystick_touch_index == -1 and event.position.distance_to(_joystick_center) <= JOYSTICK_RADIUS * joystick_scale * 2.0:
			_joystick_touch_index = event.index
			_update_joystick(event.position)
			return
		if _pause_touch_index == -1 and event.position.distance_to(_button_center(_pause_button)) <= PAUSE_BUTTON_RADIUS * 1.6:
			_pause_touch_index = event.index
			_animate_press(_pause_button)
			_vibrate(15)
			pause_requested.emit()
			return
		for action_name in _buttons.keys():
			if _button_touch_index.has(action_name):
				continue
			var button_control : Control = _buttons[action_name]
			# Checked this pass whether the 1.4x hit-test tolerance should grow
			# further for one-handed thumb play: the triangle cluster's A-B/
			# A-C button centers are ~44px apart (26,36 offset), and 18px
			# radius * 1.4 * 2 = 50.4px already slightly overlaps that gap -
			# raising the multiplier further would only worsen adjacent-button
			# mis-hits, not help them, so this is left as-is. No concrete,
			# verified improvement found here beyond what the last two polish
			# passes already did.
			if event.position.distance_to(_button_center(button_control)) <= BUTTON_RADIUS * button_scale * 1.4:
				_button_touch_index[action_name] = event.index
				Input.action_press(action_name)
				_animate_press(button_control)
				_vibrate(10)
	else:
		if event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_reset_joystick()
		if event.index == _pause_touch_index:
			_pause_touch_index = -1
			_animate_release(_pause_button)
		for action_name in _button_touch_index.keys():
			if _button_touch_index[action_name] == event.index:
				_button_touch_index.erase(action_name)
				Input.action_release(action_name)
				_animate_release(_buttons[action_name])

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_index:
		_update_joystick(event.position)

func _button_center(control: Control) -> Vector2:
	return control.position + control.size * 0.5

# Cheap press feedback: scale the button down slightly on press, back up on
# release. Kept to a single Tween per button (killed/replaced rather than
# stacked) so this stays lightweight on a phone. Also fires a ripple + a
# brief glow on press (visual polish only, no gameplay meaning - there's no
# cooldown/lockout mechanic anywhere in this game to represent, so neither
# effect is tied to any timer beyond its own fixed duration).
const BUTTON_ALPHA_IDLE := 0.5
const BUTTON_ALPHA_PRESSED := 0.85

func _animate_press(control: Control) -> void:
	_run_scale_tween(control, Vector2.ONE * PRESS_SCALE)
	_spawn_ripple(control)
	_animate_glow(control)
	_animate_fill_alpha(control, BUTTON_ALPHA_PRESSED)

func _animate_release(control: Control) -> void:
	_run_scale_tween(control, Vector2.ONE)
	_animate_fill_alpha(control, BUTTON_ALPHA_IDLE)

# Idle fill alpha is baked at BUTTON_ALPHA_IDLE (see _build_button's Color
# literals). Control.modulate can't exceed 1.0, so it can't be used to push
# opacity ABOVE that baked-in idle value on press - instead this tweens the
# StyleBoxFlat's own bg_color.a directly (same technique as _animate_glow's
# shadow_size/shadow_color tween just below), landing the pressed state in
# the requested 80-90% range while idle stays at 40-60%. Skipped for the
# pause button, which was never part of the idle/pressed opacity request.
func _animate_fill_alpha(control: Control, target_alpha: float) -> void:
	if control == null or control == _pause_button:
		return
	var panel := control.get_child(0) as Panel
	if panel == null:
		return
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var tween := panel.create_tween()
	tween.tween_property(style, "bg_color:a", target_alpha, PRESS_ANIM_DURATION)

func _run_scale_tween(control: Control, target_scale: Vector2) -> void:
	if control == null:
		return
	var existing : Tween = _button_tweens.get(control)
	if existing != null and existing.is_valid():
		existing.kill()
	var tween := create_tween()
	tween.tween_property(control, "scale", target_scale, PRESS_ANIM_DURATION)
	_button_tweens[control] = tween

# A temporary expanding, fading ring spawned as a sibling of `control` (same
# parent/coordinate space, same center), independent of control's own
# press/release scale tween. The Tween driving it is created from the ripple
# node itself (not from TouchControls) precisely so it isn't affected by
# anything else's lifecycle - it owns its own cleanup via queue_free() on
# `finished`, same Tween-ownership precedent as _run_scale_tween/
# _run_item_tween elsewhere in this project.
func _spawn_ripple(control: Control) -> void:
	if control == null or control.get_parent() == null:
		return
	var radius : float = control.size.x * 0.5
	if radius <= 0.0:
		return
	var ripple := _make_circle(radius, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.7), 2.0)
	ripple.position = control.position
	ripple.pivot_offset = control.pivot_offset
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.get_parent().add_child(ripple)
	var tween := ripple.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", Vector2.ONE * RIPPLE_MAX_SCALE, RIPPLE_DURATION)
	tween.tween_property(ripple, "modulate:a", 0.0, RIPPLE_DURATION)
	tween.finished.connect(func() -> void:
		if is_instance_valid(ripple):
			ripple.queue_free()
	)

# Subtle glow: briefly brightens/enlarges the existing StyleBoxFlat shadow
# (already set up in _make_circle) rather than building a new rendering
# technique. The Tween is created from the Panel that owns the StyleBoxFlat
# (a permanent child of `control`, same lifetime), and any prior in-flight
# glow tween on it is killed first so rapid re-presses don't stack tweens.
func _animate_glow(control: Control) -> void:
	if control == null:
		return
	var panel := control.get_child(0) as Panel
	if panel == null:
		return
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var existing : Tween = _glow_tweens.get(control)
	if existing != null and existing.is_valid():
		existing.kill()
	# shadow_size is an int property on StyleBoxFlat - tweened with int
	# literals here (not float) to avoid relying on implicit float->int
	# coercion inside Tween's property interpolation.
	var base_shadow_size := 3
	var base_shadow_color := Color(0, 0, 0, 0.35)
	var tween := panel.create_tween()
	tween.tween_property(style, "shadow_size", base_shadow_size + 4, PRESS_ANIM_DURATION)
	tween.parallel().tween_property(style, "shadow_color", Color(1, 1, 1, 0.5), PRESS_ANIM_DURATION)
	tween.tween_property(style, "shadow_size", base_shadow_size, PRESS_ANIM_DURATION * 3.0)
	tween.parallel().tween_property(style, "shadow_color", base_shadow_color, PRESS_ANIM_DURATION * 3.0)
	_glow_tweens[control] = tween

# NOTE (uncertain, could not run the Editor/a device to verify): per Godot 4
# docs Input.vibrate_handheld() is documented as a no-op on platforms that
# don't support it (desktop/web), so calling it unconditionally should be
# safe, but this hasn't been playtested on an actual Android device here -
# double check haptics behave as expected on a real phone.
func _vibrate(duration_ms: int) -> void:
	if not haptics_enabled:
		return
	Input.vibrate_handheld(duration_ms)

func _update_joystick(touch_position: Vector2) -> void:
	_joystick_base.modulate.a = JOYSTICK_ALPHA_TOUCHED
	_joystick_knob.modulate.a = JOYSTICK_ALPHA_TOUCHED
	# touch_position/_joystick_center are real screen-space coordinates, not
	# affected by _joystick_group's own scale transform - so the max-travel
	# and deadzone thresholds need to scale by joystick_scale explicitly to
	# match how big the base is actually drawn (see _apply_joystick_scale).
	var scaled_radius := JOYSTICK_RADIUS * joystick_scale
	var scaled_deadzone := JOYSTICK_DEADZONE * joystick_scale
	var drag_offset := touch_position - _joystick_center
	if drag_offset.length() > scaled_radius:
		drag_offset = drag_offset.normalized() * scaled_radius
	# The knob node lives inside _joystick_group's own (unscaled, local)
	# coordinate space, so its position is set in JOYSTICK_RADIUS units and
	# the group's scale transform handles the rest visually - divide back out
	# of screen-space here to avoid double-scaling.
	var local_offset := drag_offset / joystick_scale if joystick_scale != 0.0 else Vector2.ZERO
	_joystick_knob.position = _joystick_center + local_offset - Vector2(JOYSTICK_RADIUS, JOYSTICK_RADIUS) * 0.5

	# Diagonal movement matches keyboard behavior: drive up to two opposing
	# action pairs simultaneously, exactly what Input.get_vector() expects.
	# The same deadzone governs both the visual knob's "at rest" feel (small
	# jitters below it still move the knob a little, which is expected/
	# desired touch feedback) and the actual action-press threshold below -
	# both branches read from the same scaled value so they can't drift out
	# of agreement.
	var release_all := drag_offset.length() < scaled_deadzone
	_set_directional_action("p1_left", not release_all and drag_offset.x < -scaled_deadzone * 0.5)
	_set_directional_action("p1_right", not release_all and drag_offset.x > scaled_deadzone * 0.5)
	_set_directional_action("p1_up", not release_all and drag_offset.y < -scaled_deadzone * 0.5)
	_set_directional_action("p1_down", not release_all and drag_offset.y > scaled_deadzone * 0.5)

func _reset_joystick() -> void:
	_joystick_base.modulate.a = JOYSTICK_ALPHA_IDLE
	_joystick_knob.modulate.a = JOYSTICK_ALPHA_IDLE
	_joystick_knob.position = _joystick_knob_rest_position
	for action_name in ["p1_left", "p1_right", "p1_up", "p1_down"]:
		_set_directional_action(action_name, false)

func _set_directional_action(action_name: String, should_be_pressed: bool) -> void:
	if should_be_pressed and not Input.is_action_pressed(action_name):
		Input.action_press(action_name)
	elif not should_be_pressed and Input.is_action_pressed(action_name):
		Input.action_release(action_name)
