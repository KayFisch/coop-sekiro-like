class_name HitterCrack
extends Node2D
## A crack (docs/boss_heavy_hitter.md, the rules, 2): where a blade of the Heavy Hitter comes down
## with nobody of its layer in front of it, it crashes into the mirror, and the glass cracks. From
## there it runs both ways along the floor line, a front each way (F2 "hitter_crack_speed"), as far
## as "hitter_crack_length" or a wall. A front passing the layer's player while they're on the floor
## hits them (HeavyHitter.crack_hits(): once, whatever they hold; jump it). The other player it
## never touches. Drawn in that player's half of the mirrored screen; one-sided, in their color.

const GLASS = Color(0.86, 0.95, 1.0)  # pale, as glass
const WIDTH = 2.5
const ZIG = 3.0  # px it zigzags up and down by...
const STEP = 12.0  # ...a corner every this far
const BRANCH_EVERY = 3  # a short branch off every this many corners
const BRANCH = Vector2(9.0, 6.0)  # (how far along, and off the line)
const LIFT = 2.0  # px over the floor: in the light half just over the mirror line, in the shadow half just under it
const HEAD_RADIUS = 4.0  # a front, a bright point while it runs
const FADE_TIME = 0.7  # s it takes to fade once both fronts are done
const ONE_SIDED_TINT = 0.6  # one-sided: this far toward its player's color

var boss  # the HeavyHitter it's from
var layer = 1  # whose layer it's in: a player_id
var origin = 0.0  # x where the blade came down
var floor_y = 600.0

var _run = {-1: 0.0, 1: 0.0}  # way -> how far that front has run
var _ends = {-1: 0.0, 1: 0.0}  # way -> how far it may: its length, or to the wall
var _hit = false  # it has hit its player
var _done_for = 0.0  # s since both fronts were done
var _zig = []  # per corner, how far up or down it is


func _ready():
	add_to_group("hitter_cracks")
	top_level = true
	global_position = Vector2.ZERO
	z_index = 5
	var length = Tuning.value("hitter_crack_length")
	_ends[-1] = clampf(origin - BaseBoss.ARENA_LEFT, 0.0, length)
	_ends[1] = clampf(BaseBoss.ARENA_RIGHT - origin, 0.0, length)
	for i in int(length / STEP) + 2:
		_zig.append(randf_range(-ZIG, ZIG))
	_follow_halves()


func _physics_process(delta):
	var speed = Tuning.value("hitter_crack_speed")
	var running = false
	for way in [-1, 1]:
		var from = _run[way]
		_run[way] = minf(_run[way] + speed * delta, _ends[way])
		running = running or _run[way] < _ends[way]
		_catch(way, from, _run[way])
	if not running:
		_done_for += delta
		if _done_for >= FADE_TIME:
			queue_free()
			return
	_follow_halves()
	queue_redraw()


# Seconds until a front of it reaches that player; INF if none will (it's past them, it won't get
# that far, it's another's layer, or it has hit already).
func time_to_reach(p) -> float:
	if _hit or p == null or p.player_id != layer:
		return INF
	var way = 1 if p.global_position.x >= origin else -1
	var half = p.body.size.x / 2.0
	var near_edge = absf(p.global_position.x - origin) - half
	var gap = near_edge - _run[way]
	if gap < -2.0 * half or near_edge > _ends[way]:
		return INF
	return maxf(gap, 0.0) / Tuning.value("hitter_crack_speed")


# A front swept from `from` to `to` (px along) this frame: its player there, on the floor, is hit.
func _catch(way: int, from: float, to: float):
	if _hit or to <= from or not is_instance_valid(boss):
		return
	var p = boss.player_of(layer)
	if p == null or not p.is_on_floor():
		return
	var half = p.body.size.x / 2.0
	var a = origin + way * from
	var b = origin + way * to
	if p.global_position.x >= minf(a, b) - half and p.global_position.x <= maxf(a, b) + half:
		_hit = true
		boss.crack_hits(p, origin)


# In its player's half, or in both.
func _follow_halves():
	if is_instance_valid(boss):
		visibility_layer = boss.layer_bit(layer)


func _draw():
	var fade = clampf(1.0 - _done_for / FADE_TIME, 0.0, 1.0)
	var color = GLASS
	var p = boss.player_of(layer) if is_instance_valid(boss) else null
	if p != null and visibility_layer == MirrorView.WORLD:
		color = GLASS.lerp(p.player_color, ONE_SIDED_TINT)
	var y = floor_y - LIFT
	for way in [-1, 1]:
		if _run[way] <= 0.0:
			continue
		var points = PackedVector2Array([Vector2(origin, y)])
		for i in int(_run[way] / STEP):
			var corner = Vector2(origin + way * (i + 1) * STEP, y + _zig[i + 1])
			points.append(corner)
			if (i + 1) % BRANCH_EVERY == 0:
				var off = Vector2(way * BRANCH.x, -BRANCH.y if i % 2 == 0 else BRANCH.y * 0.5)
				draw_line(corner, corner + off, Color(color, 0.7 * fade), WIDTH * 0.6, true)
		points.append(Vector2(origin + way * _run[way], y))
		draw_polyline(points, Color(color, fade), WIDTH, true)
		if _run[way] < _ends[way]:
			draw_circle(points[points.size() - 1], HEAD_RADIUS, Color(Color.WHITE, fade))
