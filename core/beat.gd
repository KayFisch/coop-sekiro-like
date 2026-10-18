extends Node
## Autoload: the one clock for everything that goes in time. A level starts it (start()), and
## from then on every obstacle asks it where in the beat it is, or listens for `beat` / `bar`,
## instead of counting time itself: so all of them stay in time with each other. Within a level
## it is never reset or shifted, not on a respawn nor on R. It stops when the level leaves the
## tree (a scene change), and it pauses with the game (F1).
## Obstacles describe themselves in beats: a pattern of counts (1-4) and an offset.
## Clicks on every beat, accented on the 1; off at start, M switches it on and off.
## Plays a level's music (start(..., track), TRACKS) in time with itself: a stretch of the song
## looped bar for bar, its beats on the clock's. The music plays on into the next room when that
## starts the same track: the new clock then starts in the music's bar, not on a 1 (the beats
## still count from 0, a 1 every 4).

signal beat(index)  # every beat, counted from 0 at start(); index 0, 4, 8... is a 1
signal bar(index)  # every bar's 1, counted from 0

# 150 per minute, 0.4 s a beat: already the game's hidden pulse. The slash comes back in 0.41 s,
# and a jump rises for 0.39 s.
const DEFAULT_BPM = 150.0
const BEATS_PER_BAR = 4
# s from playing a click to hearing it. Judging (offset_to_beat()) moves this much later, so a
# press made on the click as heard counts as on the beat. Raise it if every hit reads late.
const AUDIO_LATENCY = 0.0
const CLICK_VOLUME = -10.0  # dB
const CLICK_ACCENT_VOLUME = -4.0  # dB, the 1

# --- Music ---
# The songs, by the name a level asks for: each a WAV of exactly `bars` bars at `bpm`, starting
# on a 1, that loops seamlessly by itself (a WAV: seeking an MP3 decodes it from the start, far
# too slow to do while playing).
const TRACKS = {
	# "Arcade Psytrance 150 BPM ... Goa Trance" (mp3, 8:54): 150 BPM, but its sections sit a few
	# tens of ms apart, so only 2:17.36-3:59.76 is cut out, four 16-bar phrases where the kick
	# stays within ~10 ms of the grid (measured from the file).
	"arcade_psytrance": {"path": "res://assets/music/arcade_psytrance_loop.wav", "bpm": 150.0, "bars": 64},
}
# s the music may drift from the clock before it's put back: a real slip (a hitch), not the
# position's jitter (a few ms; a put-back itself lands up to ~30 ms off).
const MUSIC_RESYNC = 0.08
const MUSIC_RESYNC_GAP = 1.0  # s at least between two put-backs (a position just after one is stale)
const MUSIC_LINGER = 0.3  # s the music plays on after the clock stops, for the next room to pick it up

var running = false
var bpm = DEFAULT_BPM
var click_on = false  # off until M

var _time = 0.0  # s of clock time since start(), paused time left out
# Where the current tempo began: beat count and clock time. A tempo change (not built yet) would
# start a new tempo here on a bar's 1, so the beats before it keep their times.
var _origin_beat = 0
var _origin_time = 0.0
var _next_beat = 0  # the next beat to strike
var _fresh = false  # started, the first frame not run yet: it runs at time 0
var _level: Node  # stops the clock when it leaves the tree
var _music: AudioStreamPlayer
var _track = ""  # the TRACKS name playing, "" none
var _music_shift = 0.0  # s: the loop is at fposmod(_time + this, loop length)
var _music_idle = 0.0  # s the music has played on with the clock stopped
var _resynced_at = -1000000  # Time msec of the last put-back (see MUSIC_RESYNC_GAP)
var _offset = 0.0  # s the audio (music, click) plays ahead of the clock: F1 → Sound, for a late headset
var _next_click = 0  # the next beat to click (_offset early)
var _stopped_goal = 0.0  # s into the loop the music was at when the clock stopped
var _stopped_for = 0.0  # s of physics time since it stopped (the steps run on between rooms)


func _ready():
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_update_sound()
	Moves.changed.connect(_update_sound)


# Starts the clock at beat 0 (a 1), struck on the next physics frame. `level`: whoever started
# it; the clock stops when it leaves the tree. `track`: the music (a TRACKS name), "" none; if
# it's already playing, it plays on and the clock starts where it is in its bar.
func start(new_bpm = DEFAULT_BPM, level: Node = null, track = ""):
	var into_loop = _music_now() if track != "" and track == _track and _music.playing else -1.0
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
	if into_loop >= 0.0:  # plays on: beat 0 was the 1 of the music's bar now (on the clock: _offset back)
		var on_clock = into_loop - _offset
		_origin_time = -fposmod(on_clock, bar_length())
		_next_beat = ceili(beats_at(0.0) - 0.0001)
		_music_shift = on_clock
	elif track != "":
		if not is_equal_approx(new_bpm, TRACKS[track].bpm):
			push_warning("Beat: %s is %d BPM, the level %d: they drift apart" % [track, TRACKS[track].bpm, new_bpm])
		_track = track
		_music.stream = load_track(track)
		_music_shift = 0.0
		_music.play(fposmod(_offset, _loop_length()))
	else:
		_stop_music()
	_music_idle = 0.0
	_next_click = _next_beat


func stop():
	if running and _track != "":  # where the music is on this clock: the next room picks it up from here
		_stopped_goal = fposmod(_time + _music_shift + _offset, _loop_length())
		_stopped_for = 0.0
	running = false
	if is_instance_valid(_level) and _level.tree_exiting.is_connected(stop):
		_level.tree_exiting.disconnect(stop)
	_level = null


# Where the music should be on the next physics step, s into its loop, counted in the clock's own
# time: running, by the clock; stopped, from where the clock left it plus the steps since (real
# time and measuring the playback are both off by tens of ms across a scene change).
func _music_now() -> float:
	var step = 1.0 / Engine.physics_ticks_per_second
	if running:
		return fposmod(_time + step + _music_shift + _offset, _loop_length())
	return fposmod(_stopped_goal + _stopped_for + step, _loop_length())


func _physics_process(delta):
	if not running:
		_stopped_for += delta
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
	while beat_time(_next_click) - _offset <= _time + 0.0001:  # the click, ahead of the beat by _offset
		if click_on:
			var downbeat = _next_click % BEATS_PER_BAR == 0
			Sfx.play("beat_accent" if downbeat else "beat_click", CLICK_ACCENT_VOLUME if downbeat else CLICK_VOLUME)
		_next_click += 1
	_sync_music()


# --- Music ---

func _process(delta):
	if not running and _track != "":  # no next room picked it up: it stops
		_music_idle += delta
		if _music_idle > MUSIC_LINGER:
			_stop_music()


func _loop_length() -> float:
	return track_length(_track)


# s a track's loop takes: its whole bars at its tempo.
func track_length(track: String) -> float:
	return TRACKS[track].bars * BEATS_PER_BAR * 60.0 / TRACKS[track].bpm


# A track's stream, set to loop seamlessly over its whole bars.
func load_track(track: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = load(TRACKS[track].path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(track_length(track) * stream.mix_rate)
	return stream


# The music's volume (F1 → Sound), in dB.
func music_volume_db() -> float:
	var percent = float(String(Moves.value("music_volume")).trim_suffix("%"))
	return linear_to_db(percent / 100.0) if percent > 0.0 else -80.0


# s into the loop the music is at now (the mix runs a little ahead of the position).
func _loop_position() -> float:
	return fposmod(_music.get_playback_position() + AudioServer.get_time_since_last_mix(), _loop_length())


# Puts the music back where the clock says it should be, if it has drifted; it loops by itself.
func _sync_music():
	if _track == "" or not _music.playing or Time.get_ticks_msec() < _resynced_at + MUSIC_RESYNC_GAP * 1000.0:
		return
	var length = _loop_length()
	var goal = fposmod(_time + _music_shift + _offset, length)
	var drift = fposmod(_loop_position() - goal + length / 2.0, length) - length / 2.0
	if absf(drift) > MUSIC_RESYNC:
		_music.seek(goal)
		_resynced_at = Time.get_ticks_msec()


func _stop_music():
	_music.stop()
	_track = ""


# F1 → Sound: the music's volume, and how far ahead the audio plays (a changed offset puts the
# music where it now belongs at once).
func _update_sound():
	_music.volume_db = music_volume_db()
	var offset = float(String(Moves.value("audio_offset")).trim_suffix(" ms")) / 1000.0
	if offset != _offset:
		_offset = offset
		if running and _track != "" and _music.playing:
			_music.seek(fposmod(_time + _music_shift + _offset, _loop_length()))
			_resynced_at = Time.get_ticks_msec()


func _strike(index: int):
	var downbeat = index % BEATS_PER_BAR == 0
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


# s from the nearest beat to time t (default: now), heard as the click sounds: < 0 is early
# (before the beat), > 0 late.
func offset_to_beat(t = -1.0) -> float:
	var beats = beats_at((_time if t < 0.0 else t) - AUDIO_LATENCY)
	return (beats - roundf(beats)) * beat_length()


# The same against the nearest 1.
func offset_to_downbeat(t = -1.0) -> float:
	var bars = beats_at((_time if t < 0.0 else t) - AUDIO_LATENCY) / BEATS_PER_BAR
	return (bars - roundf(bars)) * bar_length()
