extends Node
## Autoload: gives each connected gamepad to one player. The Input Map holds one keyboard layout
## (on the p1_* actions) and one gamepad layout (on the p2_* actions) that listens to every pad
## at once: fine with one pad, but with two, both would drive the same player. So at startup, and
## whenever a pad is plugged in or pulled, the gamepad layout is bound per device:
##   no pad, or one:  p1_* = the keyboard, p2_* = the pad
##   two pads:        p1_* = the keyboard and the first pad, p2_* = the second pad
## Moves "swap_controls" still trades the two sets between the players (see _action() in
## player.gd); with two pads, that swaps the pads.

signal changed

const KEYBOARD_SET = "p1_"
const PAD_SET = "p2_"
const ANY_PAD = -1  # an event's device for "every pad" (how the Input Map's events are saved)
const NO_PAD = -2

var pads: Array = []  # device ids in use: none, [the pad set's], or [the keyboard set's, the pad set's]

var _layout = {}  # action name without its set's prefix -> the Input Map's gamepad events for it


func _ready():
	for action in InputMap.get_actions():
		var action_name = String(action)
		if action_name.begins_with(PAD_SET):
			_layout[action_name.trim_prefix(PAD_SET)] = InputMap.action_get_events(action).filter(_is_pad_event)
	Input.joy_connection_changed.connect(func(_device, _connected): assign(Input.get_connected_joypads()))
	assign(Input.get_connected_joypads())


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
