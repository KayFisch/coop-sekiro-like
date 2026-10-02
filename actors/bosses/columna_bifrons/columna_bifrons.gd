class_name ColumnaBifrons
extends BaseBoss
## Columna Bifrons, the two-faced column: a test boss for fights fought from both sides at once
## (player - boss - player, "pep" below), and for what becomes of that when both players end up
## on one side of him ("ppe"). The state machine lives in BaseBoss, the attacks in attacks/;
## what's his own is here: which attacks come and how often, his two swords and whom they fight,
## his guard, how he moves, and how he answers being attacked.
##
## THE RULES, the same that hold for the players' swords (see "THE SWORD" in player.gd):
## 1. Each of his swords fights one player (its "ward"): it points at them, strikes at them and
##    guards against them, on whichever side of him they are. A player on each side: a sword on
##    each side. Both on one side: both swords there.
## 2. A blade guards or swings. While it stands at its flank it parries every sword hit of its
##    player. While it's up for a strike, dropping, lying where it landed, thrown back by a
##    parry, or away (the sweep), it can't: hits land, as many as fit.
## 3. A parried swing recoils: a player's blade is knocked back by his guard, his own is thrown
##    back by a player's perfect parry, and either takes longer to come back.
## 4. A strike that's perfect parried breaks the guard of his *other* sword for a moment, and
##    the other player's hits are sync hits: more damage, and sync.
## 5. Both swords parried at once stagger him: no guard at all.
##
## TWO MODES (Moves "bifrons_mode"), one set of attacks. "patterns": he runs one attack after
## another, and the players' part is to answer them. "reactive": he leaves a little more room
## between them, and a hit he parries calls up his next attack at once, aimed at whoever
## attacked him.
## docs/boss_columna_bifrons.md has the design and what it's meant to find out.

const LEFT = StrikePattern.LEFT
const RIGHT = StrikePattern.RIGHT
const BOTH = StrikePattern.BOTH
const CUT = StrikePattern.CUT
const CHARGE = StrikePattern.CHARGE
const BLADES = [LEFT, RIGHT]  # his two swords, named for the hand that holds each
const SIDES = [LEFT, RIGHT]

# --- Tuning ---
const MAX_HP = 1600.0

# The strike patterns: how often each comes, relative to the others (0 disables it), and its
# strikes in order, as [wait, sword] or [wait, sword, kind]. `wait` is the time until the strike
# lands, counted from the pattern's start or from the strike before, in StrikePattern.TIME_UNITs:
# a rough 1-10 scale, where 4 is a quick follow-up and 9 a long windup (under 3 is too quick to
# read). `sword` is LEFT, RIGHT or BOTH: which of his swords strikes, at its own player. `kind`
# is CUT (the default) or CHARGE (see "THE CHARGE" below). Each pattern is written once and also
# comes mirrored (MIRROR_PATTERNS).
const PATTERNS = {
	"SINGLE": {"weight": 1.0, "strikes": [[5, LEFT]]},
	"TRIPLE": {"weight": 3.0, "strikes": [[5, RIGHT], [4, RIGHT], [4, LEFT]]},
	"QUAD": {"weight": 2.0, "strikes": [[7, LEFT], [4, LEFT], [4, RIGHT], [4, BOTH]]},
	"LONG": {"weight": 1.0, "strikes": [
		[9, RIGHT], [4, RIGHT], [4, LEFT], [4, RIGHT], [4, RIGHT], [4, LEFT], [4, BOTH]]},
	# He charges past one player, so both are on one side of him, and brings both swords down
	# on them. Only with a player on each side (pep).
	"CROSSING": {"weight": 1.5, "pep_only": true, "strikes": [[6, RIGHT, CHARGE], [6, BOTH]]},
	# Building blocks, off for now: the smallest swap of roles, and a lone strike of both swords.
	"SWAP": {"weight": 0.0, "strikes": [[5, LEFT], [4, RIGHT]]},
	"BOTH": {"weight": 0.0, "strikes": [[6, BOTH]]},
}
const SWEEP_WEIGHT = 1.5  # the sweep (attacks/sweep.gd) comes among the patterns, in pep only
# The leap (attacks/leap.gd) comes among the patterns in ppe only: it's how he gets the players
# back on both sides. The patterns' weights add up to 7 there, so this is how long ppe lasts:
# at 7, every other attack is the leap.
const LEAP_WEIGHT = 7.0
# Patterns that may come twice in a row; the rest never repeat back to back.
const REPEATABLE_PATTERNS = ["SINGLE", "TRIPLE"]
# Runs each pattern as written or mirrored, whichever keeps the strikes even between his two
# swords (at random while they're even). Off: always as written.
const MIRROR_PATTERNS = true
# For testing: set to an attack's name (e.g. "TRIPLE", "SWEEP", "LEAP") to use only that one.
const TEST_ONLY_PATTERN = ""

# THE REACTIVE MODE. Between two attacks he waits REACTIVE_WAIT (after the usual recovery)
# before starting the next of his own: a little room for the players to start instead. Every
# hit he parries, at any time, counts toward his patience: one of PATIENCE's numbers, picked
# afresh with every attack. Once that many are parried and he's free, he strikes back at the
# player whose hit he parried last: with one of the same attacks, turned so its first strike is
# theirs, and that strike comes quickly (ANSWER_WAIT). Then the series runs to its end, as ever.
const REACTIVE_WAIT_MIN = 0.5
const REACTIVE_WAIT_MAX = 1.2
const PATIENCE = [1, 1, 2]
const ANSWER_WAIT = 4  # StrikePattern.TIME_UNITs until an answer's first strike lands, at most

# --- Moving ---
# HE WALKS between his attacks, never during one:
# - up to a player who has got away from him: CHASE_SLACK beyond his blades' reach, or out of
#   reach with nobody else in it (the nearer one, if both are). Sword hits slow him down for a
#   moment, so the partner can hold him back;
# - else toward the middle third of the room, as far as he can go without leaving a player out
#   of reach; faster from the room's outer fifths. A player in his way is pushed along.
# He starts an attack only while a player is in reach.
const WALK_SPEED = 110.0  # px/s
const RECENTER_SPEED = 55.0
const RECENTER_SPEED_OUTER = 110.0
const SLOWED_FACTOR = 0.3  # of his walking speed, for SLOWED_TIME after a sword hit
const SLOWED_TIME = 0.6
const CHASE_SLACK = 40.0
const REACH_MARGIN = 30.0  # he walks until a player is this far inside his reach
const REACH_RECHECK = 0.2  # nobody in reach when an attack is due: he looks again this much later
const WALL_ROOM = 90.0  # his flanks stay this far from the walls: room for both players behind him
# A LONG WINDUP (a single strike with a wait of LONG_WINDUP or more) brings him up to the
# player it's for, if they aren't next to him, so both players have to move with him.
const LONG_WINDUP = 6
const STEP_SPEED = 120.0
# THE CHARGE (a strike of kind CHARGE): a thrust, to be parried like any strike, and CHARGE_DELAY
# after it lands he follows it through, CHARGE_DISTANCE in CHARGE_TIME, his body no obstacle
# meanwhile. A player close enough is passed and ends up on his other side: both players on one
# side (ppe). One who backs off ahead of him, or stands too far away, isn't.
const CHARGE_DISTANCE = 190.0
const CHARGE_DELAY = 0.1
const CHARGE_TIME = 0.25
const CHARGE_MIN_ROOM = 130.0  # he charges toward the side that has at least this much room
# PPE: after a strike of both swords that didn't stagger him he backs off from the players.
const BACK_OFF_DISTANCE = 110.0
const BACK_OFF_DELAY = 0.1
const BACK_OFF_TIME = 0.2

# A blade landing on a player (any of his attacks).
const BLADE_REACH = 215.0  # from his center: a player this close is in his blades' reach
const BLADE_DAMAGE = 12.0
const BLADE_KNOCKBACK = 300.0
const BLOCKED_DAMAGE = 4.0
const BLOCKED_KNOCKBACK = 150.0
const SYNC_HIT_FACTOR = 2.5  # a sync hit's damage, times the sword hit's own
# TESTING ALONE (Moves "bifrons_stand_in"): a stand-in plays the player who starts on that side.
# It parries that player's sword this often, and that player is never hurt (nor walked up to).
# Below 1 it misses some, so the other player has to watch whether the parry came before hitting.
const STAND_IN_PARRY_CHANCE = 0.75

# The swords, each on a pivot at its hand.
const SWORD_LENGTH = 170.0
const SWORD_WIDTH = 12.0
const SWORD_FOLLOW = 22.0  # how fast a blade eases into its pose (1/s); a drop itself is exact
const PLATE_WIDTH = 6.0  # the guard, drawn down the flank a blade is guarding
const PARRY_FLICK_TIME = 0.12  # his own parry: the guarding blade flicked at the attacker
# A blade counts as back at its flank, guarding, once it's this close to its guard pose.
const GUARD_NEAR = Vector2(10.0, 0.2)  # px, radians
# Sword poses, for a sword on his right (on his left they're mirrored): x, y = where the hand
# is, from his center; z = the blade's angle in radians (0 points outward, level; negative is up).
const POSE_GUARD = Vector3(42.0, 46.0, -1.571)  # upright, covering its flank
const POSE_PARRY = Vector3(52.0, 38.0, -1.2)  # flicked outward, meeting a player's blade
const POSE_RAISED = Vector3(34.0, -52.0, -1.82)  # over his head, about to strike
const POSE_COILED = Vector3(30.0, -58.0, -2.07)  # drawn all the way back: the drop starts here
const POSE_DOWN = Vector3(36.0, 43.0, 0.19)  # landed: out from his flank at head height, tip on the floor
const POSE_RECOIL = Vector3(42.0, 15.0, -0.9)  # thrown back up by a parry
const POSE_OPEN = Vector3(50.0, 30.0, -1.02)  # guard broken: knocked outward, off the flank
const POSE_LIMP = Vector3(44.0, 53.0, 0.13)  # staggered or dead: dropped to the floor
const POSE_SWEEP_BACK = Vector3(46.0, 27.0, -0.75)  # a level cut's windup: held out to the side, drawn back
const POSE_SWEEP = Vector3(40.0, 40.0, 0.0)  # cutting level, at head height
const POSE_PROP = Vector3(44.0, -82.0, 1.18)  # planted in the floor out to the side, his weight on it
const POSE_LANCE_LOW = Vector3(40.0, 44.0, -0.3)  # the charge's windup: lowered, pointing at the player...
const POSE_LANCE_BACK = Vector3(10.0, 44.0, -0.06)  # ...and drawn back into him, level
const POSE_LANCE = Vector3(62.0, 44.0, 0.0)  # thrust out
const POSE_STAB = Vector3(40.0, -95.0, 1.5)  # the leap: held high, pointing straight down past his feet
# PPE, both swords on one side: the one whose hand is on the other flank reaches across. It
# stands outside the other one, leaning out (this is added to its guard poses), and it cuts
# level, from behind him, where the other comes down from above (see StrikePattern).
const ACROSS_SHIFT = Vector3(16.0, -16.0, 0.28)
const ACROSS_POSES = [POSE_GUARD, POSE_PARRY, POSE_OPEN]

const COLOR_SWORD = Color(0.8, 0.82, 0.86)  # silver
const COLOR_SWORD_LIMP = Color(0.45, 0.45, 0.5)
const COLOR_PLATE = Color(0.62, 0.64, 0.7)
const COLOR_OPEN = Color(1.0, 0.95, 0.6)  # "hit here, now": a broken guard's flank, flashing
const COLOR_PARRY = Color(1.0, 0.7, 0.3)  # sparks off his own parry
const COLOR_PLAYER_PARRY = Color(1.0, 0.85, 0.4)  # sparks off a player's
const COLOR_PROVOKED = Color(0.75, 0.33, 0.16)  # his body, the closer he is to striking back
const WARD_TINT = 0.85  # how far a sword's crossguard takes its player's color: whose it is
const HAND_SIZE = 16.0
const HAND_DARKEN = 0.25
const CROSSGUARD = Vector2(6.0, 32.0)
const PLAYER_HEAD = Vector2(30.0, 45.0)  # where a player stands, from his flank and his center

var _wards = {LEFT: null, RIGHT: null}  # sword -> the player it fights (see _assign_wards())
var _pivots = {}  # sword -> Node2D
var _blades = {}  # sword -> ColorRect
var _crossguards = {}  # sword -> ColorRect
var _plates = {}  # sword -> ColorRect: its guard
var _halves = {}  # side -> ColorRect over that half of his body
var _poses = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where each blade is drawn right now
var _targets = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where it's headed (pose_sword())
var _snaps = {LEFT: false, RIGHT: false}
# How far over toward the side *away* from its player a blade is headed: 1 on its player's
# side, -1 all the way over on the other (the sweep; a level cut's windup).
var _overs = {LEFT: 1.0, RIGHT: 1.0}
var _homes = {LEFT: false, RIGHT: false}  # posed at its own hand's flank, wherever its player is
# Where a blade is drawn: 1 at its own hand's flank, -1 across on the other. In between it's
# drawn foreshortened, passing in front of him.
var _crosses = {LEFT: 1.0, RIGHT: 1.0}
var _stagger_poses = {}  # sword -> [pose, over] for a stagger, instead of POSE_LIMP (set_stagger_pose())
var _side_tints = {LEFT: Color(1, 1, 1, 0), RIGHT: Color(1, 1, 1, 0)}  # sword -> tint_side()
var _at_guard = {LEFT: true, RIGHT: true}  # that blade is back at its flank (see is_guarding())
var _flick_until = {LEFT: 0.0, RIGHT: 0.0}  # anim_time until which that blade is parrying

# A broken guard, per sword: open from..until (anim_time). It may be broken a moment before it
# opens (break_guard()'s delay).
var _open_from = {LEFT: 0.0, RIGHT: 0.0}
var _open_until = {LEFT: 0.0, RIGHT: 0.0}
var _open_shown = {LEFT: true, RIGHT: true}  # the opening has made its sound and sparks
var _strikes_by = {LEFT: 0, RIGHT: 0}  # strikes of each sword so far (orient())

# Moving.
var _dash = null  # {from, to, since, time}: a charge or a backing off, under way
var _chased = null  # the player he's walking up to
var _ghost_until = 0.0  # anim_time until which his body blocks nobody
var _slowed_until = 0.0

# The reactive mode (see REACTIVE_WAIT).
var _provocations = 0  # hits parried since his last attack began
var _patience = 2  # how many of those he lets go before striking back
var _provoker = RIGHT  # the sword that parried the last one: its player is who he strikes back at
var _answering = false  # starting his answer (see orient() and first_wait())


func get_max_hp() -> float:
	return MAX_HP


func get_display_name() -> String:
	return "COLUMNA BIFRONS"


func get_attack_pool() -> Array:
	var pool = []
	for pattern_name in PATTERNS:
		pool.append(StrikePattern.new(pattern_name, PATTERNS[pattern_name].strikes))
	pool.append(Sweep.new())
	pool.append(Leap.new())
	for attack in pool:
		attack.strike_parried.connect(func(_player): sync_event.emit("bifrons_parried"))
		attack.both_parried.connect(sync_event.emit.bind("bifrons_both_parried"))
	return pool


# What he picks from: by where the players are (pep or ppe).
func get_attack_weights() -> Dictionary:
	if TEST_ONLY_PATTERN != "":
		return {TEST_ONLY_PATTERN: 1.0}
	var ppe = is_ppe()
	var weights = {}
	for pattern_name in PATTERNS:
		var pattern = PATTERNS[pattern_name]
		weights[pattern_name] = 0.0 if ppe and pattern.get("pep_only", false) else pattern.weight
	weights[Sweep.NAME] = 0.0 if ppe else SWEEP_WEIGHT
	weights[Leap.NAME] = LEAP_WEIGHT if ppe else 0.0
	return weights


func get_repeatable_attacks() -> Array:
	return REPEATABLE_PATTERNS


func get_idle_pause() -> float:
	if _is_reactive():
		return randf_range(REACTIVE_WAIT_MIN, REACTIVE_WAIT_MAX)
	return super()


# Players keep their eyes on him (see _process_movement() in player.gd): he passes them, and
# they'd turn their backs on him otherwise.
func holds_facing() -> bool:
	return hp > 0.0 and Moves.on("bifrons_face")


# His whole body blocks: taller than a jump, so getting to his other side is up to him.
func body_block() -> Rect2:
	if not Moves.on("boss_body") or hp <= 0.0 or anim_time < _ghost_until:
		return Rect2()
	return Rect2(global_position - body.size / 2.0, body.size)


# None of his attacks homes on one player, so a player he pushes may always shove the partner
# along (see _keep_out_of_boss() in player.gd).
func is_attacking(_player) -> bool:
	return false


func _is_reactive() -> bool:
	return Moves.value("bifrons_mode") == "reactive"


func _physics_process(delta):
	_assign_wards()
	# Nobody in reach of his blades: no attack (he walks up to them instead, see _walk()).
	if state == State.IDLE and timer <= delta and not _anyone_in_reach():
		timer = REACH_RECHECK
	super(delta)
	if hp <= 0.0:
		return
	_run_dash()
	if state == State.IDLE and _is_reactive() and _provocations >= _patience:
		_strike_back()


# --- His swords' players, and sides ---

# Each sword gets the player on its side as the fight begins, and keeps them.
func _assign_wards():
	if is_instance_valid(_wards[LEFT]) or is_instance_valid(_wards[RIGHT]):
		return
	var players = get_players()
	players.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	if players.size() == 1:
		_wards[side_of(players[0])] = players[0]
	elif players.size() > 1:
		_wards[LEFT] = players[0]
		_wards[RIGHT] = players[1]
	for blade in BLADES:
		if _wards[blade] != null:
			_crossguards[blade].color = COLOR_PLATE.lerp(_wards[blade].player_color, WARD_TINT)


# The player that sword fights, or null.
func ward_of(blade: int):
	var ward = _wards[blade]
	return ward if is_instance_valid(ward) else null


# The sword that fights that player.
func blade_of(player) -> int:
	for blade in BLADES:
		if _wards[blade] == player:
			return blade
	return side_of(player)


func side_of(player) -> int:
	return LEFT if player.global_position.x < global_position.x else RIGHT


# The side that sword is on: its player's.
func blade_side(blade: int) -> int:
	var ward = ward_of(blade)
	return side_of(ward) if ward != null else blade


# Both players on one side of him.
func is_ppe() -> bool:
	return ward_of(LEFT) != null and ward_of(RIGHT) != null and blade_side(LEFT) == blade_side(RIGHT)


# PPE: true for the sword that's on the flank its hand isn't (see ACROSS_SHIFT).
func reaches_across(blade: int) -> bool:
	return is_ppe() and blade_side(blade) != blade


# The sword whose player Moves "bifrons_stand_in" plays (see STAND_IN_PARRY_CHANCE), or 0.
func stand_in_blade() -> int:
	match Moves.value("bifrons_stand_in"):
		"left":
			return LEFT
		"right":
			return RIGHT
	return 0


# The players he has to get to: not the one a stand-in plays.
func _real_wards() -> Array:
	var wards = []
	for blade in BLADES:
		if ward_of(blade) != null and blade != stand_in_blade():
			wards.append(ward_of(blade))
	return wards


func _in_reach(player) -> bool:
	return absf(player.global_position.x - global_position.x) <= BLADE_REACH


func _anyone_in_reach() -> bool:
	return _real_wards().any(_in_reach)


# Called by an attack as it starts, with its strikes as written ([wait, sword] each): which way
# round it runs, 1 as written or -1 mirrored. His answer to a player's attack is turned so its
# first strike is that player's; any other attack, to whichever way keeps the strikes even
# between his swords (see MIRROR_PATTERNS). A charge goes where there's room for it.
func orient(strikes: Array) -> int:
	var way = 1
	var first = strikes[0][1]
	if _answering and first != BOTH:
		way = first * _provoker
	elif MIRROR_PATTERNS:
		var lean = 0  # > 0: as written, the right sword strikes more often than the left
		for strike in strikes:
			lean += strike[1]
		var ahead = (_strikes_by[RIGHT] - _strikes_by[LEFT]) * lean  # > 0: as written, it adds to the lead
		if ahead > 0 or (ahead == 0 and randf() < 0.5):
			way = -1
		if strikes[0].size() > 2 and strikes[0][2] == CHARGE and first != BOTH \
				and _charge_room(first * way) < CHARGE_MIN_ROOM and _charge_room(-first * way) >= CHARGE_MIN_ROOM:
			way = -way
	for strike in strikes:
		if strike[1] != BOTH:
			_strikes_by[strike[1] * way] += 1
	_provocations = 0
	_patience = PATIENCE.pick_random()
	return way


# Called by a pattern as it starts, with its first strike's wait as written: the wait it gets
# this run. His answer to a player's attack comes quickly, whatever the pattern.
func first_wait(written: float) -> float:
	return minf(written, ANSWER_WAIT) if _answering else written


# --- A blade landing on a player (used by his attacks) ---

# What a strike at that sword's player meets: the player, if they're within `reach` of him;
# whether they perfect parried it; and whether it counts as parried (by them, or by the stand-in
# playing them).
func judge(blade: int, reach = BLADE_REACH) -> Dictionary:
	var ward = ward_of(blade)
	var under = []
	if ward != null and absf(ward.global_position.x - global_position.x) <= reach:
		under.append(ward)
	var parriers = under.filter(func(p): return p.is_perfect_parry())
	var stand_in = stand_in_blade() == blade and randf() < STAND_IN_PARRY_CHANCE
	return {"blade": blade, "under": under, "parriers": parriers, "stand_in": stand_in,
		"parried": stand_in or not parriers.is_empty()}


# The judged strike lands: a parrier parries it (`strong`: the heavier kind of parry), anyone
# else under it is hit, or chipped behind a block.
func land(judged: Dictionary, strong = false):
	var side = blade_side(judged.blade)
	for p in judged.under:
		if p in judged.parriers:
			p.on_perfect_parry(strong)
			spawn_sparks(p.global_position + Vector2(0.0, -24.0), 10, COLOR_PLAYER_PARRY)
		elif stand_in_blade() == judged.blade:
			pass  # testing alone: the player the stand-in plays is never hurt
		elif p.is_blocking():
			p.take_damage(BLOCKED_DAMAGE, knockback_for(p, BLOCKED_KNOCKBACK), true)
		else:
			p.take_damage(BLADE_DAMAGE, knockback_for(p, BLADE_KNOCKBACK))
			shake(5.0)
	if judged.stand_in:
		# A clang and sparks where a player would stand.
		Sfx.play("parry", -3.0)
		var at = _flank(side, global_position.y + PLAYER_HEAD.y) + Vector2(side * PLAYER_HEAD.x, 0.0)
		spawn_sparks(at, 10, COLOR_PLAYER_PARRY)
	elif not judged.parried:
		Sfx.play("thunk", -6.0)  # the blade hitting the floor


# --- The guard ---

# True while that sword is back at its flank, ready: it parries its player's sword hits.
func is_guarding(blade: int) -> bool:
	return hp > 0.0 and state != State.STAGGER and _at_guard[blade] and not is_open(blade)


# True while that sword's guard is broken and open: its player's hits are sync hits.
func is_open(blade: int) -> bool:
	return anim_time >= _open_from[blade] and anim_time < _open_until[blade]


# True from the parry that breaks that sword's guard until it's back: open, or about to be.
func is_breaking(blade: int) -> bool:
	return anim_time < _open_until[blade]


# A parried strike of his other sword: after `delay` this one's guard is gone for `duration`.
func break_guard(blade: int, duration: float, delay = 0.0):
	_open_from[blade] = anim_time + delay
	_open_until[blade] = _open_from[blade] + duration
	_open_shown[blade] = false
	if delay <= 0.0:
		_show_open(blade)


func _show_open(blade: int):
	_open_shown[blade] = true
	Sfx.play("guard_break", -2.0)
	spawn_sparks(_flank(blade_side(blade), global_position.y), 12, COLOR_PLATE)


# source: the player whose sword hit landed. The sword that fights them parries it if it's
# guarding; anything else is hit.
func take_damage(amount: float, source = null):
	if source == null or hp <= 0.0 or state == State.STAGGER:
		super(amount, source)
		return
	_slowed_until = anim_time + SLOWED_TIME
	var blade = blade_of(source)
	var at = _flank(side_of(source), source.global_position.y)
	if is_open(blade):
		# Through the guard a parry of his other sword broke: a sync hit.
		sync_event.emit("bifrons_sync_hit")
		Sfx.play("sync_hit")
		shake(6.0)
		spawn_sparks(at, 16, COLOR_OPEN)
		super(amount * SYNC_HIT_FACTOR, source)
	elif is_guarding(blade):
		_parry(blade, source, at)
	else:
		# That blade is busy: nothing to parry with.
		Sfx.play("sync_hit", -6.0)
		shake(3.0)
		spawn_sparks(at, 8, COLOR_EXECUTE)
		super(amount, source)


# He parries a player's sword hit with the sword that fights them: the hit is lost and the
# player's blade is knocked back. In the reactive mode it also wears on his patience.
func _parry(blade: int, player, at: Vector2):
	player.on_swing_parried()
	_flick_until[blade] = anim_time + PARRY_FLICK_TIME
	Sfx.play("parry", -4.0)
	shake(3.0)
	spawn_sparks(at, 10, COLOR_PARRY)
	if _is_reactive():
		_provocations += 1
		_provoker = blade


# The reactive mode: his patience is gone and he's free. He strikes back at the player whose hit
# he parried last (see REACTIVE_WAIT).
func _strike_back():
	_choose_target()
	if target_player == null:
		return
	_answering = true
	_begin_telegraph(pick_attack())
	_answering = false


func _die():
	_open_until = {LEFT: 0.0, RIGHT: 0.0}
	_open_shown = {LEFT: true, RIGHT: true}
	_stagger_poses = {}
	_dash = null
	global_position.y = home_position.y  # not left hanging in a leap
	super()


# A point on that side's flank, at height y (world coordinates).
func _flank(side: int, y: float) -> Vector2:
	return Vector2(global_position.x + side * body.size.x / 2.0, y)


# --- Moving ---

func _idle_motion(delta: float):
	_walk(delta)


func _recover_motion(delta: float):
	_walk(delta)


# As far left and right as he goes.
func clamp_x(x: float) -> float:
	var edge = WALL_ROOM + body.size.x / 2.0
	return clampf(x, ARENA_LEFT + edge, ARENA_RIGHT - edge)


func _pace() -> float:
	return SLOWED_FACTOR if anim_time < _slowed_until else 1.0


# Between attacks (see "HE WALKS").
func _walk(delta: float):
	global_position.y = move_toward(global_position.y, home_position.y, STAGGER_SINK_SPEED * delta)
	if _dash != null:
		return
	var x = global_position.x
	var goal = x
	var speed = WALK_SPEED
	# After a player who has got away from him (the nearer one), until they're well in reach.
	if _chased != null and (not is_instance_valid(_chased) \
			or absf(_chased.global_position.x - x) <= BLADE_REACH - REACH_MARGIN):
		_chased = null
	if _chased == null:
		var slack = CHASE_SLACK if _anyone_in_reach() else 0.0
		for ward in _real_wards():
			var gap = absf(ward.global_position.x - x)
			if gap > BLADE_REACH + slack and (_chased == null or gap < absf(_chased.global_position.x - x)):
				_chased = ward
	if _chased != null:
		goal = _chased.global_position.x - side_of(_chased) * (BLADE_REACH - REACH_MARGIN)
	else:
		var room = ARENA_RIGHT - ARENA_LEFT
		goal = clampf(x, ARENA_LEFT + room / 3.0, ARENA_RIGHT - room / 3.0)
		var outer = x < ARENA_LEFT + room / 5.0 or x > ARENA_RIGHT - room / 5.0
		speed = RECENTER_SPEED_OUTER if outer else RECENTER_SPEED
		# ...but he leaves no player out of reach to get there.
		for ward in _real_wards():
			var at = ward.global_position.x
			if goal < x:
				goal = maxf(goal, minf(x, at - (BLADE_REACH - REACH_MARGIN)))
			else:
				goal = minf(goal, maxf(x, at + (BLADE_REACH - REACH_MARGIN)))
	global_position.x = move_toward(x, clamp_x(goal), speed * _pace() * delta)


# One frame's step toward that sword's player, until he's next to them (see "A LONG WINDUP").
func advance_on(blade: int):
	var ward = ward_of(blade)
	if ward == null or _dash != null:
		return
	var touching = body.size.x / 2.0 + ward.body.size.x / 2.0
	var goal = clamp_x(ward.global_position.x - side_of(ward) * touching)
	if signf(goal - global_position.x) != side_of(ward):
		return  # there already
	global_position.x = move_toward(global_position.x, goal, STEP_SPEED * _pace() * get_physics_process_delta_time())


# How far a charge at that sword's player would get.
func _charge_room(blade: int) -> float:
	var x = global_position.x
	return absf(clamp_x(x + blade_side(blade) * CHARGE_DISTANCE) - x)


# He follows his thrust through, past that sword's player (see "THE CHARGE").
func charge_through(blade: int):
	_dash_to(global_position.x + blade_side(blade) * CHARGE_DISTANCE, CHARGE_TIME)
	ghost(CHARGE_TIME)
	pop_body(Vector2(1.2, 0.9), CHARGE_TIME)
	Sfx.play("swing", -3.0)


# PPE: back from the players (see BACK_OFF_DISTANCE).
func back_off():
	if not is_ppe():
		return
	_dash_to(global_position.x - blade_side(LEFT) * BACK_OFF_DISTANCE, BACK_OFF_TIME)


# His body blocks nobody for that long (from now): passing a player, or coming down on one.
func ghost(duration: float):
	_ghost_until = anim_time + duration


func _dash_to(x: float, duration: float):
	_dash = {"from": global_position.x, "to": clamp_x(x), "since": anim_time, "time": duration}


func _run_dash():
	if _dash == null:
		return
	var done = clampf((anim_time - _dash.since) / _dash.time, 0.0, 1.0)
	global_position.x = lerpf(_dash.from, _dash.to, 1.0 - (1.0 - done) * (1.0 - done))  # fast, then braking
	if done >= 1.0:
		_dash = null


# --- Swords, plates and halves ---

func _setup_pose():
	# He stands on the floor: the stagger's rocking and a hit's swell turn on his foot.
	body.pivot_offset = Vector2(body.size.x / 2.0, body.size.y)
	for side in SIDES:
		# That half of his body, lit by what's happening on its side.
		var half = _rect(Vector2(body.size.x / 2.0, body.size.y), Color(1, 1, 1, 0))
		half.position = Vector2(0.0 if side == LEFT else body.size.x / 2.0, 0.0)
		body.add_child(half)
		_halves[side] = half
	for blade in BLADES:
		# Its guard: a plate down the flank it's guarding.
		var plate = _rect(Vector2(PLATE_WIDTH, body.size.y), COLOR_PLATE)
		body.add_child(plate)
		_plates[blade] = plate
		# The sword: blade, crossguard and hand on a pivot at the hand, flipped on his left.
		var pivot = Node2D.new()
		add_child(pivot)
		_pivots[blade] = pivot
		var steel = _rect(Vector2(SWORD_LENGTH, SWORD_WIDTH), COLOR_SWORD)
		steel.position = Vector2(0.0, -SWORD_WIDTH / 2.0)
		pivot.add_child(steel)
		_blades[blade] = steel
		var crossguard = _rect(CROSSGUARD, COLOR_PLATE)
		crossguard.position = Vector2(HAND_SIZE / 2.0, -CROSSGUARD.y / 2.0)
		pivot.add_child(crossguard)
		_crossguards[blade] = crossguard
		var hand = _rect(Vector2(HAND_SIZE, HAND_SIZE), COLOR_IDLE.darkened(HAND_DARKEN))
		hand.position = Vector2(-HAND_SIZE / 2.0, -HAND_SIZE / 2.0)
		pivot.add_child(hand)


func _rect(rect_size: Vector2, color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func reset_pose():
	for blade in BLADES:
		pose_sword(blade, POSE_GUARD)
		tint_sword(blade, COLOR_SWORD)
		tint_side(blade, COLOR_SWORD, 0.0)


# Where a sword should be: one of the POSE_s (or between two), on its player's side, or `over`
# toward the other (1: its player's side, -1: all the way over). It eases there, unless `snap`:
# then it's there this frame (a drop or a sweep, which have to land on time).
func pose_sword(blade: int, pose: Vector3, snap = false, over = 1.0):
	_targets[blade] = pose
	_snaps[blade] = snap
	_overs[blade] = over
	_homes[blade] = false


# The same, but at its own hand's flank wherever its player is (the leap: a sword down each side).
func pose_sword_home(blade: int, pose: Vector3, snap = false):
	pose_sword(blade, pose, snap)
	_homes[blade] = true


func tint_sword(blade: int, color: Color):
	_blades[blade].color = color


# Lights the half of his body that sword is on: where a strike is coming from.
func tint_side(blade: int, color: Color, alpha: float):
	_side_tints[blade] = Color(color, alpha)


# Where that sword lies while he's staggered, instead of dropped on its player's side. Set just
# before the stagger; forgotten after it.
func set_stagger_pose(blade: int, pose: Vector3, over = 1.0):
	_stagger_poses[blade] = [pose, over]


func _update_pose():
	var down = hp <= 0.0 or state == State.STAGGER
	var follow = 1.0 - exp(-SWORD_FOLLOW * get_physics_process_delta_time())
	if not down:
		_stagger_poses = {}
	# His body warms as his patience runs out.
	if state in [State.IDLE, State.RECOVER]:
		var heat = clampf(float(_provocations) / _patience, 0.0, 1.0) if _is_reactive() else 0.0
		body.color = COLOR_IDLE.lerp(COLOR_PROVOKED, heat)
	var tints = {LEFT: Color(1, 1, 1, 0), RIGHT: Color(1, 1, 1, 0)}  # side -> the strongest tint there
	var flashing = {LEFT: false, RIGHT: false}  # side -> a guard is open there
	for blade in BLADES:
		var side = blade_side(blade)
		var across = reaches_across(blade)
		var open = is_open(blade) and not down
		if open and not _open_shown[blade]:
			_show_open(blade)  # a guard broken with a delay opens only now
		var pose: Vector3 = _targets[blade]
		var over: float = _overs[blade]
		var snap: bool = _snaps[blade]
		var home: bool = _homes[blade]
		# Guarding means back at its flank: an attack wants it there, and it has arrived.
		var wants_guard = pose == POSE_GUARD and over == 1.0 and not home and not down and not open
		if not wants_guard:
			_at_guard[blade] = false
		elif not _at_guard[blade]:
			var off = _poses[blade] - (POSE_GUARD + (ACROSS_SHIFT if across else Vector3.ZERO))
			_at_guard[blade] = Vector2(off.x, off.y).length() <= GUARD_NEAR.x and absf(off.z) <= GUARD_NEAR.y \
				and absf(_crosses[blade] - blade * side) <= 0.1
		if down:
			var limp = _stagger_poses.get(blade, [POSE_LIMP, 1.0])
			pose = limp[0]
			over = limp[1]
			home = false
			snap = hp <= 0.0  # dead: this is the last frame he's posed
		elif open and pose == POSE_GUARD:
			pose = POSE_OPEN  # its guard is broken: knocked aside
		elif anim_time < _flick_until[blade] and not snap:
			pose = POSE_PARRY  # his parry shows even if the blade is already off to strike back
		var flicking = pose == POSE_PARRY
		if across and pose in ACROSS_POSES:
			pose += ACROSS_SHIFT
		var cross = 1.0 if home else over * blade * side
		_poses[blade] = pose if snap else _poses[blade].lerp(pose, follow)
		_crosses[blade] = cross if snap else lerpf(_crosses[blade], cross, follow)
		# Across: the blade passes in front of him, drawn foreshortened.
		var drawn = _crosses[blade]
		if absf(drawn) < 0.02:
			drawn = 0.02
		var pivot: Node2D = _pivots[blade]
		pivot.position = Vector2(_poses[blade].x * blade * drawn, _poses[blade].y)
		pivot.rotation = _poses[blade].z * blade * drawn
		pivot.scale.x = blade * drawn
		if down:
			_blades[blade].color = COLOR_SWORD_LIMP
		elif flicking:
			_blades[blade].color = Color.WHITE
		elif _targets[blade] == POSE_GUARD:
			_blades[blade].color = COLOR_SWORD
		# Its guard, down the flank it's on (outside the other's, if both are there).
		var plate: ColorRect = _plates[blade]
		var lane = PLATE_WIDTH if across else 0.0
		plate.visible = is_guarding(blade)
		plate.position.x = -PLATE_WIDTH - lane if side == LEFT else body.size.x + lane
		if open:
			flashing[side] = true
		if _side_tints[blade].a > tints[side].a:
			tints[side] = _side_tints[blade]
	for side in SIDES:
		if down:
			_halves[side].color = Color(1, 1, 1, 0)  # the body's own stagger flash shows
		elif flashing[side]:
			_halves[side].color = COLOR_OPEN if fmod(anim_time, 0.1) < 0.05 else Color.WHITE
		else:
			_halves[side].color = tints[side]


func spawn_sparks(point: Vector2, count: int, color: Color):
	for i in count:
		var spark = _rect(Vector2(4, 4), color.lerp(Color.WHITE, randf() * 0.6))
		spark.top_level = true
		add_child(spark)
		spark.global_position = point
		var fly = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0)
		var tween = spark.create_tween().set_parallel()
		tween.tween_property(spark, "global_position", point + fly, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(spark.queue_free)
