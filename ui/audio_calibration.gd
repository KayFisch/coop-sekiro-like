extends CanvasLayer
## Audio calibration (F1 → Sound), over the panel: the music plays, you press any button on every
## beat you hear, and it measures how late your presses fall against the music: the delay of your
## audio (a Bluetooth headset: ~150-250 ms) plus your controller's, or how early you press. That
## is what "Audio ahead" should be, so the music reaches you on the beat the game shows and
## judges. Nothing on screen moves in time with the music: you'd follow your eyes, not your ears.
## Enter takes the result, R starts over, Esc goes back to the panel.

signal closed

const TRACK = "arcade_psytrance"
const WARM_UP = 4  # presses not counted: finding the beat
const PRESSES = 16  # presses measured after those
const EARLY = 0.15  # s before a beat a press still counts for that beat (later ones count late, up to 0.25 s)
const UNEVEN = 0.04  # s: presses spread wider than this (around their middle) are worth repeating
const MIN_VOLUME = 0.15  # the music at least this loud here (linear), even if F1 has it quieter
const COLOR_TEXT = Color(1, 1, 1, 0.9)
const COLOR_BACKGROUND = Color(0.06, 0.06, 0.08)

var _player: AudioStreamPlayer
var _label: Label
var _offsets: Array = []  # s each counted press fell after its beat
var _presses = 0
var _result_ms = null  # the suggested "Audio ahead" in ms, once measured
var _middle = 0.0  # s: the presses' median, after the beat
var _spread = 0.0  # s: how far the presses lie from it (their median)


func _ready():
	layer = 101  # over the F1 panel
	process_mode = Node.PROCESS_MODE_ALWAYS  # the panel pauses the game
	var bg = ColorRect.new()
	bg.color = COLOR_BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	add_child(_label)
	_player = AudioStreamPlayer.new()
	_player.stream = Beat.load_track(TRACK)
	_player.volume_db = maxf(Beat.music_volume_db(), linear_to_db(MIN_VOLUME))
	add_child(_player)
	_restart()


func _restart():
	_offsets.clear()
	_presses = 0
	_result_ms = null
	_player.play()
	_show()


# Every key and button is the calibration's while it's open (the panel under it sees none).
func _input(event):
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		closed.emit()
		queue_free()
		return
	if event is InputEventKey and event.physical_keycode in [KEY_F1, KEY_M]:
		return  # the panel, the click: not a beat
	if _result_ms != null:
		if event is InputEventKey and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			Moves.set_value("audio_offset", "%d ms" % _result_ms)
			_show("Set: Audio ahead %d ms." % _result_ms)
		elif event is InputEventKey and event.physical_keycode == KEY_R:
			_restart()
		return
	_press()


# A press: how far after the nearest beat of the music it fell, as the music is being played out.
func _press():
	var beat_length = 60.0 / Beat.TRACKS[TRACK].bpm
	var at = _player.get_playback_position() + AudioServer.get_time_since_last_mix()
	var after = fposmod(at + EARLY, beat_length) - EARLY
	_presses += 1
	if _presses > WARM_UP:
		_offsets.append(after)
	if _offsets.size() >= PRESSES:
		_finish()
	_show()


func _finish():
	var sorted = _offsets.duplicate()
	sorted.sort()
	_middle = (sorted[PRESSES / 2 - 1] + sorted[PRESSES / 2]) / 2.0  # the median: a stray press doesn't pull it
	var spread = sorted.map(func(o): return absf(o - _middle))
	spread.sort()
	_spread = spread[PRESSES / 2]
	_result_ms = clampi(roundi(_middle * 100.0) * 10, -200, 300)  # the panel's steps and range


func _show(note = ""):
	var lines = ["AUDIO CALIBRATION", ""]
	if _result_ms == null:
		lines.append("Press any button on every beat you hear.")
		lines.append("Listen, not look: nothing here blinks.")
		lines.append("")
		if _presses < WARM_UP:
			lines.append("Finding the beat... %d" % (WARM_UP - _presses))
		else:
			lines.append("%d / %d" % [_offsets.size(), PRESSES])
		lines.append("")
		lines.append("Esc: back")
	else:
		var ms = roundi(_middle * 1000.0)
		lines.append("Your presses land %d ms %s the music's beat." % [absi(ms), "after" if ms >= 0 else "before"])
		lines.append("(evenness: ±%d ms%s)" % [roundi(_spread * 1000.0), ", uneven: try again with R" if _spread > UNEVEN else ""])
		lines.append("")
		lines.append("Audio ahead now: %s  →  suggested: %d ms" % [Moves.value("audio_offset"), _result_ms])
		lines.append("")
		lines.append("Enter: take it    R: again    Esc: back")
		if note != "":
			lines.append("")
			lines.append(note)
	_label.text = "\n".join(lines)
