class_name ScreenData

var tournament : Tournament = null
# Phase 9: "Retry" on WorldScreen's post-disconnect reconnect screen sets
# this so MainMenuScreen.on_set_active() reopens the Multiplayer lobby
# immediately on arrival, instead of the player needing to tap "Multiplayer"
# again by hand.
var reopen_multiplayer_lobby := false

static func build() -> ScreenData:
	return ScreenData.new()

func set_tournament(context_tournament: Tournament) -> ScreenData:
	tournament = context_tournament
	return self
