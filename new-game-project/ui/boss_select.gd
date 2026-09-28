extends Control
## Title screen: pick a fight. Up/down (keys, d-pad) and accept, or the number keys.
## In a fight, Esc comes back here (see GameManager).

const FIGHTS = [
	{"name": "Cubus Maximus", "arena": "The Arena", "scene": "res://levels/arena/arena.tscn"},
	{"name": "Sphaera Pendula", "arena": "The Scales", "scene": "res://levels/scales/scales.tscn"},
]

var _buttons: Array = []


func _ready():
	var column = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var title = Label.new()
	title.text = "Choose a fight"
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

	var hint = Label.new()
	hint.text = "Up/down + Enter (or pad A), or press the number · Esc returns here from a fight"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)

	_buttons[0].grab_focus()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		var index = event.keycode - KEY_1
		if index >= 0 and index < FIGHTS.size():
			GameManager.start_fight(FIGHTS[index].scene)
