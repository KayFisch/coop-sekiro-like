class_name ColumnaBifrons
extends BifronsMoves
## Columna Bifrons, the two-faced column: a test boss for fights fought from both sides at once
## (player - boss - player, "pep" below), and for what becomes of that when both players end up
## on one side of him ("ppe"). The state machine lives in BaseBoss, the attacks in attacks/;
## what's his own is here: which attacks come and how often, his two swords and whom they fight,
## his guard, where he stands and how he gets there, and how he answers being attacked.
##
## THE RULES, the same that hold for the players' swords (see "THE SWORD" in player_sword.gd):
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
## 6. Both swords on one side of him come down on one place: a heavy strike, parried by both
##    players together or not at all (see THE BLADE RULES).
##
## THREE MODES (Moves "bifrons_mode"). "patterns": he runs one attack after another, and the
## players' part is to answer them. "reactive": the same attacks, a little more room between them,
## and a hit he parries calls up his next attack at once, aimed at whoever attacked him.
## "chains": a try-out of the boss design principles (docs/concept.md): his attacks are chains, a
## motif repeated and then a finale (attacks/chain.gd), and after each a pause that's the players'
## (see THE CHAINS).
## docs/boss_columna_bifrons.md has the design and what it's meant to find out.
##
## He's built in three parts, each extending the one before: his swords (bifrons_swords.gd),
## his moving (bifrons_moves.gd), and this one, the boss himself: his attacks, how often each
## comes, the sync rules' hooks, his guard's answers to the players' hits, and the reactive and
## chains modes.

# --- Tuning ---
const MAX_HP = 1600.0

# HIS ATTACKS, one entry each: how often it comes, and what it is.
# "weight": how often it comes, relative to the others (0: never). Either one number, for
# wherever the players are; or one number per situation, and it doesn't come in a situation
# that's left out:
#   "pep"    a player on each side of him
#   "ppe"    both players on one side
#   "alone"  both swords on one player, the other one away (see "LEFT ALONE")
#   "pep_cornered", "ppe_cornered": the same two while he's cornered (see "CORNERED"); an
#   attack that has no weight of its own for them keeps its "pep" or "ppe" one.
# "repeats": true if it may come twice in a row; the others never repeat back to back.
# What it is, one of:
# "strikes": a series of sword strikes (attacks/strike_pattern.gd), each [wait, sword] or
#   [wait, sword, kind]. `wait` is the time until the strike lands, counted from the series'
#   start or from the strike before, in units of time_unit(): a rough 1-10 scale, where 4 is
#   a quick follow-up and 9 a long windup (under 3 is too quick to read). `sword` is LEFT, RIGHT
#   or BOTH: which of his swords strikes, at its own player. `kind` is CUT (the default),
#   CHARGE (see "THE CHARGE" below) or RUSH ("LEFT ALONE"). Each series is written once and
#   also comes mirrored (MIRROR_PATTERNS).
# "motif": a chain (attacks/chain.gd): these strikes, as a series' are written, repeated, and a
#   finale; with the "stance" he holds before it (Chain.STANCES). They come only in the chains
#   mode, and there only they do (THE CHAINS).
# "attack": the script of an attack of its own, one of the four here.
const SWEEP = preload("attacks/sweep.gd")
const LEAP = preload("attacks/leap.gd")
const GATE_LEAP = preload("attacks/gate_leap.gd")
const SHOVE = preload("attacks/shove.gd")
const CHAIN = preload("attacks/chain.gd")
const ATTACKS = {
	"SINGLE": {"weight": 0.0, "repeats": true, "strikes": [[3, LEFT]]},
	"DOUBLE": {"weight": 0.0, "strikes": [[3, LEFT], [3, RIGHT]]},
	"TRIPLE": {"weight": 1.4, "repeats": true, "strikes": [[4, RIGHT], [4, RIGHT], [2, LEFT]]},
	"QUAD": {"weight": 0.8, "strikes": [[4, LEFT], [2, LEFT], [2, RIGHT], [3, BOTH]]},
	"LONG": {"weight": 1.0, "strikes": [
		[5, RIGHT], [3, RIGHT], [3, LEFT], [4, RIGHT], [3, RIGHT], [3, LEFT], [4, BOTH]]},
	"BOTH": {"weight": 0.0, "strikes": [[4, BOTH]]},
	# He shoves one player away, goes after them with a thrust and charges past them, so both
	# are on one side of him, and brings both swords down on them.
	"CROSSING": {"weight": {"pep": 2.0, "pep_cornered": 6.0}, "strikes": [[3, RIGHT, PUSH], [4, RIGHT, CHARGE], [4, BOTH]]},
	# He dashes over to the player who's away, and strikes them.
	"RUSH": {"weight": {"alone": 2.0}, "strikes": [[5, RIGHT, RUSH]]},
	# One sword, from one side of him through to the other.
	"SWEEP": {"weight": {"pep": 1.5}, "attack": SWEEP},
	# He jumps and comes down between the players: his way of getting them back on both sides
	# (theirs is the dash-parry, see player_body.gd), and out of a corner. Its weight in ppe against
	# the series' (and the gate leap's) is how long ppe lasts if they leave it to him.
	"LEAP": {"weight": {"ppe": 2.5, "pep_cornered": 6.0, "ppe_cornered": 6.0}, "attack": LEAP},
	# The Warden's gate leap (docs/boss_bifrons_warden.md), tried out here next to the leap: he rams
	# a sword into the floor between the two, vaults over the one in front on it, strikes each of
	# them on the way down and out, and comes down on them with both swords. Back to pep too, but
	# he sets how. Only in ppe.
	"GATE_LEAP": {"weight": {"ppe": 2.5, "ppe_cornered": 6.0}, "attack": GATE_LEAP},
	# Both swords thrust at the players, to throw them back. It comes when he wants room (see
	# "MAKING ROOM"), not by weight; give it one to have it come among the others as well.
	"SHOVE": {"weight": 0.0, "attack": SHOVE},
	# The chains (placeholders for the Warden's motifs): which one comes is chance, by weight.
	"CHAIN_RRL": {"weight": 1.0, "repeats": true, "motif": [[4, RIGHT], [4, RIGHT], [3, LEFT]], "stance": "level"},
	"CHAIN_RLRL": {"weight": 1.0, "repeats": true, "motif": [[4, RIGHT], [3, LEFT], [3, RIGHT], [3, LEFT]], "stance": "cross"},
	"CHAIN_RRLL": {"weight": 1.0, "repeats": true, "motif": [[4, RIGHT], [3, RIGHT], [3, LEFT], [3, LEFT]], "stance": "high"},
}
# Runs each series of strikes as written or mirrored, whichever keeps the strikes even between
# his two swords (at random while they're even). Off: always as written.
const MIRROR_PATTERNS = true
# For testing: the names of the attacks to use, e.g. ["TRIPLE", "SWEEP"]. Empty: all of them.
const TEST_ONLY_PATTERN = [] # "TRIPLE", "QUAD", "SINGLE", "LONG", "SWEEP"

# THE REACTIVE MODE. Between two attacks he waits REACTIVE_WAIT (after the usual recovery)
# before starting the next of his own: a little room for the players to start instead. Every
# hit he parries, at any time, counts toward his patience: one of PATIENCE's numbers, picked
# afresh with every attack. Once that many are parried and he's free, he strikes back at the
# player whose hit he parried last: with one of the same attacks, turned so its first strike is
# theirs, and that strike comes quickly (ANSWER_WAIT). Then the series runs to its end, as ever.
# (REACTIVE_WAIT: F2 "bifrons_reactive_min" / "_max".)
const PATIENCE = [1, 1, 2]
const ANSWER_WAIT = 4  # units (time_unit()) until an answer's first strike lands, at most

# THE CHAINS (the chains mode; attacks/chain.gd). He attacks only with chains, a motif repeated
# and a finale, picked by weight. Which finale is never chance (chain_finale()): the players have
# pressed him (his posture is low): the double strike, their chance to stagger him; the chain has
# run its length: the finale that changes the formation (pep: the crossing; ppe: the gate leap, or
# the leap where it doesn't fit); one player away, or no room for those: the double strike.
# THE BREATH: after each chain a pause (F2 "bifrons_breath_min" / "_max", after his recovery). He
# doesn't attack; he walks toward the middle of the room (no nearer a player than FIT_DISTANCE), and
# turns to the other player (his eye, a mark at the top of his body in their color, goes over to
# their side): the next chain starts with them. His posture comes back if they leave him be. A hit
# at his guard meanwhile (parried or blocked) is answered at once: the next chain, its first strike
# at the attacker, quickly (ANSWER_WAIT). The finale of a chain that's under way comes even while
# the dev tools hold him (dev_hold); a new chain, an answer too, doesn't.
# (Not in the players' sync mode: there he fights as in the patterns mode.)
const EYE_SIZE = Vector2(10.0, 6.0)
const EYE_TOP = 14.0  # px down from his top
const EYE_INSET = 5.0  # px in from his flank
const EYE_TURN = 6.0  # how fast it goes over to the other side (1/s)

# A blade landing on a player (any of his attacks; how far it reaches: BLADE_REACH, in his swords' part).
const BLADE_KNOCKBACK = 300.0
const BLOCKED_KNOCKBACK = 150.0

# THE BLADE RULES of 2026-10-19 (docs/concept.md, "Blade rules: additions"), each on F1, its
# numbers on F2 (tab "blade rules"):
# - ONE PARRY PER BLADE ("bifrons_blade_parries"): a strike of both swords on one side of him (both
#   players there, or both swords on one player) brings two blades down on one place. That's a
#   heavy attack, and it takes both players' parries, one per blade: a lone parry only has the
#   effect of a block. Both swords in pep, one on each player, are two normal strikes at once:
#   each player parries their own, and a lone parry is a parry. (Off: every strike of both is
#   heavy, and each player parries their own blade wherever they are.)
# - A THROW BY OUTCOME ("bifrons_throw_by_outcome"): an attack that throws a player back (the
#   leap, both swords on one player) throws a parry "bifrons_parried_throw" of the way, a block as
#   far as a hit. (Off: a parry stands, but for the leap's push; a block goes half as far.) His
#   other strikes keep their own knockback.
# - THE STAGGER FROM THE ATTACK ("bifrons_chain_stagger"): a coop parry staggers him
#   "bifrons_stagger_least", and "bifrons_stagger_per_parry" more for every blade parried in that
#   attack, its last one included (both swords parried: two). (Off: the sync rules' one number.)

# LEFT ALONE. A strike whose player is out of his range when it's due is left out (see
# StrikePattern). A sword whose own player has been out of range for TURN_TIME turns on the
# other one: both swords on one player, and nothing guarding his far side. It turns back once
# its own player is within RETURN_DISTANCE again. Meanwhile he gets at the one who's away with
# THE RUSH (a strike of kind RUSH): their own sword turns back to them, and as it comes he
# dashes over, in RUSH_TIME, his body no obstacle.
const TURN_TIME = 1.5
const RETURN_DISTANCE = 300.0  # further than his blades reach: he turns to them as they come
const RUSH_TIME = 0.45

var _strikes_by = {LEFT: 0, RIGHT: 0}  # strikes of each sword so far (orient())

# The reactive mode (see REACTIVE_WAIT).
var _held_off = 0.0  # the players' sync mode: how long he has held off his next attack (see _physics_process())
var _provocations = 0  # hits parried since his last attack began
var _patience = 2  # how many of those he lets go before striking back
var _provoker = RIGHT  # the sword that parried the last one: its player is who he strikes back at
var _answering = false  # starting his answer (see orient() and first_wait())
var _attack_parries = 0  # blades parried in his attack so far (THE STAGGER FROM THE ATTACK)

# The chains (see THE CHAINS).
var _lead_blade = 0  # the sword the next attack's first strike is to be (orient()), or 0: as it comes
var _last_lead = RIGHT  # the sword the last attack's first strike was
var _gaze = RIGHT  # the sword whose player he's turned to: the next chain starts with them
var _breath_until = 0.0  # anim_time the breath lasts until
var _provoked = false  # a hit at his guard in the breath: he answers
var _handed = ""  # a chain's finale of its own, due as soon as the chain is over
var _carry_parries = false  # that finale's parries count on from the chain's
var _eye: ColorRect


# His numbers on F2 (core/tuning.gd collects them): a page of his own, in his room. The pattern
# weights' defaults are ATTACKS' own.
static func tuning_entries() -> Array:
	var entries = [
		{"page": "bifrons", "title": "Columna Bifrons", "scenes": ["levels/threshold/"], "header": "TEMPO", "tab": "tempo"},
		{"key": "bifrons_time_unit", "label": "a unit of his waits (s): a strike's wait is 2-6 of them", "default": 0.2, "step": 0.01},
		{"key": "bifrons_fall_time", "label": "a strike's drop: the cue to parry (s)", "default": 0.28, "step": 0.01},
		{"key": "bifrons_recover_time", "label": "after a series of strikes, recovering (s)", "default": 0.6, "step": 0.05},
		{"key": "bifrons_pause_min", "label": "then a pause before his next attack, from (s)", "default": 0.25, "step": 0.05},
		{"key": "bifrons_pause_max", "label": "...to (s)", "default": 0.5, "step": 0.05},
		{"header": "THE REACTIVE MODE (F1: bifrons_mode)", "column": 1},
		{"key": "bifrons_reactive_min", "label": "his pause between attacks, from (s)", "default": 0.7, "step": 0.05},
		{"key": "bifrons_reactive_max", "label": "...to (s)", "default": 1.7, "step": 0.05},
		{"header": "MOVING BETWEEN STRIKES", "tab": "moving"},
		{"key": "bifrons_drift_near", "label": "drifting: as near to the nearer player as (px)", "default": 80.0, "step": 5.0},
		{"key": "bifrons_drift_far", "label": "...as far as (px)", "default": 170.0, "step": 5.0},
		{"key": "bifrons_drift_speed", "label": "...gliding this share of that span a second", "default": 0.6, "step": 0.05},
		{"key": "bifrons_drift_pause", "label": "...and pausing up to (s)", "default": 0.5, "step": 0.05},
		{"key": "bifrons_pep_drift", "label": "between two players: off the middle by up to (px)", "default": 60.0, "step": 5.0},
		{"key": "bifrons_push_patience", "label": "pushing a player along: shoves them after (s)", "default": 2.0, "step": 0.1},
		{"key": "bifrons_crowd_patience", "label": "crowded: makes room after (s)", "default": 0.7, "step": 0.1},
		{"header": "THE SCREEN HALVES (F1: mirror_view, mirror_blades)", "tab": "halves"},
		{"key": "bifrons_fade_alpha", "label": "fade: a blade at the partner, in your half, this opaque", "default": 0.2, "step": 0.05},
		{"header": "A THROW BY OUTCOME (F1: bifrons_throw_by_outcome)", "tab": "blade rules"},
		{"key": "bifrons_parried_throw", "label": "the leap, both swords on you: parried, this share of the throw", "default": 0.5, "step": 0.1},
		{"header": "THE STAGGER FROM THE ATTACK (F1: bifrons_chain_stagger)", "column": 1},
		{"key": "bifrons_stagger_least", "label": "a coop parry staggers him (s)", "default": 0.5, "step": 0.1},
		{"key": "bifrons_stagger_per_parry", "label": "...and longer by this per blade parried in that attack (s)", "default": 0.2, "step": 0.05},
		{"header": "THE CHAINS (F1: bifrons_mode chains)", "tab": "chains"},
		{"key": "bifrons_chain_reps_min", "label": "a chain repeats its motif at least (times; at random up to...)", "default": 2.0, "step": 1.0},
		{"key": "bifrons_chain_reps_max", "label": "...at most (times), then its finale", "default": 4.0, "step": 1.0},
		{"key": "bifrons_chain_posture", "label": "...the double strike sooner, his posture under (% of it)", "default": 50.0, "step": 5.0},
		{"header": "THE BREATH AFTER A CHAIN", "column": 1},
		{"key": "bifrons_breath_min", "label": "he moves, and doesn't attack, from (s)", "default": 2.5, "step": 0.1},
		{"key": "bifrons_breath_max", "label": "...to (s)", "default": 3.5, "step": 0.1},
		{"header": "THE GATE LEAP (attacks/gate_leap.gd)", "tab": "gate leap"},
		{"key": "bifrons_gate_lift", "label": "after the upward cut, the heavy strike's windup (s): A's time to come back", "default": 0.7, "step": 0.05},
		{"header": "HOW OFTEN EACH OF HIS ATTACKS COMES", "tab": "patterns"},
	]
	for attack_name in ATTACKS:
		var weight = ATTACKS[attack_name].weight
		var per_situation = weight is Dictionary
		entries.append({"key": "bifrons_weight_" + attack_name.to_lower(),
			"label": attack_name + (": its weights by situation, times" if per_situation else ": weight"),
			"default": 1.0 if per_situation else float(weight), "step": 0.25})
	return entries


func _ready():
	super()
	parry_success.connect(func(_player, _kind): _attack_parries += 1)
	# Testing alone: the stand-in (it does nothing while Moves "bifrons_stand_in" is off). As his
	# child it runs after him and before the players, who see its presses that same frame.
	var stand_in = BifronsStandIn.new()
	stand_in.boss = self
	add_child(stand_in)
	rules = SyncRules.new()
	rules.boss = self
	add_child(rules)
	GameManager.rules = rules
	_eye = _rect(EYE_SIZE, Color.WHITE)  # THE BREATH: whom he's turned to
	_eye.visible = false
	body.add_child(_eye)


func _exit_tree():
	if rules != null and GameManager.rules == rules:
		GameManager.rules = null


func get_max_hp() -> float:
	return MAX_HP


func get_display_name() -> String:
	return "COLUMNA BIFRONS"


# One attack per entry of ATTACKS.
func get_attack_pool() -> Array:
	var pool = []
	for attack_name in ATTACKS:
		var entry = ATTACKS[attack_name]
		if entry.has("strikes"):
			pool.append(StrikePattern.new(attack_name, entry.strikes))
		elif entry.has("motif"):
			pool.append(CHAIN.new(attack_name, entry.motif, entry.get("stance", "")))
		else:
			pool.append(entry.attack.new(attack_name))
	for attack in pool:
		if attack.has_signal("both_parried"):
			attack.both_parried.connect(_on_both_parried)
	return pool


func _on_both_parried():
	if rules != null:
		rules.coop_parried()


# How long a parry of both swords by both players staggers him: longer the more of the attack was
# parried (THE STAGGER FROM THE ATTACK); or, with that off, the sync rules' number, else the
# attack's own.
func coop_stagger(own: float) -> float:
	if Moves.on("bifrons_chain_stagger"):
		return Tuning.value("bifrons_stagger_least") + Tuning.value("bifrons_stagger_per_parry") * _attack_parries
	return rules.coop_stagger() if rules != null else own


# Every attack counts its parried blades from its start; a chain's finale of its own counts on from
# the chain's. A chain starts with the player he's turned to (THE BREATH), unless he's answering.
func _begin_telegraph(attack: Attack):
	if not _carry_parries:
		_attack_parries = 0
	_carry_parries = false
	if attack is CHAIN:
		_provoked = false
		if _lead_blade == 0:
			_lead_blade = _gaze
	super(attack)


# What he picks from: each attack's weight for the situation he's in (see ATTACKS), as long as
# the attack is possible at all just now (its fits()).
func get_attack_weights() -> Dictionary:
	var situation = _situation()
	var chains = is_chains()
	var weights = {}
	for attack_name in ATTACKS:
		var attack = find_attack(attack_name)
		var fits = attack == null or attack.fits(self)
		var here = ATTACKS[attack_name].has("motif") == chains  # the chains in their mode, and only they
		weights[attack_name] = weight_in(attack_name, situation) if fits and here else 0.0
	if in_sync_mode():
		# The players' sync mode: only his series of plain cuts (StrikePattern makes them strikes of
		# both swords), nothing that throws the two apart.
		for attack_name in weights:
			var strikes = ATTACKS[attack_name].get("strikes", [])
			if strikes.is_empty() or strikes.any(func(strike): return strike.size() > 2 and strike[2] != StrikePattern.CUT):
				weights[attack_name] = 0.0
	if not TEST_ONLY_PATTERN.is_empty():
		for attack_name in weights:
			if not attack_name in TEST_ONLY_PATTERN:
				weights[attack_name] = 0.0
		# None of the listed ones comes in this situation: he uses them all the same.
		if weights.values().all(func(weight): return weight <= 0.0):
			for attack_name in TEST_ONLY_PATTERN:
				weights[attack_name] = 1.0
	return weights


# An attack's weight in a situation: its F2 weight (tab "patterns"; ATTACKS' number by default), or
# for one with a weight per situation, ATTACKS' weight there times its F2 number. The beat-runner
# and the beat-ring pick his patterns by it too.
static func weight_in(attack_name: String, situation: String) -> float:
	var weight = ATTACKS[attack_name].weight
	var tuned = Tuning.value("bifrons_weight_" + attack_name.to_lower())
	if weight is Dictionary:
		return tuned * weight.get(situation, weight.get(situation.trim_suffix("_cornered"), 0.0))
	return tuned


func get_repeatable_attacks() -> Array:
	return ATTACKS.keys().filter(func(attack_name): return ATTACKS[attack_name].get("repeats", false))


func get_idle_pause() -> float:
	if _handed != "":
		return 0.0  # a chain's finale comes at once
	if is_chains():
		# THE BREATH: he turns to the other player, whom the next chain is for.
		var breath = randf_range(Tuning.value("bifrons_breath_min"), Tuning.value("bifrons_breath_max"))
		_breath_until = anim_time + breath
		_gaze = -_last_lead
		return breath
	var pause = randf_range(Tuning.value("bifrons_pause_min"), Tuning.value("bifrons_pause_max"))
	if _is_reactive():
		pause = randf_range(Tuning.value("bifrons_reactive_min"), Tuning.value("bifrons_reactive_max"))
	if in_sync_mode():
		# On the defensive: slower, and a longer pause on guard between his attacks.
		return pause * Tuning.value("sync_mode_tempo") + Tuning.value("sync_guard_pause")
	return pause


# The players' sync mode (core/sync_rules.gd): he strikes with both swords at once, and slower.
func in_sync_mode() -> bool:
	return rules != null and rules.sync_mode


# The two bound in it (core/sync_bond.gd): his strikes of both swords take both their parries.
func is_bound() -> bool:
	return rules != null and rules.bond != null and rules.bond.bound


# One unit of his waits in seconds just now (F2 "bifrons_time_unit"): his tempo, every pattern at
# once; longer in the players' sync mode.
func time_unit() -> float:
	return Tuning.value("bifrons_time_unit") * (Tuning.value("sync_mode_tempo") if in_sync_mode() else 1.0)


# Players keep their eyes on him (see _face() in player_body.gd): he passes them, and
# they'd turn their backs on him otherwise.
func holds_facing() -> bool:
	return hp > 0.0 and Moves.on("bifrons_face")


# None of his attacks homes on one player, so a player he pushes may always shove the partner
# along (see _keep_out_of_boss() in player_body.gd).
func is_attacking(_player) -> bool:
	return false


func _is_reactive() -> bool:
	return Moves.value("bifrons_mode") == "reactive"


func _physics_process(delta):
	_assign_wards()
	if hp > 0.0:
		_update_turns(delta)
	# Nobody in his range: no attack (he walks up to them instead, see walk()), but the one the
	# dev tools ask for.
	if state == State.IDLE and timer <= delta and dev_next == "" and not _fought().any(in_range):
		timer = RANGE_RECHECK
	# The players' sync mode: he's on the defensive. While one of them draws back, he holds off his
	# next attack, on guard (up to "sync_hold_off" in a row).
	if state != State.IDLE:
		_held_off = 0.0
	elif in_sync_mode() and get_players().any(func(p): return p.is_drawing()):
		_held_off += delta
		if timer <= delta and _held_off < Tuning.value("sync_hold_off"):
			timer = RANGE_RECHECK
	super(delta)
	if hp <= 0.0:
		return
	_run_dash()
	_drift_on(delta)
	if rules != null:
		_judge_windows()
	if state == State.IDLE and _handed != "":
		_begin_finale()
	elif state == State.IDLE and _shove_due and not dev_hold:
		_shove()
	elif state == State.IDLE and _is_reactive() and _provocations >= _patience and not dev_hold:
		_strike_back()
	elif state == State.IDLE and is_chains() and _provoked and not dev_hold:
		_answer_chain()


# Where the players are, as ATTACKS has it: "alone" (both swords on one player), "ppe" (both
# players on one side of him) or "pep"; and those two with "_cornered" while he's cornered.
func _situation() -> String:
	if _turned[LEFT] or _turned[RIGHT]:
		return "alone"
	var where = "ppe" if is_ppe() else "pep"
	return where + "_cornered" if is_cornered() else where


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
	var charge = strikes.filter(func(strike): return strike.size() > 2 and strike[2] == CHARGE)
	if kind == RUSH and first != BOTH:
		for blade in BLADES:
			if _turned[blade]:
				way = first * blade
				_turn(blade, false)  # back on its own player, for this
	elif _answering and first != BOTH:
		way = first * _provoker
	elif _lead_blade != 0 and first != BOTH:
		# A chain, starting with the player he's turned to; or with the other one, if they're away.
		way = first * _lead_blade
		if not can_strike(first * way) and can_strike(-first * way):
			way = -way
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
		var charging = 0 if charge.is_empty() else charge[0][1]  # the charge's sword, as written
		var cramped = charging != 0 and _charge_room(charging * way) < CHARGE_MIN_ROOM \
			and _charge_room(-charging * way) >= CHARGE_MIN_ROOM
		if other_there and (not there or cramped):
			way = -way
	for strike in strikes:
		if strike[1] != BOTH:
			_strikes_by[strike[1] * way] += 1
	if first != BOTH:
		_last_lead = first * way
	_lead_blade = 0
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
			# Back to its own player once they're near again; or once nobody is here either.
			if (distance_to(own) <= RETURN_DISTANCE or not in_range(other)) and _is_free(blade):
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
	_color_swords()


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
# else under it is hit, or chipped behind a block. `knock` scales how far a hit throws them
# back (a heavy strike, the leap). `heavy`: a heavy attack for the sync rules (both_heavy()).
# `throws`: an attack that throws a player back (see A THROW BY OUTCOME). It throws them away
# from him; a judged strike may say which way each one goes instead ("away": player -> side).
func land(judged: Dictionary, strong = false, knock = 1.0, heavy = false, throws = false):
	if rules != null:
		rules.landing_heavy = heavy  # the players' hooks lead to the rules while it lands
	var by_outcome = throws and Moves.on("bifrons_throw_by_outcome")
	var away: Dictionary = judged.get("away", {})
	var thrown = func(p, strength: float) -> Vector2:
		return Vector2(away[p] * strength, -strength * 0.6) if away.has(p) else knockback_for(p, strength)
	for p in judged.under:
		if p in judged.parriers:
			p.on_perfect_parry(strong)
			spawn_sparks(p.global_position + Vector2(0.0, -24.0), 10, COLOR_PLAYER_PARRY)
			var share = Tuning.value("bifrons_parried_throw")
			if by_outcome and share > 0.0:
				p.apply_knockback(thrown.call(p, BLADE_KNOCKBACK * knock * share))
		elif p.is_blocking() or p in judged.get("blocked", []):  # (a lone parry where it takes two: a block)
			p.take_damage(thrown.call(p, (BLADE_KNOCKBACK if by_outcome else BLOCKED_KNOCKBACK) * knock), true)
		else:
			p.take_damage(thrown.call(p, BLADE_KNOCKBACK * knock))
			shake(5.0)
	if rules != null:
		rules.landing_heavy = false
	if not judged.parried:
		Sfx.play("thunk", -6.0)  # the blade hitting the floor


# --- Both swords at once: a strike of both, the leap (see ONE PARRY PER BLADE) ---

# True while both his blades would come down on one place: both on one side of him.
func blades_together() -> bool:
	return Moves.on("bifrons_blade_parries") and is_ppe()


# Whether a strike of both swords is a heavy attack for the sync rules: two blades on one place
# (with ONE PARRY PER BLADE off: any strike of both).
func both_heavy() -> bool:
	return blades_together() or not Moves.on("bifrons_blade_parries")


# A strike of both swords, judged (each blade's judge(), before it lands): which of its parries
# count. Where it takes both players' parries (two blades on one place; or the two bound in their
# sync mode, anywhere), a lone parry has a block's effect. Returns true if both blades were
# parried: by both players, one blade each (with ONE PARRY PER BLADE off: by whoever).
func settle_both(judged: Dictionary) -> bool:
	var parriers = []
	for blade in judged:
		for p in judged[blade].parriers:
			if not p in parriers:
				parriers.append(p)
	var both = judged[LEFT].parried and judged[RIGHT].parried
	if Moves.on("bifrons_blade_parries"):
		both = parriers.size() >= 2
	if not both and (blades_together() or is_bound()):
		for blade in judged:
			judged[blade]["blocked"] = judged[blade].get("blocked", []) + judged[blade].parriers
			judged[blade]["parriers"] = []
			judged[blade]["parried"] = false
	return both


# Sync as life: a window that closed with no sync hit through it, while someone other than the
# parrier was in reach to make one, costs the players sync.
func _judge_windows():
	for blade in BLADES:
		if _open_judged[blade] or anim_time < _open_until[blade]:
			continue
		_open_judged[blade] = true
		var could = get_players().any(func(p): return p != _opened_by[blade] and distance_to(p) <= STRIKE_RANGE)
		if not _open_used[blade] and could:
			rules.missed_window()
			Dev.window_missed()


# source: the player whose sword hit landed. Through a guard their partner's parry broke it's a
# sync hit; a sword that fights them parries it, if it's guarding; anything else is hit. (With
# Moves "bifrons_guard_break" off the guard comes first: in the window only a hit it can't parry
# lands, as a sync hit.) What each costs is the sync rules' (_struck_by_rules()).
func take_damage(amount: float, source = null):
	if rules != null and source != null and hp > 0.0:
		_struck_by_rules(amount, source)
		return
	super(amount, source)


# Sync as life (core/sync_rules.gd): the three cases, and what they cost his sync and posture
# (whatever the swing's amount: a player's attack is normal, heavy in their sync mode; a sync hit
# costs him what any hit does, and wins the players sync), and a guard that's up parries the hit
# by chance, or else blocks it. Staggered or in chaos he has no guard; a hit that lands in chaos
# kills him.
func _struck_by_rules(amount: float, source):
	_slowed_until = anim_time + SLOWED_TIME
	var at = _flank(side_of(source), source.global_position.y)
	var open = BLADES.filter(func(blade): return is_open(blade) and _opened_by[blade] != source)
	var guards = BLADES.filter(func(blade): return ward_of(blade) == source and is_guarding(blade))
	var lethal = false
	if not open.is_empty():
		_open_used[open[0]] = true  # tried: whatever comes of it, the window wasn't left unused
	if not guards.is_empty() and (open.is_empty() or not _open_breaks[open[0]]):
		if randf() < Tuning.value("boss_parry_chance"):
			_parry(guards[0], source, at)
			rules.boss_parried(source)
		else:
			_block(guards[0], source, at)
			rules.boss_blocked()
		return
	if not open.is_empty():
		var blade = open[0]
		var on_beat = anim_time - _open_from[blade] <= Tuning.value("sync_beat_time")
		rules.sync_hit(on_beat)
		Dev.sync_hit(source, anim_time - _open_from[blade], on_beat)
		Sfx.play("sync_hit")
		shake(6.0)
		spawn_sparks(at, 16, SYNC_WAVE.COLOR)  # the parry's energy, passed on into him
		if on_beat:
			Sfx.play("on_beat", -4.0)
			spawn_sparks(at, 14, SYNC_WAVE.CORE)
		lethal = rules.boss_struck()
	else:
		Sfx.play("sync_hit", -6.0)
		shake(3.0)
		spawn_sparks(at, 8, COLOR_EXECUTE)
		lethal = rules.boss_struck()
	super.take_damage(hp if lethal else 0.0, source)


# Sync mode: the bound pair's strike, let go together on the big cue (core/sync_bond.gd). His
# guard can't stop it: met by a blade that's guarding, it still costs him a normal hit's sync and
# he reels ("sync_strike_reel"); else it lands heavy. Either way a big blow.
func take_pair_strike(source):
	if rules == null or hp <= 0.0:
		return
	_slowed_until = anim_time + SLOWED_TIME
	var at = _flank(side_of(source), source.global_position.y)
	var pair = get_players()
	var guards = BLADES.filter(func(blade): return ward_of(blade) in pair and is_guarding(blade))
	shake(14.0)
	spawn_sparks(at, 28, SYNC_WAVE.COLOR)
	spawn_sparks(at, 18, SYNC_WAVE.CORE)
	Sfx.play("grand_impact", -2.0)
	var lethal = false
	if not guards.is_empty():
		_flick_until[guards[0]] = anim_time + PARRY_FLICK_TIME
		Sfx.play("parry_strong", -2.0)
		lethal = rules.pair_strike_parried()
		if not lethal and state != State.STAGGER:
			stagger_now(Tuning.value("sync_strike_reel"))
	else:
		lethal = rules.boss_struck(true)
	super.take_damage(hp if lethal else 0.0, source)


# Sync as life: he takes a player's sword hit on a sword that fights them, without parrying it.
# Their blade isn't knocked back, and it costs him posture, them nothing. In the reactive mode it
# wears on his patience like a parry.
func _block(blade: int, _player, at: Vector2):
	Sfx.play("chip", -4.0)
	shake(2.0)
	spawn_sparks(at, 6, COLOR_PLATE)
	if _is_reactive():
		_provocations += 1
		_provoker = blade
	_provoke(blade)


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
	_provoke(blade)


# He's free, and he wanted room (see "MAKING ROOM"): the shove, if anyone is still that close.
func _shove():
	_shove_due = false
	var shove = find_attack("SHOVE")
	shove.only_side = _shove_side
	_shove_side = 0
	if shove.fits(self):
		_choose_target()
		_begin_telegraph(shove)


# The reactive mode: his patience is gone and he's free. He strikes back at the player whose hit
# he parried last (see REACTIVE_WAIT).
func _strike_back():
	_choose_target()
	if target_player == null:
		return
	_answering = true
	_begin_telegraph(pick_attack())
	_answering = false


# --- The chains (see THE CHAINS) ---

func is_chains() -> bool:
	return Moves.value("bifrons_mode") == "chains" and not in_sync_mode()


# Which finale a chain ends with (attacks/chain.gd): an entry of ATTACKS.
func chain_finale(posture_low: bool) -> String:
	if posture_low or _situation() == "alone":
		return "BOTH"
	if is_ppe():
		for attack_name in ["GATE_LEAP", "LEAP"]:
			if find_attack(attack_name).fits(self):
				return attack_name
		return "BOTH"
	return "CROSSING" if finale_way("CROSSING") != 0 else "BOTH"


# Which way round a chain's finale of strikes goes: the crossing toward whichever side has more
# room for its charge (0: neither has enough); anything else as written.
func finale_way(attack_name: String) -> int:
	if attack_name != "CROSSING":
		return 1
	var charges = ATTACKS.CROSSING.strikes.filter(func(strike): return strike.size() > 2 and strike[2] == CHARGE)
	var charging = charges[0][1] if not charges.is_empty() else RIGHT  # its charge's sword, as written
	var room = _charge_room(charging)
	var other = _charge_room(-charging)
	if maxf(room, other) < CHARGE_MIN_ROOM:
		return 0
	return 1 if room >= other else -1


# A chain is over, and its finale is an attack of its own: it comes next, at once.
func hand_over(attack_name: String):
	_handed = attack_name


func _begin_finale():
	var finale = find_attack(_handed)
	_handed = ""
	if finale == null:
		return
	_carry_parries = true
	_choose_target()
	_begin_telegraph(finale)


# THE BREATH: a hit at his guard (that sword's player's) calls up the next chain.
func _provoke(blade: int):
	if is_chains() and state in [State.IDLE, State.RECOVER] and not dev_hold:
		_provoked = true
		_provoker = blade


# ...at once, its first strike at the attacker.
func _answer_chain():
	_provoked = false
	_choose_target()
	_answering = true
	_lead_blade = _provoker
	_gaze = _provoker
	_begin_telegraph(pick_attack())
	_answering = false


# THE BREATH: he walks toward the middle of the room (bifrons_moves.gd).
func _wants_middle() -> bool:
	return is_chains() and (state == State.RECOVER or (state == State.IDLE and anim_time < _breath_until))


# His eye: at the top of him, on the side of the player he's turned to, in their color.
func _update_pose():
	super()
	if _eye == null:
		return  # (BaseBoss poses him once before he's ready)
	var ward = ward_of(_gaze)
	_eye.visible = is_chains() and hp > 0.0 and ward != null
	if not _eye.visible:
		return
	var to = EYE_INSET if blade_side(_gaze) == LEFT else body.size.x - EYE_INSET - EYE_SIZE.x
	var turn = 1.0 - exp(-EYE_TURN * get_physics_process_delta_time())
	_eye.position = Vector2(lerpf(_eye.position.x, to, turn), EYE_TOP)
	_eye.color = ward.player_color


func _die():
	_open_until = {LEFT: 0.0, RIGHT: 0.0}
	_open_shown = {LEFT: true, RIGHT: true}
	_stagger_poses = {}
	_dash = null
	global_position.y = home_position.y  # not left hanging in a leap
	super()


# His body warms as his patience runs out: how far, 0 to 1.
func _body_heat() -> float:
	return clampf(float(_provocations) / _patience, 0.0, 1.0) if _is_reactive() else 0.0
