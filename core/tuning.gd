extends Node
## Autoload: numbers to tune while playing. F2 opens a panel anywhere (the game pauses): up/down
## to pick, left/right to change by a step (Shift: ten steps), F2 again to close. Values are
## saved to user://tuning.cfg and survive restarts; the last row resets them. Code asks
## Tuning.value("his_heavy_damage"), each time it needs the number, so a change counts at once.
##
## It holds the sync rules (core/sync_rules.gd, Bifrons with Moves "bifrons_rules" on "sync")
## and the beat-runner's and the beat-ring's numbers (levels/runner/, levels/ring/), each on a
## page of its own. Gains and losses are in points of a meter; how many points a meter holds is tunable
## too ("METERS"), and the thresholds of chaos and sync mode are shares of it.

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
# groups the ones below it; "column": 1 starts the panel's second column. "page": the panel
# shows the numbers of the level it's opened in: "runner" in the beat-runner, "ring" in the
# beat-ring, else "sync".
const ENTRIES = [
	{"header": "SYNC LOST: HEAVY (HIS: BOTH SWORDS; YOURS: SYNC MODE)"},
	{"key": "his_heavy_damage", "label": "his heavy attack lands: your sync lost", "default": 18.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "his_normal_share", "label": "...his normal one: this share of that", "default": 0.33, "step": 0.01, "min": 0.0, "max": 1.0},
	{"key": "their_heavy_damage", "label": "your heavy attack lands: his sync lost", "default": 18.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "their_normal_share", "label": "...your normal one: this share of that", "default": 0.33, "step": 0.01, "min": 0.0, "max": 1.0},
	{"header": "POSTURE YOU LOSE"},
	{"key": "posture_small", "label": "small: a normal attack parried (both) or blocked", "default": 5.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "posture_medium", "label": "medium: hit by a normal one; a heavy one parried/blocked", "default": 15.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "posture_large", "label": "large: hit by a heavy attack", "default": 30.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"header": "POSTURE HE LOSES (THERE ARE TWO OF YOU)"},
	{"key": "boss_posture_small", "label": "small: a normal attack parried (both) or blocked", "default": 5.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "boss_posture_medium", "label": "medium: hit by a normal one; a heavy one parried/blocked", "default": 15.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "boss_posture_large", "label": "large: hit by a heavy attack", "default": 30.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"header": "PLAYERS WIN SYNC BACK (HE DOESN'T)"},
	{"key": "sync_hit_gain", "label": "sync hit on the beat: sync gained", "default": 4.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "sync_hit_late_gain", "label": "sync hit off the beat: sync gained", "default": 2.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "sync_beat_time", "label": "on the beat: this long after his guard opens (s)", "default": 0.12, "step": 0.01, "min": 0.0, "max": 0.5},
	{"key": "missed_window_loss", "label": "window missed (partner in reach): sync lost", "default": 1.0, "step": 0.5, "min": 0.0, "max": 100.0},
	{"key": "coop_parry_gain", "label": "coop parry (both swords, both of you): sync gained", "default": 6.0, "step": 1.0, "min": 0.0, "max": 1000.0},
	{"key": "coop_parry_stagger", "label": "coop parry: his stagger (s)", "default": 1.0, "step": 0.1, "min": 0.0, "max": 5.0},
	{"header": "CHAOS AND SYNC MODE", "column": 1},
	{"key": "team_sync_start", "label": "players' sync at the start (% of their meter)", "default": 50.0, "step": 5.0, "min": 1.0, "max": 99.0},
	{"key": "chaos_exit", "label": "chaos over once sync is back to (% of the meter)", "default": 25.0, "step": 1.0, "min": 1.0, "max": 99.0},
	{"key": "sync_mode_exit", "label": "sync mode over when sync falls below (% of the meter)", "default": 70.0, "step": 1.0, "min": 1.0, "max": 99.0},
	{"header": "METERS: HOW MANY POINTS EACH HOLDS"},
	{"key": "team_sync_max", "label": "players' sync", "default": 100.0, "step": 10.0, "min": 20.0, "max": 1000.0},
	{"key": "boss_sync_max", "label": "his sync", "default": 200.0, "step": 10.0, "min": 20.0, "max": 1000.0},
	{"key": "player_posture_max", "label": "a player's posture", "default": 100.0, "step": 10.0, "min": 20.0, "max": 1000.0},
	{"key": "boss_posture_max", "label": "his posture", "default": 200.0, "step": 10.0, "min": 20.0, "max": 1000.0},
	{"header": "HIS GUARD"},
	{"key": "boss_parry_chance", "label": "a hit at his guard: chance he parries, not blocks", "default": 0.5, "step": 0.05, "min": 0.0, "max": 1.0},
	{"header": "POSTURE BACK"},
	{"key": "posture_quiet_time", "label": "only after this long with no attack, in or out (s)", "default": 2.0, "step": 0.1, "min": 0.0, "max": 10.0},
	{"key": "player_posture_regen", "label": "players: posture back per second, at full sync", "default": 20.0, "step": 1.0, "min": 0.0, "max": 200.0},
	{"key": "boss_posture_regen", "label": "him: posture back per second, at full sync", "default": 30.0, "step": 1.0, "min": 0.0, "max": 200.0},
	{"key": "block_regen_factor", "label": "a player holding block: regen times", "default": 2.0, "step": 0.5, "min": 1.0, "max": 10.0},
	{"key": "posture_regen_none_at", "label": "regen falls in a line to the floor at sync (%)", "default": 50.0, "step": 5.0, "min": 0.0, "max": 95.0},
	{"key": "posture_regen_least", "label": "...the floor: this share of the full rate", "default": 0.05, "step": 0.05, "min": 0.0, "max": 1.0},
	{"key": "player_break_stagger", "label": "player's posture broken: their stagger (s)", "default": 0.8, "step": 0.1, "min": 0.0, "max": 5.0},
	{"key": "boss_break_stagger", "label": "his posture broken: his stagger (s)", "default": 2.5, "step": 0.1, "min": 0.0, "max": 6.0},
	{"header": "RUNNER: TEMPO", "page": "runner"},
	{"key": "runner_unit", "label": "seconds per unit of a pattern's waits (Bifrons: 0.2)", "default": 0.2, "step": 0.01, "min": 0.08, "max": 0.5, "page": "runner"},
	{"key": "runner_gap", "label": "units between two patterns", "default": 5.0, "step": 1.0, "min": 1.0, "max": 20.0, "page": "runner"},
	{"key": "runner_relay_units", "label": "a parry until the partner's shard is due (units)", "default": 2.0, "step": 1.0, "min": 1.0, "max": 6.0, "page": "runner"},
	{"key": "runner_speedup", "label": "speed-up: this many % quicker every 20 s", "default": 5.0, "step": 1.0, "min": 0.0, "max": 30.0, "page": "runner"},
	{"header": "RUNNER: SPEEDS (PX/S)", "page": "runner"},
	{"key": "runner_orb_speed", "label": "an orb (parry it)", "default": 420.0, "step": 20.0, "min": 100.0, "max": 2000.0, "page": "runner"},
	{"key": "runner_shard_speed", "label": "a shard (hit it)", "default": 650.0, "step": 20.0, "min": 100.0, "max": 2000.0, "page": "runner"},
	{"key": "runner_scroll_speed", "label": "the world going by", "default": 300.0, "step": 20.0, "min": 50.0, "max": 1500.0, "page": "runner"},
	{"key": "runner_block_speed", "label": "a block (jump it)", "default": 560.0, "step": 20.0, "min": 50.0, "max": 2000.0, "page": "runner"},
	{"header": "RUNNER: THE METER (OF 100)", "page": "runner", "column": 1},
	{"key": "runner_start", "label": "at the start", "default": 50.0, "step": 5.0, "min": 5.0, "max": 100.0, "page": "runner"},
	{"key": "runner_parry_gain", "label": "a parry: gained", "default": 2.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "runner"},
	{"key": "runner_hit_gain", "label": "a shard hit: gained", "default": 3.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "runner"},
	{"key": "runner_beat_gain", "label": "a shard hit on the beat: gained", "default": 5.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "runner"},
	{"key": "runner_coop_gain", "label": "both orbs of a pair parried: gained on top", "default": 6.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "runner"},
	{"key": "runner_hit_loss", "label": "something got through: lost", "default": 10.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "runner"},
	{"key": "runner_block_loss", "label": "an orb blocked, not parried: lost", "default": 4.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "runner"},
	{"key": "runner_miss_loss", "label": "a shard from the partner not hit: lost", "default": 2.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "runner"},
	{"header": "RUNNER: BETWEEN PATTERNS (MIXED)", "page": "runner", "column": 1},
	{"key": "runner_extra_chance", "label": "chance of a shard or a block", "default": 0.4, "step": 0.05, "min": 0.0, "max": 1.0, "page": "runner"},
	{"key": "runner_block_share", "label": "of those, a block", "default": 0.3, "step": 0.05, "min": 0.0, "max": 1.0, "page": "runner"},
	{"header": "RING: HIS PATTERNS", "page": "ring"},
	{"key": "ring_unit", "label": "seconds per unit of his waits (his own: 0.2)", "default": 0.2, "step": 0.01, "min": 0.08, "max": 0.6, "page": "ring"},
	{"key": "ring_gap", "label": "units between two of his patterns", "default": 5.0, "step": 1.0, "min": 1.0, "max": 20.0, "page": "ring"},
	{"key": "ring_extra_chance", "label": "between two: chance of a grey shard or a bar", "default": 0.4, "step": 0.05, "min": 0.0, "max": 1.0, "page": "ring"},
	{"key": "ring_bar_share", "label": "of those, a bar", "default": 0.15, "step": 0.05, "min": 0.0, "max": 1.0, "page": "ring"},
	{"header": "RING: SIZES AND SPEEDS", "page": "ring"},
	{"key": "ring_radius", "label": "the circle's radius (px)", "default": 140.0, "step": 10.0, "min": 40.0, "max": 400.0, "page": "ring"},
	{"key": "ring_orb_speed", "label": "an arrowhead, a shard or a green arrow (px/s)", "default": 380.0, "step": 20.0, "min": 100.0, "max": 2000.0, "page": "ring"},
	{"key": "ring_sweep_speed", "label": "a sweep (px/s)", "default": 520.0, "step": 20.0, "min": 100.0, "max": 2000.0, "page": "ring"},
	{"key": "ring_bar_speed", "label": "a bar (px/s)", "default": 300.0, "step": 20.0, "min": 50.0, "max": 2000.0, "page": "ring"},
	{"key": "ring_relay_slow", "label": "a violet shard where it's to be hit (px/s)", "default": 600.0, "step": 50.0, "min": 100.0, "max": 3000.0, "page": "ring"},
	{"key": "ring_relay_brake", "label": "...slowing to that from the line on, over at least (px)", "default": 140.0, "step": 10.0, "min": 0.0, "max": 600.0, "page": "ring"},
	{"key": "ring_perfect", "label": "perfect: this close to its beat (s, either side)", "default": 0.07, "step": 0.01, "min": 0.01, "max": 0.5, "page": "ring"},
	{"key": "ring_good", "label": "good: this close (s)", "default": 0.16, "step": 0.01, "min": 0.01, "max": 1.0, "page": "ring"},
	{"header": "RING: THE METER (OF 100)", "page": "ring", "column": 1},
	{"key": "ring_start", "label": "at the start", "default": 50.0, "step": 5.0, "min": 5.0, "max": 100.0, "page": "ring"},
	{"key": "ring_perfect_gain", "label": "perfect: gained", "default": 4.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_good_gain", "label": "good: gained", "default": 2.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_ok_gain", "label": "taken anywhere else: gained", "default": 1.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_sweep_gain", "label": "a sweep parried by both: gained on top", "default": 6.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_pair_gain", "label": "both of a pair parried: gained on top", "default": 6.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_hit_loss", "label": "hit by an arrowhead, the sweep or a bar: lost (heavy pair: x2)", "default": 10.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_block_loss", "label": "an orb blocked, not parried: lost", "default": 4.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_relay_gain", "label": "a violet shard hit (a sync hit): gained on top", "default": 3.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_miss_loss", "label": "a violet shard not hit: lost", "default": 2.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
	{"key": "ring_lost_loss", "label": "one nobody took: lost", "default": 3.0, "step": 1.0, "min": 0.0, "max": 100.0, "page": "ring"},
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


# The numbers on the page shown, back to their defaults.
func reset_defaults():
	for e in _page_entries():
		if e.has("key"):
			_values[e.key] = e.default
	_save()


func _numbers() -> Array:
	return ENTRIES.filter(func(e): return e.has("key"))


# The page for the level the panel is opened in.
func _page() -> String:
	var scene = get_tree().current_scene
	var path = scene.scene_file_path if scene else ""
	for page in ["runner", "ring"]:
		if path.contains("/%s/" % page):
			return page
	return "sync"


func _page_entries() -> Array:
	var page = _page()
	return ENTRIES.filter(func(e): return e.get("page", "sync") == page)


# The panel's selectable rows: every number on the page, then "reset".
func _rows() -> Array:
	return _page_entries().filter(func(e): return e.has("key")) + [null]


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
		_selected = mini(_selected, _rows().size() - 1)
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
	_title.text = "TUNING: %s   (↑/↓ pick · ←/→ change, Shift: x10 · F2 close)   a changed number shows its default" 		% {"runner": "BEAT-RUNNER", "ring": "BEAT-RING"}.get(_page(), "SYNC RULES")
	var lines = [[[], []], [[], []]]  # per column: names, values
	var column = 0
	var selected = _rows()[_selected]
	for e in _page_entries():
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
		_columns[i][0].text = "\n".join(lines[i][0])
		_columns[i][1].text = "\n".join(lines[i][1])
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
