class_name MultiplayerLobby
extends CanvasLayer

# Built entirely in code (no .tscn) and added as an overlay by
# MainMenuScreen when the player picks the "Multiplayer" option, rather than
# registering a new Screen/.tscn pair - simpler and lower-risk given the
# "no hand-edited .tscn" constraint, since this is a small, self-contained
# flow that only needs to call NetworkManager and then hand off to the
# existing screen-transition system once a match is ready.

signal cancelled

var _status_label : Label
var _list_container : VBoxContainer
var _root : Control
var _local_country := ""

# Phase 8: waiting-room state, shown once both sides know each other's
# country but before either has pressed Ready.
var _waiting_room : VBoxContainer = null
var _ready_button : Button = null
var _local_ready_label : Label = null
var _remote_ready_label : Label = null
var _ip_input : LineEdit = null
var _ping_label : Label = null
var _is_host_side := false
var _name_input : LineEdit = null

func _ready() -> void:
	layer = 60
	_local_country = DataLoader.get_countries()[0]

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(60, 30)
	_root.add_child(vbox)

	var name_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = Settings.t("player_name")
	name_row.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.text = Settings.player_name
	_name_input.custom_minimum_size = Vector2(90, 20)
	_name_input.text_submitted.connect(func(_text: String) -> void: _commit_player_name())
	_name_input.focus_exited.connect(_commit_player_name)
	name_row.add_child(_name_input)
	vbox.add_child(name_row)

	var host_button := _make_button("Heberger")
	host_button.pressed.connect(_on_host_pressed)
	vbox.add_child(host_button)

	var join_button := _make_button("Rejoindre")
	join_button.pressed.connect(_on_join_pressed)
	vbox.add_child(join_button)

	var cancel_button := _make_button("Retour")
	cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(cancel_button)

	_status_label = Label.new()
	_status_label.text = ""
	vbox.add_child(_status_label)

	_list_container = VBoxContainer.new()
	vbox.add_child(_list_container)

	# Phase 8: manual IP entry, as an alternative to the auto-discovered
	# list above - some networks/routers block the UDP discovery broadcast
	# entirely, in which case the list never populates and there was
	# previously no other way to connect.
	var ip_row := HBoxContainer.new()
	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "IP manuelle"
	_ip_input.custom_minimum_size = Vector2(110, 20)
	ip_row.add_child(_ip_input)
	var ip_connect_button := _make_button("Connecter")
	ip_connect_button.pressed.connect(_on_manual_ip_pressed)
	ip_row.add_child(ip_connect_button)
	vbox.add_child(ip_row)

	_waiting_room = VBoxContainer.new()
	_waiting_room.visible = false
	vbox.add_child(_waiting_room)

	NetworkManager.host_discovered.connect(_on_host_discovered)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.countries_known.connect(_on_countries_known)
	NetworkManager.remote_ready_changed.connect(_on_remote_ready_changed)
	NetworkManager.remote_ready_to_play.connect(_on_remote_ready_to_play)
	# Ping is only ever meaningful once a connection exists - NetworkManager's
	# hand-rolled ping/pong (see network_manager.gd's "--- Ping ---" section)
	# is client -> host only (ENet has no way to probe an RTT to a host you
	# haven't connected to yet), so this can only ever show a number here in
	# the post-connection waiting room, on the client side. There is no way to
	# show per-host ping in the discovered-hosts list above; showing a fake
	# number there would misrepresent hosts nothing has pinged yet.
	NetworkManager.ping_updated.connect(_on_ping_updated)

func _commit_player_name() -> void:
	if _name_input != null:
		Settings.set_player_name(_name_input.text)
		_name_input.text = Settings.player_name # reflects trim/empty-fallback

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 20)
	return button

func _on_host_pressed() -> void:
	_commit_player_name()
	_is_host_side = true
	var local_ip := NetworkManager.get_local_ip_address()
	# Honest fallback: if IP.get_local_addresses() has nothing usable (e.g. no
	# network interface up), say so rather than showing a blank/fake address.
	var ip_text := local_ip if not local_ip.is_empty() else "IP locale indisponible"
	_status_label.text = "En attente d'un adversaire... (Votre IP: %s)" % ip_text
	NetworkManager.host_game(_local_country)

func _on_join_pressed() -> void:
	_commit_player_name()
	_is_host_side = false
	_status_label.text = "Recherche de parties..."
	for child in _list_container.get_children():
		child.queue_free()
	NetworkManager.start_discovery()

func _on_host_discovered(ip: String, host_name: String, country: String) -> void:
	var entry := _make_button("%s (%s) - %s" % [host_name, country, ip])
	entry.pressed.connect(func() -> void:
		_status_label.text = "Connexion..."
		NetworkManager.stop_discovery()
		NetworkManager.join_game(ip, _local_country)
	)
	_list_container.add_child(entry)

func _on_manual_ip_pressed() -> void:
	var ip := _ip_input.text.strip_edges()
	if ip.is_empty():
		return
	_status_label.text = "Connexion..."
	NetworkManager.stop_discovery()
	NetworkManager.join_game(ip, _local_country)

func _on_connection_succeeded() -> void:
	_status_label.text = "Connecte, echange des equipes..."

func _on_connection_failed() -> void:
	# Godot's multiplayer.connection_failed signal carries no error code or
	# distinguishing detail (ENet-level: it fires the same way whether the
	# host is offline, unreachable, or actively refusing) - honest single
	# message rather than inventing fake specificity (e.g. can't actually
	# tell "timeout" from "host full" apart here).
	_status_label.text = Settings.t("connection_failed_detail")

# Phase 8: fires once both sides know each other's country - this is where
# connection previously jumped straight into the match. Now it opens a
# waiting room instead, and the match only actually starts once both sides
# have pressed Ready (see _on_remote_ready_to_play below).
func _on_countries_known(host_country: String, client_country: String) -> void:
	_status_label.text = ""
	for child in _list_container.get_children():
		child.queue_free()
	_build_waiting_room(host_country, client_country)

func _build_waiting_room(host_country: String, client_country: String) -> void:
	for child in _waiting_room.get_children():
		child.queue_free()
	_waiting_room.visible = true

	var info := Label.new()
	info.text = "%s vs %s" % [host_country, client_country]
	_waiting_room.add_child(info)

	# By the time countries_known fires, the opponent is already connected on
	# both sides (that's what let the countries get exchanged) - MAX_CLIENTS
	# is 1 for this 1v1 game, so "connected players" only ever means this
	# binary opponent-present state, not a real player-count system.
	var connected_label := Label.new()
	connected_label.text = "Adversaire connecte (1/1)"
	_waiting_room.add_child(connected_label)

	# Real host settings (this simplified 1v1 mode just runs with whatever
	# the HOST's own Settings say - no negotiation, just surfacing them via
	# NetworkManager.host_match_duration_sec/host_match_difficulty, set from
	# the country-exchange RPC on both sides, see network_manager.gd).
	var duration_label := Label.new()
	var minutes := NetworkManager.host_match_duration_sec / 60
	var seconds := NetworkManager.host_match_duration_sec % 60
	var difficulty_key : String = ["difficulty_easy", "difficulty_normal", "difficulty_hard"][clampi(NetworkManager.host_match_difficulty, 0, 2)]
	duration_label.text = "%s: %d:%02d - %s" % [Settings.t("match_settings_label"), minutes, seconds, Settings.t(difficulty_key)]
	_waiting_room.add_child(duration_label)

	if _is_host_side:
		var local_ip := NetworkManager.get_local_ip_address()
		var host_ip_label := Label.new()
		host_ip_label.text = "Votre IP: %s" % (local_ip if not local_ip.is_empty() else "indisponible")
		_waiting_room.add_child(host_ip_label)
	else:
		_ping_label = Label.new()
		_ping_label.text = "Ping: ..."
		_waiting_room.add_child(_ping_label)

	_local_ready_label = Label.new()
	_local_ready_label.text = "Vous: pas pret"
	_waiting_room.add_child(_local_ready_label)

	_remote_ready_label = Label.new()
	_remote_ready_label.text = "Adversaire: pas pret"
	_waiting_room.add_child(_remote_ready_label)

	_ready_button = _make_button("Pret")
	_ready_button.pressed.connect(_on_ready_pressed)
	_waiting_room.add_child(_ready_button)

func _on_ready_pressed() -> void:
	NetworkManager.set_local_ready(true)
	_local_ready_label.text = "Vous: pret"
	_ready_button.disabled = true

func _on_remote_ready_changed(is_ready: bool) -> void:
	if _remote_ready_label != null:
		_remote_ready_label.text = "Adversaire: pret" if is_ready else "Adversaire: pas pret"

func _on_remote_ready_to_play(_host_country: String, _client_country: String) -> void:
	queue_free()

func _on_ping_updated(rtt_msec: int) -> void:
	if _ping_label != null:
		_ping_label.text = "Ping: %d ms (%s)" % [rtt_msec, _connection_quality_label(rtt_msec)]

# Real, cheap bucketing of the actual measured RTT (see NetworkManager's
# hand-rolled ping/pong) into a simple honest tier - not fabricated.
func _connection_quality_label(rtt_msec: int) -> String:
	if rtt_msec < 50:
		return Settings.t("connection_quality_good")
	elif rtt_msec < 150:
		return Settings.t("connection_quality_fair")
	else:
		return Settings.t("connection_quality_poor")

func _on_cancel_pressed() -> void:
	NetworkManager.stop_discovery()
	NetworkManager.stop_hosting()
	if NetworkManager.is_networked():
		NetworkManager.disconnect_network()
	cancelled.emit()
	queue_free()
