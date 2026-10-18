extends SceneTree
## Measures how heavy levels are on this machine (docs/dev_tools.md). In a window (it has to draw):
##   godot --script res://tools/perf_probe.gd -- res://levels/horologium/horologium1.tscn ...
## With no level named, it measures every level. Each one is loaded, left to settle for SETTLE s,
## then measured for MEASURE s: the frame time (mean, 95th percentile, worst), draw calls, and the
## nodes running code every frame, by script. Add --disable-vsync before --script to see what a
## frame really costs (with vsync a frame takes as long as the screen's refresh at least).

const SETTLE = 1.5
const MEASURE = 4.0


func _initialize():
	_run.call_deferred()


func _run():
	var paths = Array(OS.get_cmdline_user_args())
	if paths.is_empty():
		_collect("res://levels/", paths)
		paths.sort()
	print("renderer: %s (%s), %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()])
	for path in paths:
		change_scene_to_file(path)
		await create_timer(SETTLE).timeout
		var frames = []
		var draws = 0.0
		var started = Time.get_ticks_usec()
		var last = started
		while Time.get_ticks_usec() - started < MEASURE * 1000000.0:
			await process_frame
			var now = Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			last = now
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		frames.sort()
		var mean = frames.reduce(func(a, b): return a + b, 0.0) / frames.size()
		var busy = {}
		_count(current_scene, busy)
		var names = busy.keys()
		names.sort_custom(func(a, b): return busy[a] > busy[b])
		print("%-36s %5.2f ms a frame (95%%: %5.2f, worst %6.1f)  %4.0f draw calls  %4d nodes  every frame: %s" % [
			path.get_file(), mean, frames[int(frames.size() * 0.95)], frames.back(), draws / frames.size(),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			", ".join(names.slice(0, 6).map(func(k): return "%s x%d" % [k, busy[k]]))])
	quit()


func _collect(dir: String, into: Array):
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn"):
			into.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		if sub != "showcase":
			_collect(dir + sub + "/", into)


# Nodes whose script runs every frame, by script file.
func _count(node: Node, counts: Dictionary):
	var script = node.get_script()
	if script and (node.is_processing() or node.is_physics_processing()):
		var key = script.resource_path.get_file()
		counts[key] = counts.get(key, 0) + 1
	for child in node.get_children():
		_count(child, counts)
