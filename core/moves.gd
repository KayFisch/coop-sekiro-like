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
const VERSION = 5
# The panel's text: shrunk as far as it takes for the whole tab to fit on screen.
const PANEL_MARGIN = Vector2(80, 16)
const PANEL_FONT_SIZE = 17
const PANEL_MIN_FONT_SIZE = 10
const LABEL_WIDTH = 50  # characters: the values line up after this
const SLIDER_CELLS = 15  # characters a slider's bar takes at most

# The panel's tabs, in order. Every entry names one.
const TABS = ["Basics", "Walls", "Pogo", "Partner", "Fights", "Sync", "Runner", "Ring", "Controls", "Sound", "Dev"]

# Each switch: key, its tab, what the panel calls it, and its default (a bool, or one of
# `options`). Labels starting with "  " belong to the switch above them. A `slider` one stops at
# its ends (no wrapping round) and shows as a bar. An `action` row holds no value: Enter (or
# right) calls that method of this panel.
# Every move is on by default, everywhere: the switches are for comparing (see docs/concept.md).
const ENTRIES = [
	# Basics: on your own feet
	{"key": "dash", "tab": "Basics", "label": "Dash (the way you face)", "default": true},
	{"key": "dash_slash", "tab": "Basics", "label": "Dash-slash (dash + attack)", "default": true},
	# Walls and ledges
	{"key": "wall", "tab": "Walls", "label": "Walls: stick and slide down", "default": "slide", "options": ["off", "slide"]},
	{"key": "wall_jump", "tab": "Walls", "label": "Wall jump", "default": true},
	{"key": "wall_rhythm", "tab": "Walls", "label": "  wall rhythm: jump as you hit the wall, else weak", "default": true},
	{"key": "ledge_grab", "tab": "Walls", "label": "Ledge grab + climb", "default": true},
	# Pogo
	{"key": "pogo", "tab": "Pogo", "label": "Pogo (downslash: off your partner's upslash, or a pogo point)", "default": true},
	{"key": "pogo_refresh_dash", "tab": "Pogo", "label": "  a pogo point gives the dash back", "default": false},
	# Partner: moves made of both players
	{"key": "launch", "tab": "Partner", "label": "Launch (dash-slash into an upslash)", "default": true},
	{"key": "relay", "tab": "Partner", "label": "Relay (parry a dash-slash as it meets you, then throw it on the next beat)", "default": true},
	{"key": "chimney_clash", "tab": "Partner", "label": "Chimney clash (wall jumps meeting)", "default": true},
	{"key": "players_collide", "tab": "Partner", "label": "Players collide (stand on, bump into each other)", "default": true},
	# Fights: rules that only matter against a boss
	{"key": "boss_body", "tab": "Fights", "label": "Boss body blocks players", "default": true},
	{"key": "parry_pass", "tab": "Fights", "label": "Dash-parry: a parry mid-dash goes through the boss", "default": true},
	{"key": "bifrons_mode", "tab": "Fights", "label": "Bifrons: set patterns, or reactive (strikes back)", "default": "patterns", "options": ["patterns", "reactive"]},
	{"key": "bifrons_guard_break", "tab": "Fights", "label": "Bifrons: a parry breaks his other guard (off: the window stays, but only a hit he can't parry lands)", "default": true},
	{"key": "bifrons_blade_parries", "tab": "Fights", "label": "Bifrons: one parry per blade (both swords on one side of him: heavy, parry together, else a lone parry is a block)", "default": true},
	{"key": "bifrons_throw_by_outcome", "tab": "Fights", "label": "Bifrons: what throws you back (leap, both swords on you) throws a parry part way (F2), a block as far as a hit", "default": true},
	{"key": "bifrons_chain_stagger", "tab": "Fights", "label": "Bifrons: a coop parry staggers him longer the more of that attack was parried (F2)", "default": true},
	{"key": "bifrons_stand_in", "tab": "Fights", "label": "Stand-in (alone): plays the player starting left (P1) or right (P2); Bifrons, runner, ring", "default": "off", "options": ["off", "left", "right"]},
	{"key": "bifrons_face", "tab": "Fights", "label": "Bifrons: players always face him", "default": true},
	{"key": "mirror_view", "tab": "Fights", "label": "Bifrons: mirrored screen (P1 light above the floor, P2 its shadow below)", "default": true},
	{"key": "mirror_blades", "tab": "Fights", "label": "  a blade at the partner, in your half: mirror (as theirs), hold (on guard), fade (faint), color (in its player's color)", "default": "color", "options": ["mirror", "hold", "fade", "color"]},
	# Sync: sync as life and the sync mode (core/sync_rules.gd, core/sync_bond.gd)
	{"key": "swings_hold_posture", "tab": "Sync", "label": "Your own swings hold your posture regen back too (his attacks never do)", "default": true},
	{"key": "dash_slash_pass", "tab": "Sync", "label": "Dash-slash goes through the boss: in the sync mode only, always, or never", "default": "sync", "options": ["sync", "always", "off"]},
	{"key": "sync_merge_view", "tab": "Sync", "label": "Sync mode, mirrored screen: bound, the two halves become one (the shadow joins the light)", "default": false},
	# Runner: the beat-runner (levels/runner/)
	{"key": "runner_patterns", "tab": "Runner", "label": "Bifrons's patterns only, or mixed with shards and blocks", "default": "mixed", "options": ["mixed", "bifrons"]},
	{"key": "runner_relay", "tab": "Runner", "label": "A parried orb goes on to the partner as a shard to hit", "default": true},
	{"key": "runner_rally", "tab": "Runner", "label": "  ...and hitting that shard sends an orb back (a rally)", "default": false},
	{"key": "runner_blocks", "tab": "Runner", "label": "Now and then a block to jump", "default": true},
	{"key": "runner_speedup", "tab": "Runner", "label": "The tempo rises as the run goes on", "default": false},
	{"key": "runner_metronome", "tab": "Runner", "label": "A tick on every beat", "default": false},
	{"key": "runner_endless", "tab": "Runner", "label": "Endless (an empty meter doesn't end the run)", "default": false},
	# Ring: the beat-ring (levels/ring/)
	{"key": "ring_relay", "tab": "Ring", "label": "A parried yellow one sends a violet shard to the partner", "default": true},
	{"key": "ring_changes", "tab": "Ring", "label": "His crossing (both to one side), sweep and leap (apart again)", "default": true},
	{"key": "ring_pairs", "tab": "Ring", "label": "His strikes with both swords, as green pairs to parry together", "default": true},
	{"key": "ring_bars", "tab": "Ring", "label": "Now and then a bar from a side (low: jump, high: stay down)", "default": true},
	{"key": "ring_endless", "tab": "Ring", "label": "Endless (an empty meter doesn't end the run)", "default": false},
	# Controls
	{"key": "swap_controls", "tab": "Controls", "label": "Swap P1 / P2 controls (P1 on the pad; pad Back)", "default": false},
	{"key": "camera_p1", "tab": "Controls", "label": "Gym camera follows only P1 (testing with a bot)", "default": false},
	# Sound
	{"key": "music_volume", "tab": "Sound", "label": "Music volume", "default": "5%", "slider": true, "options": ["0%", "5%", "10%", "15%", "20%", "25%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"]},
	{"key": "audio_offset", "tab": "Sound", "label": "Audio ahead (a late headset: Bluetooth ~150-250)", "default": "0 ms", "slider": true, "options": ["-200 ms", "-190 ms", "-180 ms", "-170 ms", "-160 ms", "-150 ms", "-140 ms", "-130 ms", "-120 ms", "-110 ms", "-100 ms", "-90 ms", "-80 ms", "-70 ms", "-60 ms", "-50 ms", "-40 ms", "-30 ms", "-20 ms", "-10 ms", "0 ms", "10 ms", "20 ms", "30 ms", "40 ms", "50 ms", "60 ms", "70 ms", "80 ms", "90 ms", "100 ms", "110 ms", "120 ms", "130 ms", "140 ms", "150 ms", "160 ms", "170 ms", "180 ms", "190 ms", "200 ms", "210 ms", "220 ms", "230 ms", "240 ms", "250 ms", "260 ms", "270 ms", "280 ms", "290 ms", "300 ms"]},
	{"key": "audio_calibration", "tab": "Sound", "label": "Audio calibration: measure it", "action": "_open_calibration"},
	# Dev: developer tools (core/dev.gd: F3 overlay, F4 hitboxes, F5 boss lab)
	{"key": "fight_log", "tab": "Dev", "label": "Write each fight's log to user://fight_log.jsonl (from the next start)", "default": false},
]

var panel_open = false

var _values = {}
var _tab = 0  # index into TABS
var _selected = 0  # row on the open tab
var _was_paused = false
var _layer: CanvasLayer
var _text: Label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for e in _settings():
		_values[e.key] = e.default
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.get_value("meta", "version", 1) != VERSION:
		_save()  # an older save: back to the new defaults, once
		return
	for e in _settings():
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
	for e in _settings():
		cfg.set_value("moves", e.key, _values[e.key])
	cfg.save(SAVE_PATH)


# The entries that hold a value (not the `action` rows).
func _settings() -> Array:
	return ENTRIES.filter(func(e): return not e.has("action"))


func reset_defaults():
	for e in _settings():
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
		if not Tuning.panel_open:  # one panel at a time (F2: Tuning)
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


# Sound → Audio calibration: opens over the panel (and whatever runs under it); Esc closes it.
func _open_calibration():
	var calibration = load("res://ui/audio_calibration.gd").new()
	calibration.closed.connect(_refresh)
	add_child(calibration)


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
	if e.has("action"):
		if step > 0:
			call(e.action)
	elif e.has("options"):
		var i = e.options.find(_values[e.key])
		var to = clampi(i + step, 0, e.options.size() - 1) if e.get("slider", false) else posmod(i + step, e.options.size())
		set_value(e.key, e.options[to])
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
		var v = _values.get(e.key)
		var shown = ("ON" if v else "off") if v is bool else str(v).to_upper()
		if e.has("action"):
			shown = "[Enter]"
		elif e.get("slider", false):  # a bar, filled up to the value
			var n = e.options.find(v)
			var cells = mini(e.options.size() - 1, SLIDER_CELLS)
			var lit = roundi(n * cells / float(e.options.size() - 1))
			shown = "%s %s" % ["█".repeat(lit) + "░".repeat(cells - lit), shown]
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
