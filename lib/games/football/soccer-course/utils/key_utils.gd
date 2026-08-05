class_name KeyUtils

enum Action {LEFT, RIGHT, UP, DOWN, SHOOT, PASS, SPRINT}

const ACTIONS_MAP : Dictionary = {
	Player.ControlScheme.P1: {
		Action.LEFT: "p1_left",
		Action.RIGHT: "p1_right",
		Action.UP: "p1_up",
		Action.DOWN: "p1_down",
		Action.SHOOT: "p1_shoot",
		Action.PASS: "p1_pass",
		Action.SPRINT: "p1_sprint",
	},
	Player.ControlScheme.P2: {
		Action.LEFT: "p2_left",
		Action.RIGHT: "p2_right",
		Action.UP: "p2_up",
		Action.DOWN: "p2_down",
		Action.SHOOT: "p2_shoot",
		Action.PASS: "p2_pass",
		Action.SPRINT: "p2_sprint",
	},
}

# On a networked host, P2's real input lives on the remote client and is
# replicated via NetworkManager instead of local Input state. Local play
# (NetworkManager idle) and P1 always fall through to the original behavior.
static func get_input_vector(scheme: Player.ControlScheme) -> Vector2:
	if scheme == Player.ControlScheme.P2 and NetworkManager.is_networked() and NetworkManager.is_host():
		return NetworkManager.get_remote_input_vector()
	var map : Dictionary = ACTIONS_MAP[scheme]
	var vector := Input.get_vector(map[Action.LEFT], map[Action.RIGHT], map[Action.UP], map[Action.DOWN])
	# Phase 5: invert/sensitivity settings applied here rather than in
	# TouchControls, since both touch and keyboard ultimately drive the same
	# named p1_*/p2_* actions and this is the single point both funnel
	# through via Input.get_vector above.
	if Settings.invert_movement_x:
		vector.x = -vector.x
	if Settings.invert_movement_y:
		vector.y = -vector.y
	vector *= Settings.joystick_sensitivity
	if vector.length() > 1.0:
		vector = vector.normalized()
	return vector

static func is_action_pressed(scheme: Player.ControlScheme, action: Action) -> bool:
	if scheme == Player.ControlScheme.P2 and NetworkManager.is_networked() and NetworkManager.is_host():
		return NetworkManager.get_remote_action_pressed(action)
	return Input.is_action_pressed(ACTIONS_MAP[scheme][action])

static func is_action_just_pressed(scheme: Player.ControlScheme, action: Action) -> bool:
	if scheme == Player.ControlScheme.P2 and NetworkManager.is_networked() and NetworkManager.is_host():
		return NetworkManager.get_remote_action_just_pressed(action)
	return Input.is_action_just_pressed(ACTIONS_MAP[scheme][action])

static func is_action_just_released(scheme: Player.ControlScheme, action: Action) -> bool:
	if scheme == Player.ControlScheme.P2 and NetworkManager.is_networked() and NetworkManager.is_host():
		return NetworkManager.get_remote_action_just_released(action)
	return Input.is_action_just_released(ACTIONS_MAP[scheme][action])
