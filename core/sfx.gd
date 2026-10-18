extends Node
## Autoload: procedural sound effects, no audio files. Every sound is synthesized once at
## startup into a sample buffer, then played through a pool of AudioStreamGenerator players.
## play() returns a handle; pass it to stop() to cut a sustained sound (a grind) short.

const MIX_RATE = 22050.0
const POOL_SIZE = 16
const MAX_LENGTH = 2.0  # seconds; each generator buffer must hold a whole sound
const VOLUME_DB = -8.0  # added to every sound: the game's overall loudness (0 = as synthesized)

var _sounds = {}  # name -> PackedVector2Array
var _pool: Array = []  # AudioStreamPlayer
var _busy_until: Array = []  # seconds, per pool slot
var _tokens: Array = []  # bumped on every play, so stale handles can't stop a reused slot


func _ready():
	# Stings play over the paused end screens.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var generator = AudioStreamGenerator.new()
		generator.mix_rate = MIX_RATE
		generator.buffer_length = MAX_LENGTH
		var player = AudioStreamPlayer.new()
		player.stream = generator
		add_child(player)
		_pool.append(player)
		_busy_until.append(0.0)
		_tokens.append(0)
	_build_sounds()


func play(sound: String, volume_db = 0.0) -> Dictionary:
	var frames: PackedVector2Array = _sounds[sound]
	# Take the slot that frees up soonest (an idle one if any), stealing the oldest otherwise.
	var slot = 0
	for i in POOL_SIZE:
		if _busy_until[i] < _busy_until[slot]:
			slot = i
	var player: AudioStreamPlayer = _pool[slot]
	player.stop()
	player.volume_db = volume_db + VOLUME_DB
	player.play()
	var playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	var available = playback.get_frames_available()
	playback.push_buffer(frames if frames.size() <= available else frames.slice(0, available))
	_busy_until[slot] = _now() + frames.size() / MIX_RATE
	_tokens[slot] += 1
	return {"slot": slot, "token": _tokens[slot]}


func play_delayed(sound: String, delay: float, volume_db = 0.0):
	get_tree().create_timer(delay, true).timeout.connect(play.bind(sound, volume_db))


func stop(handle):
	if handle and _tokens[handle.slot] == handle.token:
		_pool[handle.slot].stop()
		_busy_until[handle.slot] = 0.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _build_sounds():
	_sounds["parry"] = _clang(1500.0, 0.15)
	_sounds["parry_strong"] = _clang(2000.0, 0.18)
	_sounds["slash"] = _whoosh(0.1)
	_sounds["stab"] = _stab(0.07)
	_sounds["chip"] = _thud(190.0, 110.0, 0.1, 35.0, 0.2)
	_sounds["hurt"] = _thud(120.0, 45.0, 0.2, 14.0, 0.5)
	_sounds["knockback"] = _thud(165.0, 62.0, 0.2, 14.0, 0.5)
	_sounds["stagger"] = _with_echo(_thud(75.0, 35.0, 0.3, 10.0, 0.3), 0.16, 0.45, 2)
	_sounds["counter_fire"] = _rise(0.3)
	_sounds["counter_hit"] = _explosion(0.8)
	_sounds["clash_grind"] = _grind(1.6)
	_sounds["grand_impact"] = _with_echo(_explosion(0.8), 0.2, 0.35, 1)
	_sounds["launch"] = _rise(0.25)
	_sounds["swing"] = _whoosh(0.35)  # a heavy swing (Bifrons's sweep, his leap)
	_sounds["thunk"] = _thud(90.0, 38.0, 0.35, 8.0, 0.6)  # something heavy landing
	_sounds["tell"] = _zip(0.12)  # ends on the tell ring's close (TELL_SOUND_TIME in player_partner.gd)
	_sounds["call_tick"] = _blip(1100.0, 0.06)
	# The rhythm relay's beats (see RELAY in player_partner.gd); beat 2 is "parry_strong".
	_sounds["relay_beat"] = _blip(660.0, 0.06)  # 1: the dash-slash winds up
	_sounds["relay_strike"] = _clang(1000.0, 0.12)  # 3: the partner's strike throws the dasher
	_sounds["relay_peak"] = _blip(1320.0, 0.07)  # 4: the throw's top
	# The Beat clock's click (core/beat.gd): a short wooden tick, brighter and louder on the 1.
	_sounds["beat_click"] = _blip(1400.0, 0.03)
	_sounds["beat_accent"] = _blip(2100.0, 0.045)
	# The clockwork obstacles (levels/obstacles/), each with a sound of its own on its beat.
	_sounds["hammer"] = _thud(140.0, 55.0, 0.25, 16.0, 0.7)  # a hammer hitting the floor
	_sounds["step_on"] = _blip(880.0, 0.05)  # beat steps appearing
	_sounds["bell"] = _bell(1046.5, 0.9, 4.5)  # a beat bell struck on the 1
	_sounds["bell_dull"] = _thud(420.0, 300.0, 0.09, 45.0, 0.15)  # struck off the 1: a dull clack
	_sounds["pendulum"] = _whoosh(0.28)  # a pendulum passing through the bottom
	_sounds["big_bell"] = _with_echo(_bell(261.6, 1.6, 2.2), 0.35, 0.4, 1)  # the great bell: done
	_sounds["call_go"] = _notes([784.0, 1174.7], 0.09, true)
	_sounds["guard_break"] = _clang(700.0, 0.3)  # Columna Bifrons's guard knocked open
	_sounds["sync_hit"] = _thud(240.0, 80.0, 0.18, 16.0, 0.5)  # a hit through his broken guard
	# Sync as life (core/sync_rules.gd)
	_sounds["on_beat"] = _blip(1760.0, 0.05)  # a sync hit right on the beat
	_sounds["posture_break"] = _with_echo(_explosion(0.5), 0.15, 0.3, 1)
	_sounds["chaos"] = _notes([311.1, 233.1, 155.6], 0.14, false)
	_sounds["sync_mode"] = _notes([392.0, 587.3, 784.0, 1174.7], 0.08, true)
	_sounds["game_over"] = _notes([440.0, 349.2, 293.7], 0.17, false)
	_sounds["victory"] = _notes([523.3, 659.3, 784.0, 1046.5], 0.125, true)


func _buffer(duration: float) -> PackedVector2Array:
	var frames = PackedVector2Array()
	frames.resize(int(duration * MIX_RATE))
	return frames


# Crisp metallic impact: a noise click over a few inharmonic partials with fast decay.
func _clang(pitch: float, duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	for i in out.size():
		var t = i / MIX_RATE
		var s = sin(TAU * pitch * t) * 0.45 \
			+ sin(TAU * pitch * 2.76 * t) * 0.3 \
			+ sin(TAU * pitch * 5.4 * t) * 0.2 * exp(-t * 60.0) \
			+ sin(TAU * pitch * 8.93 * t) * 0.1 * exp(-t * 90.0)
		s *= exp(-t * 28.0)
		if t < 0.003:
			s += randf_range(-1.0, 1.0) * 0.8 * (1.0 - t / 0.003)
		out[i] = Vector2.ONE * clampf(s * 0.85, -1.0, 1.0)  # the parry should cut through everything
	return out


# Band-limited noise swoosh whose brightness falls over its length (the "pitch drop").
func _whoosh(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var fast = 0.0
	var slow = 0.0
	for i in out.size():
		var k = i / float(out.size())
		fast += lerpf(0.55, 0.12, k) * (randf_range(-1.0, 1.0) - fast)
		slow += 0.05 * (fast - slow)
		out[i] = Vector2.ONE * (fast - slow) * sin(PI * k) * 1.1
	return out


# A sharper, shorter whoosh for a stab: brighter noise that snaps in and tails straight off.
func _stab(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var fast = 0.0
	var slow = 0.0
	for i in out.size():
		var k = i / float(out.size())
		fast += lerpf(0.85, 0.3, k) * (randf_range(-1.0, 1.0) - fast)
		slow += 0.08 * (fast - slow)
		var envelope = minf(k / 0.08, 1.0) * pow(1.0 - k, 1.5)
		out[i] = Vector2.ONE * clampf((fast - slow) * envelope * 1.6, -1.0, 1.0)
	return out


# Pitched body thud sweeping f0 -> f1, plus a low-passed noise rumble.
func _thud(f0: float, f1: float, duration: float, decay: float, rumble: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var phase = 0.0
	var noise = 0.0
	for i in out.size():
		var t = i / MIX_RATE
		phase += TAU * lerpf(f0, f1, t / duration) / MIX_RATE
		noise += 0.06 * (randf_range(-1.0, 1.0) - noise)
		var s = sin(phase) * exp(-t * decay) + noise * rumble * 3.0 * exp(-t * decay * 0.7)
		s *= minf(t / 0.002, 1.0)  # no click at the start
		out[i] = Vector2.ONE * clampf(s * 0.7, -1.0, 1.0)
	return out


func _with_echo(source: PackedVector2Array, delay: float, gain: float, repeats: int) -> PackedVector2Array:
	var offset = int(delay * MIX_RATE)
	var out = PackedVector2Array()
	out.resize(source.size() + offset * repeats)
	for r in repeats + 1:
		var g = pow(gain, r)
		for i in source.size():
			out[i + offset * r] += source[i] * g
	return out


# Energetic upward sweep for launching a counterattack.
func _rise(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var phase = 0.0
	for i in out.size():
		var t = i / MIX_RATE
		phase += TAU * 250.0 * pow(4.8, t / duration) / MIX_RATE
		var s = sin(phase) + sin(phase * 2.0) * 0.4 + sin(phase * 3.0) * 0.2
		s *= minf(t / 0.02, 1.0) * minf((duration - t) / 0.08, 1.0)
		out[i] = Vector2.ONE * s * 0.3
	return out


# A quick rising zip that swells and stops dead: the end is the cue.
func _zip(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var phase = 0.0
	for i in out.size():
		var k = i / float(out.size())
		phase += TAU * lerpf(500.0, 1700.0, k * k) / MIX_RATE
		var s = sin(phase) + sin(phase * 2.0) * 0.25
		s *= k * k  # swelling into the cut-off
		out[i] = Vector2.ONE * s * 0.4
	return out


# A short, clean sine blip, like a metronome tick.
func _blip(freq: float, duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	for i in out.size():
		var t = i / MIX_RATE
		var s = sin(TAU * freq * t) * minf(t / 0.002, 1.0) * exp(-t * 60.0)
		out[i] = Vector2.ONE * s * 0.5
	return out


# Big, dramatic impact: darkening noise burst over a dropping sub-bass sine.
func _explosion(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var phase = 0.0
	var noise = 0.0
	for i in out.size():
		var t = i / MIX_RATE
		var k = t / duration
		noise += lerpf(0.5, 0.02, k) * (randf_range(-1.0, 1.0) - noise)
		phase += TAU * lerpf(70.0, 28.0, k) / MIX_RATE
		var s = noise * 1.6 * exp(-t * 5.0) + sin(phase) * 0.9 * exp(-t * 4.0)
		if t < 0.004:
			s += randf_range(-1.0, 1.0)
		out[i] = Vector2.ONE * clampf(s * 0.9, -1.0, 1.0)
	return out


# Blades straining against each other: scraping noise over wobbling metallic partials.
func _grind(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var noise = 0.0
	for i in out.size():
		var t = i / MIX_RATE
		noise += 0.3 * (randf_range(-1.0, 1.0) - noise)
		var metal = sin(TAU * 820.0 * t + 3.0 * sin(TAU * 7.0 * t)) * 0.3 \
			+ sin(TAU * 1310.0 * t) * 0.2 + sin(TAU * 2230.0 * t) * 0.1
		var s = (noise * 0.7 + metal) * (0.6 + 0.4 * sin(TAU * 14.0 * t))
		s *= minf(t / 0.03, 1.0) * minf((duration - t) / 0.1, 1.0)
		out[i] = Vector2.ONE * s * 0.35
	return out


# A struck bell: inharmonic partials over the hum note, the higher ones dying first.
func _bell(pitch: float, duration: float, decay: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var partials = [[0.5, 0.25], [1.0, 0.5], [1.19, 0.3], [1.5, 0.22], [2.0, 0.2], [2.74, 0.12], [3.76, 0.08]]  # [ratio, gain]
	for i in out.size():
		var t = i / MIX_RATE
		var s = 0.0
		for p in partials:
			s += sin(TAU * pitch * p[0] * t) * p[1] * exp(-t * decay * (0.6 + p[0] * 0.5))
		s *= minf(t / 0.001, 1.0)
		if t < 0.004:
			s += randf_range(-1.0, 1.0) * 0.4 * (1.0 - t / 0.004)  # the strike
		if t > duration - 0.05:
			s *= (duration - t) / 0.05  # no click at the end
		out[i] = Vector2.ONE * clampf(s * 0.6, -1.0, 1.0)
	return out


# Short melodic sting; bright uses brighter harmonics.
func _notes(freqs: Array, note_length: float, bright: bool) -> PackedVector2Array:
	var tail = 0.05
	var out = _buffer(freqs.size() * note_length + tail)
	for n in freqs.size():
		var f = freqs[n]
		var start = int(n * note_length * MIX_RATE)
		var length = int((note_length + (tail if n == freqs.size() - 1 else 0.05)) * MIX_RATE)
		for i in length:
			if start + i >= out.size():
				break
			var t = i / MIX_RATE
			var s = sin(TAU * f * t)
			if bright:
				s += sin(TAU * f * 2.0 * t) * 0.3 + sin(TAU * f * 3.0 * t) * 0.15
			else:
				s += sin(TAU * f * 3.0 * t) * 0.12
				s *= 1.0 + 0.05 * sin(TAU * 5.0 * t)  # slight mournful vibrato
			s *= minf(t / 0.01, 1.0) * exp(-t * (5.0 if bright else 4.0))
			out[start + i] += Vector2.ONE * s * 0.3
	# Fade the last 50 ms so the sting ends without a click.
	var fade = int(0.05 * MIX_RATE)
	for i in fade:
		out[out.size() - fade + i] *= 1.0 - float(i) / fade
	return out
