class_name LineupScreen
extends CanvasLayer

# Team Lineup screen, shown after team selection and before kickoff.
# Built entirely in code (no .tscn), same convention as PauseMenu/
# TouchControls. Every field shown is either real data straight from
# DataLoader.get_squad()/PlayerResource, or an explicitly-labeled derived/
# computed value - nothing here is fabricated:
#  - Squad: this project's squads are 6 players each (assets/json/squads.json,
#    asserted in data_loader.gd), NOT a real 11-man "Starting XI" - labeled
#    "SQUAD" rather than claiming an XI that doesn't exist in the data.
#  - Formation: there is no formation concept anywhere in this codebase
#    (only per-player Player.Role). This DERIVES a simple "D-M-A" shape by
#    counting DEFENSE/MIDFIELD/OFFENSE roles in the squad (goalkeeper
#    implied, shown separately) and labels it "(derived)".
#  - Captain: no captain concept exists. This picks the highest-`power`
#    non-goalie squad member as a purely cosmetic designation for this
#    screen, labeled "(designated)" - not a gameplay mechanic.
#  - Rating: reuses the exact same "computed, not official" power-average
#    formula already built in team_selection_screen.gd's rating panel
#    (kept in sync by design; see _compute_overall_rating below).
#  - Colors: no per-country color data exists anywhere in this project's
#    data (PlayerResource only has skin_color, a per-player sprite tint,
#    not a team color) - FlagHelper's flag texture is used as the visual
#    team identity instead, as instructed.

signal continued

var country_home := ""
var country_away := ""

var _root : Control

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
	background.color = Color(0.05, 0.08, 0.05, 0.95)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var title := Label.new()
	title.text = "TEAM LINEUPS"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	_root.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.position = Vector2(4, 18)
	hbox.size = Vector2(272, 140)
	hbox.add_theme_constant_override("separation", 8)
	_root.add_child(hbox)

	hbox.add_child(_build_team_panel(country_home))
	hbox.add_child(_build_team_panel(country_away))

	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(100, 16)
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	continue_button.position = Vector2(90, -20)
	continue_button.pressed.connect(_on_continue_pressed)
	_root.add_child(continue_button)

	var tween := _root.create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.25)

func _on_continue_pressed() -> void:
	SoundPlayer.play(SoundPlayer.Sound.UI_NAV)
	var tween := _root.create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func() -> void:
		continued.emit()
		queue_free()
	)

func _build_team_panel(country: String) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(130, 140)
	vbox.add_theme_constant_override("separation", 1)

	var flag := TextureRect.new()
	flag.texture = FlagHelper.get_texture(country)
	flag.custom_minimum_size = Vector2(32, 20)
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var flag_center := CenterContainer.new()
	flag_center.add_child(flag)
	vbox.add_child(flag_center)

	var name_label := Label.new()
	name_label.text = country
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var squad := DataLoader.get_squad(country)
	var overall_rating := _compute_overall_rating(squad)
	var rating_label := Label.new()
	rating_label.text = "OVR %d (computed)" % overall_rating
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_label.add_theme_font_size_override("font_size", 8)
	vbox.add_child(rating_label)

	var goalie := _find_goalie(squad)
	var captain := _find_captain(squad)
	var formation_label := Label.new()
	formation_label.text = "Formation: %s (derived)" % _derive_formation(squad)
	formation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	formation_label.add_theme_font_size_override("font_size", 7)
	vbox.add_child(formation_label)

	if goalie != null:
		vbox.add_child(_make_small_label("GK: %s" % goalie.full_name))
	if captain != null:
		vbox.add_child(_make_small_label("Captain (designated): %s" % captain.full_name))

	vbox.add_child(HSeparator.new())
	var squad_label := Label.new()
	squad_label.text = "SQUAD (%d)" % squad.size()
	squad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	squad_label.add_theme_font_size_override("font_size", 7)
	vbox.add_child(squad_label)
	for player_data : PlayerResource in squad:
		vbox.add_child(_make_small_label("%s %s" % [_role_short_label(player_data.role), player_data.full_name]))

	return vbox

func _make_small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 7)
	return label

# Same formula as team_selection_screen.gd's update_rating_panel(): power
# averaged across the squad, scaled to a FIFA-style 0-99 range. Duplicated
# rather than shared via a static helper to avoid restructuring an existing,
# already-reviewed screen for this pass - kept numerically identical on
# purpose (power / 2.0, clamped 0-99).
func _compute_overall_rating(squad: Array) -> int:
	if squad.is_empty():
		return 0
	var total := 0.0
	for player_data : PlayerResource in squad:
		total += player_data.power
	return int(clampf(total / squad.size() / 2.0, 0.0, 99.0))

func _find_goalie(squad: Array) -> PlayerResource:
	for player_data : PlayerResource in squad:
		if player_data.role == Player.Role.GOALIE:
			return player_data
	return null

# "Captain" = highest-power outfield (non-goalie) player. No such concept
# exists in this game's data/rules - purely a cosmetic designation for this
# screen, labeled as such wherever it's shown.
func _find_captain(squad: Array) -> PlayerResource:
	var best : PlayerResource = null
	for player_data : PlayerResource in squad:
		if player_data.role == Player.Role.GOALIE:
			continue
		if best == null or player_data.power > best.power:
			best = player_data
	return best

# Derives a simple "D-M-A" shape from the squad's outfield role counts
# (goalkeeper implied/shown separately) - there is no explicit formation
# string anywhere in this project's data, this purely counts
# Player.Role.DEFENSE/MIDFIELD/OFFENSE occurrences.
func _derive_formation(squad: Array) -> String:
	var counts := {Player.Role.DEFENSE: 0, Player.Role.MIDFIELD: 0, Player.Role.OFFENSE: 0}
	for player_data : PlayerResource in squad:
		if counts.has(player_data.role):
			counts[player_data.role] += 1
	return "%d-%d-%d" % [counts[Player.Role.DEFENSE], counts[Player.Role.MIDFIELD], counts[Player.Role.OFFENSE]]

func _role_short_label(role: Player.Role) -> String:
	match role:
		Player.Role.GOALIE:
			return "GK"
		Player.Role.DEFENSE:
			return "DEF"
		Player.Role.MIDFIELD:
			return "MID"
		_:
			return "ATT"
