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
##  - It starts with the first strike: both of you on it, the player of the first number strikes
##    the wheel (whenever you like; its hub glows their colour). That beat is the sequence's
##    first, and the rest follows from there in time.
##  - A strike counts by its press, on its beat (within HIT_WINDOW); the blade lands a moment
##    later. A miss (nobody, the wrong one, a strike off its beat): down two stages, two strikes
##    back, and it stops; strike again (the hub shows who) and it goes on from there.
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
const COLOR_DOOR = Color(0.5, 0.46, 0.62)
const WHEEL_RADIUS = 16.0
const WHEEL_HEIGHT = 22.0  # its middle above the platform: a standing player's chest, where the blade cuts
const WHEEL_SPOKES = 6
const WHEEL_TURN = TAU / WHEEL_SPOKES  # a notch a strike
const WHEEL_SPEED = 14.0  # how fast it catches up with its notch (1/s)
const COLOR_WHEEL = Color(0.72, 0.62, 0.42)
const HALO = 9.0  # px the tell's light reaches past the rim


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
var _hits = {}  # player id -> their press time, struck in time for the strike being played
var _pressed_at = {}  # player id -> when they last pressed attack (Beat time)
var _wrong = false  # someone struck who shouldn't, or off the beat
var _miss_flash = 0.0
var _body: AnimatableBody2D
var _door_shapes: Array = []
var _shut = 0.0  # the doors: 0 open, 1 shut
var _wheel_angle = 0.0  # drawn; catches up with _stage's notch
var _wheel_flash = 0.0


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
	_move(delta)
	if _done or not Beat.running or _strikes.is_empty():
		return
	var t = Beat.time()
	for p in players():
		if Input.is_action_just_pressed(p._action("attack")):  # its input set (swap_controls)
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


func _struck(p):
	if p == null or not "player_id" in p:
		return
	_wheel_flash = 0.12
	if _done or _strikes.is_empty() or not Beat.running:
		play_near("chip", -8.0)
		return
	var pressed = _pressed_at.get(p.player_id, Beat.time())
	var who = _strikes[_stage][1]
	if not _running:
		_boot(p, pressed, who)
		return
	var off = pressed - Beat.beat_time(_strike_beat())
	if absf(off) <= HIT_WINDOW and (who == 3 or who == p.player_id):
		_hits[p.player_id] = pressed
		if _hit():
			_judge()  # all in: up now, not once the window is over
	else:
		_wrong = true


# Stopped: the strike it's waiting for starts it, its beat the one it was pressed nearest to.
func _boot(p, pressed: float, who: int):
	if not players().all(_on_board) or not (who == 3 or who == p.player_id):
		play_near("chip", -8.0)
		return
	for id in _hits.keys():  # both at once: the other one's strike has to be close
		if absf(_hits[id] - pressed) > HIT_WINDOW * 2.0:
			_hits.erase(id)
	_hits[p.player_id] = pressed
	if not _hit():
		return
	_start = roundi(Beat.beats_at(pressed)) - _strikes[_stage][0]
	_running = true
	_judge()


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
	_stage = maxi(_stage - 2, 0)
	_running = false
	_miss_flash = MISS_FLASH
	play_near("bell_dull", -2.0)


func _clear():
	_hits.clear()
	_wrong = false


func _move(delta: float):
	var goal = _stage * stage_height
	if _y < goal:
		_y = minf(_y + stage_height / RISE_TIME * delta, goal)
	elif _y > goal:
		_y = maxf(_y - FALL_SPEED * delta, goal)
	_body.position.y = THICKNESS / 2.0 - _y
	var shut = 1.0 if (_running or _stage > 0) and not _done else 0.0
	_shut = move_toward(_shut, shut, delta / DOOR_TIME)
	for door in _door_shapes:
		door.set_deferred("disabled", _shut < 0.5)


# The room starts over.
func reset_piece():
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
	draw_rect(Rect2(0, y, width, THICKNESS), face)
	draw_rect(Rect2(0, y, width, 2.0), COLOR_EDGE)
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
# glows the colour of who strikes next; on a tell, all of it shines in that colour.
func _draw_wheel(at: Vector2):
	draw_line(at, at + Vector2(0, WHEEL_HEIGHT), COLOR_PLATFORM.lightened(0.2), 4.0)
	var rim = COLOR_WHEEL.lightened(0.5 * _wheel_flash / 0.12)
	rim = rim.lerp(COLOR_MISS, _miss_flash / MISS_FLASH)
	var hub = COLOR_WHEEL.darkened(0.3)
	var tell = [] if in_editor() else _tell_now()
	if _done:
		hub = COLOR_DONE
		rim = COLOR_DONE
	elif not tell.is_empty():
		draw_circle(at, WHEEL_RADIUS + HALO, Color(tell[0], 0.35 * tell[1]))
		rim = rim.lerp(tell[0], tell[1])
		hub = tell[0]
	elif not _running and not _strikes.is_empty():
		hub = COLORS_STEP[_strikes[_stage][1]]
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
