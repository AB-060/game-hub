extends Node
# Registered as the "NetworkManager" autoload singleton in project.godot.
# Deliberately has no class_name: an autoload script whose class_name matches
# its singleton name shadows the singleton with the script's static class,
# turning every NetworkManager.foo() call into an (invalid) static call.

# Host-authoritative LAN multiplayer for the 1v1 "versus" mode only.
# The host runs the full local simulation exactly as single-device play does
# today; the client only ships its own input to the host and receives
# replicated Player/Ball transforms back via MultiplayerSynchronizer.

signal host_discovered(ip: String, host_name: String, country: String)
signal connection_succeeded
signal connection_failed
signal server_disconnected
signal remote_ready_to_play(host_country: String, client_country: String)
# Phase 8: lobby "waiting room" - fired as soon as both sides know each
# other's country, before either has pressed Ready. remote_ready_to_play
# (above) now only fires once BOTH sides have confirmed ready.
signal countries_known(host_country: String, client_country: String)
signal remote_ready_changed(is_ready: bool)
signal ping_updated(rtt_msec: int)
# Phase 8: mid-match disconnect handling - distinct from connection_failed
# (which fires only for an initial connection attempt that never succeeded).
signal opponent_disconnected

const ENET_PORT := 9750
const DISCOVERY_PORT := 9751
const DISCOVERY_INTERVAL := 0.5
const DISCOVERY_EXPIRY := 3.0
const MAX_CLIENTS := 1
const PING_INTERVAL := 1.0

var _discovery_broadcast_udp : PacketPeerUDP = null
var _discovery_listen_udp : PacketPeerUDP = null
var _discovery_timer : Timer = null
var _known_hosts : Dictionary = {} # ip -> {host_name, country, last_seen}

var local_host_country := ""
var local_client_country := ""
var remote_country := "" # on host: the connected client's country
var local_ready := false
var remote_ready := false
var last_ping_msec := -1
var _ping_time_accum := 0.0

# Match settings display only (see multiplayer_lobby.gd's waiting room) -
# this simplified 1v1 mode still just runs with the HOST's own Settings once
# the match starts; there is no negotiation, these two fields exist purely
# so the lobby (on both sides) can show what will actually govern the match,
# real data piggy-backed onto the existing country-exchange RPC rather than
# a new settings-sync system.
var host_match_duration_sec := 0
var host_match_difficulty : Settings.Difficulty = Settings.Difficulty.NORMAL

# Remote input state, populated on the host from the client's RPCs.
var _remote_input_vector := Vector2.ZERO
var _remote_action_pressed := {
	KeyUtils.Action.SHOOT: false,
	KeyUtils.Action.PASS: false,
	KeyUtils.Action.SPRINT: false,
}
var _remote_action_pressed_prev := {
	KeyUtils.Action.SHOOT: false,
	KeyUtils.Action.PASS: false,
	KeyUtils.Action.SPRINT: false,
}

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _process(delta: float) -> void:
	if _discovery_listen_udp != null:
		_poll_discovery_listener()
	if not _known_hosts.is_empty():
		_expire_stale_hosts()
	if is_client() and is_networked():
		_send_local_input()
		_process_ping(delta)

func is_host() -> bool:
	return is_networked() and multiplayer.is_server()

func is_client() -> bool:
	return is_networked() and not multiplayer.is_server()

func is_networked() -> bool:
	return multiplayer.multiplayer_peer != null

# --- Hosting ---

func host_game(local_country: String) -> void:
	local_host_country = local_country
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(ENET_PORT, MAX_CLIENTS)
	if err != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	_start_broadcasting(local_country)

func _start_broadcasting(local_country: String) -> void:
	_discovery_broadcast_udp = PacketPeerUDP.new()
	_discovery_broadcast_udp.set_broadcast_enabled(true)
	_discovery_timer = Timer.new()
	_discovery_timer.wait_time = DISCOVERY_INTERVAL
	_discovery_timer.autostart = true
	_discovery_timer.timeout.connect(func() -> void:
		var beacon := {
			"game": "soccer_course",
			"host_name": Settings.player_name,
			"country": local_country,
		}
		var bytes := JSON.stringify(beacon).to_utf8_buffer()
		_discovery_broadcast_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		_discovery_broadcast_udp.put_packet(bytes)
	)
	add_child(_discovery_timer)

# UI/UX pass: exposes the host device's own local network address so the
# lobby can display something a player on the same WiFi/hotspot can type into
# "IP manuelle" on another device, instead of only ever seeing "En attente
# d'un adversaire..." with no address at all. IP.get_local_addresses() is the
# real Godot API for this (no dedicated "get my LAN IP" call exists) -
# filtered here to drop loopback (127.x) and link-local (169.254.x, common on
# an interface with no DHCP lease yet) addresses, which are never useful to
# hand to another device. Returns "" if nothing better is found rather than
# fabricating a placeholder address.
func get_local_ip_address() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.find(":") != -1: # skip IPv6 addresses, keep this LAN-simple
			continue
		return address
	return ""

func stop_hosting() -> void:
	if _discovery_timer != null:
		_discovery_timer.queue_free()
		_discovery_timer = null
	if _discovery_broadcast_udp != null:
		_discovery_broadcast_udp.close()
		_discovery_broadcast_udp = null

# --- Discovery (client) ---

func start_discovery() -> void:
	_known_hosts.clear()
	_discovery_listen_udp = PacketPeerUDP.new()
	# NOTE: binding to DISCOVERY_PORT on all interfaces to receive broadcast beacons.
	# If this errors in the Editor with a bind/permission issue, double-check
	# platform firewall rules allow inbound UDP on this port.
	_discovery_listen_udp.bind(DISCOVERY_PORT)

func stop_discovery() -> void:
	if _discovery_listen_udp != null:
		_discovery_listen_udp.close()
		_discovery_listen_udp = null
	_known_hosts.clear()

func _poll_discovery_listener() -> void:
	while _discovery_listen_udp.get_available_packet_count() > 0:
		var packet := _discovery_listen_udp.get_packet()
		var ip := _discovery_listen_udp.get_packet_ip()
		var text := packet.get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if parsed.get("game", "") != "soccer_course":
			continue
		var is_new := not _known_hosts.has(ip)
		_known_hosts[ip] = {
			"host_name": parsed.get("host_name", "Host"),
			"country": parsed.get("country", ""),
			"last_seen": Time.get_ticks_msec() / 1000.0,
		}
		if is_new:
			host_discovered.emit(ip, _known_hosts[ip]["host_name"], _known_hosts[ip]["country"])

func _expire_stale_hosts() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for ip in _known_hosts.keys():
		if now - _known_hosts[ip]["last_seen"] > DISCOVERY_EXPIRY:
			_known_hosts.erase(ip)

# --- Joining ---

func join_game(ip: String, local_country: String) -> void:
	local_client_country = local_country
	local_ready = false
	remote_ready = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, ENET_PORT)
	if err != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer

func _on_connected_to_server() -> void:
	connection_succeeded.emit()
	_rpc_announce_country.rpc_id(1, local_client_country)

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()
	_reset_session_state()

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(_id: int) -> void:
	# The host is the only side that gets useful information out of
	# peer_disconnected (multiplayer.server_disconnected already covers the
	# client's own "I lost the host" case). MAX_CLIENTS is 1, so any
	# peer_disconnected on the host means the sole opponent left, mid-match
	# or otherwise - the caller (world_screen) decides what UI to show.
	if is_host():
		opponent_disconnected.emit()
		_reset_session_state()

func _reset_session_state() -> void:
	local_ready = false
	remote_ready = false
	remote_country = ""
	last_ping_msec = -1

# Disconnects cleanly (used by "Quit Match" in a networked pause menu and by
# disconnect-handling code) rather than leaving the ENetMultiplayerPeer
# around while the game transitions screens locally.
func disconnect_network() -> void:
	stop_hosting()
	stop_discovery()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_reset_session_state()

# --- Lobby: country exchange + ready check ---

@rpc("any_peer", "reliable")
func _rpc_announce_country(client_country: String) -> void:
	# Only meaningful on the host.
	if not is_host():
		return
	remote_country = client_country
	GameManager.player_setup = [local_host_country, remote_country]
	host_match_duration_sec = Settings.match_duration_sec
	host_match_difficulty = Settings.difficulty
	_rpc_announce_host_country.rpc_id(multiplayer.get_remote_sender_id(), local_host_country, Settings.match_duration_sec, Settings.difficulty)
	countries_known.emit(local_host_country, remote_country)

@rpc("authority", "reliable")
func _rpc_announce_host_country(host_country: String, host_duration_sec: int, host_difficulty: int) -> void:
	# Runs on the client once the host has recorded both countries.
	GameManager.player_setup = [host_country, local_client_country]
	host_match_duration_sec = host_duration_sec
	host_match_difficulty = host_difficulty as Settings.Difficulty
	countries_known.emit(host_country, local_client_country)

# Called by the lobby UI on either side when the local player presses Ready.
# "remote_ready"/remote_ready_changed always means "the OTHER side's ready
# state, as seen from here" - the host tracks the client's readiness and the
# client tracks the host's, each told about the other's via RPC below.
func set_local_ready(is_ready: bool) -> void:
	local_ready = is_ready
	if is_host():
		# The host's own readiness changed - the client needs to know, and
		# the host itself may now satisfy "both ready".
		_rpc_remote_ready_state.rpc(is_ready)
		_check_both_ready()
	else:
		_rpc_set_ready.rpc_id(1, is_ready)

@rpc("any_peer", "reliable")
func _rpc_set_ready(is_ready: bool) -> void:
	# Runs on the host: records the client's ready state, tells it back the
	# host's own current ready state (so a client readying up after the host
	# already did sees "opponent ready" immediately), then checks for both-ready.
	if not is_host():
		return
	remote_ready = is_ready
	_rpc_remote_ready_state.rpc_id(multiplayer.get_remote_sender_id(), local_ready)
	_check_both_ready()

@rpc("authority", "reliable")
func _rpc_remote_ready_state(is_ready: bool) -> void:
	# Runs on the client: is_ready here is the HOST's readiness.
	remote_ready = is_ready
	remote_ready_changed.emit(is_ready)

func _check_both_ready() -> void:
	# Local-only refresh of this side's own "opponent ready" UI state.
	remote_ready_changed.emit(remote_ready)
	if is_host() and local_ready and remote_ready:
		_rpc_start_match.rpc(local_host_country, remote_country)
		remote_ready_to_play.emit(local_host_country, remote_country)

@rpc("authority", "reliable")
func _rpc_start_match(host_country: String, client_country: String) -> void:
	# Runs on the client, told by the host that both sides are ready.
	GameManager.player_setup = [host_country, client_country]
	remote_ready_to_play.emit(host_country, client_country)

# --- Match state authority (host -> client) ---
# Score/goal detection, the match clock and kickoff/half-time/full-time
# transitions must be decided exactly once, by the host, and then told to
# the client - see goal.gd's on_ball_enter_scoring_area() and
# game_state_in_play.gd for the client-side guards these RPCs pair with.

func rpc_team_scored(country: String) -> void:
	if not is_host():
		return
	_rpc_team_scored.rpc(country)

@rpc("authority", "reliable")
func _rpc_team_scored(country: String) -> void:
	if is_host():
		return
	GameEvents.team_scored.emit(country)

func rpc_sync_clock(time_left: float) -> void:
	if not is_host():
		return
	_rpc_sync_clock.rpc(time_left)

@rpc("authority", "unreliable")
func _rpc_sync_clock(time_left: float) -> void:
	if is_host():
		return
	GameManager.time_left = time_left

func rpc_time_up(is_tied: bool) -> void:
	if not is_host():
		return
	_rpc_time_up.rpc(is_tied)

@rpc("authority", "reliable")
func _rpc_time_up(is_tied: bool) -> void:
	if is_host():
		return
	GameManager.switch_state(GameManager.State.OVERTIME if is_tied else GameManager.State.GAMEOVER)

# --- Ping (custom RTT measurement) ---
# Godot/ENet don't expose a ready-made per-peer RTT accessor usable here, so
# this is a small hand-rolled ping/pong pair: the client stamps a send time
# and the host echoes it straight back unchanged; the client then diffs
# against Time.get_ticks_msec() on receipt. Simple, not a full jitter/loss
# estimator - just a live "how laggy is this connection" number.

func _process_ping(delta: float) -> void:
	_ping_time_accum += delta
	if _ping_time_accum >= PING_INTERVAL:
		_ping_time_accum = 0.0
		_rpc_ping.rpc_id(1, Time.get_ticks_msec())

@rpc("any_peer", "unreliable")
func _rpc_ping(client_send_time_msec: int) -> void:
	if not is_host():
		return
	_rpc_pong.rpc_id(multiplayer.get_remote_sender_id(), client_send_time_msec)

@rpc("authority", "unreliable")
func _rpc_pong(client_send_time_msec: int) -> void:
	last_ping_msec = Time.get_ticks_msec() - client_send_time_msec
	ping_updated.emit(last_ping_msec)

# --- Input replication (client -> host) ---

func _send_local_input() -> void:
	var vector := KeyUtils.get_input_vector(Player.ControlScheme.P2)
	var shoot := KeyUtils.is_action_pressed(Player.ControlScheme.P2, KeyUtils.Action.SHOOT)
	var pass_pressed := KeyUtils.is_action_pressed(Player.ControlScheme.P2, KeyUtils.Action.PASS)
	var sprint := KeyUtils.is_action_pressed(Player.ControlScheme.P2, KeyUtils.Action.SPRINT)
	_rpc_send_input.rpc_id(1, vector, shoot, pass_pressed, sprint)

@rpc("any_peer", "unreliable_ordered")
func _rpc_send_input(vector: Vector2, shoot: bool, pass_pressed: bool, sprint: bool) -> void:
	if not is_host():
		return
	_remote_input_vector = vector
	_remote_action_pressed_prev = _remote_action_pressed.duplicate()
	_remote_action_pressed = {
		KeyUtils.Action.SHOOT: shoot,
		KeyUtils.Action.PASS: pass_pressed,
		KeyUtils.Action.SPRINT: sprint,
	}

func get_remote_input_vector() -> Vector2:
	return _remote_input_vector

func get_remote_action_pressed(action: KeyUtils.Action) -> bool:
	return _remote_action_pressed.get(action, false)

func get_remote_action_just_pressed(action: KeyUtils.Action) -> bool:
	return _remote_action_pressed.get(action, false) and not _remote_action_pressed_prev.get(action, false)

func get_remote_action_just_released(action: KeyUtils.Action) -> bool:
	return not _remote_action_pressed.get(action, false) and _remote_action_pressed_prev.get(action, false)
