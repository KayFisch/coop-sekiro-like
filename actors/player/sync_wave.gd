class_name SyncWave
extends Node2D
## The partner's hit, shown: a parry's energy runs from the parrier's sword down through them into
## the floor, along it, and up the partner from their feet into their sword, arriving as the
## partner's hit is due (the beat). Then the partner's blade blazes for the beat, with a burst at
## its point. The sync hit is that energy passed on into the boss.
## Each part of the way is seen where its player is: on the mirrored screen (ui/mirror_view.gd)
## the parrier's part in their half, the run along the floor on the line, the partner's in theirs.
## It follows the two as they move. send() starts one.

const COLOR = Color(1.0, 0.35, 0.8)  # the energy: hot pink, read on the dark half and the light one
const CORE = Color(1.0, 0.93, 0.97)  # its white-hot middle
const EDGE = Color(0.05, 0.03, 0.07, 0.6)  # a dark rim, for the light half
const WIDTH = 4.0  # px: the core's width; the glow is GLOW times that, the rim a little more
const GLOW = 2.5
const TAIL = 120.0  # px of the way behind its head that the pulse lights up
const TRACE_ALPHA = 0.3  # the way it came, faint, until it fades after arriving
const FADE_TIME = 0.35  # s the trace takes to fade once it has arrived
const BLAZE_MIN = 0.12  # s the partner's blade blazes at least (the beat, if longer)
const BURST_TIME = 0.25  # s the burst at the blade's point takes to spread and fade...
const BURST_RADIUS = 36.0  # ...out to this radius

var from  # the parrier
var to  # the partner
var travel = 0.18  # s from the parry until it arrives
var blaze = 0.12  # s the partner's blade blazes once it has
var floor_y = 600.0
var _age = 0.0
var _parts = []  # Node2D each, drawing its part: down the parrier, along the floor, up the partner


# A wave from `parrier` to `partner`, arriving `travel_time` from now, under `parent` (the level).
static func send(parrier, partner, travel_time: float, beat_time: float, floor_level: float, parent: Node) -> SyncWave:
	var wave = SyncWave.new()
	wave.from = parrier
	wave.to = partner
	wave.travel = maxf(travel_time, 0.0)
	wave.blaze = maxf(beat_time, BLAZE_MIN)
	wave.floor_y = floor_level
	parent.add_child(wave)
	return wave


func _ready():
	top_level = true
	global_position = Vector2.ZERO
	z_index = 20
	for i in 3:
		var part = Node2D.new()
		part.draw.connect(_draw_part.bind(part, i))
		add_child(part)
		_parts.append(part)


func _process(delta):
	_age += delta
	var over = _age > travel + maxf(maxf(blaze, FADE_TIME), BURST_TIME)
	if over or not is_instance_valid(from) or not is_instance_valid(to):
		queue_free()
		return
	_parts[0].visibility_layer = from.visibility_layer
	_parts[2].visibility_layer = to.visibility_layer
	for part in _parts:
		part.queue_redraw()


# The three parts of the way, as polylines in global coordinates: from the parrier's point down
# their blade, through them and down to the floor; along the floor; up from the floor through the
# partner and along their blade to its point.
func _ways() -> Array:
	var down = [from.blade_point(1.0), from.blade_point(0.0), from.global_position, _feet(from)]
	down.append(Vector2(down.back().x, floor_y))
	var up = [Vector2(_feet(to).x, floor_y), _feet(to), to.global_position, to.blade_point(0.0), to.blade_point(1.0)]
	return [down, [down.back(), up[0]], up]


func _feet(p) -> Vector2:
	return p.global_position + Vector2(0.0, p.body.size.y / 2.0)


func _draw_part(part: Node2D, index: int):
	var ways = _ways()
	var start = 0.0  # how far along the whole way this part begins
	for i in index:
		start += _length(ways[i])
	var total = start
	for i in range(index, 3):
		total += _length(ways[i])
	var way = ways[index]
	var arrived = travel <= 0.0 or _age >= travel
	var head = total if arrived else total * _age / travel  # how far along the whole way it has come
	var since = _age - travel  # s since it arrived (< 0: not yet)
	# The way it came, faint, fading once it's there.
	var trace = TRACE_ALPHA * (1.0 if not arrived else clampf(1.0 - since / FADE_TIME, 0.0, 1.0))
	if trace > 0.0:
		_stroke(part, _slice(way, 0.0, head - start), WIDTH * 0.6, trace)
	# The pulse, on its way.
	if not arrived:
		_stroke(part, _slice(way, head - TAIL - start, head - start), WIDTH, 1.0)
	# Arrived: the partner's blade blazes, and a burst spreads from its point.
	if index == 2 and arrived:
		if since < blaze:
			_stroke(part, PackedVector2Array([to.blade_point(0.0), to.blade_point(1.0)]), WIDTH * 1.6, 1.0)
		var burst = since / BURST_TIME
		if burst < 1.0:
			var at = to.blade_point(1.0)
			var radius = lerpf(8.0, BURST_RADIUS, burst)
			part.draw_arc(at, radius, 0.0, TAU, 32, Color(EDGE, EDGE.a * (1.0 - burst)), 7.0, true)
			part.draw_arc(at, radius, 0.0, TAU, 32, Color(COLOR, 1.0 - burst), 4.0, true)


# A line of the energy: dark rim, glow, white-hot core.
func _stroke(part: Node2D, points: PackedVector2Array, width: float, alpha: float):
	if points.size() < 2:
		return
	part.draw_polyline(points, Color(EDGE, EDGE.a * alpha), width * GLOW + 3.0, true)
	part.draw_polyline(points, Color(COLOR, 0.75 * alpha), width * GLOW, true)
	part.draw_polyline(points, Color(CORE, alpha), width, true)


func _length(points: Array) -> float:
	var length = 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	return length


# The stretch of a polyline from `a` to `b` px along it (clamped to it).
func _slice(points: Array, a: float, b: float) -> PackedVector2Array:
	var out = PackedVector2Array()
	a = maxf(a, 0.0)
	if b <= a:
		return out
	var walked = 0.0
	for i in range(1, points.size()):
		var p0: Vector2 = points[i - 1]
		var p1: Vector2 = points[i]
		var step = p0.distance_to(p1)
		var from_here = walked
		walked += step
		if walked < a or step <= 0.0:
			continue
		if out.is_empty():
			out.append(p0.lerp(p1, clampf((a - from_here) / step, 0.0, 1.0)))
		if walked >= b:
			out.append(p0.lerp(p1, clampf((b - from_here) / step, 0.0, 1.0)))
			return out
		out.append(p1)
	return out
