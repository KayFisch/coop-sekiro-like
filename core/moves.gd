extends Node
## Autoload: switches for the movement abilities, to experiment with which ones the game wants.
## F1 opens a panel anywhere (the game pauses): up/down to pick, left/right or Enter to change,
## F1 again to close. Settings are saved to user://moves.cfg and survive restarts.
## Code asks Moves.on("pogo") for a switch, or Moves.value("wall") for a multi-way one.

signal changed

const SAVE_PATH = "user://moves.cfg"
# Bumped whenever the defaults change: a save from an older version is dropped once, so the new
# defaults reach it (see _ready()).
const VERSION = 2
# The panel's text: shrunk as far as it takes for the whole list to fit on screen.
const PANEL_MARGIN = Vector2(80, 16)
const PANEL_FONT_SIZE = 17
const PANEL_MIN_FONT_SIZE = 10

# Each switch: key, what the panel calls it, and its default (a bool, or one of `options`).
# The fight kit is on by default; the platforming kit is off, for the gyms (see docs/concept.md).
const ENTRIES = [
	{"key": "double_jump", "label": "Double jump", "default": false},
	{"key": "dash", "label": "Dash (the way you face)", "default": true},
	{"key": "dash_slash", "label": "Dash-slash", "default": true},
	{"key": "upslash_hop", "label": "Upslash hop", "default": false},
	{"key": "fast_fall", "label": "Fast fall (hold down in the air)", "default": false},
	{"key": "wall", "label": "Wall: slide or cling", "default": "off", "options": ["off", "slide", "cling"]},
	{"key": "wall_jump", "label": "Wall jump", "default": false},
	{"key": "wall_refresh", "label": "Wall / ledge refreshes the dash", "default": false},
	{"key": "ledge_grab", "label": "Ledge grab + climb", "default": false},
	{"key": "pogo", "label": "Pogo clash (downslash onto your partner's upslash)", "default": true},
	{"key": "pogo_environment", "label": "Pogo off targets, spikes, lanterns (gyms)", "default": false},
	{"key": "pogo_refresh_air_jump", "label": "   that pogo refreshes the air jump", "default": false},
	{"key": "pogo_refresh_dash", "label": "   that pogo refreshes the dash", "default": false},
	{"key": "launch", "label": "Launch (dash-slash into an upslash)", "default": true},
	{"key": "momentum_relay", "label": "Momentum relay (dash-slash into a block)", "default": true},
	{"key": "relay_refresh_dash", "label": "   relay refreshes the dash", "default": false},
	{"key": "chimney_clash", "label": "Chimney clash (wall jumps meeting)", "default": false},
	{"key": "players_collide", "label": "Players collide (stand on, bump into each other)", "default": true},
	{"key": "boss_body", "label": "Boss body blocks players (Cubus, Bifrons)", "default": true},
	{"key": "bifrons_mode", "label": "Bifrons: set patterns, or reactive (he parries and counters)", "default": "patterns", "options": ["patterns", "reactive"]},
	{"key": "bifrons_window", "label": "Bifrons: partner hits on the beat, or after it", "default": "beat", "options": ["beat", "after"]},
	{"key": "bifrons_guard", "label": "Bifrons: guarded (hits bounce unless a parry opens him)", "default": true},
	{"key": "bifrons_stand_in", "label": "Bifrons: a stand-in parries on that side (testing alone)", "default": "off", "options": ["off", "left", "right"]},
	{"key": "call", "label": "Call countdown (P1 Enter, P2 LB)", "default": true},
	{"key": "swap_controls", "label": "Swap P1 / P2 controls (P1 on the pad)", "default": false},
]

var panel_open = false

var _values = {}
var _selected = 0
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
	_save()
	changed.emit()


func _save():
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for e in ENTRIES:
		cfg.set_value("moves", e.key, _values[e.key])
	cfg.save(SAVE_PATH)


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
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_selected = posmod(_selected - 1, ENTRIES.size() + 1)
		KEY_DOWN, KEY_S:
			_selected = posmod(_selected + 1, ENTRIES.size() + 1)
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


# Flips the selected switch (or steps a multi-way one); the last row resets everything.
func _change(step: int):
	if _selected == ENTRIES.size():
		reset_defaults()
		return
	var e = ENTRIES[_selected]
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
	var lines = ["MOVEMENT SWITCHES   (↑/↓ pick · ←/→ or Enter change · F1 close)", ""]
	for i in ENTRIES.size():
		var e = ENTRIES[i]
		var v = _values[e.key]
		var shown = ("ON" if v else "off") if v is bool else str(v).to_upper()
		lines.append("%s %-52s %s" % ["▶" if i == _selected else " ", e.label, shown])
	lines.append("")
	lines.append("%s %s" % ["▶" if _selected == ENTRIES.size() else " ", "Reset all to defaults"])
	_text.text = "\n".join(lines)
	var room = _layer.get_viewport().get_visible_rect().size.y - 2.0 * PANEL_MARGIN.y
	var font_size = PANEL_FONT_SIZE
	_text.add_theme_font_size_override("font_size", font_size)
	while font_size > PANEL_MIN_FONT_SIZE and _text.get_minimum_size().y > room:
		font_size -= 1
		_text.add_theme_font_size_override("font_size", font_size)
