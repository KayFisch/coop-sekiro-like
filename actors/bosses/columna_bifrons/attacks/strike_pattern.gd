class_name StrikePattern
extends Attack
## Yellow blade -> red. Columna Bifrons's attack: a set series of sword strikes, each on his
## left, his right or both sides at once, landing on a beat. There's one instance per pattern
## and per counter (see ColumnaBifrons.PATTERNS and COUNTERS); the boss says which way round
## each run goes (ColumnaBifrons.orient()).
##
## A strike: that side's blade goes up over his head (so the side says who has to parry), is
## drawn back there, then drops in FALL_TIME. The drop is the cue, and both players read it:
## everyone under the blade when it lands must perfect parry it, and a parried strike breaks his
## guard on the *other* side for a moment (ColumnaBifrons.break_guard()), where the partner's
## sword hit is a sync hit. Both blades parried at once stagger him.

signal strike_parried(player)
signal both_parried

enum Phase { NONE, STRIKING }

const LEFT = -1
const RIGHT = 1
const BOTH = 0

# --- Tuning ---
# One unit of a strike's `wait` (see ColumnaBifrons.PATTERNS), in seconds: the tempo of every
# pattern at once. 4 units between strikes is 0.8 s.
const TIME_UNIT = 0.2
# The blade's drop, from drawn back to landing: the cue to press. A strike that follows the one
# before too closely for this (a wait under 3) drops faster, and gets hard to read.
const FALL_TIME = 0.28
const FALL_POWER = 1.7  # the drop starts slow and lands fast (1 = constant speed)
const STICK_TIME = 0.12  # after landing, the blade stays down (or thrown back, parried) this long
const REACH = 290.0  # from his center: players this close on the struck side are under the blade
const STRIKE_DAMAGE = 12.0
const STRIKE_KNOCKBACK = 300.0
const BLOCKED_DAMAGE = 4.0
const BLOCKED_KNOCKBACK = 150.0
# THE PARTNER'S HIT, by Moves "bifrons_window":
# "beat": parry and hit are pressed together. A sword hit landing at most HIT_EARLY before the
#   strike lands is held until it does (the same lead a parry has); from the parry on, the guard
#   stays broken for BREAK_TIME.
# "after": the hit answers the parry. Nothing is held, and the guard only breaks BREAK_DELAY
#   after the parry (his blade there is knocked aside at once: the tell), so a hit pressed on
#   the strike itself still bounces.
const HIT_EARLY = 0.133
const BREAK_DELAY = {"beat": 0.0, "after": 0.15}
const BREAK_TIME = {"beat": 0.2, "after": 0.45}
# COMMITTED: from this long before a strike lands, that blade is past parrying anything. In the
# reactive mode one sword hit on that side then lands, a plain hit (ColumnaBifrons.take_damage()):
# the price is the swing itself, which leaves little or no time to parry the strike.
const COMMIT_TIME = 0.45
const BOTH_STAGGER_TIME = 2.2  # both blades parried at once
const RECOVER_TIME = 0.6
const TREMBLE = 0.05  # radians the drawn-back blade shakes by, just before the drop
# A blade knocked aside by a broken guard goes up for its own strike at least this long before
# its drop, however long the guard stays broken: it has to be up there when the drop starts.
const RAISE_ROOM = 0.3

const COLOR = Color.YELLOW
const COLOR_PARRY = Color(1.0, 0.85, 0.4)

var _name: String
var _strikes: Array  # as written in ColumnaBifrons.PATTERNS / COUNTERS: [wait, side] each
var _contacts: Array = []  # when each strike lands, in seconds from the pattern's start
var _sides: Array = []  # this run's side for each strike (see ColumnaBifrons.orient())
var _time = 0.0  # seconds into the pattern
var _next = 0  # the strike that lands next
var _parried = {LEFT: false, RIGHT: false}  # how each blade's last strike went
var _sounded = -1  # the last strike whose drop has made its sound
var _commit_hits = {}  # (strike, side) -> true once a sword hit has landed on that committed blade


func _init(pattern_name: String, strikes: Array):
	_name = pattern_name
	_strikes = strikes
	var landing = 0.0
	for strike in strikes:
		landing += strike[0] * TIME_UNIT
		_contacts.append(landing)


func get_attack_name() -> String:
	return _name


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	var way = boss.orient(_name, _strikes)
	_sides = _strikes.map(func(strike): return strike[1] * way)
	_time = 0.0
	_next = 0
	_parried = {LEFT: false, RIGHT: false}
	_sounded = -1
	_commit_hits = {}


# His body keeps its own color: the raised blade, and that half of him, say which side it is.
func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


# The telegraph is the first strike's windup, up to its drop.
func get_telegraph_duration() -> float:
	return _contacts[0] - _fall_time(0)


func update_telegraph(progress: float):
	_time = progress * get_telegraph_duration()
	_animate()


func execute():
	phase = Phase.STRIKING
	_time = get_telegraph_duration()
	boss.body.color = boss.COLOR_IDLE  # not the usual all-red: the falling blade carries it
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	_animate()


func update(delta: float):
	_time += delta
	while _next < _contacts.size() and _time >= _contacts[_next]:
		_land(_next)
		if completed:
			return  # staggered by a parry of both blades, or dead
		_next += 1
	if _next >= _contacts.size() and _time >= _contacts.back() + STICK_TIME:
		finish(RECOVER_TIME)
		return
	_animate()


# True if a sword hit on `side` right now should wait for the strike about to land ("beat"
# window only): it's close enough (HIT_EARLY), and parried, it breaks the guard there (a strike
# on the other side, or on both).
func holds_hit(side: int) -> bool:
	return Moves.value("bifrons_window") == "beat" and phase == Phase.STRIKING \
		and _next < _contacts.size() and _sides[_next] != side \
		and _contacts[_next] - _time <= HIT_EARLY


# True while the blade on `side` is committed to a strike (see COMMIT_TIME): from shortly before
# its drop until it lands.
func is_committed(side: int) -> bool:
	return not completed and _next < _contacts.size() and _sides[_next] in [side, BOTH] \
		and _contacts[_next] - _time <= COMMIT_TIME


# A sword hit on `side` while its blade is committed: true if it lands, which one hit per
# strike does.
func take_commit_hit(side: int) -> bool:
	var key = Vector2i(_next, side)
	if not is_committed(side) or _commit_hits.has(key):
		return false
	_commit_hits[key] = true
	return true


# --- The strikes ---

func _land(index: int):
	var side = _sides[index]
	var struck = [LEFT, RIGHT] if side == BOTH else [side]
	# Who parried, before anything lands: a parry of both blades is the strong kind.
	var under = {}
	var parriers = {}
	var stand_in = {}  # testing alone: the stand-in on that side parried it
	for s in struck:
		under[s] = _under_blade(s)
		parriers[s] = under[s].filter(func(p): return p.is_perfect_parry())
		stand_in[s] = boss.stand_in_side() == s and randf() < boss.STAND_IN_PARRY_CHANCE
		_parried[s] = not parriers[s].is_empty() or stand_in[s]
	var both = side == BOTH and _parried[LEFT] and _parried[RIGHT]

	for s in struck:
		for p in under[s]:
			if p in parriers[s]:
				p.on_perfect_parry(both)
				parry_success.emit(p, "bifrons_strike")
				strike_parried.emit(p)
				boss.spawn_sparks(p.global_position + Vector2(0.0, -24.0), 10, COLOR_PARRY)
			elif boss.stand_in_side() == s:
				pass  # testing alone: nobody on the stand-in's side is hurt
			elif p.is_blocking():
				p.take_damage(BLOCKED_DAMAGE, boss.knockback_for(p, BLOCKED_KNOCKBACK), true)
			else:
				p.take_damage(STRIKE_DAMAGE, boss.knockback_for(p, STRIKE_KNOCKBACK))
				boss.shake(5.0)
		if stand_in[s]:
			boss.show_stand_in_parry(s)
		elif not _parried[s]:
			Sfx.play("thunk", -6.0)  # the blade hitting the floor

	# What the strike does to his guard; sword hits held for this landing are settled with it.
	var window = Moves.value("bifrons_window")
	if both:
		both_parried.emit()
		boss.land_held(LEFT)
		boss.land_held(RIGHT)
		if boss.hp > 0.0:
			Sfx.play("counter_hit", -2.0)
			boss.shake(12.0)
			finish_with_stagger(BOTH_STAGGER_TIME)
	elif side == BOTH:
		boss.keep_guard(LEFT)
		boss.keep_guard(RIGHT)
	elif _parried[side]:
		boss.break_guard(-side, BREAK_TIME[window], BREAK_DELAY[window])
	else:
		boss.keep_guard(-side)


# The players a strike on `side` reaches: on that side of him, close enough. Height doesn't
# matter (the blade comes from above).
func _under_blade(side: int) -> Array:
	return players.filter(func(p):
		return is_instance_valid(p) and boss.side_of(p) == side \
			and absf(p.global_position.x - boss.global_position.x) <= REACH)


# How long strike `index`'s drop takes: FALL_TIME, less if the strike before leaves no room.
func _fall_time(index: int) -> float:
	var gap = _contacts[index] - (_contacts[index - 1] if index > 0 else 0.0)
	return minf(FALL_TIME, gap * 0.6)


# --- The blades, as a function of the time into the pattern ---

func _animate():
	if _next < _contacts.size() and _next > _sounded and _time >= _contacts[_next] - _fall_time(_next):
		_sounded = _next
		Sfx.play("swing", -3.0)  # the drop starting
	for side in [LEFT, RIGHT]:
		_pose_blade(side)


func _pose_blade(side: int):
	var last = _next - 1  # the strike that landed last, -1 before the first
	# Just landed: lying where it fell, or thrown back by the parry.
	if last >= 0 and _sides[last] in [side, BOTH] and _time - _contacts[last] < STICK_TIME:
		boss.pose_sword(side, boss.POSE_RECOIL if _parried[side] else boss.POSE_DOWN)
		boss.tint_sword(side, boss.COLOR_SWORD if _parried[side] else boss.COLOR_EXECUTE)
		boss.tint_side(side, boss.COLOR_EXECUTE, 0.0)
		return
	# This blade strikes next: up from the moment the strike before has landed, then the drop.
	if _next < _contacts.size() and _sides[_next] in [side, BOTH]:
		var from = _contacts[last] + STICK_TIME if last >= 0 else 0.0
		var fall_time = _fall_time(_next)
		var fall_start = _contacts[_next] - fall_time
		if boss.is_breaking(side) and fall_start - _time > RAISE_ROOM:
			# Its guard was just broken: still knocked aside, for as long as there's room.
			boss.pose_sword(side, boss.POSE_OPEN)
			boss.tint_sword(side, boss.COLOR_SWORD)
			boss.tint_side(side, COLOR, 0.0)
		elif _time >= fall_start:
			var drop = pow(clampf((_time - fall_start) / fall_time, 0.0, 1.0), FALL_POWER)
			boss.pose_sword(side, boss.POSE_COILED.lerp(boss.POSE_DOWN, drop), true)
			boss.tint_sword(side, boss.COLOR_EXECUTE)
			boss.tint_side(side, boss.COLOR_EXECUTE, 0.45)
		else:
			# Drawn further back the closer the drop is, faster toward the end, and trembling.
			if boss.is_breaking(side):
				from = maxf(from, fall_start - RAISE_ROOM)  # it only got to go up now
			var tension = clampf((_time - from) / maxf(fall_start - from, 0.01), 0.0, 1.0)
			var pose: Vector3 = boss.POSE_RAISED.lerp(boss.POSE_COILED, ease(tension, 2.0))
			pose.z += randf_range(-TREMBLE, TREMBLE) * tension
			boss.pose_sword(side, pose)
			boss.tint_sword(side, boss.COLOR_SWORD.lerp(COLOR, 0.4 + 0.6 * tension))
			boss.tint_side(side, COLOR, 0.1 + 0.3 * tension)
		return
	# Not its turn: guarding its flank.
	boss.pose_sword(side, boss.POSE_GUARD)
	boss.tint_sword(side, boss.COLOR_SWORD)
	boss.tint_side(side, COLOR, 0.0)
