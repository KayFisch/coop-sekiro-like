extends Node
## Autoload: numbers to tune while playing. F2 opens a panel anywhere (the game pauses): up/down
## to pick, left/right to change by a step (Shift: ten steps), F2 again to close. Values are
## saved to user://tuning.cfg and survive restarts; the last row resets them. Code asks
## Tuning.value("hit_sync_loss"), each time it needs the number, so a change counts at once.
##
## For now it holds the sync rules (core/sync_rules.gd, Bifrons with Moves "bifrons_rules" on
## "sync"). Sync and posture both run from 0 to 100.

const SAVE_PATH = "user://tuning.cfg"
const VERSION = 2  # bumped when a default changes: an older save is dropped once
const PANEL_MARGIN = Vector2(48, 16)
const PANEL_FONT_SIZE = 15
const PANEL_MIN_FONT_SIZE = 10
const COLUMN_WIDTH = 540.0
const VALUE_X = 400.0  # where a column's numbers stand, right-aligned
const VALUE_WIDTH = 110.0
const LIST_TOP = 34.0  # below the title

# Each number: key, what the panel calls it, default, step, and its range. A "header" row only
# groups the ones below it; "column": 1 starts the panel's second column.
const ENTRIES = [
	{"header": "PLAYERS, HIT BY HIM"},
	{"key": "hit_sync_loss", "label": "hit, unblocked: sync lost (a heavy strike: twice)", "default": 6.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "block_posture_loss", "label": "blocked: posture lost", "default": 20.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "parry_posture_loss", "label": "parried: posture lost (never breaks it)", "default": 5.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "coop_parry_gain", "label": "coop parry (both swords, both of you): sync gained", "default": 6.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "coop_parry_stagger", "label": "coop parry: his stagger (s)", "default": 1.0, "step": 0.1, "min": 0.0, "max": 5.0},
	{"header": "PLAYERS, HITTING HIM"},
	{"key": "sync_hit_gain", "label": "sync hit on the beat: sync gained", "default": 4.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "sync_hit_late_gain", "label": "sync hit off the beat: sync gained", "default": 2.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "sync_beat_time", "label": "on the beat: this long after his guard opens (s)", "default": 0.12, "step": 0.01, "min": 0.0, "max": 0.5},
	{"key": "missed_window_loss", "label": "window missed (partner in reach): sync lost", "default": 1.0, "step": 0.5, "min": 0.0, "max": 100.0},
	{"header": "CHAOS AND SYNC MODE"},
	{"key": "team_sync_start", "label": "players' sync at the start", "default": 50.0, "step": 5.0, "min": 1.0, "max": 99.0},
	{"key": "chaos_exit", "label": "chaos: over once the players' sync is back to", "default": 25.0, "step": 1.0, "min": 1.0, "max": 99.0},
	{"key": "sync_mode_exit", "label": "sync mode: over when the players' sync falls below", "default": 70.0, "step": 1.0, "min": 1.0, "max": 99.0},
	{"key": "sync_mode_power", "label": "sync mode: what the players' hits do, times", "default": 3.0, "step": 0.5, "min": 1.0, "max": 10.0},
	{"header": "HIM, HIT BY THE PLAYERS", "column": 1},
	{"key": "boss_hit_loss", "label": "hit lands: his sync lost per slash (sync hit: x2.5)", "default": 0.8, "step": 0.1, "min": 0.0, "max": 20.0},
	{"key": "boss_parry_chance", "label": "a hit at his guard: chance he parries, not blocks", "default": 0.5, "step": 0.05, "min": 0.0, "max": 1.0},
	{"key": "boss_block_posture_loss", "label": "he blocks: his posture lost", "default": 8.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "boss_parry_posture_loss", "label": "he parries: his posture lost (never breaks it)", "default": 3.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "boss_coop_parry_gain", "label": "he parries both of you at once: his sync gained", "default": 5.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"key": "boss_sync_hit_gain", "label": "one strike hits both of you: his sync gained", "default": 5.0, "step": 1.0, "min": 0.0, "max": 100.0},
	{"header": "POSTURE"},
	{"key": "player_posture_regen", "label": "players: posture back per second, at full sync", "default": 20.0, "step": 1.0, "min": 0.0, "max": 200.0},
	{"key": "boss_posture_regen", "label": "him: posture back per second, at full sync", "default": 30.0, "step": 1.0, "min": 0.0, "max": 200.0},
	{"key": "posture_regen_floor", "label": "regen at no sync, as a share of full", "default": 0.1, "step": 0.05, "min": 0.0, "max": 1.0},
	{"key": "posture_regen_delay", "label": "regen starts this long after posture is lost (s)", "default": 1.0, "step": 0.1, "min": 0.0, "max": 5.0},
	{"key": "player_break_stagger", "label": "player's posture broken: their stagger (s)", "default": 0.8, "step": 0.1, "min": 0.0, "max": 5.0},
	{"key": "boss_break_stagger", "label": "his posture broken: his stagger (s)", "default": 2.5, "step": 0.1, "min": 0.0, "max": 6.0},
]

var panel_open = false

var _values = {}
var _selected = 0
var _was_paused = false
var _layer: CanvasLayer
var _title: Label
var _columns = []  # per column: [names, values], two Labels side by side


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for e in _numbers():
		_values[e.key] = e.default
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.get_value("meta", "version", 0) != VERSION:
		_save()
		return
	for e in _numbers():
		var saved = cfg.get_value("tuning", e.key, e.default)
		if saved is float or saved is int:
			_values[e.key] = clampf(saved, e.min, e.max)


func value(key: String) -> float:
	return _values[key]


func set_value(key: String, v: float):
	_values[key] = v
	_save()


func reset_defaults():
	for e in _numbers():
		_values[e.key] = e.default
	_save()


func _numbers() -> Array:
	return ENTRIES.filter(func(e): return e.has("key"))


# The panel's selectable rows: every number, then "reset".
func _rows() -> Array:
	return _numbers() + [null]


func _save():
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for e in _numbers():
		cfg.set_value("tuning", e.key, _values[e.key])
	cfg.save(SAVE_PATH)


# --- The F2 panel ---

func _input(event):
	if not event is InputEventKey or not event.pressed:
		return
	if event.physical_keycode == KEY_F2 and not event.echo:
		if not Moves.panel_open:
			_set_panel(not panel_open)
		get_viewport().set_input_as_handled()
		return
	if not panel_open:
		return
	var rows = _rows()
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_selected = posmod(_selected - 1, rows.size())
		KEY_DOWN, KEY_S:
			_selected = posmod(_selected + 1, rows.size())
		KEY_LEFT, KEY_A:
			_change(-10 if event.shift_pressed else -1)
		KEY_RIGHT, KEY_D:
			_change(10 if event.shift_pressed else 1)
		KEY_ENTER, KEY_SPACE:
			if rows[_selected] == null:
				reset_defaults()
	get_viewport().set_input_as_handled()
	_refresh()


func _change(steps: int):
	var e = _rows()[_selected]
	if e == null:
		return
	var v = clampf(_values[e.key] + steps * e.step, e.min, e.max)
	set_value(e.key, snappedf(v, e.step))


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


func _build_panel():
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(shade)
	_title = _panel_label(PANEL_MARGIN)
	for i in 2:
		var names = _panel_label(PANEL_MARGIN + Vector2(i * COLUMN_WIDTH, LIST_TOP))
		var values = _panel_label(names.position + Vector2(VALUE_X, 0.0))
		values.size.x = VALUE_WIDTH
		values.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_columns.append([names, values])


func _panel_label(at: Vector2) -> Label:
	var label = Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(label)
	return label


func _refresh():
	_title.text = "TUNING   (↑/↓ pick · ←/→ change, Shift: x10 · F2 close)   a changed number shows its default"
	var lines = [[[], []], [[], []]]  # per column: names, values
	var column = 0
	var selected = _rows()[_selected]
	for e in ENTRIES:
		if e.has("header"):
			column = e.get("column", column)
			if not lines[column][0].is_empty():
				lines[column][0].append("")
				lines[column][1].append("")
			lines[column][0].append("   " + e.header)
			lines[column][1].append("")
			continue
		var v = _values[e.key]
		var changed = not is_equal_approx(v, e.default)
		lines[column][0].append(("▶  " if e == selected else "    ") + e.label)
		lines[column][1].append(("(%s)  " % _shown(e, e.default) if changed else "") + _shown(e, v))
	lines[1][0].append_array(["", ("▶  " if selected == null else "    ") + "Reset all to defaults (Enter)"])
	lines[1][1].append_array(["", ""])
	for i in 2:
		_columns[i][0].text = "
".join(lines[i][0])
		_columns[i][1].text = "
".join(lines[i][1])
	var room = _layer.get_viewport().get_visible_rect().size.y - 2.0 * PANEL_MARGIN.y - LIST_TOP
	var font_size = PANEL_FONT_SIZE
	while true:
		for label in [_title] + _columns[0] + _columns[1]:
			label.add_theme_font_size_override("font_size", font_size)
		var tallest = maxf(_columns[0][0].get_minimum_size().y, _columns[1][0].get_minimum_size().y)
		if font_size <= PANEL_MIN_FONT_SIZE or tallest <= room:
			break
		font_size -= 1


func _shown(e: Dictionary, v: float) -> String:
	var decimals = 0 if e.step >= 1.0 else (1 if e.step >= 0.1 else 2)
	return ("%." + str(decimals) + "f") % v
