@tool
class_name KitElevator
extends Clockwork
## A platform that rises on a rhythm you play together, by striking the wheel in its middle.
## Its `sequence` is written a beat a character:
##   1, 2, 3   a strike: P1, P2, both at once; each one hit takes it up a stage (`stage_height`)
##   t         a tell: the wheel shines in the colour of the next strike's player
##   .         a beat with nothing on it
##   -         on to the next bar (the rest of this one is empty)
## e.g. "1.t.-2.t.-1.t.-" (a strike a bar, told two beats ahead) or "1t2t-1t2t" (every other
## beat, told one ahead). Spaces are ignored.
##  - It starts when you strike it: both of you on it, either of you strikes the wheel (whenever
##    you like; its hub glows the colour of who has the first strike). Then an intermission: the
##    rest of that bar it does nothing, the next whole bar it flashes yellow on the 1 and the 3;
##    from the 1 after that the sequence plays, its bars on the metronome's bars. While
##    it plays, the wheel pulses white with the metronome, strong on the 1 and the 3, faint on the
##    2 and the 4; on a tell's beat it flashes in the tell's colour instead.
##  - A strike counts by its press, on its beat (within HIT_WINDOW); the blade lands a moment
##    later. A miss (nobody, the wrong one, a strike off its beat): down two stages, two strikes
##    back (it flashes red), the same intermission from the missed beat, then on from there by
##    itself. Back on the ground, it shuts off: strike it to start it again.
##  - Off it (with no doors), it stops: strike again and it boots up again.
##  - Its doors (`doors`) are shut from the first strike until it's at the top.
## Place it at the platform's top-left, at the bottom; the editor draws its track up to the top
## and the sequence under it, a square a beat.

const THICKNESS = 20.0
const BAR = 4  # beats a bar, as Beat counts them
const HIT_WINDOW = 0.12  # s either side of the beat a strike counts (its press: the blade lands later)
const STRIKE_DELAY = 0.22  # s after the window a beat is judged: a press's blade reaches the wheel ~0.15 s later
const RISE_TIME = 0.12  # s for one stage up
const FALL_SPEED = 900.0  # px/s going down after a miss
const MISS_FLASH = 0.4  # s the front flashes red
const ON_MARGIN = 10.0  # px past the platform's ends still counts as on it (in the air above, too)
const DOOR_THICKNESS = 8.0
const DOOR_TIME = 0.15  # s to shut or open
const COLOR_PLATFORM = Color(0.36, 0.34, 0.3)
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const COLOR_RAIL = Color(1, 1, 1, 0.12)
const COLORS_STEP = [Color(0.4, 0.4, 0.4), Color(0.3, 0.55, 1.0), Color(1.0, 0.58, 0.18), Color(0.35, 0.95, 0.45)]  # -, P1, P2, both (green)
const COLOR_MISS = Color(1.0, 0.25, 0.2)
const COLOR_DONE = Color(1.0, 0.82, 0.3)
const COLOR_BOOT = Color(1.0, 0.92, 0.2)  # the bar it boots up
const COLOR_DOOR = Color(0.5, 0.46, 0.62)
const WHEEL_RADIUS = 16.0
const WHEEL_HEIGHT = 22.0  # its middle above the platform: a standing player's chest, where the blade cuts
const WHEEL_SPOKES = 6
const WHEEL_TURN = TAU / WHEEL_SPOKES  # a notch a strike
const WHEEL_SPEED = 14.0  # how fast it catches up with its notch (1/s)
const COLOR_WHEEL = Color(0.72, 0.62, 0.42)
const HALO = 9.0  # px the tell's light reaches past the rim
const COLOR_PULSE = Color(1, 1, 1)  # the metronome pulse: the rim brightens toward this
const PULSE_STRONG = 0.8  # how far the rim brightens on the 1 and the 3
const PULSE_FAINT = 0.12  # ... and on the 2 and the 4 (barely)
const PULSE_HALO = 0.4  # the pulse's halo, at full pulse


# What the blade hits (it looks for a body in the "boss" group, see _process_attack() in player.gd).
class WheelBox extends CharacterBody2D:
	var elevator

	func take_damage(_amount: float, source = null):
		elevator._struck(source)

## A beat a character: 1 P1, 2 P2, 3 both strike; t the wheel tells who's next; . nothing; - on to the next bar.
@export var sequence = "1.t.-2.t.-1.t.-2.t.-1.t.-2.t.-1.t.-2.t.-1":
	set(v):
		sequence = v
		_parse(v)
		queue_redraw()
@export_range(48, 640, 8, "or_greater") var width = 160:
	set(v):
		width = v
		queue_redraw()
## How far up one strike takes it.
@export_range(8, 320, 8) var stage_height = 48:
	set(v):
		stage_height = v
		queue_redraw()
## Doors at both ends, shut on the way up: no getting off.
@export var doors = true:
	set(v):
		doors = v
		queue_redraw()
## Taller than a jump (136), or you can jump out over them.
@export_range(48, 320, 8) var door_height = 144:
	set(v):
		door_height = v
		queue_redraw()

var _strikes: Array = []  # [beat in the sequence, who: 1, 2, 3]
var _tells: Array = []  # [beat in the sequence, index of the strike it tells]
var _length = 0  # beats the sequence takes, to its last character
var _stage = 0  # strikes hit so far: the next one to play, and how many stages up
var _y = 0.0  # px up from the bottom, now
var _running = false
var _done = false
var _start = 0  # the Beat index the sequence's first beat fell on (the strikes' beats count from it)
var _boot_end = 0  # the Beat index an intermission (booting up, or after a miss) ends on: a 1
var _resume_beat = 0  # the Beat index it plays on from, after booting up or a miss: strikes before count for nothing
var _hits = {}  # player id -> their press time, struck in time for the strike being played
var _pressed_at = {}  # player id -> when they last pressed attack (Beat time)
var _wrong = false  # someone struck who shouldn't, or off the beat
var _miss_flash = 0.0
var _body: AnimatableBody2D
var _door_shapes: Array = []
var _shut = 0.0  # the doors: 0 open, 1 shut
var _wheel_angle = 0.0  # drawn; catches up with _stage's notch
var _wheel_flash = 0.0
var _stacked: Array = []  # [on top, below]: held together while it rises (see _move())


func _parse(text: String):
	_strikes = []
	_tells = []
	var beat = 0
	for c in text:
		if c in ["1", "2", "3"]:
			_strikes.append([beat, int(c)])
			beat += 1
		elif c in ["t", "T"]:
			_tells.append([beat, -1])
			beat += 1
		elif c == ".":
			beat += 1
		elif c == "-" and beat % BAR != 0:
			beat += BAR - beat % BAR
	_length = beat
	for tell in _tells:
		for i in _strikes.size():
			if _strikes[i][0] > tell[0]:
				tell[1] = i
				break
	_tells = _tells.filter(func(tell): return tell[1] >= 0)  # one after the last strike tells nothing


func _ready():
	_parse(sequence)
	add_to_group("kit_reset")
	if in_editor():
		return
	_body = AnimatableBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(width, THICKNESS)
	_body.add_child(shape)
	if doors:
		for x in [DOOR_THICKNESS / 2.0, width - DOOR_THICKNESS / 2.0]:
			var door = CollisionShape2D.new()
			door.shape = RectangleShape2D.new()
			door.shape.size = Vector2(DOOR_THICKNESS, door_height)
			door.position = Vector2(x - width / 2.0, -THICKNESS / 2.0 - door_height / 2.0)  # on the platform, at its ends
			door.disabled = true
			_body.add_child(door)
			_door_shapes.append(door)
	var wheel = WheelBox.new()
	wheel.elevator = self
	wheel.add_to_group("boss")
	wheel.collision_layer = 4  # where player sword hitboxes look (the boss's layer)
	wheel.collision_mask = 0
	wheel.position = Vector2(0, -THICKNESS / 2.0 - WHEEL_HEIGHT)
	var circle = CollisionShape2D.new()
	circle.shape = CircleShape2D.new()
	circle.shape.radius = WHEEL_RADIUS
	wheel.add_child(circle)
	_body.add_child(wheel)
	_body.position = Vector2(width / 2.0, THICKNESS / 2.0)
	add_child(_body)


func top() -> float:
	return _strikes.size() * stage_height


# The Beat index the strike being played falls on.
func _strike_beat() -> int:
	return _start + _strikes[_stage][0]


func _physics_process(delta):
	if in_editor():
		return
	_play()
	_move(delta)  # after: the board check sees the platform where the players last followed it


func _play():
	if _done or not Beat.running or _strikes.is_empty():
		return
	var t = Beat.time()
	for p in players():
		if Input.is_action_just_pressed(p.action("attack")):  # its input set (swap_controls)
			_pressed_at[p.player_id] = t
	if not _running:
		return
	if not players().all(_on_board):  # no doors: off it, it stops; strike again to go on
		_running = false
		_clear()
		return
	if t > Beat.beat_time(_strike_beat()) + HIT_WINDOW + STRIKE_DELAY:
		_judge()


func _process(delta):
	super(delta)
	_miss_flash = maxf(_miss_flash - delta, 0.0)
	_wheel_flash = maxf(_wheel_flash - delta, 0.0)
	_wheel_angle = lerpf(_wheel_angle, _stage * WHEEL_TURN, minf(WHEEL_SPEED * delta, 1.0))
	if not in_editor():
		queue_redraw()


# Over it, or standing on it: in from its ends, and not below its top.
func _on_board(p) -> bool:
	var x = p.global_position.x - global_position.x
	var feet = p.global_position.y + Player.BODY_SIZE.y / 2.0
	return x > -ON_MARGIN and x < width + ON_MARGIN and feet <= global_position.y - _y + THICKNESS  # a frame behind it rising


# Standing on the other player's head (else squeezed between them and the rising platform, the
# one below gets pushed out through it).
func _on_partner(p) -> bool:
	if not p.is_on_floor():
		return false
	for i in p.get_slide_collision_count():
		var c = p.get_slide_collision(i)
		if c.get_normal().y < -0.7 and c.get_collider() != null and c.get_collider().is_in_group("players"):
			return true
	return false


func _struck(p):
	if p == null or not "player_id" in p:
		return
	_wheel_flash = 0.12
	if _done or _strikes.is_empty() or not Beat.running:
		return
	var pressed = _pressed_at.get(p.player_id, Beat.time())
	var who = _strikes[_stage][1]
	if not _running:
		_boot(pressed)
		return
	if pressed < Beat.beat_time(_resume_beat) - HIT_WINDOW:  # booting up, or off after a miss
		return
	var off = pressed - Beat.beat_time(_strike_beat())
	if absf(off) <= HIT_WINDOW and (who == 3 or who == p.player_id):
		_hits[p.player_id] = pressed
		if _hit():
			_judge()  # all in: up now, not once the window is over
	else:
		_wrong = true


# Stopped: a strike by either of you starts it, in the beat it was pressed in (not the nearest:
# late on a 4 is still that bar, not the next one's 1).
func _boot(pressed: float):
	if not players().all(_on_board):
		return
	_running = true
	_intermission(floori(Beat.beats_at(pressed)))
	play_near("bell", -10.0)


# Booting up, or after a miss: from beat `from`, the rest of its bar and one whole bar more
# (flashing yellow on that bar's 1 and 3); from the 1 after that, the sequence's bar with the
# strike it's on plays, its bars on the metronome's ("t.1-": the tell on the 1, the strike on the 3).
func _intermission(from: int):
	_boot_end = (floori(from / float(BAR)) + 2) * BAR  # Beat counts 0, 4, 8... are the 1s
	_resume_beat = _boot_end
	_start = _resume_beat - floori(_strikes[_stage][0] / float(BAR)) * BAR
	_clear()


# The yellow flash on the 1 and the 3 of an intermission's whole bar: 1 on the beat, gone by the
# next.
func _boot_flash() -> float:
	if not _running or in_editor():
		return 0.0
	var b = Beat.beats_at(Beat.time()) - (_boot_end - BAR)
	if b < 0.0 or b >= BAR or floori(b) % 2 == 1:
		return 0.0
	return 1.0 - fmod(b, 1.0)


func _hit() -> bool:
	var who = _strikes[_stage][1]
	return (_hits.has(1) and _hits.has(2) if who == 3 else _hits.has(who)) and not _wrong


func _judge():
	var hit = _hit()
	_clear()
	if hit:
		_stage += 1
		if _stage >= _strikes.size():
			_done = true
			_running = false
			play_near("big_bell", -4.0)
		else:
			play_near("bell", -6.0)
		return
	# Back on the ground: it shuts off (strike it to boot it up again). Above it: the same
	# intermission as booting up, from the missed beat, then on from the strike it's back at.
	var missed = _strike_beat()
	_stage = maxi(_stage - 2, 0)
	_miss_flash = MISS_FLASH
	if _stage == 0:
		_running = false
		return
	_intermission(missed)


func _clear():
	_hits.clear()
	_wrong = false


func _move(delta: float):
	var goal = _stage * stage_height
	var was = _y
	if _y < goal:
		_y = minf(_y + stage_height / RISE_TIME * delta, goal)
	elif _y > goal:
		_y = maxf(_y - FALL_SPEED * delta, goal)
	# The platform carries who stands on it, but not who stands on their head: squeezed between
	# the two, the one below would be pushed out through the platform. So while it rises, the one
	# on top is held on the other's head, and they don't collide.
	if _y > was:
		if _stacked.is_empty():
			for p in players():
				if _on_partner(p) and _on_board(p):
					var below = players().filter(func(o): return o != p)[0]
					p.add_collision_exception_with(below)
					below.add_collision_exception_with(p)
					_stacked.append([p, below])
		for pair in _stacked:
			pair[0].global_position.y = pair[1].global_position.y - Player.BODY_SIZE.y - (_y - was)
			pair[0].velocity.y = 0.0
	else:
		_unstack()
	_body.position.y = THICKNESS / 2.0 - _y
	var shut = 1.0 if (_running or _stage > 0) and not _done else 0.0
	_shut = move_toward(_shut, shut, delta / DOOR_TIME)
	for door in _door_shapes:
		door.set_deferred("disabled", _shut < 0.5)


func _unstack():
	for pair in _stacked:
		if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
			pair[0].remove_collision_exception_with(pair[1])
			pair[1].remove_collision_exception_with(pair[0])
	_stacked.clear()


# The room starts over.
func reset_piece():
	_unstack()
	_stage = 0
	_y = 0.0
	_running = false
	_done = false
	_clear()
	_shut = 0.0
	_wheel_angle = 0.0
	if _body:
		_body.position.y = THICKNESS / 2.0


# The tell shining now: [its colour, how bright: 1 on its beat, fading over it], or [] for none.
func _tell_now() -> Array:
	if not _running:
		return []
	var b = Beat.beats_at(Beat.time()) - _start
	for tell in _tells:
		if tell[1] >= _stage and b >= tell[0] and b < tell[0] + 1:
			return [COLORS_STEP[_strikes[tell[1]][1]], 1.0 - (b - tell[0]) * 0.6]
	return []


func _draw():
	var h = top()
	# The track: two rails up to the top, a tick per stage.
	for x in [6.0, width - 6.0]:
		draw_line(Vector2(x, THICKNESS), Vector2(x, -h), COLOR_RAIL, 2.0)
		for i in _strikes.size() + 1:
			draw_line(Vector2(x - 4.0, -i * stage_height), Vector2(x + 4.0, -i * stage_height), COLOR_RAIL, 2.0)
	if in_editor():
		draw_rect(Rect2(0, -h, width, THICKNESS), Color(COLOR_EDGE, 0.3), false, 1.5)  # where it ends up
		_draw_sequence(Vector2(0, THICKNESS + 6.0))
	var y = -_y
	var face = COLOR_PLATFORM.lerp(COLOR_MISS, _miss_flash / MISS_FLASH * 0.6)
	var boot = _boot_flash()
	face = face.lerp(COLOR_BOOT, 0.4 * boot)
	draw_rect(Rect2(0, y, width, THICKNESS), face)
	draw_rect(Rect2(0, y, width, 2.0), COLOR_EDGE.lerp(COLOR_BOOT, boot))
	if doors and (_shut > 0.0 or in_editor()):
		var dh = door_height * (1.0 if in_editor() else _shut)
		for x in [0.0, width - DOOR_THICKNESS]:
			var r = Rect2(x, y - dh, DOOR_THICKNESS, dh)
			if in_editor():
				draw_rect(r, Color(COLOR_DOOR, 0.5), false, 1.5)  # where they shut
			else:
				draw_rect(r, COLOR_DOOR)
				draw_rect(Rect2(r.position, Vector2(DOOR_THICKNESS, 2.0)), COLOR_EDGE)
	_draw_wheel(Vector2(width / 2.0, y - WHEEL_HEIGHT))


# The wheel to strike: on a post from the platform, turned a notch a strike. Stopped, its hub
# glows the colour of who strikes next; struck to start, it flashes yellow once; on a tell, all
# of it shines in that colour.
# The wheel's white pulse with the metronome, 0 to 1, fading over the beat: strong on the 1 and
# the 3, faint on the 2 and the 4. Only once the sequence plays: not while it's off, at the top,
# or in an intermission (the rest of a bar: nothing; the whole bar: the yellow flash).
func _pulse() -> float:
	if not _running or _strikes.is_empty():
		return 0.0
	var b = Beat.beats_at(Beat.time())
	if b < _boot_end:
		return 0.0
	var fade = pow(1.0 - fmod(b, 1.0), 2.0)
	return fade * (PULSE_STRONG if floori(b) % 2 == 0 else PULSE_FAINT)  # Beat counts 0, 2, 4...: the 1s and 3s


func _draw_wheel(at: Vector2):
	draw_line(at, at + Vector2(0, WHEEL_HEIGHT), COLOR_PLATFORM.lightened(0.2), 4.0)
	var rim = COLOR_WHEEL.lightened(0.5 * _wheel_flash / 0.12)
	rim = rim.lerp(COLOR_MISS, _miss_flash / MISS_FLASH)
	var hub = COLOR_WHEEL.darkened(0.3)
	var tell = [] if in_editor() else _tell_now()
	var boot = _boot_flash()
	if _done:
		hub = COLOR_DONE
		rim = COLOR_DONE
	elif not tell.is_empty():
		draw_circle(at, WHEEL_RADIUS + HALO, Color(tell[0], 0.35 * tell[1]))
		rim = rim.lerp(tell[0], tell[1])
		hub = tell[0]
	elif boot > 0.0:
		draw_circle(at, WHEEL_RADIUS + HALO, Color(COLOR_BOOT, 0.35 * boot))
		rim = rim.lerp(COLOR_BOOT, boot)
		hub = COLORS_STEP[_strikes[_stage][1]]  # who strikes once it's up
	elif not _running and not _strikes.is_empty():
		hub = COLORS_STEP[_strikes[_stage][1]]
	var pulse = _pulse()
	if pulse > 0.0 and tell.is_empty() and not _done:  # on a tell's beat, the tell is the flash
		rim = rim.lerp(COLOR_PULSE, pulse)
		draw_circle(at, WHEEL_RADIUS + HALO * 0.6, Color(COLOR_PULSE, PULSE_HALO * pulse))
	draw_arc(at, WHEEL_RADIUS - 2.0, 0.0, TAU, 32, rim, 4.0)
	for i in WHEEL_SPOKES:
		var d = Vector2.from_angle(_wheel_angle + i * WHEEL_TURN)
		draw_line(at + d * 4.0, at + d * (WHEEL_RADIUS - 2.0), rim, 2.5)
		draw_circle(at + d * (WHEEL_RADIUS + 1.0), 2.5, rim)  # the handles
	draw_circle(at, 5.0, hub)


# The editor's view of the sequence: a square a beat, the strikes in their colours, the tells as
# a small light, a gap between bars.
func _draw_sequence(at: Vector2):
	var cells = {}
	for s in _strikes:
		cells[s[0]] = COLORS_STEP[s[1]]
	var told = {}
	for tell in _tells:
		told[tell[0]] = COLORS_STEP[_strikes[tell[1]][1]]
	for b in _length:
		var r = Rect2(at + Vector2(b * RULER_CELL + floori(b / float(BAR)) * 3.0, 0), Vector2.ONE * (RULER_CELL - 2.0))
		if cells.has(b):
			draw_rect(r, cells[b])
		else:
			draw_rect(r, COLOR_RULER_OFF, false, 1.0)
			if told.has(b):
				draw_circle(r.get_center(), 2.0, told[b])
