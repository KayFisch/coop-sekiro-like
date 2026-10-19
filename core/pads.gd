extends Node
## Autoload: gives each connected gamepad to one player. The Input Map holds one keyboard layout
## (on the p1_* actions) and one gamepad layout (on the p2_* actions) that listens to every pad
## at once: fine with one pad, but with two, both would drive the same player. So at startup, and
## whenever a pad is plugged in or pulled, the gamepad layout is bound per device:
##   no pad, or one:  p1_* = the keyboard, p2_* = the pad
##   two pads:        p1_* = the keyboard and the first pad, p2_* = the second pad
## Moves "swap_controls" still trades the two sets between the players (see action() in
## player_body.gd); with two pads, that swaps the pads.
## Which buttons do what is chosen on the title screen from LAYOUTS (saved in user://pads.cfg);
## the stick stays as the Input Map has it.

signal changed

const KEYBOARD_SET = "p1_"
const PAD_SET = "p2_"
const ANY_PAD = -1  # an event's device for "every pad" (how the Input Map's events are saved)
const NO_PAD = -2
const SAVE_PATH = "user://pads.cfg"
# The pad's buttons, one layout for every pad. Each names its buttons (PlayStation names), and
# gives each action a button, or [axis, value] for a trigger. The first is the Input Map's own.
const LAYOUTS = [
	{"name": "standard", "jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X,
		"dash": JOY_BUTTON_RIGHT_SHOULDER, "block": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
		"buttons": "Cross jump · Square attack · R1 dash · R2 block"},
	{"name": "Sekiro", "jump": JOY_BUTTON_A, "attack": JOY_BUTTON_RIGHT_SHOULDER,
		"dash": JOY_BUTTON_X, "block": JOY_BUTTON_LEFT_SHOULDER,
		"buttons": "Cross jump · R1 attack · Square dash · L1 block"},
	{"name": "dash left", "jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X,
		"dash": JOY_BUTTON_LEFT_SHOULDER, "block": JOY_BUTTON_RIGHT_SHOULDER,
		"buttons": "Cross jump · Square attack · L1 dash · R1 block"},
	{"name": "Sekiro swapped", "jump": JOY_BUTTON_A, "attack": JOY_BUTTON_LEFT_SHOULDER,
		"dash": JOY_BUTTON_X, "block": JOY_BUTTON_RIGHT_SHOULDER,
		"buttons": "Cross jump · L1 attack · Square dash · R1 block"},
]

var pads: Array = []  # device ids in use: none, [the pad set's], or [the keyboard set's, the pad set's]

var layout = 0  # which of LAYOUTS
var _layout = {}  # action name without its set's prefix -> its gamepad events, in that layout


func _ready():
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		layout = clampi(cfg.get_value("pads", "layout", 0), 0, LAYOUTS.size() - 1)
	_read_layout()
	Input.joy_connection_changed.connect(func(_device, _connected): assign(Input.get_connected_joypads()))
	assign(Input.get_connected_joypads())


# The next layout (wrapping round), bound at once and saved.
func next_layout():
	set_layout((layout + 1) % LAYOUTS.size())


func set_layout(index: int, keep = true):
	layout = index
	if keep:
		var cfg = ConfigFile.new()
		cfg.set_value("pads", "layout", layout)
		cfg.save(SAVE_PATH)
	_read_layout()
	assign(Input.get_connected_joypads())


# The layout's name and buttons, e.g. "Sekiro: Cross jump · R1 attack · ...".
func describe_layout() -> String:
	return "%s: %s" % [LAYOUTS[layout].name, LAYOUTS[layout].buttons]


# The Input Map's gamepad events (the stick), with the layout's buttons in place of its own.
func _read_layout():
	_layout.clear()
	for action in InputMap.get_actions():
		var action_name = String(action)
		if not action_name.begins_with(PAD_SET):
			continue
		var button_name = action_name.trim_prefix(PAD_SET)
		if not LAYOUTS[layout].has(button_name):
			_layout[button_name] = InputMap.action_get_events(action).filter(_is_pad_event)
			continue
		var press = LAYOUTS[layout][button_name]
		var event: InputEvent
		if press is Array:
			event = InputEventJoypadMotion.new()
			event.axis = press[0]
			event.axis_value = press[1]
		else:
			event = InputEventJoypadButton.new()
			event.button_index = press
		event.device = ANY_PAD
		_layout[button_name] = [event]


# Hands out the pads in `devices` (ids, as Input.get_connected_joypads() lists them).
func assign(devices: Array):
	# Recognized gamepads only, if there are any: some keyboards and mice show up as joysticks.
	var known = devices.filter(func(device): return Input.is_joy_known(device))
	pads = known if not known.is_empty() else devices.duplicate()
	pads.sort()
	pads = pads.slice(0, 2)
	_bind(KEYBOARD_SET, pads[0] if pads.size() == 2 else NO_PAD)
	_bind(PAD_SET, pads.back() if not pads.is_empty() else ANY_PAD)
	changed.emit()


# Who plays on what, e.g. "P1: keyboard + pad 1 · P2: pad 2", with Moves "swap_controls" applied.
func describe() -> String:
	var sets = ["keyboard", "no pad connected"]
	if pads.size() == 1:
		sets = ["keyboard", "pad"]
	elif pads.size() == 2:
		sets = ["keyboard + pad 1", "pad 2"]
	if Moves.on("swap_controls"):
		sets.reverse()
	return "P1: %s · P2: %s" % sets


# Binds one input set's gamepad events to `device`; its keyboard events stay as they are.
func _bind(prefix: String, device: int):
	for action_name in _layout:
		var action = prefix + action_name
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action).filter(_is_pad_event):
			InputMap.action_erase_event(action, event)
		if device == NO_PAD:
			continue
		for event in _layout[action_name]:
			var bound = event.duplicate()
			bound.device = device
			InputMap.action_add_event(action, bound)
		# A stick's deadzone belongs to the layout, whichever set it's bound to.
		InputMap.action_set_deadzone(action, InputMap.action_get_deadzone(PAD_SET + action_name))


func _is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion
