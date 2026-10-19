extends "res://tests/test_case.gd"
## The pad's buttons (Pads.LAYOUTS, chosen on the title screen): each layout binds the pad's
## jump, attack, dash and block, and leaves the stick as the Input Map has it.


func _pad_events(action: String) -> Array:
	return InputMap.action_get_events(action).filter(Pads._is_pad_event)


# True if the pad events of `action` are exactly the one `press` of a layout.
func _bound(action: String, press) -> bool:
	var events = _pad_events(action)
	if events.size() != 1:
		return false
	var event = events[0]
	if press is Array:
		return event is InputEventJoypadMotion and event.axis == press[0] and event.axis_value == press[1]
	return event is InputEventJoypadButton and event.button_index == press


func test_each_layout_binds_its_buttons():
	var before = Pads.layout
	var stick = _pad_events("p2_left")
	for index in Pads.LAYOUTS.size():
		Pads.set_layout(index, false)
		var layout = Pads.LAYOUTS[index]
		for button in ["jump", "attack", "dash", "block"]:
			check(_bound("p2_" + button, layout[button]), "%s: %s bound" % [layout.name, button])
		check(_pad_events("p2_left").size() == stick.size(), "%s: the stick stays" % layout.name)
	Pads.set_layout(before, false)


func test_standard_is_the_input_maps_own():
	var settings = ConfigFile.new()
	settings.load("res://project.godot")
	var input = settings.get_value("input", "p2_dash")
	var event = input.events.filter(Pads._is_pad_event)[0]
	check(event.button_index == Pads.LAYOUTS[0].dash, "standard: dash as in project.godot")
	input = settings.get_value("input", "p2_block")
	event = input.events.filter(Pads._is_pad_event)[0]
	check(event.axis == Pads.LAYOUTS[0].block[0], "standard: block as in project.godot")
