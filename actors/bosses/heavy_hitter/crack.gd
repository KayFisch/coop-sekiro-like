class_name HitterCrack
extends Node2D
## The mirror cracking (docs/boss_heavy_hitter.md, the rules, 2): a blade of the Heavy Hitter that
## nothing stopped goes into the floor, the mirror line, and the glass breaks through into the other
## half, there where it struck, as a phone's screen does from the corner it fell on. It doesn't run
## anywhere: it spreads from that point over F2 "hitter_crack_delay", and as it breaks open it hits
## the other half's player if they're on the floor within "hitter_crack_reach" of it
## (HeavyHitter.crack_hits(): jump it). Then it stays a moment and fades. It's drawn in the half it
## breaks into, in the color of the one it comes from: the light half's dark breaking into the pale
## shadow half, the shadow's pale into the dark light half. One-sided, in the color of the player of
## the layer it comes from.

# --- Its look ---
const RAYS = 7  # cracks out from the point...
const RAY_LENGTH = Vector2(35.0, 95.0)  # ...each this long, at random
const RAY_SPREAD = 0.35  # radians the fan stays off the floor at either end
const KINKS = 4  # corners along a ray
const KINK = 0.3  # radians a ray bends by at a corner, at most
const BRANCH_CHANCE = 0.5  # a corner sends a short branch off
const BRANCH_LENGTH = Vector2(10.0, 24.0)
const RINGS = [0.35, 0.7]  # the glass's rings round the point, as shares of the shortest ray
const WIDTH = 2.0
const WIDTH_BROKEN = 3.0  # as it breaks open
const BROKEN_FLASH = 0.12  # s it shows the break, brighter
const HOLD_TIME = 0.5  # s it stays once broken...
const FADE_TIME = 0.5  # ...then fades
const DARK = Color(0.05, 0.05, 0.07)  # the light half's ground, breaking into the shadow half
const PALE = Color(0.93, 0.91, 0.86)  # the shadow half's, breaking into the light half
const ONE_SIDED_TINT = 0.75

var boss  # the HeavyHitter it's from
var from_layer = 1  # the layer whose blade went into the floor: a player_id
var origin = 0.0  # x where it struck
var floor_y = 600.0

var _age = 0.0
var _broken = false
var _rays = []  # per ray: [its points from the origin, [branches: [from, to]]]


func _ready():
	add_to_group("hitter_cracks")
	top_level = true
	global_position = Vector2.ZERO
	z_index = 5
	for i in RAYS:
		var angle = lerpf(-PI + RAY_SPREAD, -RAY_SPREAD, (i + randf_range(-0.3, 0.3)) / (RAYS - 1))  # up, a fan
		var length = randf_range(RAY_LENGTH.x, RAY_LENGTH.y)
		var points = [Vector2.ZERO]
		var branches = []
		for k in KINKS:
			angle += randf_range(-KINK, KINK)
			var point = points.back() + Vector2.from_angle(angle) * length / KINKS
			points.append(point)
			if k < KINKS - 1 and randf() < BRANCH_CHANCE:
				var off = angle + (0.7 if randf() < 0.5 else -0.7)
				branches.append([point, point + Vector2.from_angle(off) * randf_range(BRANCH_LENGTH.x, BRANCH_LENGTH.y)])
		_rays.append([points, branches])
	_follow_halves()


# The layer it breaks into: the other half.
func into_layer() -> int:
	return boss.other_layer(from_layer) if is_instance_valid(boss) else from_layer


func _physics_process(delta):
	_age += delta
	var delay = Tuning.value("hitter_crack_delay")
	if not _broken and _age >= delay:
		_broken = true
		_break_open()
	if _age >= delay + HOLD_TIME + FADE_TIME:
		queue_free()
		return
	_follow_halves()
	queue_redraw()


# It breaks open: the other half's player on the floor near it is hit.
func _break_open():
	if not is_instance_valid(boss):
		return
	var p = boss.player_of(into_layer())
	if p != null and p.is_on_floor() and absf(p.global_position.x - origin) <= _reach(p):
		boss.crack_hits(p, origin)


func _reach(p) -> float:
	return Tuning.value("hitter_crack_reach") + p.body.size.x / 2.0


# Seconds until it breaks open under that player; INF if it won't (another half's player, too far
# off, or broken already).
func time_to_break(p) -> float:
	if _broken or p == null or not is_instance_valid(boss) or p.player_id != into_layer() \
			or absf(p.global_position.x - origin) > _reach(p):
		return INF
	return maxf(Tuning.value("hitter_crack_delay") - _age, 0.0)


# In the half it breaks into, or in both.
func _follow_halves():
	if is_instance_valid(boss):
		visibility_layer = boss.layer_bit(into_layer())


func _draw():
	var delay = maxf(Tuning.value("hitter_crack_delay"), 0.01)
	var grown = ease(clampf(_age / delay, 0.0, 1.0), 0.4)  # spreading out from the point, fast at first
	var fade = clampf(1.0 - (_age - delay - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
	var color = DARK if from_layer == 1 else PALE  # P1's layer is the light half, P2's the shadow
	if visibility_layer == MirrorView.WORLD:
		var p = boss.player_of(from_layer) if is_instance_valid(boss) else null
		color = PALE.lerp(p.player_color, ONE_SIDED_TINT) if p != null else PALE
	var flashing = _broken and _age < delay + BROKEN_FLASH
	var width = WIDTH_BROKEN if flashing else WIDTH
	var at = Vector2(origin, floor_y)
	var shortest = INF
	for ray in _rays:
		var points: Array = ray[0]
		var line = PackedVector2Array()
		for point in points:
			line.append(at + point * grown)
		draw_polyline(line, Color(color, fade), width, true)
		shortest = minf(shortest, (points.back() as Vector2).length())
		if grown >= 1.0:
			for branch in ray[1]:
				draw_line(at + branch[0], at + branch[1], Color(color, 0.8 * fade), width * 0.7, true)
	for ring in RINGS:
		var radius = shortest * ring * grown
		if radius > 2.0:
			draw_arc(at, radius, -PI + RAY_SPREAD, -RAY_SPREAD, 12, Color(color, 0.7 * fade), width * 0.7, true)
	if flashing:
		draw_circle(at, 6.0, Color(color, 0.9))
