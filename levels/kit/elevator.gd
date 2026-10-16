@tool
class_name KitElevator
extends Clockwork
## A platform that rises on a rhythm you play together. Its `sequence` is a row of steps, one a
## beat: 1 (P1 strikes), 2 (P2 strikes), 3 (both at once), e.g. "1-2-1-2-1-1-2-2-3". A strike
## is the attack button, on the beat (within HIT_WINDOW).
##  - Both of you on it: it starts on the next 1.
##  - Each step hit: up one stage (`stage_height`). The last one: it's at the top, and stays.
##  - A step missed (nobody, the wrong one, or a strike off the beat): down two stages, back two
##    steps in the sequence, and a bar off to gather yourselves; it goes on at the 1 after that.
##  - Its doors (`doors`) shut at both ends while it runs, and open once it's at the top.
##  - Off it (fallen, jumped off; with no doors): it stops where it is, and starts again on the
##    next 1 once you're both back on.
## The steps show on its front, the one to play lit. Place it at the platform's top-left, at
## the bottom; the editor draws its track up to the top.

const THICKNESS = 20.0
const HIT_WINDOW = 0.12  # s either side of the beat a strike counts
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

## The steps, one a beat: 1 P1, 2 P2, 3 both. Anything else between them is ignored ("1-2-3", "1 2 3", "123").
@export var sequence = "1-2-1-2-1-1-2-2-3":
	set(v):
		sequence = v
		_steps = _parse(v)
		queue_redraw()
@export_range(48, 640, 8) var width = 160:
	set(v):
		width = v
		queue_redraw()
## How far up one step takes it.
@export_range(8, 320, 8) var stage_height = 48:
	set(v):
		stage_height = v
		queue_redraw()
## Doors at both ends that shut while it runs: no getting off on the way up.
@export var doors = true:
	set(v):
		doors = v
		queue_redraw()
## Taller than a jump (136), or you can jump out over them.
@export_range(48, 320, 8) var door_height = 144:
	set(v):
		door_height = v
		queue_redraw()

var _steps: Array = []
var _stage = 0  # steps hit so far: where in the sequence, and how many stages up
var _y = 0.0  # px up from the bottom, now
var _running = false
var _done = false
var _beat = 0  # the beat being played
var _hits = {}  # player id -> struck in time on _beat
var _wrong = false  # someone struck who shouldn't, or off the beat
var _miss_flash = 0.0
var _body: AnimatableBody2D
var _door_shapes: Array = []
var _shut = 0.0  # the doors: 0 open, 1 shut


static func _parse(text: String) -> Array:
	var steps = []
	for c in text:
		if c in ["1", "2", "3"]:
			steps.append(int(c))
	return steps


func _ready():
	_steps = _parse(sequence)
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
	_body.position = Vector2(width / 2.0, THICKNESS / 2.0)
	add_child(_body)


func top() -> float:
	return _steps.size() * stage_height


func _physics_process(delta):
	if in_editor():
		return
	_move(delta)
	if _done or not Beat.running or _steps.is_empty():
		return
	var t = Beat.time()
	var aboard = players().all(_on_board)
	if not _running:
		if aboard and players().all(func(p): return p.get_floor_body() == _body):
			_running = true
			_beat = _next_downbeat(t)
			_clear()
		return
	if not aboard:
		_running = false
		return
	for p in players():
		if Input.is_action_just_pressed(p._action("attack")):  # its input set (swap_controls)
			_strike(p, t)
	if t > Beat.beat_time(_beat) + HIT_WINDOW:
		_judge(t)


func _process(delta):
	super(delta)
	_miss_flash = maxf(_miss_flash - delta, 0.0)
	if not in_editor():
		queue_redraw()


# Over it, or standing on it: in from its ends, and not below its top.
func _on_board(p) -> bool:
	var x = p.global_position.x - global_position.x
	var feet = p.global_position.y + Player.BODY_SIZE.y / 2.0
	return x > -ON_MARGIN and x < width + ON_MARGIN and feet <= global_position.y - _y + THICKNESS  # a frame behind it rising


func _next_downbeat(t: float) -> int:
	return (floori(Beat.beats_at(t) / Beat.BEATS_PER_BAR) + 1) * Beat.BEATS_PER_BAR


func _strike(p, t: float):
	var off = t - Beat.beat_time(_beat)
	if off < -Beat.beat_length():
		return  # the bar off after a miss: strike all you like
	var step = _steps[_stage]
	if absf(off) <= HIT_WINDOW and (step == 3 or step == p.player_id):
		_hits[p.player_id] = true
	else:
		_wrong = true


func _judge(t: float):
	var step = _steps[_stage]
	var hit = (_hits.has(1) and _hits.has(2) if step == 3 else _hits.has(step)) and not _wrong
	_clear()
	if hit:
		_stage += 1
		if _stage >= _steps.size():
			_done = true
			_running = false
			play_near("big_bell", -4.0)
		else:
			play_near("bell", -6.0)
			_beat += 1
		return
	_stage = maxi(_stage - 2, 0)
	_miss_flash = MISS_FLASH
	play_near("bell_dull", -2.0)
	_beat = _next_downbeat(t) + Beat.BEATS_PER_BAR  # a bar off


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
	var shut = 1.0 if _running else 0.0
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
	if _body:
		_body.position.y = THICKNESS / 2.0


func _draw():
	var h = top()
	# The track: two rails up to the top, a tick per stage.
	for x in [6.0, width - 6.0]:
		draw_line(Vector2(x, THICKNESS), Vector2(x, -h), COLOR_RAIL, 2.0)
		for i in _steps.size() + 1:
			draw_line(Vector2(x - 4.0, -i * stage_height), Vector2(x + 4.0, -i * stage_height), COLOR_RAIL, 2.0)
	if in_editor():
		draw_rect(Rect2(0, -h, width, THICKNESS), Color(COLOR_EDGE, 0.3), false, 1.5)  # where it ends up
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
	# The steps on its front.
	var n = _steps.size()
	if n == 0:
		return
	var cell = minf((width - 8.0) / n, 16.0)
	var x0 = (width - cell * n) / 2.0
	for i in n:
		var c = COLORS_STEP[_steps[i]]
		var r = Rect2(x0 + i * cell + 1.5, y + 5.0, cell - 3.0, THICKNESS - 9.0)
		if _done:
			c = COLOR_DONE
		elif i < _stage:
			c = c.darkened(0.6)
		elif i > _stage or not _running:
			c = c.darkened(0.25)
		draw_rect(r, c)
		if i == _stage and _running and not _done:
			draw_rect(r.grow(1.5), Color.WHITE, false, 1.5)
