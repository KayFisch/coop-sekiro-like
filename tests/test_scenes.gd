extends "res://tests/test_case.gd"
## Every level and screen loads and runs for a moment without an engine or script error.

const ROOTS = ["res://levels/", "res://ui/"]
const RUN_TIME = 1.0  # s each


func test_every_scene_runs():
	set_move("bifrons_stand_in", "off")
	var scenes = []
	for root in ROOTS:
		_collect(root, scenes)
	scenes.sort()
	check(not scenes.is_empty(), "found the scenes")
	for path in scenes:
		await load_scene(path, RUN_TIME)
		check(get_tree().current_scene != null, path + " loads")


func _collect(dir: String, into: Array):
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn"):
			into.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir + sub + "/", into)
