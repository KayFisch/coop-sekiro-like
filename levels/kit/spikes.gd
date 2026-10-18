@tool
class_name KitSpikes
extends Clockwork
## A strip of spikes: touching them kills. Their position is one end of the base; they run
## `length` along it (right, or down for the ones facing sideways) and point `facing`. Put them
## on a KitBlock. A downslash bounces off them if F1 "Pogo off targets, spikes" is on.
## `timed`: they're out only on their beats (`pattern`, `bars`, `offset`, see Clockwork), for
## `out_beats`, and down in between: harmless, a strip of holes. In the half beat before they
## come out, their tips show.

enum Facing { UP, DOWN, LEFT, RIGHT }

const HEIGHT = 18.0
const TOOTH = 16.0
const FORGIVE = 3.0  # px each side the teeth's hitbox is smaller than they look
const OUT_TIME = 0.05  # s to shoot out: a stab, not a rise
const IN_TIME = 0.12  # s to sink back
const PEEK = 0.25  # how far out the tips show in the half beat before (of HEIGHT)
const DEADLY = 0.5  # out at least this far (of HEIGHT): they kill
const COLOR = Color(0.78, 0.32, 0.3)
const COLOR_HOLES = Color(0.1, 0.08, 0.08)

@export_range(16, 640, 16, "or_greater") var length = 96:
	set(v):
		length = v
		queue_redraw()
@export var facing = Facing.UP:
	set(v):
		facing = v
		queue_redraw()
## Out only on their beats.
@export var timed = false:
	set(v):
		timed = v
		queue_redraw()
## Counts they come out on, over `bars` bars.
@export var pattern: Array[int] = [1, 3]:
	set(v):
		pattern = v
		queue_redraw()
@export_range(1, 4) var bars = 1
## Beats later than the pattern says.
@export var offset = 0
## How long they stay out, in beats.
@export_range(0.25, 4.0, 0.25) var out_beats = 1.0

var _out = 1.0  # how far out: 0 down, 1 all the way


func zone() -> Rect2:
	match facing:
		Facing.DOWN:
			return Rect2(0, 0, length, HEIGHT)
		Facing.LEFT:
			return Rect2(-HEIGHT, 0, HEIGHT, length)
		Facing.RIGHT:
			return Rect2(0, 0, HEIGHT, length)
	return Rect2(0, -HEIGHT, length, HEIGHT)


func _ready():
	if in_editor():
		return
	# What a downslash's pogo box finds (see _check_pogo() in player_sword.gd).
	var pogo = CharacterBody2D.new()
	pogo.add_to_group("pogo")
	pogo.collision_layer = 4
	pogo.collision_mask = 0
	pogo.position = zone().get_center()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = zone().size
	pogo.add_child(shape)
	add_child(pogo)
	if timed:
		Beat.beat.connect(_on_beat)


func _on_beat(index: int):
	if plays(index, pattern, offset, bars):
		play_near("chip", -10.0)


func _physics_process(_delta):
	_update_out()
	if in_editor() or _out < DEADLY:
		return
	var hazard = Rect2(global_position + zone().position, zone().size).grow(-FORGIVE)
	for p in players():
		if hazard.intersects(player_box(p)) and not p.just_pogoed():
			hit.emit(p)


func _process(delta):
	super(delta)
	if timed and not in_editor():
		queue_redraw()


# How far out, from the clock: out on their beats for out_beats, tips showing just before.
func _update_out():
	if not timed:
		_out = 1.0
		return
	if not clock_running() or pattern.is_empty():
		_out = 0.0
		return
	var b = beats_now()
	var length_s = beat_length()
	var since = -1.0  # s since the last time they came out, if that's still going on
	for k in 4 * bars + ceili(out_beats) + 1:
		var n = floori(b) - k
		if plays(n, pattern, offset, bars):
			since = (b - n) * length_s
			break
	var out_s = out_beats * length_s
	if since >= 0.0 and since < out_s:
		_out = minf(since / OUT_TIME, 1.0)
	elif since >= out_s and since < out_s + IN_TIME:
		_out = 1.0 - (since - out_s) / IN_TIME
	else:
		_out = 0.0
	var until = (ceilf(b) - b) * length_s  # to the next beat
	if _out == 0.0 and plays(ceili(b), pattern, offset, bars) and until < length_s / 2.0:
		_out = PEEK


func _draw():
	var along = Vector2.DOWN if facing in [Facing.LEFT, Facing.RIGHT] else Vector2.RIGHT
	var out = {Facing.UP: Vector2.UP, Facing.DOWN: Vector2.DOWN, Facing.LEFT: Vector2.LEFT, Facing.RIGHT: Vector2.RIGHT}[facing]
	if timed:
		draw_line(Vector2.ZERO + out, along * length + out, COLOR_HOLES, 3.0)
	var h = HEIGHT * (_out if timed else 1.0)
	if h > 0.5:
		var points = PackedVector2Array()
		points.append(Vector2.ZERO)
		var d = 0.0
		while d < length:
			var w = minf(TOOTH, length - d)
			points.append(along * (d + w / 2.0) + out * h)
			points.append(along * (d + w))
			d += w
		draw_colored_polygon(points, COLOR)
	if timed:
		draw_ruler(Vector2(0, 8.0) if facing == Facing.UP else Vector2(0, -RULER_CELL - 8.0), pattern, offset, bars)
