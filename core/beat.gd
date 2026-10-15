extends Node
## Autoload: the one clock for everything that goes in time. A level starts it (start()), and
## from then on every obstacle asks it where in the beat it is, or listens for `beat` / `bar`,
## instead of counting time itself: so all of them stay in time with each other. Within a level
## it is never reset or shifted, not on a respawn nor on R. It stops when the level leaves the
## tree (a scene change), and it pauses with the game (F1).
## Obstacles describe themselves in beats: a pattern of counts (1-4) and an offset.
## Clicks on every beat, accented on the 1; M switches the click off and on.

signal beat(index)  # every beat, counted from 0 at start(); index 0, 4, 8... is a 1
signal bar(index)  # every bar's 1, counted from 0

# 150 per minute, 0.4 s a beat: already the game's hidden pulse. The call countdown ticks every
# 0.4 s (CALL_BEAT), Sphaera's coupled pendulums swing on 0.4, Cubus's shockwave slashes on 0.2,
# the slash comes back in 0.41 s, and a jump rises for 0.39 s.
const DEFAULT_BPM = 150.0
const BEATS_PER_BAR = 4
# s from playing a click to hearing it. Judging (offset_to_beat()) moves this much later, so a
# press made on the click as heard counts as on the beat. Raise it if every hit reads late.
const AUDIO_LATENCY = 0.0
const CLICK_VOLUME = -10.0  # dB
const CLICK_ACCENT_VOLUME = -4.0  # dB, the 1

var running = false
var bpm = DEFAULT_BPM
var click_on = true

var _time = 0.0  # s of clock time since start(), paused time left out
# Where the current tempo began: beat count and clock time. A tempo change (not built yet) would
# start a new tempo here on a bar's 1, so the beats before it keep their times.
var _origin_beat = 0
var _origin_time = 0.0
var _next_beat = 0  # the next beat to strike
var _fresh = false  # started, the first frame not run yet: it runs at time 0
var _level: Node  # stops the clock when it leaves the tree


# Starts the clock at beat 0 (a 1), struck on the next physics frame. `level`: whoever started
# it; the clock stops when it leaves the tree.
func start(new_bpm = DEFAULT_BPM, level: Node = null):
	stop()
	bpm = new_bpm
	running = true
	_time = 0.0
	_origin_beat = 0
	_origin_time = 0.0
	_next_beat = 0
	_fresh = true
	_level = level
	if level:
		level.tree_exiting.connect(stop, CONNECT_ONE_SHOT)


func stop():
	running = false
	if is_instance_valid(_level) and _level.tree_exiting.is_connected(stop):
		_level.tree_exiting.disconnect(stop)
	_level = null


func _physics_process(delta):
	if not running:
		return
	if _fresh:
		_fresh = false
	else:
		_time += delta
	# Strikes every beat whose time has come; the time past it carries over, so nothing drifts.
	# As an autoload this runs before the level, so everyone sees this frame's time and beat.
	while beat_time(_next_beat) <= _time + 0.0001:
		_strike(_next_beat)
		_next_beat += 1


func _strike(index: int):
	var downbeat = index % BEATS_PER_BAR == 0
	if click_on:
		Sfx.play("beat_accent" if downbeat else "beat_click", CLICK_ACCENT_VOLUME if downbeat else CLICK_VOLUME)
	beat.emit(index)
	if downbeat:
		bar.emit(index / BEATS_PER_BAR)


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		click_on = not click_on


# --- Asking the clock ---

# s since start(), paused time left out. Obstacles time themselves on this, not on their own.
func time() -> float:
	return _time


func beat_length() -> float:
	return 60.0 / bpm


func bar_length() -> float:
	return beat_length() * BEATS_PER_BAR


# When beat n strikes (clock time).
func beat_time(n: int) -> float:
	return _origin_time + (n - _origin_beat) * beat_length()


# The beat count at clock time t, with the fraction past it (2.5: halfway from beat 2 to 3).
func beats_at(t: float) -> float:
	return _origin_beat + (t - _origin_time) / beat_length()


# The last beat struck (-1 before the first).
func current_beat() -> int:
	return _next_beat - 1


# Where in the bar the last beat was: 1-4.
func beat_in_bar() -> int:
	return posmod(current_beat(), BEATS_PER_BAR) + 1


# How far into the current beat: 0 on it, toward 1 just before the next.
func phase() -> float:
	return fposmod(beats_at(_time), 1.0)


# How far into the current bar: 0 on the 1, toward 1 just before the next 1.
func bar_phase() -> float:
	return fposmod(beats_at(_time), BEATS_PER_BAR) / BEATS_PER_BAR


# s from the nearest beat to time t (default: now), heard as the click sounds: < 0 is early
# (before the beat), > 0 late.
func offset_to_beat(t = -1.0) -> float:
	var beats = beats_at((_time if t < 0.0 else t) - AUDIO_LATENCY)
	return (beats - roundf(beats)) * beat_length()


# The same against the nearest 1.
func offset_to_downbeat(t = -1.0) -> float:
	var bars = beats_at((_time if t < 0.0 else t) - AUDIO_LATENCY) / BEATS_PER_BAR
	return (bars - roundf(bars)) * bar_length()


# Whether a pattern of counts (1-4) plays on beat n, shifted `offset` beats later: [1, 3] with
# offset 1 plays on the 2 and the 4.
func plays_on(n: int, pattern: Array, offset = 0) -> bool:
	return pattern.has(posmod(n - offset, BEATS_PER_BAR) + 1)
