class_name KultistBolt
extends Node2D
## The lightning of FIRE_AND_LIGHTNING (attacks/fire_and_lightning.gd): a bolt straight down from
## the Kultist, flying over the middle, to the floor. His reflection's bolt meets it there, so on
## the mirrored screen it runs between his two images through the axis, in both halves. The attack
## drives it: it crackles yellow (tell(), the tell), flashes red (cue(), the cue to parry) and
## strikes (strike()), then fades; sent back by both players' parries it runs up into him instead.
## Its width, marked on the floor while it crackles, is where it strikes. A player who parried it
## holds its energy for a moment (absorb()): it crackles along their blade, in their half.

enum Mode { TELL, CUE, STRUCK }

const SEGMENT = 18.0  # px: the jagged line's steps...
const JAG = 9.0  # ...and how far each strays sideways
const CRACKLE_TIME = 0.05  # s between two shapes of the jag
const STRIKE_TIME = 0.35  # s the strike's light takes to fade
const MARK_HEIGHT = 28.0  # px: the marks at its width's edges
const ABSORB_JAG = 4.0  # px: the energy crackling along a parrier's blade

var boss  # the Kultist: it runs from his feet
var width = 120.0  # px wide, round his x
var floor_y = 600.0
var _mode = Mode.TELL
var _progress = 0.0  # through the tell, 0..1
var _reflected = false
var _since = 0.0  # s since it struck
var _shape_age = 0.0
var _jag = PackedFloat32Array()  # the jag's sideways offsets, re-rolled every CRACKLE_TIME
var _absorbs = []  # {player, left: s, part: Node2D} for each parrier


# A bolt for the Kultist `kultist`, under `parent` (the room); it waits for tell().
static func summon(kultist, parent: Node) -> KultistBolt:
	var bolt = KultistBolt.new()
	bolt.boss = kultist
	bolt.width = kultist.bolt_width
	bolt.floor_y = BaseBoss.ARENA_FLOOR_Y
	parent.add_child(bolt)
	return bolt


func _ready():
	top_level = true
	global_position = Vector2.ZERO
	z_index = 6
	_roll()


# Crackling, `progress` 0..1 of the way to its cue.
func tell(progress: float):
	_mode = Mode.TELL
	_progress = clampf(progress, 0.0, 1.0)


# The red flash: it strikes as this ends.
func cue():
	_mode = Mode.CUE


# It strikes: down onto the floor, or (`reflected`) back up into him.
func strike(reflected: bool):
	_mode = Mode.STRUCK
	_reflected = reflected
	_since = 0.0


# A parrier holds its energy for `duration` (s), crackling along their blade, in their half.
func absorb(player, duration: float):
	var part = Node2D.new()
	part.draw.connect(_draw_absorb.bind(part, player))
	add_child(part)
	_absorbs.append({"player": player, "left": duration, "part": part})


# Put out at once, unstruck (his attack cut short).
func fade():
	if _mode != Mode.STRUCK:
		_mode = Mode.STRUCK
		_reflected = false
		_since = STRIKE_TIME  # nothing left to show


func _process(delta):
	_shape_age += delta
	if _shape_age >= CRACKLE_TIME:
		_shape_age = 0.0
		_roll()
	if _mode == Mode.STRUCK:
		_since += delta
	for absorb in _absorbs.duplicate():
		absorb.left -= delta
		if absorb.left <= 0.0 or not is_instance_valid(absorb.player):
			absorb.part.queue_free()
			_absorbs.erase(absorb)
		else:
			absorb.part.visibility_layer = absorb.player.visibility_layer
			absorb.part.queue_redraw()
	if (_mode == Mode.STRUCK and _since >= STRIKE_TIME and _absorbs.is_empty()) or not is_instance_valid(boss):
		queue_free()
		return
	queue_redraw()


func _roll():
	_jag = PackedFloat32Array()
	for i in 64:
		_jag.append(randf_range(-JAG, JAG))


# Where it runs: from his feet to the floor, at his x.
func _top() -> Vector2:
	return boss.global_position + Vector2(0.0, boss.body.size.y / 2.0)


func _line(from: Vector2, to: Vector2, jag: float) -> PackedVector2Array:
	var points = PackedVector2Array([from])
	var steps = maxi(int(from.distance_to(to) / SEGMENT), 1)
	for i in range(1, steps):
		points.append(from.lerp(to, float(i) / steps) + Vector2(_jag[i % _jag.size()] * jag / JAG, 0.0))
	points.append(to)
	return points


func _draw():
	if not is_instance_valid(boss):
		return
	var top = _top()
	var bottom = Vector2(top.x, floor_y)
	var tell_color = KultistElement.tell(KultistElement.LIGHTNING)
	var cue_color = KultistElement.cue(KultistElement.LIGHTNING)
	var half = width / 2.0
	match _mode:
		Mode.TELL, Mode.CUE:
			var cue = _mode == Mode.CUE
			var color = cue_color if cue else tell_color
			var alpha = 1.0 if cue else 0.3 + 0.6 * _progress
			if bottom.y - top.y > 1.0:
				draw_polyline(_line(top, bottom, JAG), Color(color, alpha), 4.0 if cue else 2.0, true)
			# Its width on the floor: where it will strike.
			for x in [top.x - half, top.x + half]:
				draw_rect(Rect2(x - 1.0, floor_y - MARK_HEIGHT, 2.0, MARK_HEIGHT), Color(color, 0.4 + 0.5 * alpha))
			draw_rect(Rect2(top.x - half, floor_y - 3.0, width, 3.0), Color(color, 0.25 * alpha))
		Mode.STRUCK:
			var fade = clampf(1.0 - _since / STRIKE_TIME, 0.0, 1.0)
			if fade <= 0.0:
				return
			# The strike's light over its whole width, and its white-hot core: down, or (sent back)
			# up from the floor into him.
			var column = Color(Color.WHITE if _reflected else tell_color, 0.35 * fade)
			draw_rect(Rect2(top.x - half, top.y, width, bottom.y - top.y), column)
			var core_from = bottom if _reflected else top
			var core_to = top if _reflected else bottom
			draw_polyline(_line(core_from, core_to, JAG * 1.5), Color(tell_color, fade), 10.0, true)
			draw_polyline(_line(core_from, core_to, JAG * 1.5), Color(Color.WHITE, fade), 4.0, true)


# A parrier's blade, crackling with the energy it holds.
func _draw_absorb(part: Node2D, player):
	if not is_instance_valid(player):
		return
	var from = player.blade_point(0.0)
	var to = player.blade_point(1.0)
	var color = KultistElement.tell(KultistElement.LIGHTNING)
	var points = PackedVector2Array()
	var steps = 6
	for i in steps + 1:
		var along = from.lerp(to, float(i) / steps)
		var sideways = (to - from).orthogonal().normalized() * _jag[(i * 7) % _jag.size()] * ABSORB_JAG / JAG
		points.append(along + (sideways if i > 0 and i < steps else Vector2.ZERO))
	part.draw_polyline(points, Color(color, 0.9), 3.0, true)
	part.draw_polyline(points, Color(Color.WHITE, 0.9), 1.2, true)
	part.draw_circle(to, 6.0 + 2.0 * sin(_shape_age * 60.0), Color(color, 0.5))
