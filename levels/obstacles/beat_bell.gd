class_name BeatBell
extends GymTarget
## A bell struck with the blade, on the 1. What counts is the moment the blade hits it, against
## the nearest 1 (Beat.offset_to_downbeat()). Within BELL_WINDOW it rings bright and lights up;
## otherwise it gives a dull clack and goes out of tune until after the next 1, so mashing on
## it gets nothing (cf. Bifrons's mash problem). Either way it floats how far off the hit was,
## in ms, for tuning.
## A rung bell calls the beat steps in `calls` (BeatStep, CALL mode) for one bar, until the 1
## after the one it was struck on (and BELL_WINDOW past it, so a late but good strike on that 1
## keeps them without a gap): only the striker's partner's steps, never the striker's own,
## so in a shaft one rings while the other climbs. Striking it on every 1 keeps them there.

signal rung(player, downbeat)  # struck on time: on the 1 with this beat index

const BELL_WINDOW = 0.1  # s before or after the 1 that still rings
const LIT_TIME = 0.35  # s it glows after ringing
const COLOR_LIT = Color(1.0, 0.85, 0.35)
const COLOR_DETUNED = Color(0.3, 0.28, 0.3)

var calls: Array = []  # BeatSteps it calls for the striker's partner
var size_factor = 1.0  # bigger bells (the great bell)

var _detuned_until = -100.0  # Beat time
var _lit = 0.0


func _init():
	mode = Mode.BELL


func _ready():
	super()
	if size_factor != 1.0:
		for c in get_children():
			if c is CollisionShape2D:
				c.shape.size *= size_factor
		_body.size *= size_factor
		_body.position = -_body.size / 2.0
		_body.pivot_offset = _body.size / 2.0


func _process(delta):
	_lit = maxf(_lit - delta, 0.0)
	var base = COLOR_DETUNED if Beat.time() < _detuned_until else COLOR[Mode.BELL]
	_body.color = base.lerp(COLOR_LIT, _lit / LIT_TIME)


# Called by a player's blade (see _process_attack() in player.gd).
func take_damage(_amount: float, source = null):
	if source == null or not Beat.running:
		return
	var t = Beat.time()
	var off = Beat.offset_to_downbeat(t)
	_body.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(_body, "scale", Vector2.ONE, 0.15)
	_float_text("%+d ms" % roundi(off * 1000.0))
	if t < _detuned_until:
		Sfx.play("bell_dull", -4.0)
		return
	if absf(off) > BELL_WINDOW:
		Sfx.play("bell_dull", -2.0)
		# Out of tune until the next 1 is past (and its window).
		var next_one = (floori(Beat.beats_at(t) / Beat.BEATS_PER_BAR) + 1) * Beat.BEATS_PER_BAR
		_detuned_until = Beat.beat_time(next_one) + BELL_WINDOW
		return
	Sfx.play("bell", -3.0)
	_lit = LIT_TIME
	var downbeat = roundi(Beat.beats_at(t - Beat.AUDIO_LATENCY) / Beat.BEATS_PER_BAR) * Beat.BEATS_PER_BAR
	rung.emit(source, downbeat)
	for step in calls:
		if step.owner_id != 0 and step.owner_id != source.player_id:
			step.call_until(Beat.beat_time(downbeat + Beat.BEATS_PER_BAR) + BELL_WINDOW)
