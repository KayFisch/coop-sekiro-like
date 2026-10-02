class_name ColumnaBifrons
extends BaseBoss
## Columna Bifrons, the two-faced column: a test boss for fights fought from both sides at once
## (player - boss - player, "pep" below), and for what becomes of that when both players end up
## on one side of him ("ppe"). The state machine lives in BaseBoss, the attacks in attacks/;
## what's his own is here: which attacks come and how often, his two swords and whom they fight,
## his guard, where he stands and how he gets there, and how he answers being attacked.
##
## THE RULES, the same that hold for the players' swords (see "THE SWORD" in player.gd):
## 1. Each of his swords fights one player (its "ward"): it points at them, strikes at them and
##    guards against them, on whichever side of him they are. A player on each side: a sword on
##    each side. Both on one side: both swords there. A sword whose own player has left his range
##    turns on the other one until they're back (see "LEFT ALONE").
## 2. A blade guards or swings. While it stands at its flank it parries every sword hit of its
##    player. While it's up for a strike, dropping, lying where it landed, thrown back by a
##    parry, or away (the sweep), it can't: hits land, as many as fit.
## 3. A parried swing recoils: a player's blade is knocked back by his guard, his own is thrown
##    back by a player's perfect parry, and either takes longer to come back.
## 4. A strike that's perfect parried breaks the guard of his *other* sword for a moment, and
##    the other player's hits are sync hits: more damage, and sync.
## 5. Both swords parried at once, by both players, stagger him: no guard at all.
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
const RUSH = StrikePattern.RUSH
const BLADES = [LEFT, RIGHT]  # his two swords, named for the hand that holds each
const SIDES = [LEFT, RIGHT]

# --- Tuning ---
const MAX_HP = 1600.0

# The strike patterns: how often each comes, relative to the others (0 disables it), and its
# strikes in order, as [wait, sword] or [wait, sword, kind]. `wait` is the time until the strike
# lands, counted from the pattern's start or from the strike before, in StrikePattern.TIME_UNITs:
# a rough 1-10 scale, where 4 is a quick follow-up and 9 a long windup (under 3 is too quick to
# read). `sword` is LEFT, RIGHT or BOTH: which of his swords strikes, at its own player. `kind`
# is CUT (the default), CHARGE (see "THE CHARGE" below) or RUSH ("LEFT ALONE"). "when" limits a
# pattern to one situation: "pep" (a player on each side of him) or "alone" (both swords on one
# player, the other one away). Each pattern is written once and also comes mirrored
# (MIRROR_PATTERNS).
const PATTERNS = {
	"SINGLE": {"weight": 1.0, "strikes": [[5, LEFT]]},
	"TRIPLE": {"weight": 3.0, "strikes": [[5, RIGHT], [4, RIGHT], [4, LEFT]]},
	"QUAD": {"weight": 2.0, "strikes": [[7, LEFT], [4, LEFT], [4, RIGHT], [4, BOTH]]},
	"LONG": {"weight": 1.0, "strikes": [
		[9, RIGHT], [4, RIGHT], [4, LEFT], [4, RIGHT], [4, RIGHT], [4, LEFT], [4, BOTH]]},
	# He charges past one player, so both are on one side of him, and brings both swords down
	# on them.
	"CROSSING": {"weight": 1.5, "when": "pep", "strikes": [[5, RIGHT, CHARGE], [6, BOTH]]},
	# He dashes over to the player who's away, and strikes them.
	"RUSH": {"weight": 3.0, "when": "alone", "strikes": [[7, RIGHT, RUSH]]},
	# Building blocks, off for now: the smallest swap of roles, and a lone strike of both swords.
	"SWAP": {"weight": 0.0, "strikes": [[5, LEFT], [4, RIGHT]]},
	"BOTH": {"weight": 0.0, "strikes": [[6, BOTH]]},
}
const SWEEP_WEIGHT = 1.5  # the sweep (attacks/sweep.gd) comes among the patterns, in pep only
# The leap (attacks/leap.gd) comes among the patterns in ppe only: it's his way of getting the
# players back on both sides (theirs is the dash-parry, see player.gd). The patterns' weights
# add up to 7 there, so this is how long ppe lasts if they leave it to him: at 3.5, one attack
# in three is the leap.
const LEAP_WEIGHT = 3.5
# Cornered (see "CORNERED"), he gets out: the leap gets this weight, and with a player on each
# side the crossing does too.
const CORNERED_WEIGHT = 6.0
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

# A blade landing on a player (any of his attacks).
const BLADE_REACH = 215.0  # from his center: a player this close is in his blades' reach
const BLADE_DAMAGE = 12.0
const BLADE_KNOCKBACK = 300.0
const BLOCKED_DAMAGE = 4.0
const BLOCKED_KNOCKBACK = 150.0
const SYNC_HIT_FACTOR = 2.5  # a sync hit's damage, times the sword hit's own

# --- Moving ---
# WHERE HE STANDS: where his blades reach the players, and not right up against one.
# - A player on each side, close enough together for his blades to reach both: in the middle
#   between them (once he's PLACE_SLACK off it, he walks there).
# - Else (both on one side, only one to fight, or too far apart) he goes by the nearer one:
#   closer than CROWD_DISTANCE, he steps back to FIT_DISTANCE; out of his blades' reach, he
#   walks up until they're REACH_MARGIN inside it; in between he's fine where he is.
# - Fine where he is, with the players between him and a wall, he backs toward the room's
#   middle third, as far as the nearer one stays REACH_MARGIN inside his reach.
# He walks between his attacks, and at ATTACK_PACE through their windups. Sword hits slow him
# down for a moment, so a player can hold him. He starts an attack only while a player is in
# his range.
# (Distances are between his center and a player's. Touching is 52; a player's sword reaches
# him from 118, and two players side by side both reach him with the nearer one at 78.)
const CROWD_DISTANCE = 62.0
const FIT_DISTANCE = 90.0
const REACH_MARGIN = 30.0
const PLACE_SLACK = 28.0
const WALK_SPEED = 110.0  # px/s
const ATTACK_PACE = 0.5  # of his walking speed, while he's in an attack
const SLOWED_FACTOR = 0.3  # of his walking speed, for SLOWED_TIME after a sword hit
const SLOWED_TIME = 0.6
const RANGE_RECHECK = 0.2  # nobody in range when an attack is due: he looks again this much later
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
# for all through it, until he has reached them, and then lunges. Both players have to move.
const LONG_WINDUP = 6
const ADVANCE_SPEED = 70.0
# CROWDED (a player closer than CROWD_DISTANCE) for CROWD_PATIENCE: stepping back hasn't
# helped, so he hops back instead (BACK_OFF_), HOP_COOLDOWN apart at least. He backs off the
# same way after a strike of both swords that didn't stagger him, if the players are on one
# side of him.
# CORNERED: no room for any of that. A player on each side, both crowding him; or the players
# on one side and the wall behind him (he's in the room's outer fifth). He gets out with his
# next attack: over them with the leap, or past one with the crossing (see CORNERED_WEIGHT).
const CROWD_PATIENCE = 0.7
const HOP_COOLDOWN = 4.0
const BACK_OFF_DISTANCE = 110.0
const BACK_OFF_DELAY = 0.1
const BACK_OFF_TIME = 0.2
const BACK_OFF_HOP = 22.0  # px off the floor at the top of it
# THE CHARGE (a strike of kind CHARGE): a thrust, to be parried like any strike, and CHARGE_DELAY
# after it lands he follows it through, CHARGE_DISTANCE in CHARGE_TIME, his body no obstacle
# meanwhile. A player close enough is passed and ends up on his other side: both players on one
# side (ppe). One who backs off ahead of him, or stands too far away, isn't.
const CHARGE_DISTANCE = 230.0
const CHARGE_DELAY = 0.1
const CHARGE_TIME = 0.25
const CHARGE_MIN_ROOM = 150.0  # he charges toward the side that has at least this much room
# LEFT ALONE. A strike whose player is out of his range when it's due is left out (see
# StrikePattern). A sword whose own player has been out of range for TURN_TIME turns on the
# other one: both swords on one player, and nothing guarding his far side. It turns back when
# its own player is in reach again. Meanwhile he gets at the one who's away with THE RUSH (a
# strike of kind RUSH): their own sword turns back to them, and as it comes he dashes over, in
# RUSH_TIME, his body no obstacle.
const TURN_TIME = 1.5
const RUSH_TIME = 0.45

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
const POSE_SWEEP_BACK = Vector3(46.0, 27.0, -0.75)  # the sweep's windup: held out to the side, drawn back
const POSE_SWEEP = Vector3(40.0, 40.0, 0.0)  # cutting level, at head height
const POSE_PROP = Vector3(44.0, -82.0, 1.18)  # planted in the floor out to the side, his weight on it
const POSE_LANCE_LOW = Vector3(40.0, 44.0, -0.3)  # the charge's windup: lowered, pointing at the player...
const POSE_LANCE_BACK = Vector3(-18.0, 44.0, -0.04)  # ...and drawn far back, level, the hand behind his middle
const POSE_LANCE = Vector3(62.0, 44.0, 0.0)  # thrust out
const POSE_STAB = Vector3(13.0, -95.0, 1.54)  # the leap: held high over his middle, pointing straight down
# PPE, both swords on one side: the one whose hand is on the other flank reaches across, in
# front of him and of the other sword. It stands outside the other one, leaning out (this is
# added to its guard poses). And where the other comes down from over his head, it cuts lower,
# on a slant: drawn back at shoulder height on its own flank, and around his front
# (see StrikePattern).
const ACROSS_SHIFT = Vector3(16.0, -16.0, 0.28)
const ACROSS_POSES = [POSE_GUARD, POSE_PARRY, POSE_OPEN]
const POSE_SLASH_BACK = Vector3(46.0, -6.0, -0.95)

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

var _wards = {LEFT: null, RIGHT: null}  # sword -> its own player (see _assign_wards())
var _turned = {LEFT: false, RIGHT: false}  # sword -> it has turned on the other sword's player
var _away_for = {LEFT: 0.0, RIGHT: 0.0}  # sword -> how long its own player has been out of range
var _pivots = {}  # sword -> Node2D
var _blades = {}  # sword -> ColorRect
var _crossguards = {}  # sword -> ColorRect
var _plates = {}  # sword -> ColorRect: its guard
var _halves = {}  # side -> ColorRect over that half of his body
var _poses = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where each blade is drawn right now
var _targets = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where it's headed (pose_sword())
var _snaps = {LEFT: false, RIGHT: false}
# How far over toward the side *away* from its player a blade is headed: 1 on its player's
# side, -1 all the way over on the other (the sweep; a cut's windup on the far flank).
var _overs = {LEFT: 1.0, RIGHT: 1.0}
var _homes = {LEFT: false, RIGHT: false}  # posed at its own hand's flank, wherever its player is
# Where a blade is drawn: 1 at its own hand's flank, -1 across on the other. In between it's
# drawn foreshortened, passing in front of him.
var _crosses = {LEFT: 1.0, RIGHT: 1.0}
var _front = 0  # the sword drawn in front of the other: the one that last reached across
var _stagger_poses = {}  # sword -> [pose, over] for a stagger, instead of POSE_LIMP (set_stagger_pose())
var _side_tints = {LEFT: Color(1, 1, 1, 0), RIGHT: Color(1, 1, 1, 0)}  # sword -> tint_side()
var _at_guard = {LEFT: true, RIGHT: true}  # that blade is back at its flank (see is_guarding())
var _flick_until = {LEFT: 0.0, RIGHT: 0.0}  # anim_time until which that blade is parrying

# A broken guard, per sword: open from..until (anim_time). It may be broken a moment before it
# opens (break_guard()'s delay).
var _open_from = {LEFT: 0.0, RIGHT: 0.0}
var _open_until = {LEFT: 0.0, RIGHT: 0.0}
var _open_shown = {LEFT: true, RIGHT: true}  # the opening has made its sound and sparks
var _opened_by = {LEFT: null, RIGHT: null}  # the player whose parry broke it
var _strikes_by = {LEFT: 0, RIGHT: 0}  # strikes of each sword so far (orient())

# Moving.
var _dash = null  # {from, to, since, time, hop}: a charge or a backing off, under way
# What he's walking for (see _place()): to the middle between the players, back from one who's
# too close, or up to one who's out of reach. Each lasts until he's there.
var _centering = false
var _backing = false
var _closing = false
var _ghost_until = 0.0  # anim_time until which his body blocks nobody
var _slowed_until = 0.0
var _crowded_for = 0.0  # how long a player has been closer than CROWD_DISTANCE
var _hop_ready = 0.0  # anim_time from which he may hop back again

# The reactive mode (see REACTIVE_WAIT).
var _provocations = 0  # hits parried since his last attack began
var _patience = 2  # how many of those he lets go before striking back
var _provoker = RIGHT  # the sword that parried the last one: its player is who he strikes back at
var _answering = false  # starting his answer (see orient() and first_wait())


func _ready():
	super()
	# Testing alone: the stand-in (it does nothing while Moves "bifrons_stand_in" is off). As his
	# child it runs after him and before the players, who see its presses that same frame.
	var stand_in = BifronsStandIn.new()
	stand_in.boss = self
	add_child(stand_in)


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


# What he picks from: by where the players are, and whether they leave him room.
func get_attack_weights() -> Dictionary:
	if TEST_ONLY_PATTERN != "":
		return {TEST_ONLY_PATTERN: 1.0}
	var situation = _situation()
	var weights = {}
	for pattern_name in PATTERNS:
		var pattern = PATTERNS[pattern_name]
		weights[pattern_name] = pattern.weight if pattern.get("when", situation) == situation else 0.0
	weights[Sweep.NAME] = SWEEP_WEIGHT if situation == "pep" else 0.0
	weights[Leap.NAME] = LEAP_WEIGHT if situation == "ppe" else 0.0
	if situation != "alone" and is_cornered():
		weights[Leap.NAME] = CORNERED_WEIGHT
		if situation == "pep":
			weights["CROSSING"] = CORNERED_WEIGHT
	# No leap while there's no room for him between the players: both at a wall, behind him.
	var spot = Leap.landing_spot(self, global_position.x)
	if absf(clamp_x(spot) - spot) > 1.0:
		weights[Leap.NAME] = 0.0
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


# His whole body blocks: taller than a jump. Getting to his other side takes a dash-parry (see
# player.gd), or him.
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
	if hp > 0.0:
		_update_turns(delta)
	# Nobody in his range: no attack (he walks up to them instead, see walk()).
	if state == State.IDLE and timer <= delta and not _fought().any(in_range):
		timer = RANGE_RECHECK
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
	_color_crossguards()


# That sword's own player, or null.
func own_ward(blade: int):
	var ward = _wards[blade]
	return ward if is_instance_valid(ward) else null


# The player that sword fights right now, or null: its own, unless it has turned on the other
# sword's (see "LEFT ALONE").
func ward_of(blade: int):
	return own_ward(-blade if _turned[blade] else blade)


# The sword that's that player's own.
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


# Both swords on one side of him: both players there, or both swords on one player.
func is_ppe() -> bool:
	return ward_of(LEFT) != null and ward_of(RIGHT) != null and blade_side(LEFT) == blade_side(RIGHT)


# PPE: true for the sword that's on the flank its hand isn't (see ACROSS_SHIFT).
func reaches_across(blade: int) -> bool:
	return is_ppe() and blade_side(blade) != blade


# "alone" (both swords on one player), "ppe" (both players on one side of him) or "pep".
func _situation() -> String:
	if _turned[LEFT] or _turned[RIGHT]:
		return "alone"
	return "ppe" if is_ppe() else "pep"


# The players his swords fight right now: both, or the one who's there.
func _fought() -> Array:
	var players = []
	for blade in BLADES:
		var ward = ward_of(blade)
		if ward != null and not ward in players:
			players.append(ward)
	return players


func distance_to(player) -> float:
	return absf(player.global_position.x - global_position.x)


# Close enough to be struck (see STRIKE_RANGE).
func in_range(player) -> bool:
	return distance_to(player) <= STRIKE_RANGE


# True if a strike of that sword would have someone to go for.
func can_strike(blade: int) -> bool:
	var ward = ward_of(blade)
	return ward != null and in_range(ward)


# The player Moves "bifrons_stand_in" has the stand-in play (see stand_in.gd), or null.
func stand_in_player():
	match Moves.value("bifrons_stand_in"):
		"left":
			return own_ward(LEFT)
		"right":
			return own_ward(RIGHT)
	return null


# Seconds until his next blade lands on that player; INF if none is coming at them.
func time_to_strike(player) -> float:
	if current_attack == null or not state in [State.TELEGRAPH, State.ATTACKING]:
		return INF
	return current_attack.time_to_strike(player)


# Called by an attack as it starts, with its strikes as written ([wait, sword] each): which way
# round it runs, 1 as written or -1 mirrored. A rush goes at the player who's away. His answer
# to a player's attack is turned so its first strike is that player's; any other attack, to
# whichever way keeps the strikes even between his swords (see MIRROR_PATTERNS). A charge goes
# where there's room for it, and no attack starts on a player who isn't there.
func orient(strikes: Array) -> int:
	var way = 1
	var first = strikes[0][1]
	var kind = strikes[0][2] if strikes[0].size() > 2 else CUT
	if kind == RUSH and first != BOTH:
		for blade in BLADES:
			if _turned[blade]:
				way = first * blade
				_turn(blade, false)  # back on its own player, for this
	elif _answering and first != BOTH:
		way = first * _provoker
	elif first != BOTH:
		if MIRROR_PATTERNS:
			var lean = 0  # > 0: as written, the right sword strikes more often than the left
			for strike in strikes:
				lean += strike[1]
			var ahead = (_strikes_by[RIGHT] - _strikes_by[LEFT]) * lean  # > 0: as written, it adds to the lead
			if ahead > 0 or (ahead == 0 and randf() < 0.5):
				way = -1
		var there = can_strike(first * way)
		var other_there = can_strike(-first * way)
		var cramped = kind == CHARGE and _charge_room(first * way) < CHARGE_MIN_ROOM \
			and _charge_room(-first * way) >= CHARGE_MIN_ROOM
		if other_there and (not there or cramped):
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


# --- Left alone (see "LEFT ALONE") ---

func _update_turns(delta: float):
	for blade in BLADES:
		var own = own_ward(blade)
		var other = own_ward(-blade)
		if own == null or other == null:
			continue
		if _turned[blade]:
			# Back to its own player once they're in reach; or once nobody is here either.
			if (distance_to(own) <= BLADE_REACH or not in_range(other)) and _is_free(blade):
				_turn(blade, false)
			continue
		_away_for[blade] = 0.0 if in_range(own) else _away_for[blade] + delta
		if _away_for[blade] >= TURN_TIME and not _turned[-blade] and in_range(other) and _is_free(blade):
			_turn(blade, true)


# That sword has nothing to do just now: it's at its guard, between two attacks or in a pattern.
func _is_free(blade: int) -> bool:
	return state != State.STAGGER and (current_attack == null or current_attack is StrikePattern) \
		and _targets[blade] == POSE_GUARD and not _homes[blade] and not is_breaking(blade)


func _turn(blade: int, on: bool):
	_turned[blade] = on
	_away_for[blade] = 0.0
	_color_crossguards()


# A sword's crossguard has the color of the player it fights.
func _color_crossguards():
	for blade in BLADES:
		var ward = ward_of(blade)
		_crossguards[blade].color = COLOR_PLATE if ward == null else COLOR_PLATE.lerp(ward.player_color, WARD_TINT)


# --- A blade landing on a player (used by his attacks) ---

# What a strike at that sword's player meets: the player, if they're within `reach` of him, and
# whether they perfect parried it.
func judge(blade: int, reach = BLADE_REACH) -> Dictionary:
	var ward = ward_of(blade)
	var under = []
	if ward != null and distance_to(ward) <= reach:
		under.append(ward)
	var parriers = under.filter(func(p): return p.is_perfect_parry())
	return {"blade": blade, "under": under, "parriers": parriers, "parried": not parriers.is_empty()}


# The judged strike lands: a parrier parries it (`strong`: the heavier kind of parry), anyone
# else under it is hit, or chipped behind a block. `damage` and `knock` scale what a hit does
# (a heavy strike, the leap).
func land(judged: Dictionary, strong = false, damage = 1.0, knock = 1.0):
	for p in judged.under:
		if p in judged.parriers:
			p.on_perfect_parry(strong)
			spawn_sparks(p.global_position + Vector2(0.0, -24.0), 10, COLOR_PLAYER_PARRY)
		elif p.is_blocking():
			p.take_damage(BLOCKED_DAMAGE * damage, knockback_for(p, BLOCKED_KNOCKBACK * knock), true)
		else:
			p.take_damage(BLADE_DAMAGE * damage, knockback_for(p, BLADE_KNOCKBACK * knock))
			shake(5.0)
	if not judged.parried:
		Sfx.play("thunk", -6.0)  # the blade hitting the floor


# --- The guard ---

# True while that sword is back at its flank, ready: it parries its player's sword hits.
func is_guarding(blade: int) -> bool:
	return hp > 0.0 and state != State.STAGGER and _at_guard[blade] and not is_open(blade)


# True while that sword's guard is broken and open: the other player's hits are sync hits.
func is_open(blade: int) -> bool:
	return anim_time >= _open_from[blade] and anim_time < _open_until[blade]


# True from the parry that breaks that sword's guard until it's back: open, or about to be.
func is_breaking(blade: int) -> bool:
	return anim_time < _open_until[blade]


# A strike of his other sword, parried by `by`: after `delay` this one's guard is gone for
# `duration`.
func break_guard(blade: int, duration: float, delay = 0.0, by = null):
	_open_from[blade] = anim_time + delay
	_open_until[blade] = _open_from[blade] + duration
	_open_shown[blade] = false
	_opened_by[blade] = by
	if delay <= 0.0:
		_show_open(blade)


func _show_open(blade: int):
	_open_shown[blade] = true
	Sfx.play("guard_break", -2.0)
	spawn_sparks(_flank(blade_side(blade), global_position.y), 12, COLOR_PLATE)


# source: the player whose sword hit landed. Through a guard their partner's parry broke it's a
# sync hit; a sword that fights them parries it, if it's guarding; anything else is hit.
func take_damage(amount: float, source = null):
	if source == null or hp <= 0.0 or state == State.STAGGER:
		super(amount, source)
		return
	_slowed_until = anim_time + SLOWED_TIME
	var at = _flank(side_of(source), source.global_position.y)
	var guards = BLADES.filter(func(blade): return ward_of(blade) == source and is_guarding(blade))
	if BLADES.any(func(blade): return is_open(blade) and _opened_by[blade] != source):
		sync_event.emit("bifrons_sync_hit")
		Sfx.play("sync_hit")
		shake(6.0)
		spawn_sparks(at, 16, COLOR_OPEN)
		super(amount * SYNC_HIT_FACTOR, source)
	elif not guards.is_empty():
		_parry(guards[0], source, at)
	else:
		# No blade of his is guarding against them: busy, thrown back, or turned on their partner.
		Sfx.play("sync_hit", -6.0)
		shake(3.0)
		spawn_sparks(at, 8, COLOR_EXECUTE)
		super(amount, source)


# He parries a player's sword hit with a sword that fights them: the hit is lost and the
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
		if absf(middle - x) > PLACE_SLACK:
			_centering = true
		elif absf(middle - x) < 1.0:
			_centering = false
		return middle if _centering else x
	# By the nearer one: back from them until they're at his distance, or up to them until they're
	# well in reach.
	_centering = false
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
	return x


# One frame of walking to his place, at `pace` times his speed.
func walk(delta: float, pace = 1.0):
	if _dash != null:
		return
	global_position.x = move_toward(global_position.x, clamp_x(_place()), WALK_SPEED * pace * _pace() * delta)


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


# Crowded for a while, with room behind him: he hops back.
func _mind_the_crowd(delta: float):
	var crowding = _fought().any(func(p): return distance_to(p) < CROWD_DISTANCE)
	_crowded_for = _crowded_for + delta if crowding else 0.0
	if _crowded_for >= CROWD_PATIENCE and anim_time >= _hop_ready and _dash == null:
		_crowded_for = 0.0
		if back_off():
			_hop_ready = anim_time + HOP_COOLDOWN


# How far he can go toward that side before he's CLOSEST to a player there.
func _room_toward(side: int) -> float:
	var room = INF
	for p in get_players():
		if side_of(p) == side:
			room = minf(room, distance_to(p) - CLOSEST)
	return maxf(room, 0.0)


# A long windup: one frame of walking at that sword's player. False once he has reached them.
func advance_on(blade: int, delta: float) -> bool:
	var ward = ward_of(blade)
	if ward == null:
		return false
	if _dash != null:
		return true
	var side = side_of(ward)
	var x = global_position.x
	var goal = clamp_x(x + side * _room_toward(side))
	global_position.x = move_toward(x, goal, ADVANCE_SPEED * _pace() * delta)
	return not is_equal_approx(global_position.x, goal)


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
	_dash_to(global_position.x + blade_side(blade) * CHARGE_DISTANCE, CHARGE_TIME)
	ghost(CHARGE_TIME)
	pop_body(Vector2(1.2, 0.9), CHARGE_TIME)
	Sfx.play("swing", -3.0)


# A hop back from the players, if they're all on one side of him and the wall isn't right
# behind him (see "CROWDED" above). True if he does.
func back_off() -> bool:
	var fought = _fought()
	if fought.is_empty():
		return false
	var side = side_of(fought[0])
	if fought.any(func(p): return side_of(p) != side):
		return false
	var to = clamp_x(global_position.x - side * BACK_OFF_DISTANCE)
	if absf(to - global_position.x) < BACK_OFF_DISTANCE / 2.0:
		return false
	_dash_to(to, BACK_OFF_TIME, BACK_OFF_HOP)
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
		if across and _front != blade:
			_front = blade  # it reaches across in front of the other sword
			move_child(_pivots[blade], -1)
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
