extends Node
## Autoload: procedural sound effects, no audio files. Every sound is synthesized once at
## startup into a sample buffer, then played through a pool of AudioStreamGenerator players.
## play() returns a handle; pass it to stop() to cut a sustained sound (hum, drone, drink) short.

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
	_sounds["drink"] = _bubbles(1.5)
	_sounds["stagger"] = _with_echo(_thud(75.0, 35.0, 0.3, 10.0, 0.3), 0.16, 0.45, 2)
	_sounds["hum"] = _hum(1.2)
	_sounds["counter_fire"] = _rise(0.3)
	_sounds["counter_hit"] = _explosion(0.8)
	_sounds["grand_drone"] = _drone(0.9)
	_sounds["clash_grind"] = _grind(1.6)
	_sounds["clash_hum"] = _clash_hum(0.8)
	_sounds["grand_impact"] = _with_echo(_explosion(0.8), 0.2, 0.35, 1)
	_sounds["launch"] = _rise(0.25)
	_sounds["swing"] = _whoosh(0.35)  # Sphaera Pendula's heavy swings
	_sounds["chain"] = _grind(0.3)  # chains paying out and snapping taut
	_sounds["thunk"] = _thud(90.0, 38.0, 0.35, 8.0, 0.6)  # the sphere landing on a pan
	_sounds["tell"] = _zip(0.12)  # ends on the tell ring's close (TELL_SOUND_TIME in player.gd)
	_sounds["call_tick"] = _blip(1100.0, 0.06)
	_sounds["call_go"] = _notes([784.0, 1174.7], 0.09, true)
	_sounds["clap"] = _clap(0.09)  # the grab's hands shutting on nothing
	_sounds["guard_break"] = _clang(700.0, 0.3)  # Columna Bifrons's guard knocked open
	_sounds["sync_hit"] = _thud(240.0, 80.0, 0.18, 16.0, 0.5)  # a hit through his broken guard
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


# Rising "blub" chirps whose base pitch climbs over the whole drink.
func _bubbles(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var spacing = 0.08
	var phase = 0.0
	var last_bubble = -1
	var bubble_freq = 0.0
	for i in out.size():
		var t = i / MIX_RATE
		var bubble = int(t / spacing)
		if bubble != last_bubble:
			last_bubble = bubble
			phase = 0.0
			bubble_freq = lerpf(300.0, 900.0, t / duration) * randf_range(0.85, 1.15)
		var local = t - bubble * spacing
		phase += TAU * bubble_freq * (1.0 + local * 25.0) / MIX_RATE
		var s = sin(phase) * exp(-local * 45.0) * minf(local / 0.003, 1.0)
		out[i] = Vector2.ONE * s * 0.35
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


# Low buzzing hum with a slight tremolo; meant to be stopped early.
func _hum(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	for i in out.size():
		var t = i / MIX_RATE
		var s = sin(TAU * 85.0 * t) * 0.5 + sin(TAU * 170.0 * t) * 0.25 + sin(TAU * 255.0 * t) * 0.1
		s *= 0.8 + 0.2 * sin(TAU * 9.0 * t)
		s *= minf(t / 0.05, 1.0) * minf((duration - t) / 0.05, 1.0)
		out[i] = Vector2.ONE * s * 0.35
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


# A dry clap: a bright noise burst with a fast decay.
func _clap(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var last = 0.0
	for i in out.size():
		var t = i / MIX_RATE
		var noise = randf_range(-1.0, 1.0)
		var bright = noise - last  # a crude high-pass
		last = noise
		out[i] = Vector2.ONE * clampf(bright * 0.45 * exp(-t * 45.0) * minf(t / 0.001, 1.0), -1.0, 1.0)
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


# Ominous rising drone: detuned low tones climbing and swelling.
func _drone(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	var phase_a = 0.0
	var phase_b = 0.0
	for i in out.size():
		var t = i / MIX_RATE
		var k = t / duration
		var f = 55.0 * pow(130.0 / 55.0, k)
		phase_a += TAU * f / MIX_RATE
		phase_b += TAU * f * 1.012 / MIX_RATE
		var s = sin(phase_a) + sin(phase_b) + (sin(phase_a * 2.0) + sin(phase_b * 3.0)) * 0.3
		s *= pow(k, 1.5) * 0.8 + 0.2
		s *= 0.85 + 0.15 * sin(TAU * 6.0 * t)
		out[i] = Vector2.ONE * s * 0.25
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


# Blades locked edge to edge: a ringing metallic tone, slowly beating; meant to be stopped early.
func _clash_hum(duration: float) -> PackedVector2Array:
	var out = _buffer(duration)
	for i in out.size():
		var t = i / MIX_RATE
		var s = sin(TAU * 660.0 * t) * 0.4 + sin(TAU * 664.0 * t) * 0.3 \
			+ sin(TAU * 1822.0 * t) * 0.15 + sin(TAU * 2970.0 * t) * 0.08
		s *= 0.8 + 0.2 * sin(TAU * 11.0 * t)
		s *= minf(t / 0.01, 1.0) * minf((duration - t) / 0.05, 1.0)
		out[i] = Vector2.ONE * s * 0.35
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
