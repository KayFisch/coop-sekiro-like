class_name AcrobatBody
extends BaseBoss
## The Acrobat, part 1 of 2 (docs/boss_acrobat.md): his body and how it moves, his two hands with
## their rings, his foot blades, and the windows his parried strikes open. Part 2, the boss himself
## (his rule, the chains, the finales, his breath, the rules' hooks): acrobat.gd.
##
## ONE BODY (the mirror rule, stage 0: docs/concept.md): he is one body in one world and is drawn
## the same in both halves of the mirrored screen. Only whom a thing is for differs: a ring is in the
## color of the player it's aimed at (as the blades with Moves "mirror_blades" on "color"), so on the
## ground of that player's half it stands out.
## HIS HANDS: two, one for each player (a hand is its player's id), each on the side of its player.
## Each holds a pair of rings held as one: in close combat one blade (one parry per blade). A throw
## takes one ring of the pair (pair_count()); the hand strikes on with the other and catches the
## thrown one back. Only the rally throws all four.
## HOW HE MOVES (move_to()): he never walks. A dash along the floor, a jump or a salto through the
## air (turning over on the way), clinging to a wall at a height a jump reaches, or gliding under
## the floor in the mirror line, faint in both halves (Place). Off the floor his body blocks nobody
## (body_block()).
## THE PARTNER'S HIT: as the Heavy Hitter's (hitter_weapon.gd): a parry of his that counts opens the
## partner's window for a sync hit (open_window()), the parry's energy running over to them.

enum Place { FLOOR, AIR, WALL, LINE }

const SIZE = Vector2(28.0, 56.0)  # his body (the scene's): about a player's (20 x 40), a little more

# --- His hands, for a hand on the side of its player: x toward that side, y down, px from his center ---
const HAND_REST = Vector2(16.0, -2.0)  # at his side, a pair of rings held up
const HAND_RAISED = Vector2(-6.0, -34.0)  # a strike drawn back, up over his shoulder...
const HAND_STRIKE = Vector2(40.0, 6.0)  # ...and cut down, out in front
const HAND_RECOIL = Vector2(12.0, -30.0)  # thrown back up by a parry
const HAND_THROW_BACK = Vector2(-18.0, -24.0)  # a ring drawn back over his shoulder to throw...
const HAND_THROWN = Vector2(30.0, -16.0)  # ...and let go
const HAND_CATCH = Vector2(8.0, -42.0)  # reaching up for a ring coming back
const HAND_CROSSED = Vector2(-6.0, 2.0)  # the plunge's tell: both hands crossed in front of him
const HAND_OUT = Vector2(30.0, -6.0)  # held out in front (the dive's tell, Moves "acrobat_dive_tell" blade)
const HAND_EASE = 30.0  # how fast a hand eases into its pose (1/s); a strike's drop is exact
const BACK_HAND = Vector2(-5.0, 5.0)  # both hands on one side: the farther one's, a little behind
const HAND_SIZE = 8.0
const HAND_DARKEN = 0.25
# --- His rings ---
const RING_RADIUS = 11.0  # a ring, seen face on
const RING_WIDTH = 3.0
const PAIR_APART = 3.0  # px between the two rings of a pair: it reads as one thick ring
const COLOR_RING = Color(0.8, 0.82, 0.86)  # silver
const COLOR_RING_LIMP = Color(0.45, 0.45, 0.5)
const AIM_TINT = 0.85  # how far a ring takes the color of the player it's aimed at
const TELL_WIDTH = 2.0  # the telegraph's color, round a ring's edge
# --- His feet: a small blade on each, for the kick in a salto ---
const FOOT_BLADE = [Vector2(-3.0, 0.0), Vector2(9.0, 4.0), Vector2(-3.0, 6.0)]  # from a foot, toward his front
# --- Moving ---
const DASH_TIME = 0.15  # a dash along the floor
const WALL_FEET = 70.0  # px over the floor his feet hang on a wall: a jump attack reaches him
const WALL_GAP = 2.0  # px between his body and the wall
const WALL_LEAN = 0.18  # radians he leans off a wall
const LINE_LOOK = Vector2(1.6, 0.14)  # his body in the mirror line: flat along it...
const LINE_ALPHA = 0.3  # ...and faint, in both halves
# --- The mirror line: the ripple where he'll come up, the cut he dives into ---
const RIPPLE_WIDTH = 34.0
const CUT_WIDTH = 40.0
const COLOR_RIPPLE = Color(0.8, 0.82, 0.86, 0.8)
const COLOR_PARRY = Color(1.0, 0.85, 0.4)  # sparks off a player's parry
const WINDOW_REACH = 220.0  # a window left unused costs sync if its player was this near him

# Sync as life (core/sync_rules.gd): the fight's rules, set once he's ready (acrobat.gd).
var rules: SyncRules = null
var place = Place.FLOOR

var _move = {}  # the motion under way (move_to()): {from, to, start, time, height, turns, land}; {}: none
var _hand_at = {1: HAND_REST, 2: HAND_REST}  # hand -> where it's drawn just now
var _hand_goal = {1: HAND_REST, 2: HAND_REST}  # ...where it's headed (pose_hand())...
var _hand_snap = {1: false, 2: false}  # ...there this frame: a drop has to land on time
var _hand_tint = {1: COLOR_RING, 2: COLOR_RING}  # hand -> its telegraph's color (silver: none)
var _hand_spin = {1: 0.0, 2: 0.0}  # hand -> radians its rings are turned round their own axis (the feint)
var _pairs = {1: 2, 2: 2}  # hand -> the rings it holds
var _foot_tint = COLOR_RING  # the foot blades' telegraph
var _ripple = Vector2(0.0, 0.0)  # x on the line, share 0..1 (0: none)
var _cut = Vector2(0.0, 0.0)  # x on the line, share 0..1 (0: none)
var _look: Node2D  # draws his hands, rings, feet and what he does to the line
# player -> the window for their sync hit, which their partner's parry opened: {from, until (anim_time),
# by (the parrier), used (a hit came in it), shown (its cue), judged (its closing seen)}.
var _windows = {}


# --- Players and sides ---

func side_of(player) -> int:
	return -1 if player.global_position.x < global_position.x else 1


# The player whose hand (layer) that is, or null.
func player_of(hand: int):
	for p in get_players():
		if p.player_id == hand:
			return p
	return null


# The players still in the fight, the nearer to him first.
func by_distance() -> Array:
	var players = get_players().filter(func(p): return not p.is_dead())
	players.sort_custom(func(a, b): return distance_to(a) < distance_to(b))
	return players


func nearer():
	var players = by_distance()
	return players[0] if not players.is_empty() else null


func farther():
	var players = by_distance()
	return players.back() if not players.is_empty() else null


# Both on one side of him (ppe).
func together() -> bool:
	var players = by_distance()
	return players.size() < 2 or side_of(players[0]) == side_of(players[1])


# The visibility layer things of that player's are drawn on: their half, or both if not split.
func half_of(hand: int) -> int:
	if not _split():
		return MirrorView.WORLD
	return MirrorView.LIGHT if hand == 1 else MirrorView.SHADOW


func _split() -> bool:
	var view = get_tree().get_first_node_in_group("mirror_view")
	return view != null and view.split()


# --- How he moves ---

# He goes to `goal` (his center) in `duration`: along the floor or the line if `height` is 0 (a
# dash: fast, then slowing), else through the air, up `height` over the straight way, turning over
# `turns` times on the way (a salto: 1; the other way round: negative). He's in the air meanwhile,
# and `land` once there.
func move_to(goal: Vector2, duration: float, height = 0.0, turns = 0.0, land = Place.FLOOR):
	_move = {"from": global_position, "to": goal, "start": anim_time, "time": maxf(duration, 0.01),
		"height": height, "turns": turns, "land": land}
	place = Place.AIR if height > 0.0 else land


func moving() -> bool:
	return not _move.is_empty()


# Seconds until the motion under way is over (0: none).
func move_left() -> float:
	if _move.is_empty():
		return 0.0
	return maxf(_move.start + _move.time - anim_time, 0.0)


# Where the motion under way ends (where he is, if none).
func move_goal() -> Vector2:
	return _move.to if not _move.is_empty() else global_position


func stop_moving():
	_move = {}
	body.rotation = 0.0


func _update_motion():
	if _move.is_empty():
		return
	var share = clampf((anim_time - _move.start) / _move.time, 0.0, 1.0)
	var along = share if _move.height > 0.0 else 1.0 - (1.0 - share) * (1.0 - share)
	var at: Vector2 = _move.from.lerp(_move.to, along)
	at.y -= _move.height * 4.0 * share * (1.0 - share)
	global_position = at
	body.rotation = TAU * _move.turns * share
	if share >= 1.0:
		place = _move.land
		_move = {}
		body.rotation = 0.0


# Standing on the floor, at x (his center).
func floor_point(x: float) -> Vector2:
	return Vector2(clamp_x(x), home_position.y)


# Hanging on the wall on that side.
func wall_point(side: int) -> Vector2:
	var x = ARENA_LEFT + SIZE.x / 2.0 + WALL_GAP if side < 0 else ARENA_RIGHT - SIZE.x / 2.0 - WALL_GAP
	return Vector2(x, home_position.y - WALL_FEET)


# In the mirror line, at x.
func line_point(x: float) -> Vector2:
	return Vector2(clamp_x(x), ARENA_FLOOR_Y)


# The wall nearer to him: -1 left, 1 right.
func nearer_wall() -> int:
	return -1 if global_position.x - ARENA_LEFT < ARENA_RIGHT - global_position.x else 1


func clamp_x(x: float) -> float:
	return clampf(x, ARENA_LEFT + SIZE.x / 2.0 + WALL_GAP, ARENA_RIGHT - SIZE.x / 2.0 - WALL_GAP)


# --- His hands and rings ---

# Where a hand should be (one of the HAND_s, or between two): it eases there, unless `snap` (a drop,
# which has to land on time). `tint`: its telegraph (silver: none); `spin`: its rings turned round
# their own axis (radians).
func pose_hand(hand: int, at: Vector2, tint = COLOR_RING, spin = 0.0, snap = false):
	_hand_goal[hand] = at
	_hand_snap[hand] = snap
	_hand_tint[hand] = tint
	_hand_spin[hand] = spin


func pose_hands(at: Vector2, tint = COLOR_RING):
	for hand in [1, 2]:
		pose_hand(hand, at, tint)


# The foot blades' telegraph (silver: none).
func tint_feet(color: Color):
	_foot_tint = color


# The rings a hand holds just now (2: the pair).
func pair_count(hand: int) -> int:
	return _pairs[hand]


func take_ring(hand: int, count = 1):
	_pairs[hand] = maxi(_pairs[hand] - count, 0)


func give_ring(hand: int, count = 1):
	_pairs[hand] = mini(_pairs[hand] + count, 2)


# The side a hand is on: its player's (the way he faces, if they're gone).
func hand_side(hand: int) -> int:
	var p = player_of(hand)
	return side_of(p) if p != null and not p.is_dead() else int(facing)


# Where a hand is, in world coordinates.
func hand_point(hand: int) -> Vector2:
	return global_position + _hand_local(hand)


func _hand_local(hand: int) -> Vector2:
	var side = hand_side(hand)
	var at: Vector2 = _hand_at[hand]
	var local = Vector2(at.x * side, at.y)
	if hand_side(3 - hand) == side and _is_back_hand(hand):
		local += Vector2(BACK_HAND.x * side, BACK_HAND.y)
	return local.rotated(body.rotation) + (body.position - body_rest)


# Both hands on one side: the farther player's is drawn a little behind.
func _is_back_hand(hand: int) -> bool:
	var mine = player_of(hand)
	var other = player_of(3 - hand)
	return mine != null and other != null and distance_to(mine) > distance_to(other)


# The color a ring of that hand is in: its player's (the ground of their half does the contrast).
func ring_color(hand: int) -> Color:
	var p = player_of(hand)
	return COLOR_RING if p == null else COLOR_RING.lerp(p.player_color, AIM_TINT)


# --- The line: the ripple where he'll come up, the cut he dives into ---

func show_ripple(x: float, share: float):
	_ripple = Vector2(x, share)


func show_cut(x: float, share: float):
	_cut = Vector2(x, share)


# --- The partner's hit (as the Heavy Hitter's) ---

# A parry of `by`'s opens `player`'s window: after the sync rules' delay, for its time, the parry's
# energy running over to them meanwhile.
func open_window(player, by):
	if player == null:
		return
	var delay = Tuning.value("sync_window_delay")
	var from = anim_time + delay
	_windows[player] = {"from": from, "until": from + Tuning.value("sync_beat_time") + Tuning.value("sync_window_late"),
		"by": by, "used": false, "shown": false, "judged": false}
	SyncWave.send(by, player, delay, Tuning.value("sync_beat_time"), ARENA_FLOOR_Y, get_parent())
	update_windows()


# True while that player's window is open.
func window_for(player) -> bool:
	var window = _windows.get(player)
	return window != null and anim_time >= window.from and anim_time < window.until


# The window of `player`'s that's open just now, or null.
func open_window_of(player):
	return _windows[player] if window_for(player) else null


# Each window opening (its cue on its player's blade, as the energy arrives) and closing: unused,
# with its player near enough to have used it, it costs the players sync.
func update_windows():
	for p in _windows:
		var window = _windows[p]
		if not is_instance_valid(p):
			window.judged = true
			continue
		if not window.shown and anim_time >= window.from:
			window.shown = true
			p.cue_sync(Tuning.value("sync_beat_time"), SyncWave.COLOR)
		if not window.judged and anim_time >= window.until:
			window.judged = true
			if not window.used and rules != null and distance_to(p) <= WINDOW_REACH:
				rules.missed_window()
				Dev.window_missed()


# --- His body ---

# His body blocks players (Moves "boss_body") while he stands on the floor; in the air, on a wall
# and in the line it blocks nobody.
func body_block() -> Rect2:
	if not Moves.on("boss_body") or hp <= 0.0 or place != Place.FLOOR:
		return Rect2()
	return Rect2(global_position - body.size / 2.0, body.size)


func spawn_sparks(point: Vector2, count: int, color: Color):
	Fx.sparks(self, point, count, color)


# --- The look ---

func _setup_pose():
	_look = Node2D.new()
	_look.z_index = 1
	_look.draw.connect(_draw_look)
	add_child(_look)


func reset_pose():
	pose_hands(HAND_REST)
	tint_feet(COLOR_RING)
	_ripple = Vector2.ZERO
	_cut = Vector2.ZERO


func _update_pose():
	_update_motion()
	var follow = 1.0 - exp(-HAND_EASE * get_physics_process_delta_time())
	var down = hp <= 0.0 or state == State.STAGGER
	for hand in [1, 2]:
		var goal: Vector2 = HAND_RECOIL.lerp(HAND_REST, 0.5) + Vector2(0.0, 20.0) if down else _hand_goal[hand]
		_hand_at[hand] = goal if _hand_snap[hand] and not down else _hand_at[hand].lerp(goal, follow)
	# Where he is: in the line flat and faint, on a wall leaning off it.
	if place == Place.LINE:
		body.scale = LINE_LOOK
		body.modulate.a = LINE_ALPHA
	elif place == Place.WALL:
		body.rotation = WALL_LEAN * (1.0 if global_position.x < (ARENA_LEFT + ARENA_RIGHT) / 2.0 else -1.0)
	elif place == Place.FLOOR and _move.is_empty() and state != State.STAGGER:
		body.rotation = 0.0
	if place != Place.LINE and body.scale == LINE_LOOK:
		body.scale = Vector2.ONE
	_look.queue_redraw()


func _draw_look():
	var dead = hp <= 0.0
	var faint = place == Place.LINE
	for hand in [1, 2]:
		if faint:
			continue
		var at = _hand_local(hand)
		var hand_color = body.color.darkened(HAND_DARKEN)
		_look.draw_rect(Rect2(at - Vector2(HAND_SIZE, HAND_SIZE) / 2.0, Vector2(HAND_SIZE, HAND_SIZE)), hand_color)
		var count = _pairs[hand]
		if count <= 0:
			continue
		var color = COLOR_RING_LIMP if dead else ring_color(hand)
		var tint: Color = COLOR_RING_LIMP if dead else _hand_tint[hand]
		var squeeze = absf(cos(_hand_spin[hand]))
		for i in count:
			var offset = Vector2(0.0, PAIR_APART * (i - (count - 1) / 2.0))
			_ellipse(at + offset, RING_RADIUS * maxf(squeeze, 0.08), RING_RADIUS, color, RING_WIDTH)
		if tint != COLOR_RING:
			_ellipse(at, RING_RADIUS * maxf(squeeze, 0.08) + RING_WIDTH, RING_RADIUS + RING_WIDTH, tint, TELL_WIDTH)
	if not faint:
		for side in [-1, 1]:
			var foot = Vector2(side * SIZE.x * 0.3, SIZE.y / 2.0).rotated(body.rotation) + (body.position - body_rest)
			var blade = PackedVector2Array()
			for point in FOOT_BLADE:
				blade.append(foot + Vector2(point.x * facing, point.y).rotated(body.rotation))
			_look.draw_colored_polygon(blade, COLOR_RING_LIMP if dead else _foot_tint)
	var line_y = ARENA_FLOOR_Y - global_position.y
	if _cut.y > 0.0:
		var x = _cut.x - global_position.x
		var half = CUT_WIDTH * 0.5 * _cut.y
		_look.draw_line(Vector2(x - half, line_y), Vector2(x + half, line_y), Color.WHITE, 3.0, true)
	if _ripple.y > 0.0:
		var x = _ripple.x - global_position.x
		for i in 3:
			var k = fmod(anim_time * 2.0 + i / 3.0, 1.0)
			var width = RIPPLE_WIDTH * (0.4 + 0.6 * k)
			var color = Color(COLOR_RIPPLE, COLOR_RIPPLE.a * (1.0 - k) * _ripple.y)
			_look.draw_line(Vector2(x - width, line_y - 2.0 * i), Vector2(x + width, line_y - 2.0 * i), color, 2.0, true)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, width: float):
	var points = PackedVector2Array()
	for i in 21:
		var a = TAU * i / 20.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	_look.draw_polyline(points, color, width, true)


func _die():
	_windows = {}
	stop_moving()
	place = Place.FLOOR
	global_position.y = home_position.y  # not left on a wall or in the line
	super()
