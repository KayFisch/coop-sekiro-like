extends Node
## Autoload: switches for the movement abilities, to experiment with which ones the game wants.
## F1 opens a panel anywhere (the game pauses), with the switches grouped in tabs: Tab / Q / E
## (or Page Up / Down) to change tabs, up/down to pick, left/right or Enter to change, F1 again
## to close. Settings are saved to user://moves.cfg and survive restarts.
## Code asks Moves.on("pogo") for a switch, or Moves.value("wall") for a multi-way one.

signal changed

const SAVE_PATH = "user://moves.cfg"
# Bumped whenever the defaults change: a save from an older version is dropped once, so the new
# defaults reach it (see _ready()).
const VERSION = 2
# The panel's text: shrunk as far as it takes for the whole tab to fit on screen.
const PANEL_MARGIN = Vector2(80, 16)
const PANEL_FONT_SIZE = 17
const PANEL_MIN_FONT_SIZE = 10
const LABEL_WIDTH = 50  # characters: the values line up after this

# The panel's tabs, in order. Every entry names one.
const TABS = ["Basics", "Walls", "Pogo", "Partner", "Fights", "Controls"]

# Each switch: key, its tab, what the panel calls it, and its default (a bool, or one of
# `options`). Labels starting with "  " belong to the switch above them.
# The fight kit is on by default; the platforming kit is off, for the gyms (see docs/concept.md).
const ENTRIES = [
	# Basics: on your own feet
	{"key": "dash", "tab": "Basics", "label": "Dash (the way you face)", "default": true},
	{"key": "dash_slash", "tab": "Basics", "label": "Dash-slash (dash + attack)", "default": true},
	{"key": "double_jump", "tab": "Basics", "label": "Double jump", "default": false},
	{"key": "upslash_hop", "tab": "Basics", "label": "Upslash hop", "default": false},
	{"key": "fast_fall", "tab": "Basics", "label": "Fast fall (hold down in the air)", "default": false},
	# Walls and ledges
	{"key": "wall", "tab": "Walls", "label": "Wall: slide or cling", "default": "off", "options": ["off", "slide", "cling"]},
	{"key": "wall_jump", "tab": "Walls", "label": "Wall jump", "default": false},
	{"key": "wall_turn_grace", "tab": "Walls", "label": "  turn grace: holding back just before a wall or partner keeps flying", "default": false},
	{"key": "wall_reach", "tab": "Walls", "label": "  wall reach: turned back this many px short, still jumps off", "default": "off", "options": ["off", "4", "8", "12", "16"]},
	{"key": "wall_rhythm", "tab": "Walls", "label": "  wall rhythm: jump as you hit the wall, else weak", "default": false},
	{"key": "wall_log", "tab": "Walls", "label": "  wall gym: log every climb's timing (wall_log.jsonl)", "default": false},
	{"key": "wall_refresh", "tab": "Walls", "label": "Wall / ledge refreshes the dash", "default": false},
	{"key": "ledge_grab", "tab": "Walls", "label": "Ledge grab + climb", "default": false},
	# Pogo
	{"key": "pogo", "tab": "Pogo", "label": "Pogo clash (downslash onto your partner's upslash)", "default": true},
	{"key": "pogo_environment", "tab": "Pogo", "label": "Pogo off targets, spikes, lanterns (gyms)", "default": false},
	{"key": "pogo_refresh_air_jump", "tab": "Pogo", "label": "  that pogo refreshes the air jump", "default": false},
	{"key": "pogo_refresh_dash", "tab": "Pogo", "label": "  that pogo refreshes the dash", "default": false},
	# Partner: moves made of both players
	{"key": "launch", "tab": "Partner", "label": "Launch (dash-slash into an upslash)", "default": true},
	{"key": "momentum_relay", "tab": "Partner", "label": "Momentum relay (dash-slash into a block)", "default": true},
	{"key": "relay_rhythm", "tab": "Partner", "label": "  rhythm relay: partner strikes on the beat, aims", "default": false},
	{"key": "relay_refresh_dash", "tab": "Partner", "label": "  relay refreshes the dash (rhythm relay: always)", "default": false},
	{"key": "chimney_clash", "tab": "Partner", "label": "Chimney clash (wall jumps meeting)", "default": false},
	{"key": "players_collide", "tab": "Partner", "label": "Players collide (stand on, bump into each other)", "default": true},
	{"key": "call", "tab": "Partner", "label": "Call countdown (P1 Enter, P2 LB)", "default": true},
	# Fights: rules that only matter against a boss
	{"key": "boss_body", "tab": "Fights", "label": "Boss body blocks players (Cubus, Bifrons)", "default": true},
	{"key": "parry_pass", "tab": "Fights", "label": "Dash-parry: a parry mid-dash goes through the boss", "default": true},
	{"key": "bifrons_mode", "tab": "Fights", "label": "Bifrons: set patterns, or reactive (strikes back)", "default": "patterns", "options": ["patterns", "reactive"]},
	{"key": "bifrons_window", "tab": "Fights", "label": "Bifrons: partner hits on the beat, or after it", "default": "beat", "options": ["beat", "after"]},
	{"key": "bifrons_stand_in", "tab": "Fights", "label": "Bifrons: a stand-in plays the player there (alone)", "default": "off", "options": ["off", "left", "right"]},
	{"key": "bifrons_face", "tab": "Fights", "label": "Bifrons: players always face him", "default": true},
	# Controls
	{"key": "swap_controls", "tab": "Controls", "label": "Swap P1 / P2 controls (P1 on the pad; pad Back)", "default": false},
	{"key": "camera_p1", "tab": "Controls", "label": "Gym camera follows only P1 (testing with a bot)", "default": false},
]

var panel_open = false

var _values = {}
var _overridden = {}  # key -> its own value, while a level overrides it (override())
var _tab = 0  # index into TABS
var _selected = 0  # row on the open tab
var _was_paused = false
var _layer: CanvasLayer
var _text: Label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for e in ENTRIES:
		_values[e.key] = e.default
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.get_value("meta", "version", 1) != VERSION:
		_save()  # an older save: back to the new defaults, once
		return
	for e in ENTRIES:
		var saved = cfg.get_value("moves", e.key, e.default)
		if typeof(saved) == typeof(e.default) and (not e.has("options") or saved in e.options):
			_values[e.key] = saved


# True if a switch is on (for a multi-way one: anything but "off").
func on(key: String) -> bool:
	var v = _values.get(key, false)
	return v if v is bool else v != "off"


func value(key: String):
	return _values.get(key)


func set_value(key: String, v):
	_values[key] = v
	_overridden.erase(key)  # set by hand: it's the player's own value now
	_save()
	changed.emit()


func _save():
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for e in ENTRIES:
		cfg.set_value("moves", e.key, _overridden.get(e.key, _values[e.key]))
	cfg.save(SAVE_PATH)


# A level switches something on for as long as it runs (e.g. wall jumps in a room with a
# shaft), without saving it: clear_overrides() puts back the player's own values.
func override(key: String, v):
	if not _overridden.has(key):
		_overridden[key] = _values.get(key)
	_values[key] = v
	changed.emit()


func clear_overrides():
	for key in _overridden:
		_values[key] = _overridden[key]
	_overridden.clear()
	changed.emit()


func reset_defaults():
	for e in ENTRIES:
		set_value(e.key, e.default)


# --- The F1 panel ---

func _input(event):
	# Pad Back / Select swaps the players' controls, anywhere (e.g. to take P1 onto the pad).
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
		set_value("swap_controls", not on("swap_controls"))
		if panel_open:
			_refresh()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F1:
		_set_panel(not panel_open)
		get_viewport().set_input_as_handled()
		return
	if not panel_open:
		return
	var rows = _tab_entries().size() + 1  # the last row resets everything
	match event.physical_keycode:
		KEY_TAB:
			_switch_tab(-1 if event.shift_pressed else 1)
		KEY_E, KEY_PAGEDOWN:
			_switch_tab(1)
		KEY_Q, KEY_PAGEUP:
			_switch_tab(-1)
		KEY_UP, KEY_W:
			_selected = posmod(_selected - 1, rows)
		KEY_DOWN, KEY_S:
			_selected = posmod(_selected + 1, rows)
		KEY_LEFT, KEY_A:
			_change(-1)
		KEY_RIGHT, KEY_D, KEY_ENTER, KEY_SPACE:
			_change(1)
	get_viewport().set_input_as_handled()
	_refresh()


func _set_panel(open: bool):
	if open == panel_open:
		return
	panel_open = open
	if open:
		_was_paused = get_tree().paused
		get_tree().paused = true
		if _layer == null:
			_build_panel()
		_layer.visible = true
		_refresh()
	else:
		_layer.visible = false
		get_tree().paused = _was_paused


# The entries on the open tab, in order.
func _tab_entries() -> Array:
	return ENTRIES.filter(func(e): return e.tab == TABS[_tab])


func _switch_tab(step: int):
	_tab = posmod(_tab + step, TABS.size())
	_selected = 0


# Flips the selected switch (or steps a multi-way one); the last row resets everything.
func _change(step: int):
	var entries = _tab_entries()
	if _selected == entries.size():
		reset_defaults()
		return
	var e = entries[_selected]
	if e.has("options"):
		var i = e.options.find(_values[e.key])
		set_value(e.key, e.options[posmod(i + step, e.options.size())])
	else:
		set_value(e.key, not _values[e.key])


func _build_panel():
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(shade)
	_text = Label.new()
	_text.position = PANEL_MARGIN
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_text)


func _refresh():
	var tabs = []
	for i in TABS.size():
		tabs.append("[ %s ]" % TABS[i].to_upper() if i == _tab else "  %s  " % TABS[i])
	var lines = [
		"MOVEMENT SWITCHES",
		"Tab / Q / E: tab   ↑/↓: pick   ←/→ or Enter: change   F1: close",
		"",
		" ".join(tabs),
		"",
	]
	var entries = _tab_entries()
	for i in entries.size():
		var e = entries[i]
		var v = _values[e.key]
		var shown = ("ON" if v else "off") if v is bool else str(v).to_upper()
		lines.append("%s %s %s" % ["▶" if i == _selected else " ", e.label.rpad(LABEL_WIDTH, " "), shown])
	lines.append("")
	lines.append("%s %s" % ["▶" if _selected == entries.size() else " ", "Reset all to defaults"])
	_text.text = "\n".join(lines)
	var room = _layer.get_viewport().get_visible_rect().size.y - 2.0 * PANEL_MARGIN.y
	var font_size = PANEL_FONT_SIZE
	_text.add_theme_font_size_override("font_size", font_size)
	while font_size > PANEL_MIN_FONT_SIZE and _text.get_minimum_size().y > room:
		font_size -= 1
		_text.add_theme_font_size_override("font_size", font_size)
