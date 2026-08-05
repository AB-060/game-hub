class_name GameStateInPlay
extends GameState

# Phase 8: host-authoritative clock. On a networked client, _process here
# does nothing but return early - the host is the sole source of truth for
# manager.time_left and for the decision that time is up, and RPCs both to
# the client (NetworkManager.rpc_sync_clock / rpc_time_up) rather than each
# side running its own independent countdown that could drift or hit zero
# at slightly different real-world moments.
var _last_synced_time := -1.0

func _enter_tree() -> void:
	GameEvents.team_scored.connect(on_team_scored.bind())

func _process(delta: float) -> void:
	if NetworkManager.is_networked() and not NetworkManager.is_host():
		return
	manager.time_left -= delta
	if NetworkManager.is_networked() and NetworkManager.is_host():
		_sync_clock_if_due()
	if manager.is_time_up():
		var is_tied := manager.current_match.is_tied()
		if NetworkManager.is_networked() and NetworkManager.is_host():
			NetworkManager.rpc_time_up(is_tied)
		if is_tied:
			transition_state(GameManager.State.OVERTIME)
		else:
			transition_state(GameManager.State.GAMEOVER)

func _sync_clock_if_due() -> void:
	# Throttled to roughly once per second of match time rather than every
	# frame - frequent enough the client's clock never visibly drifts,
	# cheap enough not to matter for a 1v1 2D game.
	if _last_synced_time < 0 or _last_synced_time - manager.time_left >= 1.0:
		_last_synced_time = manager.time_left
		NetworkManager.rpc_sync_clock(manager.time_left)

func on_team_scored(country_scored_on: String) -> void:
	transition_state(GameManager.State.SCORED, GameStateData.build().set_country_scored_on(country_scored_on))
