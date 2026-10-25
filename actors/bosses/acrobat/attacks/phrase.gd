class_name AcrobatPhrase
extends Attack
## The Acrobat's attack (docs/boss_acrobat.md): a run of steps, one after the other, each one of his
## verbs. As a chain (his own attack, THE CHAINS in acrobat.gd) it plays a motif, decides at its end
## what comes next (another motif, or the finale), and the salto that ends every motif says which
## (Acrobat.salto_steps()). Run with steps of its own instead (the F5 lab: a motif, a finale, a verb),
## it plays those and is over.
## Unlike the Heavy Hitter's chain (a fixed time line), his steps run one at a time: a step's time
## may hang on a ring coming back (the catch), or on how a strike came out (the plunge).
## THE VERBS, each with one telegraph, the same everywhere (yellow: yours to parry; green: parry it
## together; red: it comes). A step's `wait` is in his beats (Acrobat.beat()), from the step before.
##   dash    in (to his target's reach) or back (away from whoever is close; none close: nothing)
##   strike  a ring as a blade at one player, by the hand of that player: drawn straight back (yellow),
##           then down (red: F2 "acrobat_strike_time"). Out of reach, he dashes in as he winds up.
##   feint   a strike that turns its rings once round their axis as it winds up (the tell, before
##           anyone parries); where a strike would land it only twitches, and the real one comes F2
##           "acrobat_feint_delay" later, red only then.
##   both    both hands at once at where the players are: one each side, two normal strikes; both on
##           one side, heavy (green): parry it together.
##   throw   a ring drawn back over his shoulder (yellow), red as it leaves his hand (ring.gd). The
##           hand of the player it's for throws; if that hand has a ring out, the other.
##   catch   waits for the last ring thrown, reaching for it, and jumps to meet it; caught (or struck
##           back: sooner), the jump becomes a jump strike at whoever struck it back, else the nearer.
##   salto   forward over the nearer one with a kick (the foot blade yellow as he takes off), backward
##           away from them with a throw at its top, to a wall, or into the mirror line (head first).
##   cut     the dive's tell: a ring thrown at the line ahead, which cuts it open (Moves
##           "acrobat_dive_tell": or his blades held out in front instead).
##   under   in the line, faint, under the front one; where he'll come up ripples a moment before.
##   upcut   he comes up there: a strike at that player that throws them over him (the formation
##           flips), whatever they did.
##   plunge  from a wall, crouched, hands crossed (the tell), at the players: between them if they're
##           apart (a strike each side), in front of the front one if together (heavy). Parried
##           together: he stands on their blades a moment and flips back off them with a throw; else he
##           lands and dashes away.
##   volley  (the rally) all four rings, a pair at each player: heavy, parry it together.
##   await   the rings out come back; a finale's end. A ring that ends a finale struck back: he falls
##           (from a wall) or lands off balance, staggered.
## THE STAGGER: only at the end of a finale (the rally's volley or the plunge's throw struck back, the
## dive's last strike parried together): "acrobat_stagger_least" and "acrobat_stagger_per_parry" more
## for every blade parried in the chain (Acrobat.chain_blades).

enum Phase { NONE, RUNNING }

# --- Tuning ---
const CLOSE = 150.0  # px: a player this close to him makes the throwing chain start with a dash back
const DASH_BACK = 160.0  # px a dash back takes him
const DASH_IN_MARGIN = 35.0  # dashing in, he stops this far inside his reach
const LUNGE_MAX = 260.0  # px a strike's dash in goes at most
const REST_TIME = 0.18  # a hand stays where its strike landed (or was thrown back up) this long
const TWITCH = 0.3  # the feint's twitch: the hand jerks this share of the way toward the strike
const SALTO_TIME = 0.6  # a salto through the air (a long one to a wall: up to twice that)
const SALTO_HEIGHT = 90.0  # px over the straight way: over a player's head
const SALTO_PAST = 90.0  # px beyond the one he flips over
const SALTO_BACK = 170.0  # px a backward salto takes him
const WALL_SALTO_RANGE = 220.0  # px: farther to the wall, the salto takes longer (up to 2 times)
const WALL_SALTO_HEIGHT = 110.0
const CROUCH = Vector2(1.15, 0.8)  # his body, loaded for a salto or a plunge
const JUMP_RISE = 0.22  # s: he jumps to meet a ring coming back this long before it arrives...
const JUMP_HEIGHT = 60.0  # ...this high
const JUMP_STRIKE_HEIGHT = 50.0  # the jump strike after the catch, coming down at its target
const CATCH_TIMEOUT = 3.0  # s he waits for a ring at most
const LINE_HOP = 80.0  # px he hops into the line, toward the front one
const LINE_FLIGHT = 0.45  # s
const LINE_SPEED = 700.0  # px/s he glides under the floor
const UPCUT_RISE = 0.12  # s from the line up into his strike
const UPCUT_REACH = 60.0  # px: the one he comes up under must be this near it
const TOSS = Vector2(260.0, -640.0)  # the upcut throws them over him: up and across
const PLUNGE_FLIGHT = 0.3  # s from the wall to the floor
const PLUNGE_HEIGHT = 30.0
const PLUNGE_STAND = 0.4  # s he stands on their blades
const STAND_LIFT = 26.0  # px over the floor he stands on them
const VOLLEY_WAIT = 1.5  # s he waits at most for his rings, before the volley
const AWAIT_TIMEOUT = 4.0
const LEAP_DOWN_TIME = 0.5  # off the wall, down to the floor
const FALL_TIME = 0.35  # falling off it, staggered
const COLOR_ALONE = Color.YELLOW  # yours to parry
const COLOR_TOGETHER = Color(0.25, 1.0, 0.45)  # parry it together (as the other bosses' green)

var _name: String
var _written  # its entry in Acrobat.ATTACKS (the lab's: a motif, a finale, steps)
var _chain = false
var _steps: Array = []  # the steps to come
var _step = {}  # the one under way
var _t = 0.0  # s into it
var _run_time = 0.0  # s into the run
var _due = {}  # player -> run time the step under way lands on them
var _rings: Array = []  # every ring thrown in this run
var _last_thrown = null  # the last of them
var _last_target = null  # whom the last throw was at (the rally's turns)
var _last_struck = null  # whom the last strike was at ("other")
var _dive_target = null  # the front one, as the dive begins: he comes up under them
var _dive_x = 0.0  # where the cut opens the line
var _rest = {1: [0.0, Vector2.ZERO], 2: [0.0, Vector2.ZERO]}  # hand -> [run time it rests from, its pose until then]
var _motifs: Array = []  # the motifs played (the log)
var _motifs_max = 1
var _finale = ""
var stagger_due = false  # a ring that ends a finale was struck back


func _init(attack_name: String, written, chain = false):
	_name = attack_name
	_written = written
	_chain = chain


func get_attack_name() -> String:
	return _name


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_steps = []
	_step = {}
	_t = 0.0
	_run_time = 0.0
	_due = {}
	_rings = []
	_last_thrown = null
	_last_target = null
	_last_struck = null
	_dive_target = null
	_rest = {1: [0.0, Vector2.ZERO], 2: [0.0, Vector2.ZERO]}
	_motifs = []
	_finale = ""
	stagger_due = false
	boss.begin_run()
	if _chain:
		var least = int(Tuning.value("acrobat_motifs_min"))
		_motifs_max = 1 if boss.in_sync_mode() else randi_range(maxi(least, 1), maxi(int(Tuning.value("acrobat_motifs_max")), least))
		var motif = boss.pick_motif()
		_motifs.append(motif)
		_steps = boss.motif_steps(motif, boss.answering(), false)
	else:
		_steps = boss.lab_steps(_written)


# His body keeps its own color: his rings say what's coming.
func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


func get_telegraph_duration() -> float:
	return 0.01


func execute():
	phase = Phase.RUNNING
	boss.body.color = boss.COLOR_IDLE  # not the usual all-red: the rings carry it
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	_next_step()


func update(delta: float):
	_t += delta
	_run_time += delta
	timer = _t
	var guard = 0
	while not completed and _step_over() and guard < 8:
		guard += 1
		_next_step()
	if completed:
		return
	_update_step(delta)
	_pose_resting_hands()


# Seconds until his next blow lands on that player (his rings in the air are Acrobat.time_to_strike()'s).
func time_to_strike(player) -> float:
	if not _due.has(player):
		return INF
	return _due[player] - _run_time


# A ring that ends a finale was struck back (Acrobat.ring_struck_back()): staggered, at its end.
func on_strike_back(ring):
	if ring in _rings and ring.finale_end:
		stagger_due = true


# Cut short (his posture broken, the boss dead): his rings back in his hands, he's back on the floor.
func interrupt():
	for ring in _rings:
		if is_instance_valid(ring):
			ring.fizzle()
	boss.settle()
	super()


func cleanup():
	boss.show_ripple(0.0, 0.0)
	boss.show_cut(0.0, 0.0)
	boss.tint_feet(boss.COLOR_RING)


# --- The steps ---

func _next_step():
	_due = {}
	if _steps.is_empty():
		_step = {}
		finish(Tuning.value("acrobat_recover_time"))
		return
	_step = _steps.pop_front()
	_t = 0.0
	_step.length = 0.0  # s into it that it's over (a step may wait on more: _step_over())
	_step.landed = false
	match _step.do:
		"dash": _begin_dash()
		"strike": _begin_strike()
		"both": _begin_both()
		"throw": _begin_throw()
		"catch": _begin_catch()
		"salto": _begin_salto()
		"cut": _begin_cut()
		"under": _begin_under()
		"upcut": _begin_upcut()
		"plunge": _begin_plunge()
		"stand": _begin_stand()
		"volley": _begin_volley()
		"await": _step.length = AWAIT_TIMEOUT
		"motif_end": _end_motif()


func _step_over() -> bool:
	if _step.is_empty():
		return true
	if boss.moving() and _step.do != "await":
		return false  # no step is over while he's still on his way (a salto lands first)
	match _step.do:
		"catch":
			return _step.get("lands", INF) <= _t and _step.landed
		"volley":
			return _step.get("release", INF) <= _t and _step.landed
		"await":
			return _await_over()
	return _t >= _step.length and (_step.landed or not _step.has("lands"))


func _update_step(delta: float):
	if _step.is_empty():
		return
	match _step.do:
		"dash": pass
		"strike": _update_strike()
		"both": _update_both()
		"throw": _update_throw()
		"catch": _update_catch()
		"salto": _update_salto()
		"cut": _update_cut()
		"under": _update_under(delta)
		"upcut": _update_upcut()
		"plunge": _update_plunge()
		"stand": pass
		"volley": _update_volley()
		"await": pass


func _beats(n: float) -> float:
	return n * boss.beat()


# A step's player: one named, or by a word: "near", "far", "turn" (the one the last throw wasn't at),
# "other" (the one the step before wasn't at).
func _who(at):
	if at is Object:
		return at if is_instance_valid(at) and not at.is_dead() else boss.nearer()
	match at:
		"far":
			return boss.farther()
		"turn":
			var them = boss.by_distance()
			if them.size() > 1 and _last_target != null:
				return them[1] if them[0] == _last_target else them[0]
			return boss.farther()
		"other":
			var them = boss.by_distance()
			if them.size() > 1 and _last_struck != null:
				return them[1] if them[0] == _last_struck else them[0]
	return boss.nearer()


# A hand that's done striking rests where it landed a moment, then at his side.
func _pose_resting_hands():
	for hand in [1, 2]:
		if _hand_busy(hand):
			continue
		if _run_time < _rest[hand][0]:
			boss.pose_hand(hand, _rest[hand][1])
		else:
			boss.pose_hand(hand, boss.HAND_REST)


func _hand_busy(hand: int) -> bool:
	return _step.get("hands", []).has(hand)


func _rest_hand(hand: int, pose: Vector2):
	_rest[hand] = [_run_time + REST_TIME, pose]


# --- dash ---

func _begin_dash():
	_step.length = _beats(_step.get("wait", 2))
	var who = _who(_step.get("at", "near"))
	if who == null:
		return
	var x = boss.global_position.x
	if _step.way == "in":
		var side = boss.side_of(who)
		x = who.global_position.x - side * (boss.STRIKE_REACH - DASH_IN_MARGIN)
		if boss.distance_to(who) <= boss.STRIKE_REACH - DASH_IN_MARGIN:
			return
	else:
		var near = boss.nearer()
		if near == null or boss.distance_to(near) > CLOSE:
			_step.length = 0.0  # nobody close: no dash back
			return
		x -= boss.side_of(near) * DASH_BACK
	boss.face(who.global_position.x)
	boss.move_to(boss.floor_point(x), boss.DASH_TIME)
	Sfx.play("swing", -10.0)


# --- strike, feint ---

func _begin_strike():
	var target = boss.strike_target(_who(_step.get("at", "near")))
	_step.target = target
	if target == null:
		_step.length = _beats(_step.get("wait", 3))
		return
	_step.hand = target.player_id
	_step.hands = [_step.hand]
	var normal = _beats(_step.get("wait", 3))
	_step.normal = normal
	_step.lands = normal + (Tuning.value("acrobat_feint_delay") if _step.get("feint", false) else 0.0)
	_step.length = _step.lands
	_due[target] = _run_time + _step.lands
	boss.face(target.global_position.x)
	_lunge(target)


# Out of reach: he dashes in as he winds up.
func _lunge(target):
	var gap = boss.distance_to(target)
	if gap <= boss.STRIKE_REACH - 10.0 or boss.place != AcrobatBody.Place.FLOOR:
		return
	var side = boss.side_of(target)
	var go = minf(gap - (boss.STRIKE_REACH - DASH_IN_MARGIN), LUNGE_MAX)
	boss.move_to(boss.floor_point(boss.global_position.x + side * go), boss.DASH_TIME)


func _update_strike():
	if _step.target == null:
		return
	var hand: int = _step.hand
	var drop = _drop_time(_step.lands)
	var drop_at = _step.lands - drop
	if _t >= _step.lands:
		if not _step.landed:
			_land_strike()
		return
	var feint: bool = _step.get("feint", false)
	if _t >= drop_at:
		var fall = pow(clampf((_t - drop_at) / drop, 0.0, 1.0), 1.7)
		boss.pose_hand(hand, boss.HAND_RAISED.lerp(boss.HAND_STRIKE, fall), boss.COLOR_EXECUTE, 0.0, true)
		return
	var normal_drop = _step.normal - drop
	if feint and _t >= normal_drop:
		# Where the strike would come, it only twitches: the rings whirl, nothing red.
		var k = clampf((_t - normal_drop) / maxf(drop_at - normal_drop, 0.01), 0.0, 1.0)
		var twitch = boss.HAND_RAISED.lerp(boss.HAND_STRIKE, TWITCH * sin(PI * k))
		boss.pose_hand(hand, twitch, COLOR_ALONE, TAU * 3.0 * k)
		return
	var tension = clampf(_t / maxf(drop_at, 0.01), 0.0, 1.0)
	# The feint's tell: drawn back, its rings turn once round their axis.
	var spin = TAU * clampf(_t / maxf(normal_drop, 0.01), 0.0, 1.0) if feint else 0.0
	boss.pose_hand(hand, boss.HAND_REST.lerp(boss.HAND_RAISED, smoothstep(0.0, 0.7, tension)),
		boss.COLOR_RING.lerp(COLOR_ALONE, 0.4 + 0.6 * tension), spin)


func _land_strike():
	_step.landed = true
	_due.erase(_step.target)
	_last_struck = _step.target
	var parriers = boss.land_strike([_step.target], false)
	var parried = _step.target in parriers
	_rest_hand(_step.hand, boss.HAND_RECOIL if parried else boss.HAND_STRIKE)
	_emit(parriers, "acrobat_strike")


# A drop's time (its cue), less if the step leaves no room for it.
func _drop_time(lands: float) -> float:
	return minf(Tuning.value("acrobat_strike_time"), lands * 0.6)


func _emit(parriers: Array, kind: String):
	for p in parriers:
		parry_success.emit(p, kind)


# --- both ---

func _begin_both():
	_step.hands = [1, 2]
	_step.lands = _beats(_step.get("wait", 4))
	_step.length = _step.lands
	_step.heavy = boss.together()
	for p in boss.by_distance():
		_due[p] = _run_time + _step.lands


func _update_both():
	if _t >= _step.lands:
		if not _step.landed:
			_step.landed = true
			_due = {}
			var result = boss.land_both()
			for hand in [1, 2]:
				_rest_hand(hand, boss.HAND_STRIKE)
			_emit(result.parriers, "acrobat_both")
			if _step.get("end", false) and result.together:
				finish_with_stagger(boss.chain_stagger())
		return
	var drop = _drop_time(_step.lands)
	var drop_at = _step.lands - drop
	for hand in [1, 2]:
		if _t >= drop_at:
			var fall = pow(clampf((_t - drop_at) / drop, 0.0, 1.0), 1.7)
			boss.pose_hand(hand, boss.HAND_RAISED.lerp(boss.HAND_STRIKE, fall), boss.COLOR_EXECUTE, 0.0, true)
		else:
			var tension = clampf(_t / maxf(drop_at, 0.01), 0.0, 1.0)
			var color = COLOR_TOGETHER if _step.heavy else COLOR_ALONE
			boss.pose_hand(hand, boss.HAND_REST.lerp(boss.HAND_RAISED, smoothstep(0.0, 0.7, tension)),
				boss.COLOR_RING.lerp(color, 0.4 + 0.6 * tension))


# --- throw ---

func _begin_throw():
	_step.release = _beats(_step.get("wait", 3))
	_step.lands = _step.release
	_step.length = _step.release
	_aim(_who(_step.get("at", "far")), _step.release, _step.get("rally", false))


# Takes a ring in hand to throw at `target`: the hand of that player if it holds its pair, else the
# other (in the rally: any ring). It leaves his hand `release` s into the step. No ring to throw: no
# throw.
func _aim(target, release: float, rally = false):
	_step.ring = null
	var least = 1 if rally else 2
	var hand = target.player_id if target != null else 1
	if target != null and boss.pair_count(hand) < least:
		hand = 3 - hand
	if target == null or boss.pair_count(hand) < least:
		_step.landed = true  # nothing to let go
		return
	_step.hand = hand
	_step.hands = [hand]
	_step.target = target
	_step.ring = AcrobatRing.aim(boss, hand, target)
	_step.ring.finale_end = _step.get("end", false)
	_rings.append(_step.ring)
	_last_target = target
	_due[target] = _run_time + release + Tuning.value("acrobat_throw_flight")
	boss.face(target.global_position.x)


func _update_throw():
	_throw_pose(_step.release)


# The hand drawn back over his shoulder, yellow; at `release`, the ring let go, red.
func _throw_pose(release: float):
	var ring = _step.get("ring")
	if ring == null:
		return
	var hand: int = _step.hand
	if _t >= release:
		if not _step.landed:
			_step.landed = true
			_let_go(ring, hand)
		return
	var tension = clampf(_t / maxf(release, 0.01), 0.0, 1.0)
	boss.pose_hand(hand, boss.HAND_REST.lerp(boss.HAND_THROW_BACK, smoothstep(0.0, 0.7, tension)),
		boss.COLOR_RING.lerp(COLOR_ALONE, 0.4 + 0.6 * tension))


func _let_go(ring, hand: int):
	boss.take_ring(hand, 2 if ring.pair else 1)
	ring.release(Tuning.value("acrobat_throw_flight"))
	_last_thrown = ring
	_rest_hand(hand, boss.HAND_THROWN)
	boss.pose_hand(hand, boss.HAND_THROWN, boss.COLOR_EXECUTE, 0.0, true)
	Sfx.play("swing", -6.0)
	_due.erase(ring.target)


# --- catch ---

func _begin_catch():
	_step.ring = _last_thrown
	_step.jumped = false
	_step.caught_at = -1.0
	_step.hand = _last_thrown.hand if _last_thrown != null else 1
	_step.hands = [_step.hand]


func _update_catch():
	var ring = _step.ring
	if _step.caught_at < 0.0:
		var back = ring == null or not is_instance_valid(ring) or ring.is_back() or ring.stage == AcrobatRing.Stage.STRUCK
		if back or _t >= CATCH_TIMEOUT:
			_caught()
			return
		boss.pose_hand(_step.hand, boss.HAND_CATCH)
		if not _step.jumped and ring.eta() <= JUMP_RISE and boss.place == AcrobatBody.Place.FLOOR:
			_step.jumped = true
			boss.move_to(boss.global_position, JUMP_RISE * 2.0, JUMP_HEIGHT)
		return
	if _step.landed:
		return
	var target = _step.target
	var drop = _drop_time(_step.lands - _step.caught_at)
	var drop_at = _step.lands - drop
	var hand = target.player_id if target != null else _step.hand
	_step.hands = [hand]
	if _t >= _step.lands:
		_step.landed = true
		_due = {}
		_last_struck = target
		var parriers = boss.land_strike([target], false) if target != null else []
		_rest_hand(hand, boss.HAND_RECOIL if target in parriers else boss.HAND_STRIKE)
		_emit(parriers, "acrobat_jump_strike")
	elif _t >= drop_at:
		var fall = pow(clampf((_t - drop_at) / drop, 0.0, 1.0), 1.7)
		boss.pose_hand(hand, boss.HAND_RAISED.lerp(boss.HAND_STRIKE, fall), boss.COLOR_EXECUTE, 0.0, true)
	else:
		boss.pose_hand(hand, boss.HAND_RAISED, boss.COLOR_RING.lerp(COLOR_ALONE, 0.8))


# Caught (or struck back): the jump becomes a jump strike, at whoever struck it back, else the
# nearer one, `wait` beats on.
func _caught():
	_step.caught_at = _t
	var ring = _step.ring
	var by = ring.struck_by if ring != null and is_instance_valid(ring) else null
	var target = by if by != null and is_instance_valid(by) and not by.is_dead() else boss.nearer()
	_step.target = target
	_step.lands = _t + _beats(_step.get("wait", 2))
	_step.length = _step.lands
	if target == null:
		return
	_due[target] = _run_time + (_step.lands - _t)
	boss.face(target.global_position.x)
	var side = boss.side_of(target)
	var x = target.global_position.x - side * (boss.STRIKE_REACH - DASH_IN_MARGIN)
	if boss.distance_to(target) <= boss.STRIKE_REACH - DASH_IN_MARGIN:
		x = boss.global_position.x
	boss.move_to(boss.floor_point(x), _step.lands - _t, JUMP_STRIKE_HEIGHT)


# --- salto ---

func _begin_salto():
	var kind: String = _step.kind
	var near = boss.nearer()
	var from = boss.global_position
	var flight = SALTO_TIME
	var goal = from
	var height = SALTO_HEIGHT
	var land = AcrobatBody.Place.FLOOR
	var dir = boss.side_of(near) if near != null else int(boss.facing)
	var look = dir  # the way he faces as he goes
	_step.kick_share = -1.0  # the share of the flight at which the kick lands (-1: no kick)
	_step.throw_at = null
	match kind:
		"kick":
			if near != null:
				goal = boss.floor_point(near.global_position.x + dir * SALTO_PAST)
				_step.over = near
				_step.kick_share = _share_over(from.x, goal.x, near.global_position.x)
		"throw":
			goal = boss.floor_point(from.x - dir * SALTO_BACK)
			dir = -dir  # away from them, facing them
			_step.throw_at = _who(_step.get("at", "far"))
		"wall":
			var side = boss.nearer_wall()
			goal = boss.wall_point(side)
			land = AcrobatBody.Place.WALL
			height = WALL_SALTO_HEIGHT
			flight = SALTO_TIME * clampf(absf(goal.x - from.x) / WALL_SALTO_RANGE, 1.0, 2.0)
			var forward = near != null and boss.side_of(near) == side
			if forward:
				_step.over = near
				_step.kick_share = _share_over(from.x, goal.x, near.global_position.x)
			elif not _step.get("no_throw", false):
				_step.throw_at = _who("far")
			dir = side
			look = side if forward else -side
		"line":
			goal = boss.line_point(_dive_x if _dive_target != null else from.x + dir * LINE_HOP)
			land = AcrobatBody.Place.LINE
			height = SALTO_HEIGHT * 0.7
			flight = LINE_FLIGHT
	# The kick lands, or the ring leaves his hand at the top, `wait` beats from the step's start.
	var moment = _beats(_step.get("wait", 4))
	var key_share = _step.kick_share if _step.kick_share >= 0.0 else 0.5
	_step.takeoff = maxf(moment - key_share * flight, _beats(1))
	_step.flight = flight
	_step.goal = goal
	_step.height = height
	_step.land = land
	_step.turns = (0.5 if kind == "line" else 1.0) * signf(goal.x - from.x if goal.x != from.x else float(dir))
	_step.length = _step.takeoff + flight
	_step.lands = _step.takeoff + key_share * flight
	if _step.kick_share >= 0.0 and _step.over != null:
		_due[_step.over] = _run_time + _step.lands
	if _step.throw_at != null:
		_aim(_step.throw_at, _step.lands)
		if _step.get("ring") != null:
			_step.ring.finale_end = _step.get("end", false)
		_step.landed = false  # (the salto lands itself)
	if not _step.has("hands"):
		_step.hands = []
	boss.face(boss.global_position.x + look)


# Where along the way from `a` to `b` he's over `x` (kept off the very start and end).
func _share_over(a: float, b: float, x: float) -> float:
	if absf(b - a) < 1.0:
		return 0.5
	return clampf((x - a) / (b - a), 0.2, 0.8)


func _update_salto():
	if _t < _step.takeoff:
		var tension = clampf(_t / _step.takeoff, 0.0, 1.0)
		boss.squash_body(Vector2.ONE.lerp(CROUCH, ease(tension, 0.5)))
		if _step.kick_share >= 0.0:
			boss.tint_feet(boss.COLOR_RING.lerp(COLOR_ALONE, 0.4 + 0.6 * tension))
		if _step.get("ring") != null:
			_throw_pose(_step.lands)
		return
	if not _step.get("off", false):
		_step.off = true
		boss.pop_body(Vector2(0.85, 1.2), 0.25)
		boss.move_to(_step.goal, _step.flight, _step.height, _step.turns, _step.land)
		Sfx.play("launch", -6.0)
		if _step.kick_share >= 0.0:
			boss.tint_feet(COLOR_ALONE)
	if _step.get("ring") != null:
		_throw_pose(_step.lands)
		return
	if _step.kick_share < 0.0:
		_step.landed = true  # nothing more to land: the salto is over as he lands
		return
	if _t >= _step.lands:
		if not _step.landed:
			_step.landed = true
			_due.erase(_step.over)
			boss.tint_feet(boss.COLOR_RING)
			var parriers = boss.land_strike([_step.over], false)
			_emit(parriers, "acrobat_kick")
	elif _t >= _step.lands - _drop_time(_step.lands):
		boss.tint_feet(boss.COLOR_EXECUTE)


# --- the dive: cut, under, upcut ---

func _begin_cut():
	var front = boss.nearer()
	_step.release = _beats(_step.get("wait", 2))
	_step.length = _step.release + 0.25
	var dir = boss.side_of(front) if front != null else int(boss.facing)
	var x = boss.clamp_x(boss.global_position.x + dir * LINE_HOP)
	_step.x = x
	_dive_target = front
	_dive_x = x
	_step.ring = null
	if Moves.value("acrobat_dive_tell") != "blade":
		var hand = 1 if boss.pair_count(1) >= 2 else 2
		_step.hand = hand
		_step.hands = [hand]
		_step.ring = AcrobatRing.aim(boss, hand, null, x)
		_rings.append(_step.ring)
	else:
		_step.hands = [1, 2]
	boss.face(x)


func _update_cut():
	if _step.ring == null:
		# The other tell (Moves "acrobat_dive_tell" blade): his blades held out in front as he goes.
		var tension = clampf(_t / maxf(_step.release, 0.01), 0.0, 1.0)
		boss.pose_hands(boss.HAND_REST.lerp(boss.HAND_OUT, tension), boss.COLOR_RING.lerp(COLOR_ALONE, tension))
		_step.landed = true
		return
	_throw_pose(_step.release)
	if _t >= _step.release:
		boss.show_cut(_dive_x, clampf((_t - _step.release) / 0.25, 0.0, 1.0))


func _begin_under():
	_step.length = Tuning.value("acrobat_line_time")
	_step.hands = [1, 2]
	for ring in _rings:
		if is_instance_valid(ring) and ring.target == null:
			ring.pick_up()
	boss.show_cut(0.0, 0.0)
	_step.x = boss.global_position.x
	if _dive_target != null and is_instance_valid(_dive_target):
		_due[_dive_target] = _run_time + _step.length + UPCUT_RISE


func _update_under(delta: float):
	var ripple = Tuning.value("acrobat_ripple_time")
	var target = _dive_target if _dive_target != null and is_instance_valid(_dive_target) else boss.nearer()
	if _t < _step.length - ripple and target != null:
		_step.x = boss.clamp_x(target.global_position.x)  # under them, until it shows where
	var x = move_toward(boss.global_position.x, _step.x, LINE_SPEED * delta)
	boss.global_position = boss.line_point(x)
	if _t >= _step.length - ripple:
		boss.show_ripple(_step.x, clampf((_t - (_step.length - ripple)) / ripple, 0.0, 1.0))
	boss.pose_hands(boss.HAND_REST)


func _begin_upcut():
	_step.lands = UPCUT_RISE
	_step.length = UPCUT_RISE + 0.1
	_step.x = boss.global_position.x
	var target = _dive_target if _dive_target != null and is_instance_valid(_dive_target) else boss.nearer()
	_step.target = target
	_step.hand = target.player_id if target != null else 1
	_step.hands = [_step.hand]
	boss.show_ripple(0.0, 0.0)
	boss.move_to(boss.floor_point(_step.x), UPCUT_RISE + 0.2, 40.0)
	Sfx.play("launch", -4.0)


func _update_upcut():
	var hand: int = _step.hand
	if _t < _step.lands:
		boss.pose_hand(hand, boss.HAND_STRIKE.lerp(boss.HAND_CATCH, _t / _step.lands), boss.COLOR_EXECUTE, 0.0, true)
		return
	if _step.landed:
		return
	_step.landed = true
	_due = {}
	_rest_hand(hand, boss.HAND_CATCH)
	var target = _step.target
	if target == null or absf(target.global_position.x - _step.x) > UPCUT_REACH:
		return
	# Over him, to his other side: away from the partner if they're together, toward them if apart.
	var partner = target.partner()
	var away = 1.0 if target.global_position.x >= _step.x else -1.0
	if partner != null and not partner.is_dead():
		var apart = (partner.global_position.x - _step.x) * (target.global_position.x - _step.x) < 0.0
		away = signf(partner.global_position.x - target.global_position.x) if apart else signf(target.global_position.x - partner.global_position.x)
		if away == 0.0:
			away = 1.0
	var parriers = boss.land_strike([target], false, Vector2(away * TOSS.x, TOSS.y))
	_emit(parriers, "acrobat_upcut")


# --- plunge ---

func _begin_plunge():
	_step.hands = [1, 2]
	_step.lands = _beats(_step.get("wait", 4))
	_step.takeoff = maxf(_step.lands - PLUNGE_FLIGHT, 0.0)
	_step.length = _step.lands
	_step.heavy = boss.together()
	for p in boss.by_distance():
		_due[p] = _run_time + _step.lands


func _update_plunge():
	if _t < _step.takeoff:
		var tension = clampf(_t / maxf(_step.takeoff, 0.01), 0.0, 1.0)
		boss.squash_body(Vector2.ONE.lerp(CROUCH, ease(tension, 0.5)))
		var color = COLOR_TOGETHER if _step.heavy else COLOR_ALONE
		boss.pose_hands(boss.HAND_CROSSED, boss.COLOR_RING.lerp(color, 0.4 + 0.6 * tension))
		return
	if not _step.get("off", false):
		_step.off = true
		_step.heavy = boss.together()  # where they are as he throws himself at them
		boss.pop_body(Vector2(0.85, 1.2), 0.2)
		boss.move_to(boss.floor_point(boss.plunge_x()), PLUNGE_FLIGHT, PLUNGE_HEIGHT)
		Sfx.play("launch", -4.0)
	if _t < _step.lands:
		boss.pose_hands(boss.HAND_CROSSED.lerp(boss.HAND_STRIKE, clampf((_t - _step.takeoff) / PLUNGE_FLIGHT, 0.0, 1.0)), boss.COLOR_EXECUTE)
		return
	if _step.landed:
		return
	_step.landed = true
	_due = {}
	var result = boss.land_both()
	_emit(result.parriers, "acrobat_plunge")
	for hand in [1, 2]:
		_rest_hand(hand, boss.HAND_RECOIL if result.together else boss.HAND_STRIKE)
	if result.together:
		if boss.in_sync_mode():
			finish_with_stagger(boss.chain_stagger())
			return
		# Parried together: on their blades a moment, then back off them with a throw; struck back, it
		# staggers him.
		_steps.push_front({"do": "await", "end": true})
		_steps.push_front({"do": "salto", "kind": "throw", "wait": 2, "end": true})
		_steps.push_front({"do": "stand"})
	else:
		_steps.push_front({"do": "dash", "way": "back", "wait": 2})


func _begin_stand():
	_step.length = Tuning.value("acrobat_plunge_stand")
	_step.hands = [1, 2]
	boss.move_to(boss.global_position - Vector2(0.0, STAND_LIFT), 0.08, 0.0, 0.0, AcrobatBody.Place.AIR)
	boss.pose_hands(boss.HAND_REST)


# --- volley (the rally's last throw) ---

func _begin_volley():
	_step.waited = 0.0
	_step.release = INF
	_step.hands = [1, 2]


func _update_volley():
	if _step.release == INF:
		# His rings back in his hands first (at most VOLLEY_WAIT).
		boss.pose_hands(boss.HAND_CATCH)
		if (boss.pair_count(1) >= 2 and boss.pair_count(2) >= 2) or _t >= VOLLEY_WAIT:
			_step.release = _t + _beats(_step.get("wait", 5))
			_step.rings = []
			var volley = []
			for p in boss.by_distance():
				var ring = AcrobatRing.aim(boss, p.player_id, p)
				ring.pair = true
				ring.finale_end = true
				volley.append(ring)
				_rings.append(ring)
				_due[p] = _run_time + (_step.release - _t) + Tuning.value("acrobat_throw_flight")
			for ring in volley:
				ring.volley = volley
			_step.rings = volley
		return
	if _t >= _step.release:
		if not _step.landed:
			_step.landed = true
			for ring in _step.rings:
				boss.take_ring(ring.hand, 2)
				ring.release(Tuning.value("acrobat_throw_flight"))
				_last_thrown = ring
			for hand in [1, 2]:
				_rest_hand(hand, boss.HAND_THROWN)
			_due = {}
			Sfx.play("swing", -3.0)
		return
	var tension = clampf((_t - (_step.release - _beats(_step.get("wait", 5)))) / _beats(_step.get("wait", 5)), 0.0, 1.0)
	boss.pose_hands(boss.HAND_REST.lerp(boss.HAND_THROW_BACK, smoothstep(0.0, 0.7, tension)),
		boss.COLOR_RING.lerp(COLOR_TOGETHER, 0.4 + 0.6 * tension))


# --- await: a finale's end ---

func _await_over() -> bool:
	if stagger_due:
		if boss.place == AcrobatBody.Place.WALL:
			boss.move_to(boss.floor_point(boss.global_position.x), FALL_TIME)  # he falls off it
			Sfx.play("thunk", -4.0)
		if not boss.moving():
			finish_with_stagger(boss.chain_stagger())
		return false
	var out = _rings.any(func(r): return is_instance_valid(r) and not r.is_back() and r.target != null)
	if out and _t < AWAIT_TIMEOUT:
		boss.pose_hands(boss.HAND_CATCH)
		return false
	if boss.place == AcrobatBody.Place.WALL:
		var middle = (BaseBoss.ARENA_LEFT + BaseBoss.ARENA_RIGHT) / 2.0
		var off = boss.global_position.x + signf(middle - boss.global_position.x) * 120.0
		boss.move_to(boss.floor_point(off), LEAP_DOWN_TIME, 40.0)
		return false
	return not boss.moving()


# --- a motif's end: what comes next ---

# The decision, as the motif's last step is over: another motif (until the chain has the ones it was
# given, or his posture is low), else the finale; and the salto that says which.
func _end_motif():
	var low = boss.rules != null and boss.rules.posture_share(boss) * 100.0 < Tuning.value("acrobat_chain_posture")
	if _motifs.size() < _motifs_max and not low:
		var motif = boss.pick_motif()
		_motifs.append(motif)
		var after = boss.salto_steps(motif)
		_steps = after + boss.motif_steps(motif, null, after.back().kind == "throw")
		return
	_finale = boss.chain_finale()
	Dev.note("chain", {"motifs": _motifs.duplicate(), "finale": _finale, "why": boss.finale_reason, "posture_low": low})
	_steps = boss.salto_steps(_finale) + boss.finale_steps(_finale)
