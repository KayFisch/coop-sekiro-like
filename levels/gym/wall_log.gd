class_name WallLog
extends Node
## Logs the wall gym's climbs (Moves "wall_log"), for analysing the rhythm's timing after a test.
## A run starts with player 1's first wall jump in a shaft (when the Metronome starts) and ends
## when they land: on top (success) or back on the floor (fail). Each run is one JSON line
## appended to log_path. Every time in it is in ms since the run's first wall jump, which is the
## Metronome's beat 0, so the ticks are at multiples of the beat (500 ms at 120 BPM), off-beats
## halfway between. Events:
##   press    a jump press; `off`: ms from the nearest moment to jump (wall contact or meeting
##            the partner) within ±MATCH_RANGE, else absent; `beat_off`: ms from the nearest tick
##            or off-beat
##   contact  hitting a wall (`side` -1 left, 1 right); `beat_off` as above
##   meet     meeting the partner in the coop chimney; `beat_off` as above
##   jump     a wall jump; `kind` "wall" or "clash", `moment` (what it was timed to), `off` (ms
##            from it, as the readout shows), `full` (on time, or weak)

var log_path = "user://wall_log.jsonl"  # where the runs go (a test can point it elsewhere)
const MATCH_RANGE = 500.0  # ms: a press this far from a moment to jump still counts as aimed at it

var player  # player 1
var metronome: Metronome
var shafts = []  # [name, left x, right x] of each shaft, walls and caps included
var top_y = 0.0  # landing above this is reaching the top
var runs = {}  # shaft name -> [successes, fails] this session

var _run = {}  # the run being logged, empty if none
var _last_jump = -100.0
var _last_clash = -100.0
var _last_press = -100.0
var _last_contact = -100.0
var _last_meet = -100.0


func _physics_process(_delta):
	if player == null or not Moves.on("wall_log"):
		_run = {}
		_sync()
		return
	if _run.is_empty():
		if player.wall_beat_time != _last_jump and metronome.running:
			_start()
		_sync()
		return
	_record()
	if player.is_on_floor():
		_finish(player.global_position.y < top_y)


# Takes in the player's current times without logging them, so a run only logs what's new.
func _sync():
	_last_jump = player.wall_beat_time
	_last_clash = player.chimney_clash_time
	_last_press = player._jump_press_time
	_last_contact = player._wall_contact_time
	_last_meet = player._chimney_meet_time


func _start():
	var shaft = _shaft_at(player.global_position.x)
	if shaft == "":
		return
	_run = {
		"shaft": shaft,
		"date": Time.get_datetime_string_from_system(false, true),
		"bpm": metronome.bpm,
		"tolerance_ms": roundi(player.WALL_RHYTHM_TOLERANCE * 1000.0),
		"wall_mode": Moves.value("wall"),
		"origin": metronome.origin,
		"lowest_y": player.global_position.y,
		"events": [],
	}
	# The first jump's own press and contact came just before it.
	if _last_press > metronome.origin - MATCH_RANGE / 1000.0:
		_event("press", _last_press)
	if _last_contact > metronome.origin - MATCH_RANGE / 1000.0:
		_event("contact", _last_contact, {"side": player._wall_contact_side})
	_last_jump = -100.0  # logs the first jump itself
	_record()


func _record():
	_run.lowest_y = minf(_run.lowest_y, player.global_position.y)
	if player._jump_press_time != _last_press:
		_last_press = player._jump_press_time
		_event("press", _last_press)
	if player._wall_contact_time != _last_contact:
		_last_contact = player._wall_contact_time
		_event("contact", _last_contact, {"side": player._wall_contact_side})
	if player._chimney_meet_time != _last_meet:
		_last_meet = player._chimney_meet_time
		if _last_meet > 0.0:
			_event("meet", _last_meet)
	if player.wall_beat_time != _last_jump:
		_last_jump = player.wall_beat_time
		_jump_event("wall", _last_jump)
	if player.chimney_clash_time != _last_clash:
		_last_clash = player.chimney_clash_time
		_jump_event("clash", _last_clash)


func _event(type: String, t: float, extra = {}):
	var e = {"type": type, "t": _ms(t)}
	e.merge(extra)
	_run.events.append(e)


func _jump_event(kind: String, t: float):
	_event("jump", t, {"kind": kind, "moment": _ms(player.wall_jump_moment),
		"off": roundi(player.wall_jump_off * 1000.0), "full": player.wall_jump_strong})


func _finish(success: bool):
	var events: Array = _run.events
	var half = 1000.0 * metronome.beat_length() / 2.0
	var moments = events.filter(func(e): return e.type == "contact" or e.type == "meet")
	for e in events:
		if e.type in ["press", "contact", "meet"]:
			e["beat_off"] = roundi(e.t - roundf(e.t / half) * half)
		if e.type == "press":
			var best = INF
			for m in moments:
				if absf(e.t - m.t) < absf(best):
					best = e.t - m.t
			if absf(best) <= MATCH_RANGE:
				e["off"] = roundi(best)
	_run["result"] = "success" if success else "fail"
	_run["duration_ms"] = _ms(Time.get_ticks_msec() / 1000.0)
	_run.erase("origin")
	_run["climbed_px"] = roundi(GymLevel.GROUND_Y - _run.lowest_y)
	_run.erase("lowest_y")
	_write(_run)
	var tally = runs.get(_run.shaft, [0, 0])
	tally[0 if success else 1] += 1
	runs[_run.shaft] = tally
	_run = {}
	_sync()


func _write(run: Dictionary):
	var file = FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if file == null:
		push_warning("wall log: can't write %s" % log_path)
		return
	file.seek_end()
	file.store_line(JSON.stringify(run))
	file.close()


func _ms(t: float) -> int:
	return roundi((t - _run.origin) * 1000.0)


func _shaft_at(x: float) -> String:
	for s in shafts:
		if x >= s[1] and x <= s[2]:
			return s[0]
	return ""


# For the readout: this session's runs per shaft.
func summary() -> String:
	if not Moves.on("wall_log"):
		return ""
	var parts = []
	for name in ["wide", "narrow", "coop"]:
		var tally = runs.get(name, [0, 0])
		parts.append("%s %d✓ %d✗" % [name, tally[0], tally[1]])
	return "logging runs (%s):  %s" % [ProjectSettings.globalize_path(log_path), "   ".join(parts)]
