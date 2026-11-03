extends Control
## Title screen: pick a fight or a movement gym. Up/down (keys, d-pad) and accept, or the number keys.
## Esc comes back here from anywhere (see GameManager).
## The try-out boss and the test rooms ("test": true) are shown only with Moves "select_all" (F1 →
## Dev); hidden, they can't be started from here, by their number either. The list follows the
## switch at once.

const FIGHTS = [
	{"name": "Tutorial", "arena": "the training dummy: start here", "scene": "res://levels/tutorial/tutorial.tscn"},
	{"name": "Columna Bifrons", "arena": "the Warden of the Threshold", "scene": "res://levels/warden/warden.tscn"},
	{"name": "Heavy Hitter", "arena": "the Ettin (phase 1)", "scene": "res://levels/heavy_hitter/hitter_room.tscn"},
	{"name": "Kultist", "arena": "The Threshold, mirrored", "scene": "res://levels/kultist/kultist_room.tscn"},
	{"name": "Acrobat", "arena": "the juggler (phase 1)", "scene": "res://levels/acrobat/acrobat_room.tscn"},
	{"name": "Horologium", "arena": "2 players", "scene": "res://levels/horologium/horologium1.tscn"},
	{"name": "Try-out boss", "arena": "The Threshold (workbench)", "scene": "res://levels/threshold/threshold.tscn", "test": true},
	{"name": "Movement Gym", "arena": "1 player", "scene": "res://levels/gym/movement_gym.tscn", "test": true},
	{"name": "Duo Gym", "arena": "2 players", "scene": "res://levels/gym/coop_gym.tscn", "test": true},
	{"name": "Relay Gym", "arena": "1 player + bot", "scene": "res://levels/gym/relay_gym.tscn", "test": true},
	{"name": "Wall Gym", "arena": "1 player + bot", "scene": "res://levels/gym/wall_gym.tscn", "test": true},
	{"name": "Kit: showcase", "arena": "2 players", "scene": "res://levels/kit/showcase/hub.tscn", "test": true},
	{"name": "Beat-Runner", "arena": "between the bosses (prototype)", "scene": "res://levels/runner/runner.tscn", "test": true},
	{"name": "Beat-Ring", "arena": "between the bosses (prototype 2)", "scene": "res://levels/ring/ring.tscn", "test": true},
]

var _buttons: Array = []  # the controls' buttons under the levels (swap, pad)
var _levels: Array = []  # the level buttons, as shown
var _list: VBoxContainer
var _swap: Button
var _pad: Button


# The entries of FIGHTS shown now: all with Moves "select_all", else none of the test ones.
static func shown() -> Array:
	return FIGHTS.filter(func(f): return Moves.on("select_all") or not f.get("test", false))


func _ready():
	var column = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 6)  # compact: all of it fits in 648 px
	add_child(column)

	var title = Label.new()
	title.text = "Choose a level"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	column.add_child(_list)
	_build_list()
	Moves.changed.connect(_build_list)

	# Trades the players' input sets (Moves "swap_controls"), e.g. to play a 1-player level on the pad.
	_swap = Button.new()
	_swap.custom_minimum_size = Vector2(420, 32)
	_swap.add_theme_font_size_override("font_size", 15)
	_swap.pressed.connect(_toggle_swap)
	Moves.changed.connect(_label_swap)
	Pads.changed.connect(_label_swap)  # a pad plugged in or pulled
	_label_swap()
	column.add_child(_swap)
	_buttons.append(_swap)

	# The pad's buttons (Pads.LAYOUTS): each press the next layout.
	_pad = Button.new()
	_pad.custom_minimum_size = Vector2(420, 32)
	_pad.add_theme_font_size_override("font_size", 15)
	_pad.pressed.connect(Pads.next_layout)
	Pads.changed.connect(_label_pad)
	_label_pad()
	column.add_child(_pad)
	_buttons.append(_pad)

	var hint = Label.new()
	hint.text = "Up/down + Enter (or pad A), or press the number · Esc returns here from a level"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)

	_focusable()[0].grab_focus()


# The level buttons, one for each entry shown now (shown()); again whenever a switch changes.
func _build_list():
	var focused = get_viewport().gui_get_focus_owner() in _levels if is_inside_tree() else false
	for button in _levels:
		_list.remove_child(button)
		button.queue_free()
	_levels.clear()
	var fights = shown()
	for i in fights.size():
		var fight = fights[i]
		var button = Button.new()
		button.text = "%d   %s  —  %s" % [(i + 1) % 10, fight.name, fight.arena]
		button.custom_minimum_size = Vector2(420, 38)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(GameManager.start_fight.bind(fight.scene))
		_list.add_child(button)
		_levels.append(button)
	if focused:
		_focusable()[0].grab_focus()


# Everything up/down goes through: the levels shown, then the controls' buttons.
func _focusable() -> Array:
	return _levels + _buttons


func _unhandled_input(event):
	# Pad A / Start presses the highlighted button (ui_accept doesn't include the pad by default).
	if event is InputEventJoypadButton and event.pressed \
			and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
		# Handled first: pressing a level's button changes the scene, and this screen is out of
		# the tree (no viewport) by the time the press returns.
		get_viewport().set_input_as_handled()
		var focused = get_viewport().gui_get_focus_owner()
		if focused in _focusable():
			focused.pressed.emit()
		else:
			_focusable()[0].grab_focus()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index = 9 if event.keycode == KEY_0 else event.keycode - KEY_1  # 0: the tenth
		var fights = shown()  # (a hidden one has no number)
		if index >= 0 and index < fights.size():
			GameManager.start_fight(fights[index].scene)
		elif event.keycode == KEY_C:
			_toggle_swap()
		elif event.keycode == KEY_P:
			Pads.next_layout()


func _toggle_swap():
	Moves.set_value("swap_controls", not Moves.on("swap_controls"))


func _label_swap():
	_swap.text = "%s   (C / pad Back to swap)" % Pads.describe()


func _label_pad():
	_pad.text = "Pad: %s   (P to change)" % Pads.describe_layout()
