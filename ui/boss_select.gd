extends Control
## Title screen: pick a fight or a movement gym. Up/down (keys, d-pad) and accept, or the number keys.
## Esc comes back here from anywhere (see GameManager).

const FIGHTS = [
	{"name": "Cubus Maximus", "arena": "The Arena", "scene": "res://levels/arena/arena.tscn"},
	{"name": "Sphaera Pendula", "arena": "The Scales", "scene": "res://levels/scales/scales.tscn"},
	{"name": "Movement Gym", "arena": "1 player", "scene": "res://levels/gym/movement_gym.tscn"},
	{"name": "Duo Gym", "arena": "2 players", "scene": "res://levels/gym/coop_gym.tscn"},
]

var _buttons: Array = []
var _swap: Button


func _ready():
	var column = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var title = Label.new()
	title.text = "Choose a level"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	column.add_child(title)

	for i in FIGHTS.size():
		var fight = FIGHTS[i]
		var button = Button.new()
		button.text = "%d   %s  —  %s" % [i + 1, fight.name, fight.arena]
		button.custom_minimum_size = Vector2(420, 52)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(GameManager.start_fight.bind(fight.scene))
		column.add_child(button)
		_buttons.append(button)

	# Trades the players' input sets (Moves "swap_controls"), e.g. to play a 1-player level on the pad.
	_swap = Button.new()
	_swap.custom_minimum_size = Vector2(420, 40)
	_swap.add_theme_font_size_override("font_size", 18)
	_swap.pressed.connect(_toggle_swap)
	Moves.changed.connect(_label_swap)
	Pads.changed.connect(_label_swap)  # a pad plugged in or pulled
	_label_swap()
	column.add_child(_swap)
	_buttons.append(_swap)

	var hint = Label.new()
	hint.text = "Up/down + Enter (or pad A), or press the number · Esc returns here from a level"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)

	_buttons[0].grab_focus()


func _unhandled_input(event):
	# Pad A / Start presses the highlighted button (ui_accept doesn't include the pad by default).
	if event is InputEventJoypadButton and event.pressed \
			and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
		var focused = get_viewport().gui_get_focus_owner()
		if focused in _buttons:
			focused.pressed.emit()
		else:
			_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index = event.keycode - KEY_1
		if index >= 0 and index < FIGHTS.size():
			GameManager.start_fight(FIGHTS[index].scene)
		elif event.keycode == KEY_C:
			_toggle_swap()


func _toggle_swap():
	Moves.set_value("swap_controls", not Moves.on("swap_controls"))


func _label_swap():
	_swap.text = "%s   (C / pad Back to swap)" % Pads.describe()
