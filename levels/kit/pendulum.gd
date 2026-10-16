@tool
class_name KitPendulum
extends Clockwork
## A heavy blade on a rod, hanging from a pivot in the ceiling (this node's position), swinging
## with the clock: through the bottom on the 1 and the 3 and at its turning points on the 2 and
## the 4 (with `bars` 1; 2 swings half as fast). `offset` 2 starts it the other way. Rod and
## blade both kill: it's a sweeping wall, nothing to jump over. Unless you meet it with your own
## blade:
##  - A perfect parry (block pressed in time, is_perfect_parry() as against the bosses) locks
##    the blades: the pendulum stops and holds the parrier (set_clashing(), like Cubus's grand
##    slash) for exactly one swing there and back, so it then goes on in time, away from the
##    parrier, who is free again and ignored for a moment.
##  - Only blocking: knocked away (apply_knockback()), nothing locks.
## A held pendulum clears the way for the partner, but whoever holds it can't pass.

const BLADE_RADIUS = 30.0  # what touches you: a disc around the blade's middle, and the rod
const ROD_WIDTH = 6.0
const IGNORE_TIME = 0.35  # s it can't touch whoever it just let go of, or knocked away
const BLOCK_PUSH = Vector2(520, -260)  # px/s a mere block is knocked away with
const COLOR_ROD = Color(0.35, 0.35, 0.4)
const COLOR_BLADE = Color(0.75, 0.78, 0.85)
const COLOR_EDGE = Color(0.95, 0.96, 1.0)
const COLOR_HELD = Color(1.0, 0.85, 0.4)  # sparks of the locked blades, and the hold's ring
const COLOR_ARC = Color(1.0, 0.4, 0.3, 0.3)  # the editor: the blade's path

## Pivot to the blade's middle.
@export_range(80, 900, 8) var length = 300.0:
	set(v):
		length = v
		queue_redraw()
## Out to each turning point, in degrees.
@export_range(5, 85, 1) var amplitude_deg = 50.0:
	set(v):
		amplitude_deg = v
		queue_redraw()
## Bars for one swing there and back.
@export_range(1, 4) var bars = 1
## Beats later (2: it starts swinging the other way).
@export var offset = 0

var _angle = 0.0
var _holder = null
var _hold_until = -100.0  # Beat time
var _ignore = {}  # player -> Beat time until which it passes through them
var _grind = null


func _ready():
	add_to_group("kit_reset")
	if not in_editor():
		Beat.beat.connect(_on_beat)


func amplitude() -> float:
	return deg_to_rad(amplitude_deg)


# Where the blade's middle is, relative to the pivot.
func blade_offset() -> Vector2:
	return Vector2(sin(_angle), cos(_angle)) * length


# The angle the clock puts it at, at beat count b: 0 straight down, > 0 swung right.
func angle_at(b: float) -> float:
	return amplitude() * sin(PI / 2.0 * (b - offset) / bars)


func _on_beat(index: int):
	if _holder == null and posmod(index - offset, 2 * bars) == 0:
		play_near("pendulum", -6.0)  # through the bottom


func _physics_process(_delta):
	if in_editor():
		_angle = angle_at(beats_now())
		return
	var t = Beat.time()
	if _holder != null and (t >= _hold_until or not is_instance_valid(_holder)):
		_release()
	if _holder == null:
		_angle = angle_at(beats_now()) if Beat.running else 0.0
	queue_redraw()
	var blade = global_position + blade_offset()
	for p in players():
		if p == _holder or t < _ignore.get(p, -100.0):
			continue
		var box = player_box(p)
		var on_blade = _closest(box, blade).distance_to(blade) <= BLADE_RADIUS
		if not on_blade and not _rod_touches(box):
			continue
		if on_blade and _holder == null and p.is_perfect_parry():
			_hold(p)
		elif on_blade and (p.is_blocking() or p.is_perfect_parry()):
			var side = signf(p.global_position.x - blade.x)
			p.apply_knockback(Vector2((side if side != 0.0 else 1.0) * BLOCK_PUSH.x, BLOCK_PUSH.y))
			Sfx.play("parry", -4.0)
			_ignore[p] = t + IGNORE_TIME
		else:
			hit.emit(p)


func _closest(box: Rect2, point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, box.position.x, box.end.x), clampf(point.y, box.position.y, box.end.y))


# The rod, sampled along its length (it's thin; a box can't slip between the samples).
func _rod_touches(box: Rect2) -> bool:
	var tip = blade_offset()
	var steps = ceili(length / 12.0)
	for i in steps:
		var point = global_position + tip * (float(i) / steps)
		if _closest(box, point).distance_to(point) <= ROD_WIDTH / 2.0:
			return true
	return false


func _hold(p):
	_holder = p
	_hold_until = Beat.time() + Beat.bar_length() * bars
	p.on_perfect_parry(true)
	p.set_clashing(true, false)
	_grind = Sfx.play("clash_grind", -6.0)


func _release():
	if is_instance_valid(_holder):
		_holder.set_clashing(false)
		_ignore[_holder] = Beat.time() + IGNORE_TIME
	_holder = null
	Sfx.stop(_grind)
	_grind = null


# The room starts over.
func reset_piece():
	if _holder != null:
		_release()
	_ignore.clear()


func _exit_tree():
	if _holder != null and not in_editor():
		_release()


func _draw():
	if in_editor():
		var a = amplitude()
		draw_arc(Vector2.ZERO, length, PI / 2.0 - a, PI / 2.0 + a, 32, COLOR_ARC, BLADE_RADIUS * 2.0)
	var blade = blade_offset()
	draw_line(Vector2.ZERO, blade, COLOR_ROD, ROD_WIDTH)
	draw_circle(Vector2.ZERO, ROD_WIDTH, COLOR_ROD)
	# A crescent: the blade's edge faces the way out from the pivot.
	var out = blade.normalized()
	var points = PackedVector2Array()
	for i in 13:
		points.append(blade + Vector2.from_angle(out.angle() + lerpf(-1.25, 1.25, i / 12.0)) * BLADE_RADIUS)
	for i in 13:
		points.append(blade - out * 10.0 + Vector2.from_angle(out.angle() + lerpf(1.0, -1.0, i / 12.0)) * BLADE_RADIUS * 0.6)
	var held = _holder != null
	draw_colored_polygon(points, COLOR_BLADE.lerp(COLOR_HELD, 0.5) if held else COLOR_BLADE)
	draw_polyline(points.slice(0, 13), COLOR_HELD if held else COLOR_EDGE, 2.0)
	if held:
		# Shrinks to nothing as the hold runs out.
		var left = clampf((_hold_until - Beat.time()) / (Beat.bar_length() * bars), 0.0, 1.0)
		draw_arc(blade, BLADE_RADIUS + 10.0, -PI / 2.0, -PI / 2.0 + TAU * left, 32, COLOR_HELD, 3.0)
