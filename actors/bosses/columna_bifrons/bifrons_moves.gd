class_name BifronsMoves
extends BifronsSwords
## Columna Bifrons, part 2 of 3: where he stands and how he gets there. His place between
## attacks and his drift around it, pushing through a player in his way, making room when
## crowded, a lunge with every strike, the charge past a player, and his dashes (part 1, his
## swords: bifrons_swords.gd; part 3, the boss himself: columna_bifrons.gd).

# --- Moving ---
# WHERE HE STANDS: where his blades reach the players, and not right up against one.
# - A player on each side, close enough together for his blades to reach both: in the middle
#   between them, give or take his drift (below).
# - Else (both on one side, only one to fight, or too far apart) he goes by the nearer one:
#   closer than CROWD_DISTANCE, he steps back to FIT_DISTANCE; out of his blades' reach, he
#   walks up until they're REACH_MARGIN inside it; in between he drifts (below).
# - Fine where he is, with the players between him and a wall, he backs toward the room's
#   middle third, as far as the nearer one stays REACH_MARGIN inside his reach.
# - Fine where he is, he doesn't stand still: the distance he keeps from the nearer player
#   drifts, between DRIFT_NEAR and DRIFT_FAR, gliding toward one picked at random (DRIFT_SPEED:
#   the share of that span per second), and after a pause of up to DRIFT_PAUSE toward the next.
#   So he steps up to them and back from them. Between two players he drifts off the middle the
#   same way, by up to PEP_DRIFT, as long as the farther one stays well in his reach; the nearer
#   one he pushes, if they stand their ground.
# He walks between his attacks, and at ATTACK_PACE through their windups. Sword hits slow him
# down for a moment, so a player can hold him. He starts an attack only while a player is in
# his range.
# PUSHING THROUGH. A player in his way doesn't stop him: walking into one (TOUCH_DISTANCE), he
# slows to PUSH_PACE and his body pushes them along (see _keep_out_of_boss() in player_body.gd);
# after PUSH_PATIENCE of that he shoves them out of the way (attacks/shove.gd, their side only).
# (Distances are between his center and a player's. Touching is 42; a player's sword reaches
# him from 118, and two players side by side (20 wide each) both reach him with the nearer one
# at 98.)
const CROWD_DISTANCE = 62.0
const FIT_DISTANCE = 90.0
const REACH_MARGIN = 30.0
const WALK_SPEED = 110.0  # px/s
const ATTACK_PACE = 0.5  # of his walking speed, while he's in an attack
const SLOWED_FACTOR = 0.3  # of his walking speed, for SLOWED_TIME after a sword hit
const SLOWED_TIME = 0.6
const RANGE_RECHECK = 0.2  # nobody in range when an attack is due: he looks again this much later
# DRIFT_NEAR, DRIFT_FAR, DRIFT_SPEED, DRIFT_PAUSE, PEP_DRIFT: on F2 ("bifrons_drift_near" etc.).
const TOUCH_DISTANCE = 50.0  # touching is 42: his half-width and a player's
const PUSH_PACE = 0.5  # of his speed, pushing a player along
# PUSH_PATIENCE: F2 "bifrons_push_patience".
const WALL_ROOM = 90.0  # his flanks stay this far from the walls: room for both players behind him
# WITH A STRIKE HE LUNGES at the player it's for, while the blade comes: a short step, or as far
# as it takes to have the players on that side STRIKE_DISTANCE away as it lands, LUNGE_LONG at
# most. So that's his range: a player within STRIKE_RANGE can be struck. Then he stands until
# the blade moves again.
const STRIKE_DISTANCE = 105.0
const LUNGE_SHORT = 14.0
const LUNGE_LONG = 160.0
const STRIKE_RANGE = BLADE_REACH + LUNGE_LONG
const CLOSEST = 72.0  # no lunge or advance takes him closer to a player than this
# A LONG WINDUP (a single cut with a wait of LONG_WINDUP or more): he walks at the player it's
# for all through it, into them if they don't give way (PUSHING THROUGH), and then lunges. Both
# players have to move.
const LONG_WINDUP = 6
const ADVANCE_SPEED = 70.0
# MAKING ROOM. He wants room when he's been crowded (a player closer than CROWD_DISTANCE) for
# CROWD_PATIENCE, so stepping back hasn't helped (ROOM_COOLDOWN apart at least); and after a
# strike of both swords that didn't stagger him. With the players on one side of him, he makes
# it:
# - with a hop back (BACK_OFF_), if that takes him toward the middle of the room;
# - else by shoving them back (attacks/shove.gd): so making room never drives him to the wall.
# CORNERED: no room to keep his distance by walking. A player on each side, both crowding
# him; or the players on one side and the wall behind him (he's in the room's outer fifth).
# That's a situation of its own in ATTACKS: he gets out over them with the leap, or past one
# with the crossing.
# CROWD_PATIENCE: F2 "bifrons_crowd_patience".
const ROOM_COOLDOWN = 4.0
const BACK_OFF_DISTANCE = 110.0
const BACK_OFF_DELAY = 0.1
const BACK_OFF_TIME = 0.2
const BACK_OFF_HOP = 22.0  # px off the floor at the top of it
# THE CHARGE (a strike of kind CHARGE): a thrust, to be parried like any strike, lunging at the
# player as it comes like a cut; CHARGE_DELAY after it lands he follows it through in
# CHARGE_TIME, his body no obstacle meanwhile: to CHARGE_BEYOND past that player, at least
# CHARGE_DISTANCE and at most CHARGE_MOST (a hit throws its player back: he goes after them). In the crossing a PUSH comes
# first (a shove of that player, StrikePattern.PUSH): the thrust then comes from a distance,
# and its player sees it coming. A player close enough is passed and ends up on his other side: both players on one
# side (ppe). One who backs off ahead of him, or stands too far away, isn't.
const CHARGE_DISTANCE = 230.0
const CHARGE_BEYOND = 70.0
const CHARGE_MOST = 360.0
const CHARGE_DELAY = 0.1
const CHARGE_TIME = 0.25
const CHARGE_MIN_ROOM = 150.0  # he charges toward the side that has at least this much room

# Moving.
var _dash = null  # {from, to, since, time, hop}: a charge or a backing off, under way
# What he's walking for (see _place()): to the middle between the players, back from one who's
# too close, or up to one who's out of reach. Each lasts until he's there.
var _backing = false
var _closing = false
var _ghost_until = 0.0  # anim_time until which his body blocks nobody
var _slowed_until = 0.0
var _crowded_for = 0.0  # how long a player has been closer than CROWD_DISTANCE
var _drift = 0.5  # where his drift is (see "WHERE HE STANDS"): 0 near, 1 far; around the middle...
var _drift_to = 0.5  # ...gliding to here...
var _drift_wait = 0.0  # ...and once there, waiting this long for the next
var _pushing_for = 0.0  # how long he has been pushing a player along (see "PUSHING THROUGH")
var _shove_side = 0  # the side a shove is due on: that player's in his way (0: both sides)
var _room_ready = 0.0  # anim_time from which crowding may make him make room again
var _shove_due = false  # he wants room, and it's the shove: as soon as he's free


# His whole body blocks: taller than a jump. Getting to his other side takes a dash-parry (see
# DASH-PARRY in player_body.gd), or him.
func body_block() -> Rect2:
	if not Moves.on("boss_body") or hp <= 0.0 or anim_time < _ghost_until:
		return Rect2()
	return Rect2(global_position - body.size / 2.0, body.size)

# Close enough to be struck (see STRIKE_RANGE).
func in_range(player) -> bool:
	return distance_to(player) <= STRIKE_RANGE


# True if a strike of that sword would have someone to go for.
func can_strike(blade: int) -> bool:
	var ward = ward_of(blade)
	return ward != null and in_range(ward)


# --- Moving ---

func _idle_motion(delta: float):
	_between_attacks(delta)


func _recover_motion(delta: float):
	_between_attacks(delta)


func _between_attacks(delta: float):
	if _dash == null:
		global_position.y = move_toward(global_position.y, home_position.y, STAGGER_SINK_SPEED * delta)
	_mind_the_crowd(delta)
	walk(delta)


# As far left and right as he goes.
func clamp_x(x: float) -> float:
	var edge = WALL_ROOM + body.size.x / 2.0
	return clampf(x, ARENA_LEFT + edge, ARENA_RIGHT - edge)


func _pace() -> float:
	return SLOWED_FACTOR if anim_time < _slowed_until else 1.0


# Where he's headed (see "WHERE HE STANDS"), walls aside; where he is, if he's fine there.
func _place() -> float:
	var x = global_position.x
	var fought = _fought()
	if fought.is_empty():
		return x
	fought.sort_custom(func(a, b): return distance_to(a) < distance_to(b))
	var near = fought[0]
	var side = side_of(near)
	var gap = distance_to(near)
	if fought.size() == 2 and side_of(fought[1]) != side and gap + distance_to(fought[1]) <= 2.0 * BLADE_REACH:
		# A player on each side: to the middle, once he's far enough off it; and all the way.
		var middle = (near.global_position.x + fought[1].global_position.x) / 2.0
		_backing = false
		_closing = false
		# Off the middle by his drift, toward one of them (into them, if they don't give way: he
		# pushes them, see "PUSHING THROUGH"), as long as the other stays well in reach.
		var half = absf(fought[1].global_position.x - near.global_position.x) / 2.0
		var most = clampf(BLADE_REACH - REACH_MARGIN - half, 0.0, Tuning.value("bifrons_pep_drift"))
		return middle + (2.0 * _drift - 1.0) * most
	# By the nearer one: back from them until they're at his distance, or up to them until they're
	# well in reach.
	if gap < CROWD_DISTANCE:
		_backing = true
	elif gap >= FIT_DISTANCE:
		_backing = false
	if gap > BLADE_REACH:
		_closing = true
	elif gap <= BLADE_REACH - REACH_MARGIN:
		_closing = false
	var well_in_reach = near.global_position.x - side * (BLADE_REACH - REACH_MARGIN)
	if _backing:
		return near.global_position.x - side * FIT_DISTANCE
	if _closing:
		return well_in_reach
	# Fine as far as the players go. With all of them on one side, toward the wall: back toward
	# the room's middle third, as far as the nearer one stays well in reach. That gives players
	# he has against a wall room, and draws them out.
	if fought.all(func(p): return side_of(p) == side):
		var room = ARENA_RIGHT - ARENA_LEFT
		var goal = clampf(x, ARENA_LEFT + room / 3.0, ARENA_RIGHT - room / 3.0)
		if (goal - well_in_reach) * side < 0.0:
			goal = well_in_reach
		if (goal - x) * side < 0.0:
			return goal
	# Else his drift: the distance to keep from the nearer one just now.
	return near.global_position.x - side * lerpf(Tuning.value("bifrons_drift_near"), Tuning.value("bifrons_drift_far"), _drift)


# One frame of his drift: gliding to where it's headed, or waiting there for the next.
func _drift_on(delta: float):
	if _drift == _drift_to:
		_drift_wait -= delta
		if _drift_wait <= 0.0:
			_drift_to = randf()
			_drift_wait = randf_range(0.0, Tuning.value("bifrons_drift_pause"))
	else:
		_drift = move_toward(_drift, _drift_to, Tuning.value("bifrons_drift_speed") * delta)


# One frame of walking to his place, at `pace` times his speed.
func walk(delta: float, pace = 1.0):
	if _dash != null:
		return
	var x = global_position.x
	var goal = clamp_x(_place())
	pace *= _pushing(signf(goal - x), delta)
	global_position.x = move_toward(x, goal, WALK_SPEED * pace * _pace() * delta)


# Walking `way`: into a player? Then slower, and after PUSH_PATIENCE a shove of that side is due
# (see "PUSHING THROUGH"). Returns his pace for it.
func _pushing(way: float, delta: float) -> float:
	var touching = way != 0.0 and get_players().any(
		func(p): return side_of(p) == way and distance_to(p) <= TOUCH_DISTANCE)
	if not touching:
		_pushing_for = 0.0
		return 1.0
	_pushing_for += delta
	if _pushing_for >= Tuning.value("bifrons_push_patience") and not _shove_due:
		_pushing_for = 0.0
		_shove_due = true
		_shove_side = int(way)
	return PUSH_PACE


# No room to keep his distance by walking (see "CORNERED").
func is_cornered() -> bool:
	var fought = _fought()
	if fought.is_empty():
		return false
	var side = side_of(fought[0])
	if fought.any(func(p): return side_of(p) != side):
		return fought.all(func(p): return distance_to(p) < CROWD_DISTANCE)  # pinched
	var room = ARENA_RIGHT - ARENA_LEFT
	var x = global_position.x
	return x < ARENA_LEFT + room / 5.0 if side == RIGHT else x > ARENA_RIGHT - room / 5.0


# Crowded for a while: he makes room.
func _mind_the_crowd(delta: float):
	var crowding = _fought().any(func(p): return distance_to(p) < CROWD_DISTANCE)
	_crowded_for = _crowded_for + delta if crowding else 0.0
	if _crowded_for >= Tuning.value("bifrons_crowd_patience") and anim_time >= _room_ready and _dash == null:
		_crowded_for = 0.0
		if make_room():
			_room_ready = anim_time + ROOM_COOLDOWN


# How far he can go toward that side before he's CLOSEST to a player there.
func _room_toward(side: int) -> float:
	var room = INF
	for p in get_players():
		if side_of(p) == side:
			room = minf(room, distance_to(p) - CLOSEST)
	return maxf(room, 0.0)


# A long windup: one frame of walking at that sword's player, into them if they don't give way
# (pushing them along). False if there's nobody to walk at.
func advance_on(blade: int, delta: float) -> bool:
	var ward = ward_of(blade)
	if ward == null:
		return false
	if _dash != null:
		return true
	var x = global_position.x
	var pace = _pushing(side_of(ward), delta)
	global_position.x = move_toward(x, clamp_x(ward.global_position.x), ADVANCE_SPEED * pace * _pace() * delta)
	return true


# Where a strike of that sword (or of BOTH) takes him (see "WITH A STRIKE HE LUNGES"). `rush`:
# as far as it takes, and through whoever is in the way.
func lunge_goal(sword: int, rush = false) -> float:
	var x = global_position.x
	var struck = []
	for blade in BLADES:
		var ward = ward_of(blade)
		if (sword == BOTH or sword == blade) and ward != null and not ward in struck:
			struck.append(ward)
	if struck.is_empty():
		return x
	var side = side_of(struck[0])
	if struck.any(func(p): return side_of(p) != side):
		return x  # one on each side: he stays between them
	if rush:
		return clamp_x(x + side * maxf(distance_to(struck[0]) - STRIKE_DISTANCE, 0.0))
	# Up to the players on that side: so the partner of the one it's for is in their reach too.
	var far = 0.0
	for p in _fought():
		if side_of(p) == side:
			far = maxf(far, distance_to(p))
	var step = minf(clampf(far - STRIKE_DISTANCE, LUNGE_SHORT, LUNGE_LONG), _room_toward(side))
	return clamp_x(x + side * step)


# How far a charge at that sword's player would get.
func _charge_room(blade: int) -> float:
	var x = global_position.x
	return absf(clamp_x(x + blade_side(blade) * CHARGE_DISTANCE) - x)


# He follows his thrust through, past that sword's player (see "THE CHARGE").
func charge_through(blade: int):
	var way = blade_side(blade)
	var length = CHARGE_DISTANCE
	var ward = ward_of(blade)
	if ward != null and side_of(ward) == way:
		length = clampf(distance_to(ward) + CHARGE_BEYOND, CHARGE_DISTANCE, CHARGE_MOST)
	_dash_to(global_position.x + way * length, CHARGE_TIME)
	ghost(CHARGE_TIME)
	pop_body(Vector2(1.2, 0.9), CHARGE_TIME)
	Sfx.play("swing", -3.0)


# He makes room between him and the players, if they're all on one side of him (see "MAKING
# ROOM"): a hop back at once, or a shove as soon as he's free. False if he can't.
func make_room() -> bool:
	var fought = _fought()
	if fought.is_empty():
		return false
	var side = side_of(fought[0])
	if fought.any(func(p): return side_of(p) != side):
		return false
	var x = global_position.x
	var to = clamp_x(x - side * BACK_OFF_DISTANCE)
	var toward_middle = ((ARENA_LEFT + ARENA_RIGHT) / 2.0 - x) * side <= 0.0
	if toward_middle and absf(to - x) >= BACK_OFF_DISTANCE / 2.0:
		_dash_to(to, BACK_OFF_TIME, BACK_OFF_HOP)
	else:
		_shove_due = true
	return true


# His body blocks nobody for that long (from now): passing a player, or coming down on one.
func ghost(duration: float):
	_ghost_until = anim_time + duration


func is_dashing() -> bool:
	return _dash != null


func _dash_to(x: float, duration: float, hop = 0.0):
	_dash = {"from": global_position.x, "to": clamp_x(x), "since": anim_time, "time": duration, "hop": hop}


func _run_dash():
	if _dash == null:
		return
	var done = clampf((anim_time - _dash.since) / _dash.time, 0.0, 1.0)
	global_position.x = lerpf(_dash.from, _dash.to, 1.0 - (1.0 - done) * (1.0 - done))  # fast, then braking
	global_position.y = home_position.y - _dash.hop * 4.0 * done * (1.0 - done)
	if done >= 1.0:
		_dash = null
