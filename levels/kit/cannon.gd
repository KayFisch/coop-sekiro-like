@tool
class_name KitCannon
extends Clockwork
## A cannon firing a ball on its beats, in a straight line (`angle_deg`, `speed`), no gravity.
## The ball is a billiard ball and you are the cushion: a perfect parry (block pressed in time,
## is_perfect_parry() as against the bosses) sends it back off you, angle in = angle out, off
## the side of you it meets: from the side, across goes the other way and up or down stays; from
## above or below, up and down turn round and across stays. So it zigzags on between the two of
## you, side by side or one above the other, drifting as it goes, and you keep it going from
## both sides until it reaches a KitSwitch with `trigger` BALL, the target.
##  - Only blocking (block held): the ball shatters on your blade, nothing else happens.
##  - Neither: it kills.
##  - A wall, floor or ceiling (KitBlock, a shut KitDoor) shatters it; one-way platforms it
##    flies through.
## Place it at the muzzle's pivot. In the editor a dotted line shows where it aims, a tick for
## every beat of flight.

const BALL_RADIUS = 9.0
const PARRY_REACH = 22.0  # px off the body where a parry already meets the ball (the blade's reach)
const IGNORE_TIME = 0.2  # s after a parry the ball can't touch whoever sent it
const MAX_FLIGHT_BEATS = 64  # a ball still flying after this long is gone
const BARREL = Vector2(44, 18)  # length, thickness
const BASE_RADIUS = 20.0
const AIM_BEATS = 6  # the editor's aim line: this many beats of flight
const COLOR_BODY = Color(0.32, 0.31, 0.36)
const COLOR_BARREL = Color(0.42, 0.41, 0.47)
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const COLOR_GLOW = Color(1.0, 0.55, 0.2)  # heating up in the beat before it fires
const COLOR_BALL = Color(0.2, 0.2, 0.24)
const COLOR_BALL_EDGE = Color(1.0, 0.82, 0.3)
const COLORS_SENT = [COLOR_BALL_EDGE, Color(0.35, 0.6, 1.0), Color(1.0, 0.6, 0.2)]  # nobody, P1, P2 parried it last
const COLOR_AIM = Color(1.0, 0.55, 0.2, 0.5)

## Where it aims, in degrees: 0 right, 90 up, 180 left, -30 a little down to the right.
@export_range(-180, 180, 1) var angle_deg = 30.0:
	set(v):
		angle_deg = v
		queue_redraw()
## How far the ball flies in a beat, in px (260 at 150 BPM: 650 px/s, almost twice a run).
@export_range(40, 800, 10) var speed = 260.0:
	set(v):
		speed = v
		queue_redraw()
## Counts it fires on, over `bars` bars: [1] once a bar.
@export var pattern: Array[int] = [1]:
	set(v):
		pattern = v
		queue_redraw()
## How many bars the pattern spans (2: counts 1-8, [1] fires every other bar).
@export_range(1, 4) var bars = 2
## Beats later than the pattern says.
@export var offset = 0

var _glow = 0.0
var _flash = 0.0


# A ball in flight: on its own (top_level), so it flies on however the cannon is turned.
class Ball extends Node2D:
	var cannon
	var velocity = Vector2.ZERO  # px/s
	var player_id = 0  # who parried it last (0: nobody yet); a target's `who` asks this
	var _born = 0.0
	var _ignore = {}  # player -> Beat time until which it passes them
	var _query: PhysicsShapeQueryParameters2D

	func _ready():
		top_level = true
		_born = Beat.time()
		_query = PhysicsShapeQueryParameters2D.new()
		_query.shape = CircleShape2D.new()
		_query.shape.radius = BALL_RADIUS
		_query.collision_mask = 1  # the world's layer: walls, floors, shut doors

	func _physics_process(delta):
		global_position += velocity * delta
		queue_redraw()
		if Beat.time() - _born > MAX_FLIGHT_BEATS * Beat.beat_length():
			queue_free()
			return
		for target in get_tree().get_nodes_in_group("kit_ball_targets"):
			if target.ball_touches(global_position, BALL_RADIUS):
				target.ball_hit(self)
				_shatter()
				return
		if _touch_players():
			return
		_query.transform = Transform2D(0.0, global_position)
		if not get_world_2d().direct_space_state.intersect_shape(_query, 1).is_empty():
			_shatter()

	# Parried, blocked or hit: true if the ball is gone.
	func _touch_players() -> bool:
		var t = Beat.time()
		for p in cannon.players():
			if t < _ignore.get(p, -100.0):
				continue
			var box = cannon.player_box(p)
			var d = _closest(box, global_position).distance_to(global_position)
			if d <= BALL_RADIUS + PARRY_REACH and p.is_perfect_parry():
				_bounce_off(p, box)
			elif d > BALL_RADIUS:
				continue
			elif p.is_blocking():
				Sfx.play("chip", -2.0)
				_shatter()
				return true
			else:
				cannon.hit.emit(p)
				_shatter()
				return true
		return false

	# Angle in = angle out, off the side of the parrier's box the ball is past furthest (its
	# sides: across turns round, away from them; its top or bottom: up and down turn round).
	func _bounce_off(p, box: Rect2):
		var off = global_position - box.get_center()
		var past = off.abs() - box.size / 2.0  # how far out past each side, across and up
		var vertical = past.y > past.x  # above or below
		if absf(velocity.y if vertical else velocity.x) < 1.0:
			vertical = not vertical  # flying along that side: it goes straight back
		if vertical:
			var away = signf(off.y) if off.y != 0.0 else -signf(velocity.y)
			velocity.y = absf(velocity.y) * away
		else:
			var away = signf(off.x) if off.x != 0.0 else -signf(velocity.x)
			velocity.x = absf(velocity.x) * away
		player_id = p.player_id
		_ignore[p] = Beat.time() + IGNORE_TIME
		p.on_perfect_parry(false)

	func _closest(box: Rect2, point: Vector2) -> Vector2:
		return Vector2(clampf(point.x, box.position.x, box.end.x), clampf(point.y, box.position.y, box.end.y))

	func _shatter():
		cannon.play_near("thunk", -6.0)
		queue_free()

	func _draw():
		draw_circle(Vector2.ZERO, BALL_RADIUS, COLOR_BALL)
		draw_arc(Vector2.ZERO, BALL_RADIUS, 0.0, TAU, 20, COLORS_SENT[player_id], 2.5)


func _ready():
	add_to_group("kit_reset")
	if not in_editor():
		Beat.beat.connect(_on_beat)


func direction() -> Vector2:
	return Vector2.from_angle(-deg_to_rad(angle_deg))


func _on_beat(index: int):
	if not plays(index, pattern, offset, bars):
		return
	var ball = Ball.new()
	ball.cannon = self
	ball.velocity = direction() * speed / Beat.beat_length()
	add_child(ball)
	ball.global_position = global_position + direction() * BARREL.x
	_flash = 0.12
	play_near("counter_fire", -6.0)


func _process(delta):
	super(delta)
	_flash = maxf(_flash - delta, 0.0)
	_glow = 0.0
	if clock_running() and not pattern.is_empty():
		var b = beats_now()
		if plays(floori(b) + 1, pattern, offset, bars):
			_glow = smoothstep(0.0, 1.0, b - floori(b))  # the beat before it fires
	if not in_editor():
		queue_redraw()  # (in the editor, at Clockwork.EDITOR_FPS)


# The room starts over: the balls in flight are gone.
func reset_piece():
	for c in get_children():
		if c is Ball:
			c.queue_free()


func _draw():
	var dir = direction()
	if in_editor():
		var step = dir * speed
		for i in AIM_BEATS:
			var d = 0.0
			while d < speed:
				draw_line(step * i + dir * d, step * i + dir * minf(d + 8.0, speed), COLOR_AIM, 2.0)
				d += 14.0
			draw_circle(step * (i + 1), 3.0, COLOR_AIM)
	var heat = maxf(_glow * 0.8, _flash / 0.12)
	var side = dir.orthogonal() * BARREL.y / 2.0
	var barrel = PackedVector2Array([side, dir * BARREL.x + side, dir * BARREL.x - side, -side])
	draw_colored_polygon(barrel, COLOR_BARREL.lerp(COLOR_GLOW, heat))
	draw_line(dir * BARREL.x + side, dir * BARREL.x - side, COLOR_EDGE.lerp(COLOR_GLOW, heat), 3.0)
	draw_circle(Vector2.ZERO, BASE_RADIUS, COLOR_BODY)
	draw_arc(Vector2.ZERO, BASE_RADIUS, 0.0, TAU, 24, COLOR_EDGE, 1.5)
	draw_ruler(Vector2(-BASE_RADIUS, BASE_RADIUS + 8.0), pattern, offset, bars)
