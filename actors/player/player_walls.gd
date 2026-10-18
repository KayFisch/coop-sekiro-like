class_name PlayerWalls
extends PlayerSword
## A player, part 3 of 5: walls and ledges. Sliding and clinging, the wall jump and its rhythm on
## the room's clock, ledges, and the chimney clash, where each of two players is the other's wall.
## Part 2, the sword: player_sword.gd. Part 4, moves with the partner: player_partner.gd.

# WALLS (Moves "wall": off / slide / cling). In the air, press into a wall (or fly into it fast)
# to stick to it, facing away from it; rising, you carry on up along it first. Sliding, you then
# slip down at WALL_SLIDE_SPEED; clinging, you hang still for WALL_CLING_TIME, then slide. Press
# away, or land, to let go. Wall jump: jump off a wall you're on or touching, up and away; for
# WALL_JUMP_LOCK you can't steer back, so it carries you clear of the wall. A wall you jumped off
# is spent until you land, catch a ledge or reach another wall: you can't stick to it, jump off
# it or get refreshed by it again, so one wall alone can't be climbed (two facing ones can).
# A wall you're merely next to only counts if you're moving into it: pressing toward it, or
# still flying from the last wall jump (for WALL_FLIGHT_TIME). In that flight, holding back
# toward the wall you left, or holding nothing, doesn't steer, so between two walls you can keep
# one direction held (or none) and just time the jumps. The flight is short: it carries you
# across a narrow gap (half a beat) on its own; a wider one needs the stick held toward it
# (SPEED is the push, so holding keeps the flight's timing). Once it ends you steer freely.
# Walls and ledges refresh the dash (Moves "wall_refresh"), never the air jump.
# Partners aren't walls.
const WALL_PROBE = 4.0  # px: how close a wall has to be to stick to or jump off
const WALL_ATTACH_SPEED = 150.0  # flying into a wall this fast sticks without pressing into it
const WALL_SLIDE_SPEED = 140.0
const WALL_CLING_TIME = 1.2
const WALL_COYOTE_TIME = 0.1  # a wall jump this soon after letting go of the wall still works
const WALL_SPENT_RANGE = 24.0  # px: a wall on the spent side this close to where you jumped is the same wall
const WALL_JUMP_HEIGHT = 145.0  # its top ~0.4 s up, so a beat's flight lands near it; never cut short by letting go of jump
const WALL_JUMP_PUSH = 360.0  # px/s away from the wall
const WALL_JUMP_LOCK = 0.15
# Riding up a wall past its top hops you over onto it (no dead zone where the wall's too short to
# jump off but you're too low to land on it).
const WALL_TOP_HOP_SPEED = 300.0  # px/s over the edge...
const WALL_TOP_HOP_RISE = 200.0  # ...rising at least this fast (~11 px up)...
const WALL_TOP_HOP_TIME = 0.12  # ...unsteerable this long: ~35 px onto the top
const WALL_FLIGHT_TIME = 0.3  # how long a wall jump flies on its own (~110 px: a narrow shaft's half beat and some, not a wide one's beat)
# WALL RHYTHM (Moves "wall_rhythm"): a wall jump is timed to the moment you hit the wall. Pressed
# within WALL_RHYTHM_TOLERANCE of it (an early press waits for the wall, see JUMP_BUFFER_TIME),
# it's a full one; earlier or later, weak (WALL_WEAK_HEIGHT), so mashing or hanging on sinks you.
# So the rhythm is the walls': a shaft as wide as a beat's flight is climbed on every beat, one
# half as wide twice as fast. The first wall jump of a climb is always a full one. While the
# level's clock runs (Beat), a full jump flies to the next wall a little faster or slower
# (_resync()), so it arrives on one of the clock's beats or half-beats, whatever was off (a late
# press, a slow flight): nothing adds up and drifts off the room's beat (and its music). A ring
# around you closes on the next moment to jump (reaching the wall, meeting the partner for a
# chimney clash) and flashes white for its window.
const WALL_RESYNC_MAX = 0.1  # s a flight is pulled at most toward arriving on the clock's half-beats (see _steer_tempo())
const WALL_TEMPO_RANGE = 0.2  # the flight to the next wall goes at most 20% faster or slower to land on the beat
const WALL_TEMPO_REACH = 1000.0  # px: a wall further than this isn't flown to on the beat
const WALL_TEMPO_LONGEST = 1.0  # s a flight is steered on the beat at most (it's at a wall long before)
const WALL_RHYTHM_TOLERANCE = 0.065  # s before or after hitting the wall that still counts
const WALL_WEAK_HEIGHT = 0.0  # a mistimed wall jump goes this fraction as high: none, just the push off the wall
const WALL_RING_RADIUS = 26.0  # the ring closes to this, just around the body...
const WALL_RING_SHRINK = 220.0  # ...shrinking this many px/s toward it
# LEDGE GRAB: in the air, pressing into a wall whose top edge is between a little above your
# head and your middle, with room to stand up there: you catch the edge and hang. Up climbs at
# once, and so does holding toward the wall once you've hung for LEDGE_MIN_HANG; jump jumps
# from the hang; down or away lets go.
const LEDGE_REACH_UP = 50.0  # the edge may be this far above your middle (head top + 30)...
const LEDGE_REACH_DOWN = 6.0  # ...down to this far below it
const LEDGE_MAX_RISE = 250.0  # rising faster than this, you fly past edges instead of catching them
const LEDGE_HANG_DROP = 14.0  # hanging, your middle is this far below the edge
const LEDGE_MIN_HANG = 0.1
const LEDGE_CLIMB_TIME = 0.18
const LEDGE_REGRAB_TIME = 0.3  # after letting go or jumping off
# CHIMNEY CLASH (Moves "chimney_clash"): two players who both just wall-jumped, flying at each
# other, clash in mid-air: each is the other's wall. Both wall-jump off each other, back toward
# the walls they came from, exactly like a wall jump (same push, same height, no hold), so a
# chimney twice as wide as one climbed alone is climbed in the same rhythm, the partner standing
# in for the far wall. They meet when they touch (players collide; if not, when they'd touch).
# Meeting isn't enough: both press jump, each within CHIMNEY_PRESS_TOLERANCE of the meeting (a
# press there never air-jumps); without both presses they fly on and fall. With Moves
# "wall_rhythm" on, each one's press is judged against the meeting like a wall jump's against
# hitting the wall: within WALL_RHYTHM_TOLERANCE a full jump, else a weak one.
const CHIMNEY_WINDOW = 0.7  # s since each one's wall jump: past the meeting and its press window
const CHIMNEY_PRESS_TOLERANCE = 0.08  # s before or after meeting that a jump press still clashes (weak past WALL_RHYTHM_TOLERANCE)
const CHIMNEY_REACH = Vector2(60.0, 60.0)  # once met, staying this close still lets a late press clash

var _wall_side = 0.0  # -1 / 1 while stuck to a wall on that side, else 0
var _last_wall_side = 0.0
var _wall_time = 0.0  # time stuck, not counting rising along it
var _wall_coyote = 0.0
var _spent_wall_side = 0.0  # the wall last jumped off (see WALL_SPENT_RANGE), 0 once cleared
var _spent_wall_x = 0.0
var _wall_jump_time = -100.0
var _wall_chain = false  # wall-jumped since last on the floor (see WALL RHYTHM)
var wall_beat_time = -100.0  # the last wall jump, for WALL RHYTHM (a clash resets _wall_jump_time)
var _wall_contact_time = -100.0  # when you last hit a wall (see WALL RHYTHM), stuck to it or not
var _wall_contact_side = 0.0  # that wall's side
var _wall_touch_side = 0.0  # the wall you're touching (and moving into) this frame, 0 if none
var wall_jump_moment = -100.0  # when the last wall jump should have been pressed: hitting the wall, or the beat
var wall_jump_off = 0.0  # s the last wall jump's press was off its moment (< 0 early)
var wall_jump_strong = true  # the last wall jump was on time (a full one)
var _chimney_meet_time = -100.0  # when this wall flight met the partner's (see CHIMNEY CLASH)
var _beat_ring: Node2D  # the ring closing on the next moment to jump (see _update_beat_ring())
var wall_rhythm_sound = true  # this player's wall jumps sound and show the ring (see WALL RHYTHM); a bot's may not
var _wall_jump_dir = 0.0  # which way the last wall jump flew
var _wall_jump_lock = 0.0
var _wall_flight = 0.0  # > 0 while flying from a wall jump (see WALL_FLIGHT_TIME)
var _wall_held_away = 0.0  # a key held away from the wall since arriving on it (doesn't let go)
var _tempo = 1.0  # times the usual sideways speed, flying to the next wall on the beat (see _resync())
var _tempo_until = -100.0  # flying on the beat (see _resync()) until then at the latest; < 0 if not
var chimney_clash_time = -100.0  # the last chimney clash
var _ledge = false  # hanging from (or climbing over) a ledge
var _ledge_side = 0.0
var _ledge_hang = Vector2.ZERO
var _ledge_stand = Vector2.ZERO  # where the climb ends
var _ledge_time = 0.0
var _ledge_climb = -1.0  # time into the climb; < 0 while hanging
var _ledge_regrab = 0.0


func _ready():
	super()
	_beat_ring = Node2D.new()
	_beat_ring.z_index = 5
	_beat_ring.visible = false
	_beat_ring.draw.connect(_draw_beat_ring)
	add_child(_beat_ring)


# --- Walls: slide / cling, wall jump ------------------------------------------

# Sticks to, stays on, or lets go of a wall. True while on one (it has moved the player).
func _update_wall(direction: float, delta: float) -> bool:
	var mode = Moves.value("wall")
	if _wall_side != 0.0:
		if signf(direction) != _wall_held_away:
			_wall_held_away = 0.0  # let go of (or changed) the key held on arrival
		var pressing_away = direction != 0.0 and signf(direction) == -_wall_side and _wall_held_away == 0.0
		if mode == "off" or pressing_away or not _touching_wall(_wall_side):
			var hop = mode != "off" and not pressing_away and velocity.y < 0.0
			if hop:
				_hop_over_wall_top()
			_leave_wall()
			if hop:
				_wall_coyote = 0.0  # going over: a late press doesn't pull you back off it
	elif mode != "off":
		var in_flight = _wall_flight > 0.0
		for side in _sides_moving_into(direction):
			if not _wall_spent(side) and _touching_wall(side):
				_attach_wall(side)
				# Carried here by a wall jump while still holding the other way: that key doesn't
				# pull you off until it's let go, so chained wall jumps need no key switching.
				_wall_held_away = signf(direction) if in_flight and signf(direction) == -side else 0.0
				break
	if _wall_side == 0.0:
		return false
	facing = -_wall_side
	velocity.x = 0.0
	if velocity.y < 0.0:
		_apply_gravity(delta)  # still rising along it
	elif mode == "cling" and _wall_time < WALL_CLING_TIME:
		velocity.y = 0.0
		_wall_time += delta
	else:
		velocity.y = WALL_SLIDE_SPEED
		_wall_time += delta
	return true


# The sides you're moving into: the one pressed, the one you're flying toward fast, and the
# one a wall jump is carrying you to.
func _sides_moving_into(direction: float) -> Array:
	var sides = []
	if direction != 0.0:
		sides.append(signf(direction))
	if absf(velocity.x) >= WALL_ATTACH_SPEED:
		sides.append(signf(velocity.x))
	if _wall_flight > 0.0:
		sides.append(_wall_jump_dir)
	return sides


# Notes the moment you hit a wall (one you're moving into, not the one you jumped off), whether
# you stick to it or not: the moment a wall jump off it is timed to (see WALL RHYTHM).
func _track_wall_contact(direction: float):
	var sides = _sides_moving_into(direction)
	if _wall_side != 0.0:
		sides.push_front(_wall_side)
	var touching = 0.0
	for side in sides:
		if not _wall_spent(side) and _touching_wall(side):
			touching = side
			break
	if touching != 0.0 and touching != _wall_touch_side:
		_wall_contact_time = _now()
		_wall_contact_side = touching
		_end_tempo()  # arrived
	_wall_touch_side = touching


# A wall right beside you on `side`. Only the world counts: a partner isn't a wall.
func _touching_wall(side: float) -> bool:
	return _wall_distance(side, WALL_PROBE) < INF


# px to the world on `side`, looking at most `reach` far; INF if nothing's there.
func _wall_distance(side: float, reach: float) -> float:
	var params = PhysicsTestMotionParameters2D.new()
	params.from = global_transform
	params.motion = Vector2(side * reach, 0.0)
	var other = partner()
	if other:
		var skip: Array[RID] = [other.get_rid()]
		params.exclude_bodies = skip
	var result = PhysicsTestMotionResult2D.new()
	if not PhysicsServer2D.body_test_motion(get_rid(), params, result):
		return INF
	return result.get_travel().length()


# The wall on `side` is the one last jumped off (see WALL_SPENT_RANGE).
func _wall_spent(side: float) -> bool:
	return side == _spent_wall_side and absf(global_position.x - _spent_wall_x) <= WALL_SPENT_RANGE


func _attach_wall(side: float):
	_wall_side = side
	_wall_time = 0.0
	_wall_flight = 0.0
	_spent_wall_side = 0.0  # a new wall: the old one is fresh again
	_end_dash()
	_end_carry()
	if Moves.on("wall_refresh"):
		refresh_dash()


# Rode up the wall past its top: hop over onto it, rather than hang beside its edge with no
# wall left to jump off and no way onto it.
func _hop_over_wall_top():
	velocity.x = _wall_side * WALL_TOP_HOP_SPEED
	velocity.y = minf(velocity.y, -WALL_TOP_HOP_RISE)
	_wall_jump_lock = maxf(_wall_jump_lock, WALL_TOP_HOP_TIME)


func _leave_wall():
	if _wall_side != 0.0:
		_last_wall_side = _wall_side
		_wall_coyote = WALL_COYOTE_TIME
	_wall_side = 0.0


# The wall a jump now would push off: the one you're on, one you just let go of, or one you're
# touching and moving into. 0 if none.
func _wall_jump_side() -> float:
	if _wall_side != 0.0:
		return _wall_side
	if _wall_coyote > 0.0:
		return _last_wall_side
	for side in _sides_moving_into(move_axis()):
		if not _wall_spent(side) and _touching_wall(side):
			return side
	# Bounced off a wall you didn't stick to: a press late within the window still jumps off it.
	if _wall_chain and _since(_wall_contact_time) <= WALL_RHYTHM_TOLERANCE \
			and not _wall_spent(_wall_contact_side):
		return _wall_contact_side
	return 0.0


func _wall_jump(side: float):
	var now = _now()
	# Timed to hitting this wall; the first of a climb is always a full one.
	var timed = _wall_chain
	var moment = now
	if timed and _wall_contact_side == side and _wall_contact_time > maxf(_wall_jump_time, chimney_clash_time):
		moment = _wall_contact_time
	_wall_chain = true
	wall_beat_time = now
	_chimney_meet_time = -100.0
	_wall_side = 0.0
	_wall_coyote = 0.0
	_spent_wall_side = side
	_spent_wall_x = global_position.x
	_wall_jump_time = now
	_wall_held_away = 0.0
	_end_carry()
	_end_dash()
	_fly_off(-side, moment, timed)


# The flight off a wall, or off the partner in a chimney clash: up and the way `dir`. With WALL
# RHYTHM it's judged by how far the jump press was off `moment` (when it should have come): a full
# jump within WALL_RHYTHM_TOLERANCE, else a weak one. Not `timed` (a climb's first), always full.
func _fly_off(dir: float, moment: float, timed = true):
	wall_jump_moment = moment
	wall_jump_off = _jump_press_time - moment if timed else 0.0
	wall_jump_strong = not Moves.on("wall_rhythm") or absf(wall_jump_off) <= WALL_RHYTHM_TOLERANCE
	if Moves.on("wall_rhythm") and wall_rhythm_sound:
		Sfx.play("relay_peak" if wall_jump_strong else "chip", -4.0)
	var rise = rise_speed(WALL_JUMP_HEIGHT * (1.0 if wall_jump_strong else WALL_WEAK_HEIGHT))
	velocity = Vector2(dir * WALL_JUMP_PUSH, -rise)
	_uncut_timer = rise / GRAVITY  # a tap goes as high as a hold: the timing decides, not the hold
	facing = dir
	_wall_jump_lock = WALL_JUMP_LOCK
	_wall_jump_dir = dir
	_wall_flight = WALL_FLIGHT_TIME
	_jump_buffer = 0.0  # the press is spent: it doesn't wall-jump again on arrival
	if Moves.on("wall_rhythm") and wall_jump_strong:
		_resync()


# A full wall jump (or chimney clash) just launched: its flight to the next moment to jump
# (hitting a wall, meeting the partner) goes on the clock's beat (_steer_tempo()), so neither
# late presses nor a slow flight (steering) add up and drift off it.
func _resync():
	_tempo_until = _now() + WALL_TEMPO_LONGEST
	_steer_tempo(move_axis())


# Flying to the next moment to jump on the beat (see _resync()): when it would get there at the
# usual speed, rounded to the clock's nearest half-beat (by at most WALL_RESYNC_MAX), is when it's
# to get there; this sets the speed that does, within WALL_TEMPO_RANGE of the usual. Flying on
# its own, the flight's; steered toward it, how fast holding the stick goes (any tilt toward it
# flies at least half speed's worth of it). Held away or not at all, it doesn't steer for you.
func _steer_tempo(direction: float):
	if _tempo_until < 0.0:
		return
	var distance = _tempo_distance()
	if _now() > _tempo_until or distance == INF or not Beat.running:
		_end_tempo()
		return
	var usual = distance / WALL_JUMP_PUSH
	if usual <= get_physics_process_delta_time():
		return  # there (or nearly): keep the speed it has
	var halves = Beat.beats_at(Beat.time() + usual + _seen_late()) * 2.0  # arriving at the usual speed
	var left = usual + clampf((roundf(halves) - halves) * Beat.beat_length() / 2.0, -WALL_RESYNC_MAX, WALL_RESYNC_MAX)
	var k = clampf(usual / maxf(left, 0.001), 1.0 - WALL_TEMPO_RANGE, 1.0 + WALL_TEMPO_RANGE)
	var on_its_own = _wall_jump_lock > 0.0 \
		or (_wall_flight > 0.0 and (direction == 0.0 or signf(direction) == -_wall_jump_dir))
	if on_its_own and velocity.x * _wall_jump_dir > 0.0:
		velocity.x = _wall_jump_dir * WALL_JUMP_PUSH * k
	_tempo = 1.0
	if direction * _wall_jump_dir > 0.0:
		_tempo = k * WALL_JUMP_PUSH / (maxf(absf(direction), 0.5) * SPEED)


func _tempo_distance() -> float:
	var gap = _wall_distance(_wall_jump_dir, WALL_TEMPO_REACH)
	if gap == INF:
		return INF
	var other = partner()
	if other and not other.is_on_floor():
		var ahead = (other.global_position.x - global_position.x) * _wall_jump_dir
		if ahead > 0.0 and ahead < gap:
			return maxf(ahead - body.size.x - WALL_PROBE, 0.0) / 2.0  # met once in reach (see _check_chimney())
	return gap


# s after reaching a wall that it's seen: up to a frame.
func _seen_late() -> float:
	return get_physics_process_delta_time() / 2.0


# Back to the usual speed (see _resync()).
func _end_tempo():
	_tempo = 1.0
	_tempo_until = -100.0


# s until the next moment to jump (see WALL RHYTHM), and s since the last one; -1 if none.
func _jump_cues() -> Vector2:
	var left = INF
	var since = INF
	if is_held() or is_on_floor():
		return Vector2(-1.0, -1.0)
	if _wall_chain:
		since = _since(_wall_contact_time)
		if _wall_side == 0.0 and absf(velocity.x) > 1.0:  # flying (or steering) at a wall
			var side = signf(velocity.x)
			left = _wall_distance(side, absf(velocity.x) * Beat.beat_length()) / absf(velocity.x)
		since = minf(since, _since(_chimney_meet_time))
		var other = _chimney_partner()
		if other and _chimney_meet_time < 0.0:
			var gap = other.global_position.x - global_position.x
			var closing = velocity.x * signf(gap) - other.velocity.x * signf(gap)
			if closing > 1.0:
				left = minf(left, maxf(absf(gap) - body.size.x, 0.0) / closing)
	return Vector2(left if left < INF else -1.0, since if since < INF else -1.0)


# The partner, if both of you are flying from a wall jump (a chimney clash in the making).
func _chimney_partner():
	var other = partner()
	if Moves.on("chimney_clash") and _in_wall_flight() and other and other._in_wall_flight():
		return other
	return null


func _update_beat_ring():
	_beat_ring.visible = Moves.on("wall_rhythm") and wall_rhythm_sound
	if _beat_ring.visible:
		_beat_ring.queue_redraw()


# Closes on the next moment to jump, and flashes white for its window.
func _draw_beat_ring():
	var cues = _jump_cues()
	var closed = cues.y >= 0.0 and cues.y <= WALL_RHYTHM_TOLERANCE
	if not closed and cues.x < 0.0:
		return
	var radius = WALL_RING_RADIUS if closed else WALL_RING_RADIUS + cues.x * WALL_RING_SHRINK
	var color = Color.WHITE if closed else body_color.lightened(0.4)
	var alpha = 1.0 if closed else clampf(1.0 - cues.x / Beat.beat_length(), 0.15, 0.8)
	_beat_ring.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, alpha), 4.0 if closed else 2.0, true)


# --- Ledges: grab, hang, climb -------------------------------------------------

# Catches a ledge if one is in reach on the side pressed into (or the wall you're on).
func _try_ledge_grab(direction: float) -> bool:
	if not Moves.on("ledge_grab") or _ledge_regrab > 0.0 or velocity.y < -LEDGE_MAX_RISE:
		return false
	var side = _wall_side if _wall_side != 0.0 else signf(direction)
	if side == 0.0:
		return false
	var edge = _find_ledge(side)
	if edge.is_empty():
		return false
	_ledge = true
	_ledge_side = side
	_ledge_hang = Vector2(edge.face_x - side * body.size.x / 2.0, edge.top + LEDGE_HANG_DROP)
	_ledge_stand = edge.stand
	_ledge_time = 0.0
	_ledge_climb = -1.0
	_wall_side = 0.0
	_wall_flight = 0.0
	_spent_wall_side = 0.0
	_end_dash()
	_end_carry()
	velocity = Vector2.ZERO
	global_position = _ledge_hang
	facing = side
	if Moves.on("wall_refresh"):
		refresh_dash()
	return true


# A wall on `side` that ends within reach, with room to stand on top: {face_x, top, stand}.
func _find_ledge(side: float) -> Dictionary:
	var space = get_world_2d().direct_space_state
	var half = body.size.x / 2.0
	var at = global_position
	var reach = side * (half + WALL_PROBE + 2.0)
	if not _ray(space, at + Vector2(0.0, -LEDGE_REACH_UP), at + Vector2(reach, -LEDGE_REACH_UP)).is_empty():
		return {}  # the wall goes on above: no edge in reach
	var low = _ray(space, at + Vector2(0.0, LEDGE_REACH_DOWN), at + Vector2(reach, LEDGE_REACH_DOWN))
	if low.is_empty():
		return {}  # no wall here at all
	var face_x = low.position.x
	var inside = face_x + side * 3.0
	var down = _ray(space, Vector2(inside, at.y - LEDGE_REACH_UP), Vector2(inside, at.y + LEDGE_REACH_DOWN + 1.0))
	if down.is_empty():
		return {}
	var stand = Vector2(face_x + side * (half + 4.0), down.position.y - body.size.y / 2.0 - 1.0)
	if not _room_for_body(space, stand):
		return {}
	return {"face_x": face_x, "top": down.position.y, "stand": stand}


func _ray(space, from: Vector2, to: Vector2) -> Dictionary:
	var query = PhysicsRayQueryParameters2D.create(from, to, 1 << (WORLD_LAYER - 1))
	return space.intersect_ray(query)


func _room_for_body(space, center: Vector2) -> bool:
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = RectangleShape2D.new()
	shape.size = body.size - Vector2(2.0, 2.0)
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 1 << (WORLD_LAYER - 1)
	return space.intersect_shape(query, 1).is_empty()


func _process_ledge(delta):
	velocity = Vector2.ZERO
	if _ledge_climb >= 0.0:
		# Up first, then over the edge.
		_ledge_climb += delta
		var t = clampf(_ledge_climb / LEDGE_CLIMB_TIME, 0.0, 1.0)
		var up = Vector2(_ledge_hang.x, _ledge_stand.y)
		global_position = _ledge_hang.lerp(up, minf(t * 2.0, 1.0)) if t < 0.5 else up.lerp(_ledge_stand, t * 2.0 - 1.0)
		if t >= 1.0:
			_ledge = false
		return
	global_position = _ledge_hang
	_ledge_time += delta
	var direction = move_axis()
	var toward = direction != 0.0 and signf(direction) == _ledge_side
	if signf(direction) != _wall_held_away:
		_wall_held_away = 0.0
	var away = direction != 0.0 and signf(direction) == -_ledge_side and _wall_held_away == 0.0
	if _pressed("jump"):
		_ledge = false
		_ledge_regrab = LEDGE_REGRAB_TIME
		velocity.y = -rise_speed(JUMP_HEIGHT)
	elif _held("up") or (toward and _ledge_time >= LEDGE_MIN_HANG):
		_ledge_climb = 0.0
	elif away or _pressed("down"):
		_ledge = false
		_ledge_regrab = LEDGE_REGRAB_TIME


# --- The chimney clash (see CHIMNEY CLASH) -------------------------------------

# Checked every frame after moving: two wall jumps meeting in the air. Each pair is checked once,
# by the lower id. Flying at each other, or already bumped together (the bump stops them) after
# jumping off opposite walls. Once met, the press window holds even if they've flown apart again.
func _check_chimney():
	var other = partner()
	if other == null or other.is_held():
		return
	var gap = other.global_position - global_position
	var met_now = _chimney_meet_time >= 0.0 and _since(_chimney_meet_time) <= CHIMNEY_PRESS_TOLERANCE
	if Moves.on("chimney_clash") and player_id < other.player_id and _in_wall_flight() \
			and other._in_wall_flight() and (absf(gap.x) <= CHIMNEY_REACH.x or met_now) \
			and absf(gap.y) <= CHIMNEY_REACH.y:
		var touching = absf(gap.x) <= body.size.x + WALL_PROBE
		var closing = gap.x * velocity.x > 0.0 and gap.x * other.velocity.x < 0.0
		var bumped = _wall_jump_dir * gap.x > 0.0 and other._wall_jump_dir * gap.x < 0.0
		if (touching and (closing or bumped)) or _chimney_meet_time >= 0.0:  # once met, in reach is enough
			if _chimney_meet_time < 0.0:
				_chimney_meet_time = _now()
				other._chimney_meet_time = _chimney_meet_time
			# Both pressed jump around the meeting (see CHIMNEY CLASH); too late, they fly on.
			if _pressed_near(_chimney_meet_time) and other._pressed_near(_chimney_meet_time):
				_chimney_clash(other)


func _pressed_near(t: float) -> bool:
	return absf(_jump_press_time - t) <= CHIMNEY_PRESS_TOLERANCE


func _in_wall_flight() -> bool:
	return not is_on_floor() and not is_held() and _since(_wall_jump_time) <= CHIMNEY_WINDOW


# Both wall-jump off each other, back toward the walls they came from (see CHIMNEY CLASH).
func _chimney_clash(other):
	var middle = (global_position.x + other.global_position.x) / 2.0
	for p in [self, other]:
		p.chimney_clash_time = _now()
		p._wall_jump_time = -100.0  # one clash per wall jump
		p._spent_wall_side = 0.0  # back at the wall they came from: it's climbable again
		p._sword_flash = SWORD_FLASH_TIME
		# Timed to the meeting, as a wall jump is to hitting the wall (see WALL RHYTHM).
		p._fly_off(signf(p.global_position.x - middle), _chimney_meet_time)
	_clash_fx(other, 14)


# Held in place by a clash with the partner (a relay's, see player_partner.gd).
func is_held() -> bool:
	return false


# --- What walls add to the body -----------------------------------------------------

func _before_move(direction: float):
	super(direction)
	if is_on_floor():
		_wall_side = 0.0
		_spent_wall_side = 0.0
		_wall_flight = 0.0
		_wall_chain = false  # the climb is over
		_wall_touch_side = 0.0
		_end_tempo()
	else:
		_track_wall_contact(direction)
		_steer_tempo(direction)


# Flying off a wall, holding back toward it or nothing keeps the flight (see WALLS).
func _coasting(direction: float) -> bool:
	return _wall_flight > 0.0 and (direction == 0.0 or signf(direction) == -_wall_jump_dir)


func _face(direction: float):
	super(direction)
	if _coasting(direction):
		facing = _wall_jump_dir  # holding toward the wall you left doesn't turn you around


func _cling(direction: float, delta: float) -> bool:
	return _try_ledge_grab(direction) or _update_wall(direction, delta)


func _keeps_course(direction: float) -> bool:
	return super(direction) or _wall_jump_lock > 0.0 or _coasting(direction)


func _speed_scale() -> float:
	return super() * _tempo


func _try_wall_jump() -> bool:
	var side = _wall_jump_side() if Moves.on("wall_jump") else 0.0
	if side == 0.0:
		return false
	_wall_jump(side)
	return true


# Flying at the partner, a jump press is the chimney clash's, not an air jump.
func _may_air_jump() -> bool:
	return super() and not _chimney_partner()


# A dash lets go of the wall.
func _start_dash(direction: float) -> bool:
	if not super(direction):
		return false
	_leave_wall()
	_wall_flight = 0.0
	return true


func _tick_timers(delta):
	super(delta)
	_wall_coyote = maxf(_wall_coyote - delta, 0.0)
	_wall_jump_lock = maxf(_wall_jump_lock - delta, 0.0)
	_wall_flight = maxf(_wall_flight - delta, 0.0)
	_ledge_regrab = maxf(_ledge_regrab - delta, 0.0)


func interrupt_movement():
	super()
	_wall_side = 0.0
	_wall_flight = 0.0
	_ledge = false
	_end_tempo()


func movement_state() -> String:
	if _ledge:
		return "climbing" if _ledge_climb >= 0.0 else "ledge"
	if _wall_side != 0.0:
		return "wall cling" if velocity.y == 0.0 else "wall slide"
	return super()
