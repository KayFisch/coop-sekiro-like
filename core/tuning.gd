extends Node
## Autoload: numbers to tune while playing. F2 opens a panel anywhere (the game pauses): Z / C for
## the page, Q / E (or Tab) for the tab, up/down to pick, left/right to change by a step (Shift:
## ten steps), F2 again to close. Laid out as the F1 panel: page, keys, tabs, then the numbers. Values are saved to user://tuning.cfg and survive
## restarts; a tab's last row resets it. Code asks Tuning.value("his_heavy_damage") each time it
## needs the number, so a change counts at once.
##
## The numbers belong to the systems that use them: each of SOURCES has a static
## tuning_entries() next to its code, read the first time a number is asked for. A page is one
## system (the sync rules, a boss, a level); the panel opens on the page of the level it's in.
## To give a new boss or level its numbers: write its tuning_entries() and add it to SOURCES.

const SAVE_PATH = "user://tuning.cfg"
const VERSION = 2  # bumped when a default changes: an older save is dropped once
# Whose numbers there are, in the panel's order.
const SOURCES = [
	"res://core/sync_rules.gd",  # page "sync": sync as life (tabs damage, sync and posture, sync hit)
	"res://core/sync_bond.gd",  # page "sync", tab "sync mode"
	"res://actors/bosses/columna_bifrons/columna_bifrons.gd",  # page "bifrons"
	"res://levels/runner/runner.gd",  # page "runner"
	"res://levels/ring/ring.gd",  # page "ring"
]
const PANEL_MARGIN = Vector2(48, 16)
const PANEL_FONT_SIZE = 16
const PANEL_MIN_FONT_SIZE = 10
const LINE_SPACING = 5  # px between two rows
const COLUMN_WIDTH = 560.0
const VALUE_X = 410.0  # where a column's numbers stand, right-aligned
const VALUE_WIDTH = 120.0
const KEYS = "Z / C: page   Q / E: tab   ↑/↓: pick   ←/→: change (Shift: x10)   F2: close"

# An entry (from a tuning_entries()) is a number: key, what the panel calls it, default, step,
# and its range. Or a "header" row, grouping the ones below it: "column": 1 starts the panel's
# second column; "page" (with its "title" and the "scenes" it opens in, path parts) and "tab"
# hold for the entries after it until a header names others.

var panel_open = false

var _entries = []  # every entry, each with its page and tab: {entry, page, tab, title}
var _scenes = {}  # page -> the scene paths it opens in
var _loaded = false
var _values = {}
var _selected = 0
var _tab = 0  # the index of the tab shown, among all pages' (_tabs())
var _was_paused = false
var _layer: CanvasLayer
var _title: Label
var _columns = []  # per column: [names, values], two Labels side by side


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


# Reads every source's entries and the saved values, once. Not in _ready(): the sources name
# other autoloads, which may not be there yet then.
func _load():
	if _loaded:
		return
	_loaded = true
	var page = ""
	var tab = ""
	var title = ""
	for path in SOURCES:
		for e in load(path).tuning_entries():
			if e.has("page"):
				page = e.page
				title = e.get("title", page.to_upper())
				_scenes[page] = e.get("scenes", [])
			tab = e.get("tab", tab)
			_entries.append({"entry": e, "page": page, "tab": tab, "title": title})
			if e.has("key"):
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
	if not _loaded:
		_load()
	return _values[key]


func set_value(key: String, v: float):
	_values[key] = v
	_save()


# The numbers on the tab shown, back to their defaults.
func reset_defaults():
	for e in _tab_entries():
		if e.has("key"):
			_values[e.key] = e.default
	_save()


func _numbers() -> Array:
	return _entries.map(func(x): return x.entry).filter(func(e): return e.has("key"))


# Every tab of every page, in the order they first come: [page, tab, title]. A tab may be
# declared in more than one source (the sync rules' "sync mode", with core/sync_bond.gd's).
func _tabs() -> Array:
	var tabs = []
	for x in _entries:
		if not tabs.any(func(t): return t[0] == x.page and t[1] == x.tab):
			tabs.append([x.page, x.tab, x.title])
	return tabs


func _tab_entries() -> Array:
	var shown = _tabs()[_tab]
	return _entries.filter(func(x): return x.page == shown[0] and x.tab == shown[1]).map(func(x): return x.entry)


# The panel's selectable rows: every number on the tab, then "reset".
func _rows() -> Array:
	return _tab_entries().filter(func(e): return e.has("key")) + [null]


# The first tab of the page the current level belongs to, or -1.
func _scene_tab() -> int:
	var scene = get_tree().current_scene
	var path = scene.scene_file_path if scene else ""
	var tabs = _tabs()
	for i in tabs.size():
		for part in _scenes.get(tabs[i][0], []):
			if path.contains(part):
				return i
	return -1


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
	var tabs = _tabs()
	var rows = _rows()
	match event.physical_keycode:
		KEY_Q, KEY_E, KEY_TAB:
			var back = event.physical_keycode == KEY_Q or (event.physical_keycode == KEY_TAB and event.shift_pressed)
			_tab = posmod(_tab + (-1 if back else 1), tabs.size())
			_selected = 0
		KEY_Z, KEY_C:
			_tab = _next_page(1 if event.physical_keycode == KEY_C else -1)
			_selected = 0
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


# The first tab of the next page (step 1) or the previous one (-1).
func _next_page(step: int) -> int:
	var tabs = _tabs()
	var pages = []
	for t in tabs:
		if not t[0] in pages:
			pages.append(t[0])
	var page = pages[posmod(pages.find(tabs[_tab][0]) + step, pages.size())]
	for i in tabs.size():
		if tabs[i][0] == page:
			return i
	return 0


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
		_load()
		_was_paused = get_tree().paused
		get_tree().paused = true
		# Opened in a level with a page of its own: on that page, unless already on it.
		var at_scene = _scene_tab()
		if at_scene >= 0 and _tabs()[_tab][0] != _tabs()[at_scene][0]:
			_tab = at_scene
			_selected = 0
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
		var names = _panel_label(PANEL_MARGIN)
		var values = _panel_label(PANEL_MARGIN)
		values.size.x = VALUE_WIDTH
		values.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_columns.append([names, values])


func _panel_label(at: Vector2) -> Label:
	var label = Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("line_spacing", LINE_SPACING)
	_layer.add_child(label)
	return label


# As the F1 panel: the page (Z / C), the keys, the page's tabs (Q / E) with the one shown in
# brackets, then its numbers in two columns.
func _refresh():
	var tabs = _tabs()
	var shown = tabs[_tab]
	var page_tabs = []
	for t in tabs:
		if t[0] == shown[0]:
			var tab_name = t[1].capitalize()
			page_tabs.append("[ %s ]" % tab_name.to_upper() if t == shown else "  %s  " % tab_name)
	_title.text = "
".join(["TUNING:   <  %s  >" % shown[2], KEYS, "", " ".join(page_tabs), ""])
	var lines = [[[], []], [[], []]]  # per column: names, values
	var column = 0
	var selected = _rows()[_selected]
	for e in _tab_entries():
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
	lines[1][0].append_array(["", ("▶  " if selected == null else "    ") + "Reset this tab to defaults (Enter)"])
	lines[1][1].append_array(["", ""])
	for i in 2:
		_columns[i][0].text = "
".join(lines[i][0])
		_columns[i][1].text = "
".join(lines[i][1])
	var room = _layer.get_viewport().get_visible_rect().size.y - 2.0 * PANEL_MARGIN.y
	var font_size = PANEL_FONT_SIZE
	while true:
		for label in [_title] + _columns[0] + _columns[1]:
			label.add_theme_font_size_override("font_size", font_size)
		var title = _title.get_minimum_size().y
		var tallest = maxf(_columns[0][0].get_minimum_size().y, _columns[1][0].get_minimum_size().y)
		if font_size <= PANEL_MIN_FONT_SIZE or title + tallest <= room:
			break
		font_size -= 1
	var top = _title.get_minimum_size().y
	var scale = font_size / float(PANEL_FONT_SIZE)  # the columns narrow with the font
	for i in 2:
		_columns[i][0].position = PANEL_MARGIN + Vector2(i * COLUMN_WIDTH * scale, top)
		_columns[i][1].position = _columns[i][0].position + Vector2(VALUE_X * scale, 0.0)


func _shown(e: Dictionary, v: float) -> String:
	var decimals = 0 if e.step >= 1.0 else (1 if e.step >= 0.1 else 2)
	return ("%." + str(decimals) + "f") % v
