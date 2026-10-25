class_name Acrobat
extends AcrobatBody
## The Acrobat (working title; docs/boss_acrobat.md): light, quick, never long in one place; a juggler
## with four rings, two in each hand (acrobat_body.gd). He moves himself all the time, and the
## formation shifts because the players chase him. Phase 1 only (the mirror rule's stage 0: one body);
## phase 2, point-mirrored, comes next.
##
## HIS RULE, THE ARC AND THE STRIKE BACK (ring.gd): every ring he throws flies back to him in an arc,
## and he catches it. Blocked, hit or missed, in the layer it came in, and nobody can strike it.
## Parried, it goes through the mirror into the partner's layer, and the partner can strike it where it
## passes them: then it goes straight at him, a strike back (ring_struck_back()): a hit on him, always;
## in the partner's window (the parry opened it), a sync hit. It staggers him only at the end of a
## finale (the rally's last throw, the throw off the plunge parried together).
##
## THE CHAINS (attacks/phrase.gd): a chain is one or two motifs (at random, F2 "acrobat_motifs_min" to
## "_max"; sooner done if his posture is low, "acrobat_chain_posture"), then a finale. The motifs are
## longer phrases, each told by its first link (MOTIFS in motif_steps()):
## - THE THROWING CHAIN: [a dash back, if someone is close] -> a throw at the farther one -> the ring
##   back, caught in a jump (or struck back) -> a jump strike (at whoever struck it back, else the
##   nearer one) -> two quick strikes, each hand at its player;
## - THE WHIRL: a dash in -> strike -> strike -> feint -> strike, each hand at its player, by turns, the
##   nearer one first (so the feint, always third, is the nearer one's).
## Which motif: at random, weighted by distance (pick_motif(): the nearer one farther than
## "acrobat_far", rather the throwing chain, by "acrobat_far_weight" to 1; else rather the whirl).
## THE SALTO ends every motif, and where he lands says what comes (salto_steps()): forward over the
## nearer one with a kick, the whirl next (or a wall behind them: a wall finale); backward away from
## them with a throw, the throwing chain next (its throw is the salto's; or a wall behind him); into the
## mirror line, the dive.
## THE FINALES, by what he sees, never by chance (chain_finale()): a ring struck back in this chain,
## the rally; else both on one side of him (ppe), the dive; else (pep), the plunge. The same one at most
## twice in a row (fresh_finale()): a third time, the next in FINALE_ORDER comes instead.
## HIS BREATH (2-3 s, "acrobat_breath_min" / "_max"): always moving (dashes, a salto over them, a moment
## on a wall). A hit then meets nothing: he evades (_evade()), and his next chain starts at the
## attacker (not while the dev tools hold him, dev_hold). In a chain he's open: hits land, on the floor,
## in the air, on a wall (a jump attack reaches him there).
## HIS POSTURE: a placeholder for phase 2 (which its first break will start): broken, a long stagger
## ("acrobat_break_stagger"), and his sync stays.
## IN THE PLAYERS' SYNC MODE (a stand-in for a pattern of his own, still open): the whirl only, and
## the plunge without a throw (parried together: staggered at once); no dive; slower
## ("sync_mode_tempo", his breath too); he holds off his next chain while one of them draws back.

# --- Tuning ---
const MAX_HP = 1000.0  # (BaseBoss's; sync as life decides the fight)
const PHRASE = preload("attacks/phrase.gd")
# HIS ATTACKS, in the F5 lab's order. The chain comes by itself; the rest are its parts, one at a time
# for the lab: a motif (with a salto after it), a finale (with the salto that leads into it), a verb.
const ATTACKS = {
	"CHAIN": {"chain": true},
	"WHIRL": {"motif": "WHIRL"},
	"THROWING": {"motif": "THROWING"},
	"RALLY": {"finale": "RALLY"},
	"PLUNGE": {"finale": "PLUNGE"},
	"DIVE": {"finale": "DIVE"},
	"STRIKE": {"steps": [{"do": "strike", "at": "near", "wait": 3}]},
	"FEINT": {"steps": [{"do": "strike", "at": "near", "wait": 3, "feint": true}]},
	"THROW": {"steps": [{"do": "throw", "at": "far", "wait": 3}, {"do": "await"}]},
	"SALTO_KICK": {"steps": [{"do": "salto", "kind": "kick", "wait": 4}]},
	"SALTO_THROW": {"steps": [{"do": "salto", "kind": "throw", "wait": 4}, {"do": "await"}]},
}
const FINALE_ORDER = ["RALLY", "DIVE", "PLUNGE"]  # a third time in a row: the next one here instead

# HIS STRIKES LANDING (land_strike(), ring_arrived()):
const STRIKE_REACH = 100.0  # px from his center along the floor: a strike reaches this far...
const REACH_UP = 110.0  # ...and this far up or down (a kick from over their head)
const PLUNGE_REACH = 150.0  # the plunge, landing between them: each hand reaches this far
const MEET_REACH = 44.0  # a thrown ring meets its player this near their chest
const STRIKE_KNOCKBACK = 220.0  # hit
const BLOCKED_KNOCKBACK = 110.0
const HEAVY_KNOCKBACK = 300.0  # a heavy strike, hit or blocked
const RING_KNOCKBACK = 160.0  # a ring, hit
# HIS BREATH: a move every BREATH_STEP_MIN to _MAX s; he keeps BREATH_NEAR to _FAR from the nearer
# one, now and then flips over them, or hangs a moment on a wall near him.
const BREATH_STEP_MIN = 0.5
const BREATH_STEP_MAX = 0.9
const BREATH_NEAR = 150.0
const BREATH_FAR = 220.0
const BREATH_SALTO_CHANCE = 0.2
const BREATH_WALL_CHANCE = 0.15
const BREATH_WALL_NEAR = 180.0  # px: a wall this near, he may jump onto it
const EVADE_DISTANCE = 150.0  # a hit in his breath: he dashes this far away
const RECHECK = 0.1  # not ready to start a chain (moving, off the floor): he looks again this much later

var finale_reason = ""  # why the last chain's finale was what it was (the log, the tests)
var chain_blades = 0  # blades parried in the run under way (THE STAGGER in attacks/phrase.gd)
var _struck_this_chain = false  # the players struck a ring back in this chain
var _finales: Array = []  # his finales so far, the last last
var _next_move = 0.0  # his breath: s until his next move
var _provoked_by = null  # a hit in his breath: whom he answers
var _answering = null  # ...while his answer starts (answering())
var _held_off = 0.0  # the players' sync mode: how long he has held off his next chain


# His numbers on F2 (core/tuning.gd collects them): a page of his own, in his room.
static func tuning_entries() -> Array:
	return [
		{"page": "acrobat", "title": "Acrobat", "scenes": ["levels/acrobat/"], "header": "TEMPO", "tab": "tempo"},
		{"key": "acrobat_beat", "label": "a beat of his (s): his steps' waits are 2-5 of them", "default": 0.2, "step": 0.01},
		{"key": "acrobat_strike_time", "label": "a strike's drop: the cue to parry (s)", "default": 0.15, "step": 0.01},
		{"key": "acrobat_feint_delay", "label": "a feint: the real strike this long after it twitches (s)", "default": 0.2, "step": 0.01},
		{"key": "acrobat_recover_time", "label": "after a chain, before his breath (s)", "default": 0.4, "step": 0.05},
		{"header": "THE CHAINS", "column": 1},
		{"key": "acrobat_motifs_min", "label": "a chain plays at least this many motifs (at random up to...)", "default": 1.0, "step": 1.0},
		{"key": "acrobat_motifs_max", "label": "...at most, then its finale", "default": 2.0, "step": 1.0},
		{"key": "acrobat_chain_posture", "label": "his posture below this (%): the finale after this motif", "default": 30.0, "step": 5.0},
		{"key": "acrobat_far", "label": "the nearer one farther than this (px): rather the throwing chain", "default": 220.0, "step": 10.0},
		{"key": "acrobat_far_weight", "label": "...by this to 1 (else rather the whirl, the same)", "default": 3.0, "step": 0.5},
		{"key": "acrobat_breath_min", "label": "his breath after a chain, from (s)", "default": 2.0, "step": 0.1},
		{"key": "acrobat_breath_max", "label": "...to (s)", "default": 3.0, "step": 0.1},
		{"header": "THE RINGS: THE ARC AND THE STRIKE BACK", "tab": "rings"},
		{"key": "acrobat_throw_flight", "label": "a throw: from his hand to you, red (s)", "default": 0.35, "step": 0.01},
		{"key": "acrobat_arc_time", "label": "back to him in an arc (s)", "default": 1.2, "step": 0.05},
		{"key": "acrobat_arc_height", "label": "...this high over the straight way (px)", "default": 90.0, "step": 5.0},
		{"key": "acrobat_arc_ease", "label": "...this slow at its start (1: even; 2: slow, then fast)", "default": 2.0, "step": 0.1},
		{"key": "acrobat_strike_back_reach", "label": "the partner's blade strikes it back this near it (px)", "default": 48.0, "step": 2.0},
		{"header": "THE FINALES", "column": 1},
		{"key": "acrobat_plunge_stand", "label": "the plunge parried together: on your blades (s)", "default": 0.4, "step": 0.05},
		{"key": "acrobat_line_time", "label": "the dive: under the floor (s)", "default": 1.0, "step": 0.05},
		{"key": "acrobat_ripple_time", "label": "...where he comes up ripples this long before (s)", "default": 0.5, "step": 0.05},
		{"header": "THE STAGGER (A FINALE'S END) AND HIS POSTURE", "tab": "stagger"},
		{"key": "acrobat_stagger_least", "label": "staggered (s)", "default": 0.5, "step": 0.1},
		{"key": "acrobat_stagger_per_parry", "label": "...and longer by this per blade parried in the chain (s)", "default": 0.2, "step": 0.05},
		{"key": "acrobat_posture_max", "label": "his posture (points)", "default": 200.0, "step": 10.0},
		{"key": "acrobat_break_stagger", "label": "his posture broken (phase 2's place, for now): staggered (s)", "default": 3.0, "step": 0.1},
		{"header": "THE STAND-IN (F1: bifrons_stand_in)", "column": 1},
		{"key": "acrobat_stand_in_parry", "label": "it parries his strikes and rings this often", "default": 0.75, "step": 0.05},
		{"key": "acrobat_stand_in_block", "label": "...only blocks them this often (the rest hit it)", "default": 0.15, "step": 0.05},
		{"key": "acrobat_stand_in_strike_back", "label": "it strikes back a parried ring passing it this often", "default": 0.7, "step": 0.05},
	]


func _ready():
	super()
	rules = SyncRules.new()
	rules.boss = self
	add_child(rules)
	GameManager.rules = rules
	# Testing alone: the stand-in (it does nothing while Moves "bifrons_stand_in" is off). As his
	# child it runs after him and before the players, who see its presses that same frame.
	var stand_in = AcrobatStandIn.new()
	stand_in.boss = self
	add_child(stand_in)


func _exit_tree():
	if rules != null and GameManager.rules == rules:
		GameManager.rules = null


func get_max_hp() -> float:
	return MAX_HP


func get_display_name() -> String:
	return "ACROBAT"


# One attack per entry of ATTACKS.
func get_attack_pool() -> Array:
	var pool = []
	for attack_name in ATTACKS:
		pool.append(PHRASE.new(attack_name, ATTACKS[attack_name], ATTACKS[attack_name].get("chain", false)))
	return pool


# Only the chain comes by itself (the rest: the F5 lab's).
func get_attack_weights() -> Dictionary:
	return {"CHAIN": 1.0}


func get_repeatable_attacks() -> Array:
	return ["CHAIN"]


# HIS BREATH, after his recovery.
func get_idle_pause() -> float:
	var breath = randf_range(Tuning.value("acrobat_breath_min"), Tuning.value("acrobat_breath_max"))
	return breath * (Tuning.value("sync_mode_tempo") if in_sync_mode() else 1.0)


# The players keep their eyes on him (see _face() in player_body.gd): he flips over them.
func holds_facing() -> bool:
	return hp > 0.0


# None of his attacks homes on one player, so a player he pushes may always shove the partner along
# (see _keep_out_of_boss() in player_body.gd).
func is_attacking(_player) -> bool:
	return false


func _physics_process(delta):
	# Not ready for a chain while he's still moving or off the floor (a wall in his breath).
	if state == State.IDLE and timer <= delta and dev_next == "" and (moving() or place != Place.FLOOR):
		timer = RECHECK
	# The players' sync mode: while one of them draws back, he holds off his next chain (up to
	# "sync_hold_off" in a row).
	if state != State.IDLE:
		_held_off = 0.0
	elif in_sync_mode() and get_players().any(func(p): return p.is_drawing()):
		_held_off += delta
		if timer <= delta and _held_off < Tuning.value("sync_hold_off"):
			timer = RECHECK
	super(delta)
	if hp <= 0.0:
		return
	update_windows()
	if state in [State.IDLE, State.RECOVER] and nearer() != null and not moving():
		face(nearer().global_position.x)
	if state == State.IDLE and is_instance_valid(_provoked_by) and not dev_hold and not moving() and place == Place.FLOOR:
		_answer()


# --- Sync as life (core/sync_rules.gd) ---

func max_posture() -> float:
	return Tuning.value("acrobat_posture_max")


# His posture broken: for now a long stagger, and his sync stays (phase 2 will begin here).
func on_posture_broken() -> bool:
	stagger_now(Tuning.value("acrobat_break_stagger"))
	return false


# The players' sync mode (core/sync_rules.gd): slower, the whirl and the plunge only.
func in_sync_mode() -> bool:
	return rules != null and rules.sync_mode


# The two bound in it (core/sync_bond.gd).
func is_bound() -> bool:
	return rules != null and rules.bond != null and rules.bond.bound


# One beat of his in seconds just now (F2 "acrobat_beat"); slower in the players' sync mode.
func beat() -> float:
	return Tuning.value("acrobat_beat") * (Tuning.value("sync_mode_tempo") if in_sync_mode() else 1.0)


# His breath: between his chains (not staggered).
func in_breath() -> bool:
	return state in [State.IDLE, State.RECOVER]


# source: the player whose sword hit landed. In his breath it meets nothing: he evades. Otherwise it
# lands: in a window their partner's parry opened, a sync hit. What each costs is the sync rules'.
func take_damage(amount: float, source = null):
	if rules != null and source != null and hp > 0.0:
		_struck_by(source)
		return
	super(amount, source)


func _struck_by(source):
	if in_breath():
		_evade(source)
		return
	var lethal = _lands_on_him(source, global_position + Vector2(side_of(source) * SIZE.x / 2.0, 0.0))
	super.take_damage(hp if lethal else 0.0, source)


# A hit of `p`'s landing on him at `at`: a sync hit if their window is open. Returns true if it kills.
func _lands_on_him(p, at: Vector2) -> bool:
	var window = open_window_of(p) if p != null else null
	if window != null:
		window.used = true
		var on_beat = anim_time - window.from <= Tuning.value("sync_beat_time")
		rules.sync_hit(on_beat)
		Dev.sync_hit(p, anim_time - window.from, on_beat)
		Sfx.play("sync_hit")
		shake(6.0)
		spawn_sparks(at, 16, SyncWave.COLOR)  # the parry's energy, passed on into him
		if on_beat:
			Sfx.play("on_beat", -4.0)
			spawn_sparks(at, 14, SyncWave.CORE)
	else:
		Sfx.play("sync_hit", -6.0)
		shake(3.0)
		spawn_sparks(at, 8, COLOR_EXECUTE)
	return rules.boss_struck(false)


# A hit in his breath: it meets nothing. He dashes away (off a wall: jumps), and answers with his next
# chain, its first link at the attacker.
func _evade(source):
	Sfx.play("swing", -6.0)
	var away = -side_of(source)
	stop_moving()
	var goal = floor_point(global_position.x + away * EVADE_DISTANCE)
	if place == Place.FLOOR:
		move_to(goal, DASH_TIME)
	else:
		move_to(goal, 0.4, 40.0)
	Dev.note("evade", {"by": source.player_id})
	if not dev_hold:
		_provoked_by = source


# ...at once, its first link at the attacker.
func _answer():
	_answering = _provoked_by
	_provoked_by = null
	_choose_target()
	_begin_telegraph(find_attack("CHAIN"))
	_answering = null


# The player whose hit his chain starting just now answers, or null.
func answering():
	return _answering if is_instance_valid(_answering) else null


# Sync mode: the bound pair's strike, let go together on the big cue (core/sync_bond.gd). In his
# breath he can't get away from it: it costs him a normal hit's sync and he reels ("sync_strike_reel");
# else it lands heavy.
func take_pair_strike(source):
	if rules == null or hp <= 0.0:
		return
	var at = global_position
	shake(14.0)
	spawn_sparks(at, 28, SyncWave.COLOR)
	spawn_sparks(at, 18, SyncWave.CORE)
	Sfx.play("grand_impact", -2.0)
	var lethal = false
	if in_breath():
		lethal = rules.pair_strike_parried()
		if not lethal and state != State.STAGGER:
			stagger_now(Tuning.value("sync_strike_reel"))
	else:
		lethal = rules.boss_struck(true)
	super.take_damage(hp if lethal else 0.0, source)


# Seconds until his next blow lands on that player, a strike or a ring; INF if none is coming at them.
func time_to_strike(player) -> float:
	var due = INF
	if current_attack != null and state in [State.TELEGRAPH, State.ATTACKING]:
		due = current_attack.time_to_strike(player)
	for ring in get_tree().get_nodes_in_group("acrobat_rings"):
		due = minf(due, ring.time_to_strike(player))
	return due


# --- His strikes landing (used by attacks/phrase.gd) ---

# That player is in reach of a strike of his (from his center; `reach` along the floor).
func in_reach(p, reach = STRIKE_REACH) -> bool:
	return absf(p.global_position.x - global_position.x) <= reach \
		and absf(p.global_position.y - global_position.y) <= REACH_UP


# A strike lands on `targets` (those in reach meet it). Normal (one blade, one player): a lone parry
# is a parry, and opens the partner's window. Heavy (both hands on one place): parried by both, a
# co-op parry (each opens the other's window); by one, a block's effect. `toss`: the upcut, which
# throws them that way whatever they did. Returns the players whose parries counted.
func land_strike(targets: Array, heavy: bool, toss = Vector2.ZERO, reach = STRIKE_REACH) -> Array:
	var under = targets.filter(func(p): return p != null and is_instance_valid(p) and not p.is_dead() and in_reach(p, reach))
	var tried = under.filter(func(p): return p.is_perfect_parry())
	var counted = tried.size() >= 2 or (not heavy and not tried.is_empty())
	var parriers = []
	rules.landing_heavy = heavy  # the players' hooks lead to the rules while it lands
	for p in under:
		var thrown = toss if toss != Vector2.ZERO else knockback_for(p, HEAVY_KNOCKBACK if heavy else STRIKE_KNOCKBACK)
		if p in tried and counted:
			p.on_perfect_parry(heavy)
			spawn_sparks(p.global_position + Vector2(0.0, -20.0), 12 if heavy else 8, COLOR_PARRY)
			parriers.append(p)
			if toss != Vector2.ZERO:
				p.apply_knockback(toss)
		elif p.is_blocking() or p in tried:  # (a lone parry where it takes two: a block's effect)
			p.take_damage(toss if toss != Vector2.ZERO else knockback_for(p, HEAVY_KNOCKBACK if heavy else BLOCKED_KNOCKBACK), true)
		else:
			p.take_damage(thrown)
	rules.landing_heavy = false
	for p in parriers:
		open_window(p.partner(), p)
	chain_blades += parriers.size()
	if heavy and parriers.size() >= 2:
		Sfx.play("counter_hit", -4.0)
	shake(7.0 if heavy else 4.0)
	Sfx.play("stab", -6.0)
	return parriers


# Both hands at once, at where the players are: one each side, two normal strikes; both on one side,
# heavy. Returns {parriers, together: both blades parried}.
func land_both(reach = PLUNGE_REACH) -> Dictionary:
	var them = by_distance()
	var parriers = []
	if them.size() >= 2 and side_of(them[0]) == side_of(them[1]):
		parriers = land_strike(them, true, Vector2.ZERO, reach)
	else:
		for p in them:
			parriers += land_strike([p], false, Vector2.ZERO, reach)
	return {"parriers": parriers, "together": them.size() >= 2 and parriers.size() >= 2}


# A strike meant for `p` (gone: the nearer one).
func strike_target(p):
	if p != null and is_instance_valid(p) and not p.is_dead():
		return p
	return nearer()


# Where the plunge comes down: between them if they're apart; else in front of the front one.
func plunge_x() -> float:
	var them = by_distance()
	if them.is_empty():
		return global_position.x
	if them.size() >= 2 and not together():
		return (them[0].global_position.x + them[1].global_position.x) / 2.0
	var front = them[0]
	return front.global_position.x - side_of(front) * STRIKE_REACH * 0.5


# A ring has arrived where it was thrown (ring.gd): its player meets it there, if they're there. A
# volley (the rally's last throw) is one heavy throw: both have to parry, else a parry has a block's
# effect. Parried, a ring goes through the mirror to the partner, and the parry opens their window.
func ring_arrived(ring):
	if ring.outcome != "":
		return  # (met with its volley)
	var rings = ring.volley if ring.volley.size() >= 2 else [ring]
	var heavy = rings.size() >= 2
	var met = {}  # ring -> its player, there
	var tried = []
	for r in rings:
		var p = r.target
		if p != null and is_instance_valid(p) and not p.is_dead() \
				and (p.global_position + AcrobatRing.CHEST).distance_to(r.point()) <= MEET_REACH:
			met[r] = p
			if p.is_perfect_parry():
				tried.append(r)
	var counted = tried.size() >= 2 or (not heavy and not tried.is_empty())
	var parriers = []
	rules.landing_heavy = heavy
	for r in rings:
		if not met.has(r):
			r.resolve(AcrobatRing.MISSED)
			continue
		var p = met[r]
		if r in tried and counted:
			p.on_perfect_parry(heavy)
			spawn_sparks(r.point(), 10, COLOR_PARRY)
			parriers.append(p)
			r.resolve(AcrobatRing.PARRIED)
		elif p.is_blocking() or r in tried:
			p.take_damage(knockback_for(p, HEAVY_KNOCKBACK if heavy else BLOCKED_KNOCKBACK), true)
			r.resolve(AcrobatRing.BLOCKED)
		else:
			p.take_damage(knockback_for(p, HEAVY_KNOCKBACK if heavy else RING_KNOCKBACK))
			r.resolve(AcrobatRing.HIT)
	rules.landing_heavy = false
	for p in parriers:
		open_window(p.partner(), p)
	chain_blades += parriers.size()
	Dev.note("ring", {"outcome": rings.map(func(r): return r.outcome), "heavy": heavy})


# A ring back in his hand.
func catch_ring(_ring):
	Sfx.play("chip", -12.0)


# A ring struck back at him (ring.gd): a hit, always, by whoever struck it; in their window (their
# partner's parry opened it), a sync hit. At the end of a finale it staggers him (attacks/phrase.gd).
func ring_struck_back(ring, by):
	_struck_this_chain = true
	if rules == null or hp <= 0.0:
		return
	Dev.note("strike_back", {"by": by.player_id if by != null else 0, "finale_end": ring.finale_end})
	shake(6.0)
	var lethal = _lands_on_him(by, ring.point())
	if current_attack != null and current_attack.has_method("on_strike_back"):
		current_attack.on_strike_back(ring)
	super.take_damage(hp if lethal else 0.0, null)


# How long a finale's end staggers him: longer the more blades of the chain were parried.
func chain_stagger() -> float:
	return Tuning.value("acrobat_stagger_least") + Tuning.value("acrobat_stagger_per_parry") * chain_blades


# A run of his begins (attacks/phrase.gd): nothing parried yet, nothing struck back.
func begin_run():
	chain_blades = 0
	_struck_this_chain = false


# --- The chains: the motifs, the salto, the finales (THE CHAINS) ---

# Which motif comes: at random, weighted by distance. In the players' sync mode, the whirl.
func pick_motif() -> String:
	if in_sync_mode():
		return "WHIRL"
	var near = nearer()
	var far = near != null and distance_to(near) > Tuning.value("acrobat_far")
	var weight = Tuning.value("acrobat_far_weight")
	var throwing = weight if far else 1.0
	var whirl = 1.0 if far else weight
	return "THROWING" if randf() * (throwing + whirl) < throwing else "WHIRL"


# A motif's steps, told by its first link: `first` is whom it starts at (an attacker he answers;
# null: the whirl's the nearer one, the throwing chain's the farther one). `after_salto`: the throwing
# chain whose throw was the salto's.
func motif_steps(motif: String, first, after_salto: bool) -> Array:
	match motif:
		"WHIRL":
			var a = first if first != null else nearer()
			var b = _other_than(a)
			return [{"do": "dash", "way": "in", "at": a, "wait": 2},
				{"do": "strike", "at": a, "wait": 3}, {"do": "strike", "at": b, "wait": 3},
				{"do": "strike", "at": a, "wait": 3, "feint": true}, {"do": "strike", "at": b, "wait": 3},
				{"do": "motif_end"}]
		"THROWING":
			var steps = []
			if not after_salto:
				var target = first if first != null else farther()
				steps = [{"do": "dash", "way": "back", "at": target, "wait": 2}, {"do": "throw", "at": target, "wait": 3}]
			return steps + [{"do": "catch", "wait": 2}, {"do": "strike", "at": "near", "wait": 2},
				{"do": "strike", "at": "other", "wait": 2}, {"do": "motif_end"}]
	return [{"do": "motif_end"}]


func _other_than(p):
	for q in by_distance():
		if q != p:
			return q
	return p


# The salto that ends a motif, by what comes next: forward with a kick (the whirl), backward with a
# throw (the throwing chain), to the wall (the rally, the plunge), into the line after the cut (the
# dive).
func salto_steps(next: String) -> Array:
	match next:
		"THROWING":
			return [{"do": "salto", "kind": "throw", "at": "far", "wait": 4}]
		"RALLY", "PLUNGE":
			return [{"do": "salto", "kind": "wall", "wait": 4, "no_throw": in_sync_mode()}]
		"DIVE":
			return [{"do": "cut", "wait": 2}, {"do": "salto", "kind": "line", "wait": 2}]
	return [{"do": "salto", "kind": "kick", "wait": 4}]


func finale_steps(finale: String) -> Array:
	match finale:
		"RALLY":
			return [{"do": "throw", "at": "turn", "wait": 5, "rally": true}, {"do": "throw", "at": "turn", "wait": 4, "rally": true},
				{"do": "throw", "at": "turn", "wait": 3, "rally": true}, {"do": "volley", "wait": 5}, {"do": "await", "end": true}]
		"PLUNGE":
			return [{"do": "plunge", "wait": 4}]
		"DIVE":
			return [{"do": "under"}, {"do": "upcut"}, {"do": "both", "wait": 4, "end": true}]
	return []


# The lab's steps for one entry of ATTACKS: a motif with the salto after it, a finale with the salto
# into it, or a verb.
func lab_steps(entry: Dictionary) -> Array:
	if entry.has("motif"):
		var steps = motif_steps(entry.motif, null, false).filter(func(s): return s.do != "motif_end")
		return steps + salto_steps("WHIRL")
	if entry.has("finale"):
		return salto_steps(entry.finale) + finale_steps(entry.finale)
	return entry.get("steps", []).duplicate(true)


# Which finale a chain ends with (THE FINALES), by what he sees; why is left in finale_reason.
func chain_finale() -> String:
	var pick = "PLUNGE"
	if in_sync_mode():
		finale_reason = "sync mode"
		_finales.append(pick)
		return pick
	if _struck_this_chain:
		pick = "RALLY"
		finale_reason = "a ring struck back"
	elif together():
		pick = "DIVE"
		finale_reason = "together (ppe)"
	else:
		finale_reason = "apart (pep)"
	var fresh = fresh_finale(pick, _finales, FINALE_ORDER)
	if fresh != pick:
		finale_reason += "; %s twice already" % pick
	_finales.append(fresh)
	return fresh


# No finale starves, none takes over (docs/concept.md): `pick` a third time in a row (after `before`,
# the last last) gives way to the next in `order`.
static func fresh_finale(pick: String, before: Array, order: Array) -> String:
	if before.size() >= 2 and before[-1] == pick and before[-2] == pick:
		return order[(order.find(pick) + 1) % order.size()]
	return pick


# --- His breath (HIS BREATH) ---

func _idle_motion(delta: float):
	_breathe(delta)


func _recover_motion(delta: float):
	_breathe(delta)


# Always moving: a dash to keep his distance from the nearer one, now and then a salto over them, or a
# moment on a wall near him.
func _breathe(delta: float):
	if moving():
		return
	_next_move -= delta
	if _next_move > 0.0:
		return
	_next_move = randf_range(BREATH_STEP_MIN, BREATH_STEP_MAX)
	var x = global_position.x
	if place != Place.FLOOR:
		var middle = (ARENA_LEFT + ARENA_RIGHT) / 2.0
		move_to(floor_point(x + signf(middle - x) * 120.0), 0.45, 40.0)  # off the wall
		return
	var near = nearer()
	if near == null:
		return
	var side = side_of(near)
	var roll = randf()
	var wall = nearer_wall()
	if roll < BREATH_WALL_CHANCE and absf(wall_point(wall).x - x) < BREATH_WALL_NEAR:
		move_to(wall_point(wall), 0.4, 50.0, 0.0, Place.WALL)
		return
	if roll < BREATH_WALL_CHANCE + BREATH_SALTO_CHANCE and distance_to(near) < BREATH_FAR:
		var over = floor_point(near.global_position.x + side * 120.0)
		if absf(over.x - near.global_position.x) > 60.0:
			move_to(over, 0.55, 90.0, side)
			return
	var want = near.global_position.x - side * randf_range(BREATH_NEAR, BREATH_FAR)
	if absf(want - x) > 30.0:
		move_to(floor_point(want), DASH_TIME)


# Back on the floor where he is, at once (an attack cut short).
func settle():
	stop_moving()
	place = Place.FLOOR
	global_position = floor_point(global_position.x)
	body.scale = Vector2.ONE
	body.modulate.a = 1.0


# --- Testing alone ---

# The player Moves "bifrons_stand_in" has the stand-in play ("left": P1, "right": P2), or null.
func stand_in_player():
	var id = {"left": 1, "right": 2}.get(Moves.value("bifrons_stand_in"), 0)
	return player_of(id) if id != 0 else null
