class_name Metronome
extends Node
## A level's tempo: ticks every beat while it runs, with a softer, lower tick on the off-beat
## halfway between. The level's rhythms (a shaft's width, a throw's flight) are meant to follow
## from `bpm`, so changing it changes them all. The player finds it in the group "metronome": a
## climb's first wall jump starts it, ticking on that jump, and landing stops it again (see WALL
## RHYTHM in player.gd).

var bpm = 120.0
var volume = -6.0  # dB of the tick
var off_beat_volume = -12.0  # dB of the off-beat tick

var running = false
var origin = 0.0  # when beat 0 ticked (s, the players' clock)
var _half = -1  # the last half beat ticked (even: a beat, odd: an off-beat)


func _ready():
	add_to_group("metronome")


func beat_length() -> float:
	return 60.0 / bpm


# Starts the beat (over) at time t (now or just past), ticking on it.
func restart(t: float):
	running = true
	origin = t
	_half = -1


func stop():
	running = false


func _process(_delta):
	if not running:
		return
	var half = floori((_now() - origin) / (beat_length() / 2.0))
	if half != _half:
		_half = half
		if half % 2 == 0:
			Sfx.play("relay_beat", volume)
		else:
			Sfx.play("metronome_off", off_beat_volume)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
