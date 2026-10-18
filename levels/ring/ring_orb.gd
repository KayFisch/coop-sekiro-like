extends Node2D
## Something coming at a player: an arrowhead (parry), a shard (hit), one of a green pair, the
## crossing's green arrow, the sweep, or a violet shard running along the circle. Placed by the
## ring each frame (BeatRing._place()) as a function of the time. Before its beat it marks where
## it'll meet the circle.
## (The beat-ring's, levels/ring/ring.gd: BeatRing.Orb.)

var ring
var kind = 0
var lane = 0  # whose half it's in now (the sweep's and a violet shard's change at the line)
var first = 0  # whose half it was first in
var beat = 0.0  # when it meets the circle (the sweep: the first time)
var side = 1.0  # the side it comes from (a violet shard: where it was born): -1 left, 1 right
var speed = 0.0  # px/s (a violet shard: radians/s along the circle, while it's fast)
var slow = 0.0  # a violet shard: radians/s where it's to be hit...
var brake_u = 0.0  # ...slowing down to that from here (radians along its way)...
var brake_time = 0.0  # ...over this long (s)
var pair = -1
var heavy = false  # the crossing's pair
var target = 0  # a violet shard: whose it is
var meet = 1.0  # a violet shard: the side of the circle it meets them on
var meet_u = PI  # ...how far along its way that is (radians)...
var end_u = TAU  # ...and where its way ends, at the line
var born = 0.0  # a violet shard: when the parry sent it
var answered = {}  # the sweep: lane -> parried (true) or hit (false)
var serial = -1  # the swing that last tried it
var done = false
var split = false
var drift = Vector2.ZERO  # done: how it drifts off as it fades
var result = ""  # what became of it last (the text shown)

# A violet shard: radians along its way at run time `t` (BeatRing._pace_relay()).
func travelled(t: float) -> float:
	var s = t - born
	var fast_time = brake_u / speed
	var u: float
	if s < fast_time:
		u = speed * s
	elif s < fast_time + brake_time:
		var q = (s - fast_time) / brake_time  # its speed: lerp(speed, slow, smoothstep(q))
		u = brake_u + speed * (s - fast_time) + (slow - speed) * brake_time * (q * q * q - q * q * q * q / 2.0)
	else:
		# Past where it's to be hit: gliding on toward the line, slower and slower.
		var left = end_u - meet_u
		u = end_u - left * exp(-slow * (s - fast_time - brake_time) / left)
	return clampf(u, 0.0, end_u)

func color() -> Color:
	match kind:
		BeatRing.Kind.SHARD:
			return BeatRing.COLOR_SHARD
		BeatRing.Kind.RELAY:
			return BeatRing.COLOR_RELAY
		BeatRing.Kind.PAIR, BeatRing.Kind.SWEEP, BeatRing.Kind.CHARGE:
			return BeatRing.COLOR_TOGETHER
	return BeatRing.COLOR_PARRY

# When the sweep meets the circle the second time, in the other's half.
func second_beat() -> float:
	return beat + 2.0 * ring.radius() / speed

# The side of the circle it meets next.
func meeting_side() -> float:
	if kind == BeatRing.Kind.RELAY:
		return meet
	if kind == BeatRing.Kind.SWEEP and lane != first:
		return -side
	return side

# The way it flies just now.
func heading() -> Vector2:
	match kind:
		BeatRing.Kind.RELAY:
			var u = travelled(ring._time)
			return (ring.arc_point(side, u + 0.01) - ring.arc_point(side, u)).normalized()
		BeatRing.Kind.SWEEP:
			var a = ring.chest_angle()
			var down = Vector2(-side * cos(a), sin(a))
			return down if lane == first else Vector2(down.x, -down.y)
	return Vector2(-side, 0.0)

func _draw():
	var c = color()
	var to_go = (second_beat() if kind == BeatRing.Kind.SWEEP and lane != first else beat) - ring._time
	if not done and to_go > 0.0 and to_go < BeatRing.MARK_TIME and kind != BeatRing.Kind.RELAY:
		var spot = Vector2(BeatRing.CENTER.x + meeting_side() * ring.meet_x(), BeatRing.FLOOR_Y - BeatRing.CHEST)
		draw_arc(spot - position, BeatRing.SIZE + 6.0 + 10.0 * to_go, 0.0, TAU, 24, Color(c, 0.7 * (1.0 - to_go)), 2.0, true)
	var ahead = heading()
	var across = Vector2(-ahead.y, ahead.x)
	var r = BeatRing.SIZE * (BeatRing.HEAVY_SIZE if heavy else 1.0)
	match kind:
		BeatRing.Kind.SHARD, BeatRing.Kind.RELAY:
			if kind == BeatRing.Kind.RELAY and not done:
				_draw_trail(c)
			r *= 1.2
			# A diamond with its cut across the middle; hit, it falls apart along it.
			var gap = across * 6.0 if split else Vector2.ZERO
			draw_colored_polygon(PackedVector2Array([ahead * r + gap, across * r + gap, -ahead * r + gap]), c)
			draw_colored_polygon(PackedVector2Array([ahead * r - gap, -across * r - gap, -ahead * r - gap]), c)
			if not split:
				draw_line(-ahead * (r + 3.0), ahead * (r + 3.0), Color(1, 1, 1, 0.8), 2.0, true)
		BeatRing.Kind.SWEEP, BeatRing.Kind.CHARGE:
			draw_line(-ahead * BeatRing.ARROW_LENGTH, -ahead * r, c, 4.0, true)
			draw_colored_polygon(PackedVector2Array([ahead * r, -ahead * r + across * r, -ahead * r * 0.5,
				-ahead * r - across * r]), c)
		_:
			# An arrowhead, pointing the way it flies.
			draw_colored_polygon(PackedVector2Array([ahead * r * 1.2, -ahead * r + across * r, -ahead * r * 0.3,
				-ahead * r - across * r]), c)

# A violet shard's trail along the circle behind it, back to where it was RELAY_TRAIL ago (long
# while it's fast, short as it slows down), in this half only.
func _draw_trail(c: Color):
	var u = travelled(ring._time)
	var a = ring.chest_angle()
	var start = 0.0 if lane == first else PI - a  # where this half's part of its way begins
	var from = maxf(travelled(ring._time - BeatRing.RELAY_TRAIL), start)
	if u - from < 0.02:
		return
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	for i in 13:
		var at = lerpf(from, u, i / 12.0)
		points.append(ring.arc_point(side, at) - position)
		colors.append(Color(c, 0.6 * i / 12.0))
	draw_polyline_colors(points, colors, 4.0, true)
