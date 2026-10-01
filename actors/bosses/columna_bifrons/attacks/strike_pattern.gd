class_name StrikePattern
extends Attack
## Yellow blade -> red. Columna Bifrons's main attack: a set series of sword strikes, each on
## his left, his right or both sides at once, landing on a beat. There's one instance per pattern
## (see ColumnaBifrons.PATTERNS); the boss says which way round each run goes
## (ColumnaBifrons.orient()) and how soon its first strike comes (first_wait()).
##
## A strike: that side's blade goes up over his head (so the side says who has to parry), is
## drawn back there, then drops in FALL_TIME. The drop is the cue, and both players read it:
## everyone under the blade when it lands must perfect parry it, and a parried strike breaks his
## guard on the *other* side for a moment (ColumnaBifrons.break_guard()), where the partner's
## sword hit is a sync hit. Both blades parried at once stagger him.
##
## A blade that's up, dropping, lying where it landed or thrown back by a parry isn't guarding
## its flank: sword hits on that side land (see ColumnaBifrons.is_guarding()).

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
# After landing, the blade stays where it is this long before it goes back to its flank (or up
# again): lying on the floor, or thrown back by a parry, which takes it longer to get over.
const STICK_TIME = 0.12
const RECOIL_TIME = 0.35
# THE PARTNER'S HIT. A parried strike breaks the guard on the other side BREAK_DELAY after the
# parry, for BREAK_TIME; by Moves "bifrons_window". A player's swing lands 0.08 s after its
# press (see ATTACK_WINDUP_TIME in player.gd), so the press has to come that much earlier:
# "beat": at once. Parry and hit are pressed together, the hitter betting on the parry: the
#   attack press has to come between 0.08 s before the strike lands and 0.17 s after.
# "after": a moment later, so a swing started on the strike itself is still parried, and the
#   hitter has to see the parry first: press 0.17 to 0.47 s after the strike landed.
const BREAK_DELAY = {"beat": 0.0, "after": 0.25}
const BREAK_TIME = {"beat": 0.25, "after": 0.3}
const BOTH_STAGGER_TIME = 2.2  # both blades parried at once
const RECOVER_TIME = 0.6
const TREMBLE = 0.05  # radians the drawn-back blade shakes by, just before the drop
# A blade goes up for its strike at least this long before its drop, whatever it was doing
# (thrown back, or waiting out a broken guard): it has to be up there when the drop starts.
const RAISE_ROOM = 0.3

const COLOR = Color.YELLOW

var _name: String
var _strikes: Array  # as written in ColumnaBifrons.PATTERNS: [wait, side] each
var _contacts: Array = []  # when each strike lands this run, in seconds from the pattern's start
var _sides: Array = []  # this run's side for each strike (see ColumnaBifrons.orient())
var _time = 0.0  # seconds into the pattern
var _next = 0  # the strike that lands next
var _parried = {LEFT: false, RIGHT: false}  # how each blade's last strike went
var _sounded = -1  # the last strike whose drop has made its sound
var _up_since = {LEFT: -1.0, RIGHT: -1.0}  # when each blade went up for the next strike (-1: not yet)


func _init(pattern_name: String, strikes: Array):
	_name = pattern_name
	_strikes = strikes


func get_attack_name() -> String:
	return _name


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	var lead = boss.first_wait(_strikes[0][0])
	var way = boss.orient(_strikes)
	_sides = _strikes.map(func(strike): return strike[1] * way)
	_contacts = []
	var landing = 0.0
	for i in _strikes.size():
		landing += (lead if i == 0 else _strikes[i][0]) * TIME_UNIT
		_contacts.append(landing)
	_time = 0.0
	_next = 0
	_parried = {LEFT: false, RIGHT: false}
	_sounded = -1
	_up_since = {LEFT: -1.0, RIGHT: -1.0}


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
		_up_since = {LEFT: -1.0, RIGHT: -1.0}
	if _next >= _contacts.size() and _time >= _contacts.back() + _rest_time(_sides.back()):
		finish(RECOVER_TIME)
		return
	_animate()


# --- The strikes ---

func _land(index: int):
	var side = _sides[index]
	var struck = [LEFT, RIGHT] if side == BOTH else [side]
	# Who parried, before anything lands: a parry of both blades is the strong kind.
	var judged = {}
	for s in struck:
		judged[s] = boss.judge(s, players)
		_parried[s] = judged[s].parried
	var both = side == BOTH and _parried[LEFT] and _parried[RIGHT]
	for s in struck:
		boss.land(judged[s], both)
		for p in judged[s].parriers:
			parry_success.emit(p, "bifrons_strike")
			strike_parried.emit(p)

	if both:
		both_parried.emit()
		Sfx.play("counter_hit", -2.0)
		boss.shake(12.0)
		finish_with_stagger(BOTH_STAGGER_TIME)
	elif side != BOTH and _parried[side]:
		var window = Moves.value("bifrons_window")
		boss.break_guard(-side, BREAK_TIME[window], BREAK_DELAY[window])


# How long strike `index`'s drop takes: FALL_TIME, less if the strike before leaves no room.
func _fall_time(index: int) -> float:
	var gap = _contacts[index] - (_contacts[index - 1] if index > 0 else 0.0)
	return minf(FALL_TIME, gap * 0.6)


# How long a blade stays where its last strike left it (STICK_TIME, or RECOIL_TIME if parried).
# For a strike on both sides: the longer of the two.
func _rest_time(side: int) -> float:
	if side == BOTH:
		return maxf(_rest_time(LEFT), _rest_time(RIGHT))
	return RECOIL_TIME if _parried[side] else STICK_TIME


# --- The blades, as a function of the time into the pattern ---

func _animate():
	if _next < _contacts.size() and _next > _sounded and _time >= _contacts[_next] - _fall_time(_next):
		_sounded = _next
		Sfx.play("swing", -3.0)  # the drop starting
	for side in [LEFT, RIGHT]:
		_pose_blade(side)


func _pose_blade(side: int):
	var last = _next - 1  # the strike that landed last, -1 before the first
	var landed_here = last >= 0 and _sides[last] in [side, BOTH]
	var resting = landed_here and _time - _contacts[last] < _rest_time(side)
	if _next < _contacts.size() and _sides[_next] in [side, BOTH]:
		# This blade strikes next.
		var fall_time = _fall_time(_next)
		var fall_start = _contacts[_next] - fall_time
		if _time >= fall_start:
			var drop = pow(clampf((_time - fall_start) / fall_time, 0.0, 1.0), FALL_POWER)
			boss.pose_sword(side, boss.POSE_COILED.lerp(boss.POSE_DOWN, drop), true)
			boss.tint_sword(side, boss.COLOR_EXECUTE)
			boss.tint_side(side, boss.COLOR_EXECUTE, 0.45)
			return
		# It goes up once it's done lying where its last strike landed, and once a broken guard
		# on its side is back; but in time for its drop, whatever else.
		var held_back = resting or boss.is_breaking(side)
		if not held_back or _time >= fall_start - RAISE_ROOM:
			if _up_since[side] < 0.0:
				_up_since[side] = _time
			# Drawn further back the closer the drop is, faster toward the end, and trembling.
			var tension = clampf((_time - _up_since[side]) / maxf(fall_start - _up_since[side], 0.01), 0.0, 1.0)
			var pose: Vector3 = boss.POSE_RAISED.lerp(boss.POSE_COILED, ease(tension, 2.0))
			pose.z += randf_range(-TREMBLE, TREMBLE) * tension
			boss.pose_sword(side, pose)
			boss.tint_sword(side, boss.COLOR_SWORD.lerp(COLOR, 0.4 + 0.6 * tension))
			boss.tint_side(side, COLOR, 0.1 + 0.3 * tension)
			return
	if resting:
		# Just landed: lying where it fell, or thrown back by the parry.
		boss.pose_sword(side, boss.POSE_RECOIL if _parried[side] else boss.POSE_DOWN)
		boss.tint_sword(side, boss.COLOR_SWORD if _parried[side] else boss.COLOR_EXECUTE)
		boss.tint_side(side, COLOR, 0.0)
		return
	# Guarding its flank (the boss knocks it aside while that guard is broken).
	boss.pose_sword(side, boss.POSE_GUARD)
	boss.tint_sword(side, boss.COLOR_SWORD)
	boss.tint_side(side, COLOR, 0.0)
