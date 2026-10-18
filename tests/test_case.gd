extends Node
## The base of a test file (tests/run.gd runs them). Each method named test_* is one test: it
## may await (load a level, wait, press buttons) and checks with check() / near(). Switches and
## numbers changed with set_move() / set_number() are only changed in memory (nothing is saved)
## and are put back after each test; so are held buttons and the time scale.

var _failures = []
var _moves_before = {}
var _numbers_before = {}


# Runs every test_* method of this file; returns [{test, failures}].
func run_all(errors) -> Array:
	var results = []
	for method in get_method_list():
		if not method.name.begins_with("test_"):
			continue
		_failures = []
		var errors_before = errors.errors
		await call(method.name)
		if errors.errors > errors_before:
			_failures.append("%d engine error(s), the last: %s" % [errors.errors - errors_before, errors.last])
		_restore()
		results.append({"test": method.name, "failures": _failures})
	return results


# --- Checks ---

func check(condition: bool, what: String):
	if not condition:
		_failures.append(what)


func near(got: float, want: float, tolerance: float, what: String):
	if absf(got - want) > tolerance:
		_failures.append("%s: got %.3f, want %.3f (±%.3f)" % [what, got, want, tolerance])


# --- The game, for a test ---

# Loads a level from scratch, as the boss select screen does, and waits `settle` s in it.
func load_scene(path: String, settle = 0.5):
	GameManager.start_fight(path)
	var waited = 0
	while (get_tree().current_scene == null or get_tree().current_scene.scene_file_path != path) and waited < 300:
		await get_tree().process_frame
		waited += 1
	check(waited < 300, path + " didn't load")
	await wait(settle)


func wait(seconds: float):
	await get_tree().create_timer(seconds, true, false, true).timeout


func frames(count: int):
	for i in count:
		await get_tree().physics_frame


# A switch (F1) or a number (F2), changed in memory for this test only.
func set_move(key: String, value):
	if not _moves_before.has(key):
		_moves_before[key] = Moves.value(key)
	Moves._values[key] = value
	Moves.changed.emit()


func set_number(key: String, value: float):
	if not _numbers_before.has(key):
		_numbers_before[key] = Tuning.value(key)
	Tuning._values[key] = value


# Presses (or lets go of) a player's button, as the stand-ins do.
func hold(player, button: String, down = true):
	var action = player._action(button)
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


func tap(player, button: String):
	hold(player, button)
	await frames(2)
	hold(player, button, false)


func _restore():
	for key in _moves_before:
		Moves._values[key] = _moves_before[key]
	for key in _numbers_before:
		Tuning._values[key] = _numbers_before[key]
	_moves_before.clear()
	_numbers_before.clear()
	if Tuning.panel_open:
		Tuning._set_panel(false)
	Tuning.saving = true
	Moves.changed.emit()
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)
	Engine.time_scale = 1.0
