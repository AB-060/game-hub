class_name TeamSelectionScreen
extends Screen

const FLAG_ANCHOR_POINT := Vector2(35, 80)
const FLAG_SELECTOR_PREFAB := preload("res://scenes/screens/team_selection/flag_selector.tscn")
const NB_COLS := 4
const NB_ROWS := 2

@onready var flags_container : Control = %FlagsContainer

# Built programmatically rather than hand-edited into
# team_selection_screen.tscn (per the "no hand-edited .tscn for new
# standalone/dynamic UI" convention) since this text is fully dynamic and
# doesn't need to live inside the existing scene's node tree.
var _rating_panel : Label = null

var move_dirs : Dictionary[KeyUtils.Action, Vector2i] = {
	KeyUtils.Action.UP: Vector2i.UP,
	KeyUtils.Action.DOWN: Vector2i.DOWN,
	KeyUtils.Action.LEFT: Vector2i.LEFT,
	KeyUtils.Action.RIGHT: Vector2i.RIGHT,
}
var selection : Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var selectors : Array[FlagSelector] = []

func _ready() -> void:
	place_flags()
	place_selectors()
	build_rating_panel()
	update_rating_panel(GameManager.player_setup[0])

func build_rating_panel() -> void:
	_rating_panel = Label.new()
	_rating_panel.position = Vector2(205, 15)
	_rating_panel.size = Vector2(70, 90)
	_rating_panel.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rating_panel.add_theme_font_size_override("font_size", 8)
	flags_container.add_child(_rating_panel)

# There is no team-level rating anywhere in this project's data (squads.json
# / PlayerResource only carry per-player speed/power/role) - this computes a
# simple average on the fly and labels it clearly as computed, rather than
# presenting it as an official rating. Overall/attack/midfield/defense/
# goalkeeper "ratings" here are just power averaged per Role bucket
# (0-goalie, 1-defense, 2-midfield, 3-offense), scaled down to a
# FIFA-style 0-99 range for readability.
func update_rating_panel(country: String) -> void:
	if _rating_panel == null or country.is_empty():
		return
	var squad := DataLoader.get_squad(country)
	if squad.is_empty():
		_rating_panel.text = ""
		return
	var role_totals : Dictionary[Player.Role, float] = {}
	var role_counts : Dictionary[Player.Role, int] = {}
	var overall_total := 0.0
	var lines : PackedStringArray = []
	for player_data : PlayerResource in squad:
		overall_total += player_data.power
		role_totals[player_data.role] = role_totals.get(player_data.role, 0.0) + player_data.power
		role_counts[player_data.role] = role_counts.get(player_data.role, 0) + 1
		lines.append(_role_short_label(player_data.role) + " " + player_data.full_name)
	var overall_rating := int(clamp(overall_total / squad.size() / 2.0, 0, 99))
	var text := "OVR %d (computed)\n" % overall_rating
	text += "GK %d  DEF %d\nMID %d  ATT %d\n\n" % [
		_role_rating(role_totals, role_counts, Player.Role.GOALIE),
		_role_rating(role_totals, role_counts, Player.Role.DEFENSE),
		_role_rating(role_totals, role_counts, Player.Role.MIDFIELD),
		_role_rating(role_totals, role_counts, Player.Role.OFFENSE),
	]
	text += "\n".join(lines)
	_rating_panel.text = text

func _role_rating(totals: Dictionary[Player.Role, float], counts: Dictionary[Player.Role, int], role: Player.Role) -> int:
	if not counts.has(role) or counts[role] == 0:
		return 0
	var average : float = totals[role] / counts[role]
	return int(clamp(average / 2.0, 0, 99))

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

func _process(_delta: float) -> void:
	for i in range(selectors.size()):
		var selector := selectors[i]
		if not selector.is_selected:
			for action : KeyUtils.Action in move_dirs.keys():
				if KeyUtils.is_action_just_pressed(selector.control_scheme, action):
					try_navigate(i, move_dirs[action])
	if not selectors[0].is_selected and KeyUtils.is_action_just_pressed(Player.ControlScheme.P1, KeyUtils.Action.PASS):
		SoundPlayer.play(SoundPlayer.Sound.UI_NAV)
		transition_screen(SoccerGame.ScreenType.MAIN_MENU)

func try_navigate(selector_index: int, direction: Vector2i) -> void:
	var rect : Rect2i = Rect2i(0, 0, NB_COLS, NB_ROWS)
	if rect.has_point(selection[selector_index] + direction):
		selection[selector_index] += direction
		var flag_index := selection[selector_index].x + selection[selector_index].y * NB_COLS
		GameManager.player_setup[selector_index] = DataLoader.get_countries()[1 + flag_index]
		selectors[selector_index].position = flags_container.get_child(flag_index).position
		SoundPlayer.play(SoundPlayer.Sound.UI_NAV)
		if selector_index == 0:
			update_rating_panel(GameManager.player_setup[0])

func place_flags() -> void:
	for j in range(NB_ROWS):
		for i in range(NB_COLS):
			var flag_texture := TextureRect.new()
			flag_texture.position = FLAG_ANCHOR_POINT + Vector2(55 * i, 50 * j)
			var country_index := 1 + i + j * NB_COLS
			var country := DataLoader.get_countries()[country_index]
			flag_texture.texture = FlagHelper.get_texture(country)
			flag_texture.scale = Vector2(2, 2)
			flag_texture.z_index = 1
			flags_container.add_child(flag_texture)
			
func place_selectors() -> void:
	add_selector(Player.ControlScheme.P1)
	if not GameManager.player_setup[1].is_empty():
		add_selector(Player.ControlScheme.P2)
	
func add_selector(control_scheme: Player.ControlScheme) -> void:
	var selector := FLAG_SELECTOR_PREFAB.instantiate()
	selector.position = flags_container.get_child(0).position
	selector.control_scheme = control_scheme
	selector.selected.connect(on_selector_selected.bind())
	selectors.append(selector)
	flags_container.add_child(selector)

func on_selector_selected() -> void:
	for selector in selectors:
		if not selector.is_selected:
			return
	var country_p1 := GameManager.player_setup[0]
	var country_p2 := GameManager.player_setup[1]
	if not country_p2.is_empty() and country_p1 != country_p2:
		GameManager.current_match = Match.new(country_p2, country_p1)
		# New this pass: show the Team Lineup screen, then a kickoff
		# presentation (flags/vs/3-2-1 countdown), before actually
		# transitioning into IN_GAME - only for this direct head-to-head
		# path. Tournament matches (the else branch below) still go
		# straight to TOURNAMENT/IN_GAME unchanged, to limit the risk of
		# touching that separately-reviewed flow in this pass.
		show_lineup_then_kickoff(country_p2, country_p1)
	else:
		transition_screen(SoccerGame.ScreenType.TOURNAMENT, ScreenData.build().set_tournament(Tournament.new()))

func show_lineup_then_kickoff(country_home: String, country_away: String) -> void:
	# setup() must run BEFORE add_child(): once this screen's parent is
	# already in the SceneTree (it is - team_selection_screen is actively
	# running), add_child() fires the new node's _ready() synchronously,
	# before add_child() even returns. Both LineupScreen._ready() and
	# KickoffScreen._ready() build their entire UI directly from
	# country_home/country_away, so calling setup() afterward would leave
	# them building from still-empty default strings - a blank screen that
	# never recovers, since nothing re-triggers a rebuild once setup() does
	# run. Reordering avoids the problem entirely; no need to defer
	# add_child() (as GameManager.switch_state()/Player.switch_state() do
	# elsewhere in this project for the same underlying reason), since
	# setup() itself has no scene-tree dependency.
	var lineup := LineupScreen.new()
	lineup.setup(country_home, country_away)
	add_child(lineup)
	lineup.continued.connect(func() -> void:
		var kickoff := KickoffScreen.new()
		kickoff.setup(country_home, country_away)
		add_child(kickoff)
		kickoff.kickoff_finished.connect(func() -> void:
			transition_screen(SoccerGame.ScreenType.IN_GAME)
		)
	)
