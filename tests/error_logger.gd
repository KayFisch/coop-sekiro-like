extends Logger
## Counts the engine's errors (script errors among them) while the tests run (tests/run.gd), so a
## test that sets one off fails even if its own checks pass.

var errors = 0
var last = ""
var _lock = Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]):
	if error_type == ERROR_TYPE_WARNING:
		return
	_lock.lock()
	errors += 1
	last = "%s (%s:%d, %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
	_lock.unlock()


func _log_message(_message: String, _error: bool):
	pass
