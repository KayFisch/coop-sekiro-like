extends SceneTree
## Runs the tests in tests/ (every test_*.gd, or those named after "--"):
##   godot --headless --script res://tests/run.gd
##   godot --headless --script res://tests/run.gd -- sync_rules ring
## Each test file extends tests/test_case.gd; each of its test_* methods runs in turn, in real
## time (the players' timing windows read the real clock: no --fixed-fps). A script error while
## a test runs fails it too. Exits with 0 when everything passed, 1 otherwise.

const DIR = "res://tests/"


func _initialize():
	_run.call_deferred()


func _run():
	await process_frame  # the autoloads are in place: the test scripts may name them
	var errors = load(DIR + "error_logger.gd").new()
	OS.add_logger(errors)
	var wanted = OS.get_cmdline_user_args()
	var files = []
	for file in DirAccess.get_files_at(DIR):
		var short = file.trim_prefix("test_").trim_suffix(".gd")
		if file.begins_with("test_") and file.ends_with(".gd") and (wanted.is_empty() or short in wanted):
			files.append(file)
	files.sort()
	var passed = 0
	var failed = []
	var started = Time.get_ticks_msec()
	for file in files:
		var case = load(DIR + file).new()
		case.name = file.trim_suffix(".gd")
		root.add_child(case)
		var results: Array = await case.run_all(errors)
		for result in results:
			if result.failures.is_empty():
				passed += 1
				print("  ok    %s.%s" % [case.name, result.test])
			else:
				failed.append("%s.%s" % [case.name, result.test])
				print("  FAIL  %s.%s" % [case.name, result.test])
				for failure in result.failures:
					print("          %s" % failure)
		case.queue_free()
		await process_frame
	print("")
	print("%d passed, %d failed (%.1f s)%s" % [passed, failed.size(), (Time.get_ticks_msec() - started) / 1000.0,
		"" if failed.is_empty() else ": " + ", ".join(failed)])
	quit(0 if failed.is_empty() else 1)
