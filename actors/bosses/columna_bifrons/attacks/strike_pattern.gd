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
## at once come green, and parried by both players they stagger him.
##
## How a sword strikes:
## - down from over his head, when it's on the flank its hand is on;
## - lower and on a slant, from its own flank around his front, when it reaches across to the
##   other flank (ppe);
## - a CHARGE is a thrust, and he follows it through past that player;
## - a RUSH is a cut at a player who's far away: he dashes over to them as it comes.
##
## He moves while he strikes (see "Moving" in columna_bifrons.gd): walking to his place at a
## slower pace, or at the player a long windup is for, and with every cut a lunge at the player
## it's for, as the blade comes. A strike whose player is out of his range is left out.
##
## A blade that's drawn back, coming, lying where it landed or thrown back by a parry isn't
## guarding: its player's hits land (see ColumnaBifrons.is_guarding()).

signal strike_parried(player)
signal both_parried

enum Phase { NONE, STRIKING }
# His feet through a strike's windup. NONE: walking to his place, as ever. A long windup:
# WALKING at the strike's player, and once he has reached them, ARRIVED: standing there.
enum Advance { NONE, WALKING, ARRIVED }

const LEFT = -1
const RIGHT = 1
const BOTH = 0
const CUT = 0  # a strike's kind: the ordinary one...
const CHARGE = 1  # ...a thrust that he follows through (see "THE CHARGE" in columna_bifrons.gd)...
const RUSH = 2  # ...or a cut he dashes across the room with (see "LEFT ALONE" there)

# --- Tuning ---
# One unit of a strike's `wait` (see ColumnaBifrons.PATTERNS), in seconds: the tempo of every
# pattern at once. 4 units between strikes is 0.8 s.
const TIME_UNIT = 0.2
# The blade's drop, from drawn back to landing: the cue to press. A strike that follows the one
# before too closely for this (a wait under 3) drops faster, and gets hard to read.
const FALL_TIME = 0.28
const FALL_POWER = 1.7  # the drop starts slow and lands fast (1 = constant speed); his lunge too
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
const BOTH_STAGGER_TIME = 2.2  # both swords parried at once, by both players
# BOTH SWORDS ON ONE PLAYER (the other one is away): one heavy strike. One parry meets it, and
# doesn't stagger him.
const HEAVY_DAMAGE = 2.0  # times a strike's damage...
const HEAVY_KNOCKBACK = 1.5  # ...and its knockback
const RECOVER_TIME = 0.6
const TREMBLE = 0.05  # radians the drawn-back blade shakes by, just before the drop
# A blade is drawn back for its strike at least this long before its drop, whatever it was doing
# (thrown back, or waiting out a broken guard): it has to be there when the drop starts.
const RAISE_ROOM = 0.3
# The sword that reaches across (ppe): how far into its drop it has come around to the players'
# side, and from where on it comes down.
const SLASH_AROUND = 0.55
const SLASH_DOWN = 0.35
const CHARGE_LEAN = 24.0  # px his body rears back by before a charge...
const RUSH_LEAN = 14.0  # ...and before a rush
# A lunge longer than this is a dash: his body stretches with it.
const DASH_LENGTH = 50.0
const DASH_STRETCH = Vector2(1.14, 0.92)

const COLOR = Color.YELLOW  # one sword: its player parries
const COLOR_TOGETHER = Color(0.25, 1.0, 0.45)  # both swords: parry together

var _name: String
var _strikes: Array  # as written in ColumnaBifrons.PATTERNS: [wait, sword] or [wait, sword, kind] each
# This run's strikes, one entry each (a strike that's left out is taken out of all four):
var _contacts: Array = []  # when it lands, in seconds from the pattern's start
var _waits: Array = []  # its wait, in TIME_UNITs
var _swords: Array = []  # its sword (see ColumnaBifrons.orient())
var _kinds: Array = []  # CUT, CHARGE or RUSH
var _time = 0.0  # seconds into the pattern
var _next = 0  # the strike that lands next
var _parried = {LEFT: false, RIGHT: false}  # how each blade's last strike went...
var _thrust = {LEFT: false, RIGHT: false}  # ...and whether it was a charge
var _sounded = -1.0  # the landing time of the last strike whose drop has made its sound
var _drawn_since = {LEFT: -1.0, RIGHT: -1.0}  # when each blade was drawn back for the next strike (-1: not yet)
var _charge_at = -1.0  # when he follows a landed charge through (-1: none due), and with which sword
var _charge_sword = LEFT
var _back_off_at = -1.0  # when he backs off (-1: not due)
var _advance = Advance.NONE  # how he gets through the next strike's windup
var _lunge = null  # {from, to}: the next strike's lunge, once it's under way


func _init(pattern_name: String, strikes: Array):
	_name = pattern_name
	_strikes = strikes


func get_attack_name() -> String:
	return _name


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	var lead = boss.first_wait(_strikes[0][0])
	var way = boss.orient(_strikes)
	_swords = _strikes.map(func(strike): return strike[1] * way)
	_kinds = _strikes.map(func(strike): return strike[2] if strike.size() > 2 else CUT)
	_waits = _strikes.map(func(strike): return strike[0])
	_waits[0] = lead
	_contacts = _waits.duplicate()
	_time = 0.0
	_next = 0
	_schedule(0)
	_parried = {LEFT: false, RIGHT: false}
	_thrust = {LEFT: false, RIGHT: false}
	_sounded = -1.0
	_drawn_since = {LEFT: -1.0, RIGHT: -1.0}
	_charge_at = -1.0
	_back_off_at = -1.0
	_begin_strike()


# His body keeps its own color: the drawn blade, and that half of him, say whose strike it is.
func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


# The telegraph is the first strike's windup, up to its drop.
func get_telegraph_duration() -> float:
	if _contacts.is_empty():
		return 0.01  # nobody to strike: over at once
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
		_begin_strike()
	var over = _next >= _contacts.size() \
		and (_contacts.is_empty() or _time >= _contacts.back() + _rest_time(_swords.back()))
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


# Seconds until this pattern's next strike lands on that player; INF if it isn't for them.
func time_to_strike(player) -> float:
	if _next >= _contacts.size():
		return INF
	for blade in [LEFT, RIGHT]:
		if _swords[_next] in [blade, BOTH] and boss.ward_of(blade) == player:
			return _contacts[_next] - _time
	return INF


# --- The strikes ---

# Strike `_next` is the next one now: is its player there at all?
func _begin_strike():
	_lunge = null
	_leave_out_absent()
	var long = _next < _contacts.size() and _swords[_next] != BOTH and _kinds[_next] == CUT \
		and _waits[_next] >= boss.LONG_WINDUP
	_advance = Advance.WALKING if long else Advance.NONE


# A strike whose player is out of his range (ColumnaBifrons.STRIKE_RANGE) as it becomes the
# next one is left out, and what follows comes that much sooner. Of a strike of both swords
# the one whose player is there is left. A rush is what he has for a player who's away.
func _leave_out_absent():
	while _next < _contacts.size() and _kinds[_next] != RUSH:
		var sword = _swords[_next]
		var there = [LEFT, RIGHT].filter(func(blade): return sword in [blade, BOTH] and boss.can_strike(blade))
		if not there.is_empty():
			if sword == BOTH and there.size() == 1:
				_swords[_next] = there[0]
			return
		# A pattern's first strike keeps the longer windup of the two.
		if _next == 0 and _waits.size() > 1:
			_waits[1] = maxf(_waits[1], _waits[0])
		for list in [_contacts, _waits, _swords, _kinds]:
			list.remove_at(_next)
		_schedule(_next)


# The landing times of the strikes from `index` on, by their waits.
func _schedule(index: int):
	var landing = _contacts[index - 1] if index > 0 else 0.0
	for i in range(index, _waits.size()):
		landing += _waits[i] * TIME_UNIT
		_contacts[i] = landing


func _land(index: int):
	if _lunge != null:
		boss.global_position.x = _lunge.to  # he's there as the blade lands
		_lunge = null
	var sword = _swords[index]
	var striking = [LEFT, RIGHT] if sword == BOTH else [sword]
	var heavy = sword == BOTH and boss.ward_of(LEFT) == boss.ward_of(RIGHT)  # both on one player
	# Who parried, before anything lands: a parry of both blades is the strong kind.
	var judged = {}
	for blade in striking:
		judged[blade] = judged[LEFT] if heavy and blade == RIGHT else boss.judge(blade)
		_parried[blade] = judged[blade].parried
		_thrust[blade] = _kinds[index] == CHARGE
	var both = sword == BOTH and _parried[LEFT] and _parried[RIGHT]
	for blade in ([LEFT] if heavy else striking):
		if heavy:
			boss.land(judged[blade], true, HEAVY_DAMAGE, HEAVY_KNOCKBACK)
		else:
			boss.land(judged[blade], both)
		for p in judged[blade].parriers:
			parry_success.emit(p, "bifrons_strike")
			strike_parried.emit(p)

	if both and not heavy:
		both_parried.emit()
		Sfx.play("counter_hit", -2.0)
		boss.shake(12.0)
		finish_with_stagger(BOTH_STAGGER_TIME)
		return
	if sword == BOTH:
		if not both:
			_back_off_at = _contacts[index] + boss.BACK_OFF_DELAY  # if the players are on one side
	elif _parried[sword]:
		var window = Moves.value("bifrons_window")
		boss.break_guard(-sword, BREAK_TIME[window], BREAK_DELAY[window], judged[sword].parriers[0])
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


# --- His feet and his blades, as a function of the time into the pattern ---

func _animate():
	var delta = boss.get_physics_process_delta_time()
	if _next < _contacts.size():
		var landing = _contacts[_next]
		if landing > _sounded and _time >= landing - _fall_time(_next):
			_sounded = landing
			Sfx.play("stab" if _kinds[_next] == CHARGE else "swing", -3.0)  # the drop starting
		_move(delta)
	for blade in [LEFT, RIGHT]:
		_pose_blade(blade)


# His feet, for the strike that's next: walking to his place (or at the strike's player, through
# a long windup), and as the blade comes, the lunge. For a charge he stands: he follows it
# through afterwards. And he stands while the blade of his last strike lies where it landed
# (or is thrown back): that's when the players hit him.
func _move(delta: float):
	var kind = _kinds[_next]
	if kind == CHARGE:
		return
	var lunge_time = boss.RUSH_TIME if kind == RUSH else _fall_time(_next)
	var since = _time - (_contacts[_next] - lunge_time)
	if since < 0.0:
		if _next > 0 and _time - _contacts[_next - 1] < _rest_time(_swords[_next - 1]):
			return
		if _advance == Advance.NONE:
			boss.walk(delta, boss.ATTACK_PACE)
		elif _advance == Advance.WALKING and not boss.advance_on(_swords[_next], delta):
			_advance = Advance.ARRIVED
		return
	if boss.is_dashing():
		return  # still backing off, or following a charge through
	if _lunge == null:
		var from = boss.global_position.x
		_lunge = {"from": from, "to": boss.lunge_goal(_swords[_next], kind == RUSH)}
		if kind == RUSH:
			boss.ghost(lunge_time)
			Sfx.play("launch", -5.0)
		if absf(_lunge.to - from) > DASH_LENGTH:
			boss.pop_body(DASH_STRETCH, lunge_time)
	boss.global_position.x = lerpf(_lunge.from, _lunge.to, pow(clampf(since / lunge_time, 0.0, 1.0), FALL_POWER))


func _pose_blade(blade: int):
	var last = _next - 1  # the strike that landed last, -1 before the first
	var landed_here = last >= 0 and _swords[last] in [blade, BOTH]
	var resting = landed_here and _time - _contacts[last] < _rest_time(blade)
	var across = boss.reaches_across(blade)  # ppe: this one cuts on a slant, around his front
	if _next < _contacts.size() and _swords[_next] in [blade, BOTH]:
		# This blade strikes next.
		var kind = _kinds[_next]
		var color = COLOR_TOGETHER if _swords[_next] == BOTH else COLOR
		var fall_time = _fall_time(_next)
		var fall_start = _contacts[_next] - fall_time
		var back = -boss.blade_side(blade)  # the way he rears back: away from its player
		if _time >= fall_start:
			var drop = pow(clampf((_time - fall_start) / fall_time, 0.0, 1.0), FALL_POWER)
			if kind == CHARGE:
				boss.pose_sword(blade, boss.POSE_LANCE_BACK.lerp(boss.POSE_LANCE, drop), true)
				boss.squash_body(Vector2.ONE, back * CHARGE_LEAN * (1.0 - drop))
			elif across:
				# Around his front at shoulder height first, then down on a slant.
				var around = smoothstep(0.0, SLASH_AROUND, drop)
				var down = smoothstep(SLASH_DOWN, 1.0, drop)
				boss.pose_sword(blade, boss.POSE_SLASH_BACK.lerp(boss.POSE_DOWN, down), true, lerpf(-1.0, 1.0, around))
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
			# Drawn further back the closer the drop is, and trembling.
			var tension = clampf((_time - _drawn_since[blade]) / maxf(fall_start - _drawn_since[blade], 0.01), 0.0, 1.0)
			var pose: Vector3
			var over = 1.0
			if kind == CHARGE:
				# Lowered at the player, then drawn far back, quickly, and held there.
				var draw = smoothstep(0.2, 0.75, tension)
				pose = boss.POSE_LANCE_LOW.lerp(boss.POSE_LANCE_BACK, draw)
				boss.squash_body(Vector2.ONE, back * CHARGE_LEAN * draw)
			elif across:
				pose = boss.POSE_SLASH_BACK
				over = -1.0
			else:
				pose = boss.POSE_RAISED.lerp(boss.POSE_COILED, ease(tension, 2.0))
			if kind == RUSH and _lunge == null:
				boss.squash_body(Vector2.ONE, back * RUSH_LEAN * tension)
			pose.z += randf_range(-TREMBLE, TREMBLE) * tension
			boss.pose_sword(blade, pose, false, over)
			boss.tint_sword(blade, boss.COLOR_SWORD.lerp(color, 0.4 + 0.6 * tension))
			boss.tint_side(blade, color, 0.1 + 0.3 * tension)
			return
	if resting:
		# Just landed: lying where it came down, or thrown back by the parry.
		var landed = boss.POSE_LANCE if _kinds[last] == CHARGE else boss.POSE_DOWN
		boss.pose_sword(blade, boss.POSE_RECOIL if _parried[blade] else landed)
		boss.tint_sword(blade, boss.COLOR_SWORD if _parried[blade] else boss.COLOR_EXECUTE)
		boss.tint_side(blade, COLOR, 0.0)
		return
	# Guarding its flank (the boss knocks it aside while that guard is broken).
	boss.pose_sword(blade, boss.POSE_GUARD)
	boss.tint_sword(blade, boss.COLOR_SWORD)
	boss.tint_side(blade, COLOR, 0.0)
