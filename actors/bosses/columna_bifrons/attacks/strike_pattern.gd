class_name StrikePattern
extends Attack
## Yellow blade -> red. Columna Bifrons's main attack: a set series of sword strikes, each by
## his left sword, his right or both at once, landing on a beat. There's one instance per pattern
## (see ColumnaBifrons.PATTERNS); the boss says which way round each run goes
## (ColumnaBifrons.orient()) and how soon its first strike comes (first_wait()).
##
## A strike is aimed at the player its sword fights (ColumnaBifrons.ward_of()), and only they
## have to perfect parry it. The sword is drawn back, then comes in FALL_TIME: that's the cue,
## and both players read it. A parried strike breaks the guard of his *other* sword for a moment
## (ColumnaBifrons.break_guard()), and the other player's sword hit is a sync hit. Both swords
## at once come blue, and both parried stagger him.
##
## How a sword strikes:
## - down from over his head, when it's on the flank its hand is on;
## - level, from behind him and around, when it reaches across to the other flank (ppe);
## - a CHARGE is a thrust, and he follows it through past that player.
##
## A blade that's drawn back, coming, lying where it landed or thrown back by a parry isn't
## guarding: its player's hits land (see ColumnaBifrons.is_guarding()).

signal strike_parried(player)
signal both_parried

enum Phase { NONE, STRIKING }

const LEFT = -1
const RIGHT = 1
const BOTH = 0
const CUT = 0  # a strike's kind: the ordinary one...
const CHARGE = 1  # ...or a thrust that he follows through (see "THE CHARGE" in columna_bifrons.gd)

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
# THE PARTNER'S HIT. A parried strike breaks the other sword's guard BREAK_DELAY after the
# parry, for BREAK_TIME; by Moves "bifrons_window". A player's swing lands 0.08 s after its
# press (see ATTACK_WINDUP_TIME in player.gd), so the press has to come that much earlier:
# "beat": at once. Parry and hit are pressed together, the hitter betting on the parry: the
#   attack press has to come between 0.08 s before the strike lands and 0.17 s after.
# "after": a moment later, so a swing started on the strike itself is still parried, and the
#   hitter has to see the parry first: press 0.17 to 0.47 s after the strike landed.
const BREAK_DELAY = {"beat": 0.0, "after": 0.25}
const BREAK_TIME = {"beat": 0.25, "after": 0.3}
const BOTH_STAGGER_TIME = 2.2  # both swords parried at once
const RECOVER_TIME = 0.6
const TREMBLE = 0.05  # radians the drawn-back blade shakes by, just before the drop
# A blade is drawn back for its strike at least this long before its drop, whatever it was doing
# (thrown back, or waiting out a broken guard): it has to be there when the drop starts.
const RAISE_ROOM = 0.3
const CHARGE_LEAN = 12.0  # px his body rears back by before a charge

const COLOR = Color.YELLOW  # one sword: its player parries
const COLOR_TOGETHER = Color(0.3, 0.55, 1.0)  # both swords: parry together

var _name: String
var _strikes: Array  # as written in ColumnaBifrons.PATTERNS: [wait, sword] or [wait, sword, kind] each
var _contacts: Array = []  # when each strike lands this run, in seconds from the pattern's start
var _waits: Array = []  # this run's wait for each strike, in TIME_UNITs
var _swords: Array = []  # this run's sword for each strike (see ColumnaBifrons.orient())
var _kinds: Array = []  # CUT or CHARGE for each strike
var _time = 0.0  # seconds into the pattern
var _next = 0  # the strike that lands next
var _parried = {LEFT: false, RIGHT: false}  # how each blade's last strike went...
var _thrust = {LEFT: false, RIGHT: false}  # ...and whether it was a charge
var _sounded = -1  # the last strike whose drop has made its sound
var _drawn_since = {LEFT: -1.0, RIGHT: -1.0}  # when each blade was drawn back for the next strike (-1: not yet)
var _charge_at = -1.0  # when he follows a landed charge through (-1: none due), and with which sword
var _charge_sword = LEFT
var _back_off_at = -1.0  # when he backs off (-1: not due)


func _init(pattern_name: String, strikes: Array):
	_name = pattern_name
	_strikes = strikes
	_kinds = strikes.map(func(strike): return strike[2] if strike.size() > 2 else CUT)


func get_attack_name() -> String:
	return _name


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	var lead = boss.first_wait(_strikes[0][0])
	var way = boss.orient(_strikes)
	_swords = _strikes.map(func(strike): return strike[1] * way)
	_waits = []
	_contacts = []
	var landing = 0.0
	for i in _strikes.size():
		_waits.append(lead if i == 0 else _strikes[i][0])
		landing += _waits[i] * TIME_UNIT
		_contacts.append(landing)
	_time = 0.0
	_next = 0
	_parried = {LEFT: false, RIGHT: false}
	_thrust = {LEFT: false, RIGHT: false}
	_sounded = -1
	_drawn_since = {LEFT: -1.0, RIGHT: -1.0}
	_charge_at = -1.0
	_back_off_at = -1.0


# His body keeps its own color: the drawn blade, and that half of him, say whose strike it is.
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
		_drawn_since = {LEFT: -1.0, RIGHT: -1.0}
	var over = _next >= _contacts.size() and _time >= _contacts.back() + _rest_time(_swords.back())
	if _charge_at >= 0.0 and (_time >= _charge_at or over):
		_charge_at = -1.0
		boss.charge_through(_charge_sword)
	if _back_off_at >= 0.0 and (_time >= _back_off_at or over):
		_back_off_at = -1.0
		boss.back_off()
	if over:
		finish(RECOVER_TIME)
		return
	_animate()


# --- The strikes ---

func _land(index: int):
	var sword = _swords[index]
	var striking = [LEFT, RIGHT] if sword == BOTH else [sword]
	# Who parried, before anything lands: a parry of both blades is the strong kind.
	var judged = {}
	for blade in striking:
		judged[blade] = boss.judge(blade)
		_parried[blade] = judged[blade].parried
		_thrust[blade] = _kinds[index] == CHARGE
	var both = sword == BOTH and _parried[LEFT] and _parried[RIGHT]
	for blade in striking:
		boss.land(judged[blade], both)
		for p in judged[blade].parriers:
			parry_success.emit(p, "bifrons_strike")
			strike_parried.emit(p)

	if both:
		both_parried.emit()
		Sfx.play("counter_hit", -2.0)
		boss.shake(12.0)
		finish_with_stagger(BOTH_STAGGER_TIME)
		return
	if sword == BOTH:
		_back_off_at = _contacts[index] + boss.BACK_OFF_DELAY  # ppe only (the boss knows)
	elif _parried[sword]:
		var window = Moves.value("bifrons_window")
		boss.break_guard(-sword, BREAK_TIME[window], BREAK_DELAY[window])
	if _kinds[index] == CHARGE and sword != BOTH:
		_charge_at = _contacts[index] + boss.CHARGE_DELAY
		_charge_sword = sword
		boss.squash_body(Vector2.ONE)  # no longer rearing back


# How long strike `index`'s drop takes: FALL_TIME, less if the strike before leaves no room.
func _fall_time(index: int) -> float:
	var gap = _contacts[index] - (_contacts[index - 1] if index > 0 else 0.0)
	return minf(FALL_TIME, gap * 0.6)


# How long a blade stays where its last strike left it: STICK_TIME, RECOIL_TIME if it was
# parried, or all through a charge (thrust out, the point on its player as he passes them).
# For a strike of both: the longer of the two.
func _rest_time(sword: int) -> float:
	if sword == BOTH:
		return maxf(_rest_time(LEFT), _rest_time(RIGHT))
	if _parried[sword]:
		return RECOIL_TIME
	return boss.CHARGE_DELAY + boss.CHARGE_TIME if _thrust[sword] else STICK_TIME


# --- His blades (and his steps), as a function of the time into the pattern ---

func _animate():
	if _next < _contacts.size():
		var fall_start = _contacts[_next] - _fall_time(_next)
		if _next > _sounded and _time >= fall_start:
			_sounded = _next
			Sfx.play("stab" if _kinds[_next] == CHARGE else "swing", -3.0)  # the drop starting
		# A long windup brings him closer to the player it's for.
		if _swords[_next] != BOTH and _kinds[_next] == CUT and _waits[_next] >= boss.LONG_WINDUP \
				and _time < fall_start:
			boss.advance_on(_swords[_next])
	for blade in [LEFT, RIGHT]:
		_pose_blade(blade)


func _pose_blade(blade: int):
	var last = _next - 1  # the strike that landed last, -1 before the first
	var landed_here = last >= 0 and _swords[last] in [blade, BOTH]
	var resting = landed_here and _time - _contacts[last] < _rest_time(blade)
	var across = boss.reaches_across(blade)  # ppe: this one cuts level, from behind him
	if _next < _contacts.size() and _swords[_next] in [blade, BOTH]:
		# This blade strikes next.
		var thrust = _kinds[_next] == CHARGE
		var color = COLOR_TOGETHER if _swords[_next] == BOTH else COLOR
		var fall_time = _fall_time(_next)
		var fall_start = _contacts[_next] - fall_time
		if _time >= fall_start:
			var drop = pow(clampf((_time - fall_start) / fall_time, 0.0, 1.0), FALL_POWER)
			if thrust:
				boss.pose_sword(blade, boss.POSE_LANCE_BACK.lerp(boss.POSE_LANCE, drop), true)
				boss.squash_body(Vector2.ONE, -boss.blade_side(blade) * CHARGE_LEAN * (1.0 - drop))
			elif across:
				boss.pose_sword(blade, boss.POSE_SWEEP_BACK.lerp(boss.POSE_SWEEP, drop), true, lerpf(-1.0, 1.0, drop))
			else:
				boss.pose_sword(blade, boss.POSE_COILED.lerp(boss.POSE_DOWN, drop), true)
			boss.tint_sword(blade, boss.COLOR_EXECUTE)
			boss.tint_side(blade, boss.COLOR_EXECUTE, 0.45)
			return
		# It's drawn back once it's done lying where its last strike landed, and once its broken
		# guard is back; but in time for its drop, whatever else.
		var held_back = resting or boss.is_breaking(blade)
		if not held_back or _time >= fall_start - RAISE_ROOM:
			if _drawn_since[blade] < 0.0:
				_drawn_since[blade] = _time
			# Drawn further back the closer the drop is, faster toward the end, and trembling.
			var tension = clampf((_time - _drawn_since[blade]) / maxf(fall_start - _drawn_since[blade], 0.01), 0.0, 1.0)
			var pose: Vector3
			var over = 1.0
			if thrust:
				pose = boss.POSE_LANCE_LOW.lerp(boss.POSE_LANCE_BACK, ease(tension, 2.0))
				boss.squash_body(Vector2.ONE, -boss.blade_side(blade) * CHARGE_LEAN * tension)
			elif across:
				pose = boss.POSE_SWEEP_BACK
				over = -1.0
			else:
				pose = boss.POSE_RAISED.lerp(boss.POSE_COILED, ease(tension, 2.0))
			pose.z += randf_range(-TREMBLE, TREMBLE) * tension
			boss.pose_sword(blade, pose, false, over)
			boss.tint_sword(blade, boss.COLOR_SWORD.lerp(color, 0.4 + 0.6 * tension))
			boss.tint_side(blade, color, 0.1 + 0.3 * tension)
			return
	if resting:
		# Just landed: lying where it came down, or thrown back by the parry.
		var landed = boss.POSE_DOWN
		if _kinds[last] == CHARGE:
			landed = boss.POSE_LANCE
		elif across:
			landed = boss.POSE_SWEEP
		boss.pose_sword(blade, boss.POSE_RECOIL if _parried[blade] else landed)
		boss.tint_sword(blade, boss.COLOR_SWORD if _parried[blade] else boss.COLOR_EXECUTE)
		boss.tint_side(blade, COLOR, 0.0)
		return
	# Guarding its flank (the boss knocks it aside while that guard is broken).
	boss.pose_sword(blade, boss.POSE_GUARD)
	boss.tint_sword(blade, boss.COLOR_SWORD)
	boss.tint_side(blade, COLOR, 0.0)
