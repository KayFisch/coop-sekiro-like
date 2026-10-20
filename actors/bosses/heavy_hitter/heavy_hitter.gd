class_name HeavyHitter
extends HitterWeapon
## The Heavy Hitter, the Ettin (working title; docs/boss_heavy_hitter.md): two heads, one weapon held
## level, which can point differently in the two players' layers (hitter_weapon.gd). He attacks
## whatever is in front of his nose, and he's open while he attacks, guarded only in his breath.
## Built so far: phase 1 (the weapon always parallel), and no rage yet: his posture broken, a long
## stagger stands in for it, and his sync stays.
##
## THE RULES (v0):
## 1. Unisono: every blade strike comes down in both layers at once, and in each the player of that
##    layer in front of the blade, in its reach, meets it (land_blade()). Both parry: a co-op parry
##    (a window each, two blades toward the stagger). Only one: their parry has a block's effect.
## 2. The crack: a blade that comes down where nobody of its layer is in front of it crashes into
##    the mirror, and a crack runs from there both ways along the floor (crack.gd). It hits that
##    layer's player on the floor: jump it.
## 3. The pommel: quick jabs at whoever is in front of it, in each layer (land_jab()). Normal strikes:
##    a lone parry is a parry, and opens the partner's window. A parried jab, and a hit on his pommel
##    side, cost him more posture (F2 "hitter_pommel_posture").
## 4. Open while he attacks (a chain's first windup to its end, a stagger too): hits land and cost his
##    sync. Guarded only in his breath (HIS GUARD in hitter_weapon.gd).
## 5. In his breath he turns, to bring the blade in front of the players (THE TURN). Only the turn:
##    the alignment stays.
## 6. Posture is his rage meter (step 2). For now, broken: a long stagger, and his sync stays.
##
## THE FIELDS: where the players are against the weapon (field()). "together": both in front of the
## blade, each in their own layer; "split": one at the blade, one at the pommel; "pommel": both at
## the pommel. By the sides they're on; whether a strike reaches them is its reach's business.
##
## THE CHAINS (attacks/swings.gd): his attack is a chain, a motif (MOTIFS: the field's, never chance)
## repeated, decided only as each repetition's last strike lands: the field's motif once more (if
## the field has changed, the new one's), until the chain has the repetitions it was given (at
## random, F2 "hitter_reps_min" to "_max"); then the finale, by what he sees (chain_finale()):
## - the together field: the great hammer;
## - the together field for "hitter_together_stale" of his chains in a row: the stomp leap;
## - split, or both at the pommel: the stomp leap.
## A finale parried together staggers him "hitter_stagger_least", and "hitter_stagger_per_parry" more
## for each blade parried in the chain (a co-op parry: two; a parried jab: one; a lone parry with a
## block's effect: none).
## THE BREATH: after each chain a pause (F2 "hitter_breath_min" / "_max", after his recovery). He
## doesn't attack, he walks slowly, and as it begins he turns round if that puts more of the players
## in front of the blade; with as many either way, to whoever hit his pommel side last since he last
## turned, and else round anyway, to the other one (THE TURN). A hit at his guard meanwhile is
## answered at once: the next chain, its first strike at the attacker (at his pommel: a jab first).
## Not while the dev tools hold him (dev_hold).
## IN THE PLAYERS' SYNC MODE (a stand-in for a pattern of his own, still open): only the together
## motif and the great hammer, slower ("sync_mode_tempo", his breath too), and he holds off his next
## chain while one of them draws back (up to "sync_hold_off").

# --- Tuning ---
const MAX_HP = 1000.0  # (BaseBoss's; sync as life decides the fight)

const BLADE = HitterSwings.BLADE
const POMMEL = HitterSwings.POMMEL
const HAMMER = HitterSwings.HAMMER
const STOMP = HitterSwings.STOMP
# THE MOTIFS, one per field, each [wait, verb]: `wait` is the beats (F2 "hitter_beat") until it lands,
# from the strike before (the first: from the chain's start, or the repetition before).
const MOTIFS = {
	"together": [[2, BLADE], [2, BLADE], [3, BLADE]],  # all three parried together
	"split": [[2, BLADE], [1, POMMEL], [2, BLADE], [1, POMMEL]],  # the seesaw
	"pommel": [[2, POMMEL], [1, POMMEL], [1, POMMEL]],  # both at the pommel: jabs only
}
const FINALES = {
	"HAMMER": [[4, HAMMER]],  # the great hammer: a long windup
	"STOMP": [[3, STOMP]],  # the stomp leap
}
# HIS ATTACKS, in the F5 lab's order. Only the chain comes by itself; the rest are its parts, one at a
# time, for the lab: a motif once, a finale, a verb, the turn.
const SWINGS = preload("attacks/swings.gd")
const TURN = preload("attacks/turn.gd")
const ATTACKS = {
	"CHAIN": {"chain": true},
	"TOGETHER": {"motif": "together"},
	"SPLIT": {"motif": "split"},
	"JABS": {"motif": "pommel"},
	"HAMMER": {"finale": "HAMMER"},
	"STOMP": {"finale": "STOMP"},
	"BLADE": {"links": [[2, BLADE]]},
	"POMMEL": {"links": [[2, POMMEL]]},
	"TURN": {"turn": true},
}
const ANSWER_BEATS = 2  # his answer to a hit at his guard: its first strike lands this many beats on

# WHERE HE STANDS: slow and heavy. A player on each side: in the middle between them. Else by the
# nearer one: closer than CROWD_DISTANCE, he steps back to FIT_DISTANCE; out of his blade's reach, he
# walks up until they're REACH_MARGIN inside it. He walks at F2 "hitter_walk_speed", at ATTACK_PACE
# of it through his windups, and stands while a blade comes down and lies. He starts a chain only
# while someone is within ATTACK_RANGE (else he walks up first).
const CROWD_DISTANCE = 70.0  # touching is 55: his half-width and a player's
const FIT_DISTANCE = 100.0
const REACH_MARGIN = 40.0
const ATTACK_PACE = 0.5
const ATTACK_RANGE = 300.0
const WALL_ROOM = 90.0  # his flanks stay this far from the walls: room for someone behind him
const RECHECK = 0.2  # nobody near, or the sync mode's hold-off: he looks again this much later

# A STRIKE LANDING (land_blade(), land_jab(), crack_hits()):
const BLADE_KNOCKBACK = 300.0  # a blade strike, hit or blocked; a jab, hit
const BLOCKED_KNOCKBACK = 150.0  # a jab blocked
const HAMMER_KNOCKBACK = 1.5  # times that, the great hammer
const CRACK_KNOCKBACK = Vector2(160.0, -320.0)  # a crack: popped up, away from where it started

var finale_reason = ""  # why the last chain's finale was what it was (the log, the tests)
var _together_for = 0  # his chains in a row whose finale came in the together field
var _pommel_hitter = null  # who hit his pommel side last since he last turned (THE TURN)
var _provoked_by = null  # a hit at his guard in his breath: whom he answers
var _answering = null  # ...while his answer starts (answer_link())
var _held_off = 0.0  # the players' sync mode: how long he has held off his next chain
var _backing = false  # walking back from the nearer player (WHERE HE STANDS)...
var _closing = false  # ...or up to them


# His numbers on F2 (core/tuning.gd collects them): a page of his own, in his room.
static func tuning_entries() -> Array:
	return [
		{"page": "hitter", "title": "Heavy Hitter", "scenes": ["levels/heavy_hitter/"], "header": "TEMPO", "tab": "tempo"},
		{"key": "hitter_beat", "label": "a beat of his (s): his motifs' waits are 1-4 of them", "default": 0.4, "step": 0.01},
		{"key": "hitter_drop_time", "label": "a blade strike's drop: the cue to parry (s)", "default": 0.3, "step": 0.01},
		{"key": "hitter_jab_time", "label": "a pommel jab's thrust: its cue (s)", "default": 0.18, "step": 0.01},
		{"key": "hitter_recover_time", "label": "after a chain, recovering (s)", "default": 0.8, "step": 0.05},
		{"key": "hitter_walk_speed", "label": "walking (px/s)", "default": 60.0, "step": 5.0},
		{"header": "THE CHAINS", "column": 1},
		{"key": "hitter_reps_min", "label": "a chain repeats its motif at least (times; at random up to...)", "default": 1.0, "step": 1.0},
		{"key": "hitter_reps_max", "label": "...at most (times), then its finale", "default": 3.0, "step": 1.0},
		{"key": "hitter_together_stale", "label": "chains in a row in the together field: then the stomp leap", "default": 2.0, "step": 1.0},
		{"key": "hitter_breath_min", "label": "the breath after a chain, from (s)", "default": 2.5, "step": 0.1},
		{"key": "hitter_breath_max", "label": "...to (s)", "default": 3.5, "step": 0.1},
		{"header": "HIS POSTURE: HIS RAGE METER (THE RAGE: STEP 2)", "tab": "posture"},
		{"key": "hitter_posture_max", "label": "his posture (points)", "default": 200.0, "step": 10.0},
		{"key": "hitter_pommel_posture", "label": "his pommel side (hits there, jabs parried): times the posture", "default": 2.0, "step": 0.25},
		{"key": "hitter_break_stagger", "label": "broken: staggered (s; for now, in the rage's place: his sync stays)", "default": 3.0, "step": 0.1},
		{"header": "THE STAGGER AFTER A FINALE", "column": 1},
		{"key": "hitter_stagger_least", "label": "a finale parried together staggers him (s)", "default": 0.5, "step": 0.1},
		{"key": "hitter_stagger_per_parry", "label": "...and longer by this per blade parried in the chain (s)", "default": 0.2, "step": 0.05},
		{"header": "THE CRACK", "tab": "crack"},
		{"key": "hitter_crack_speed", "label": "it runs along the floor (px/s)", "default": 500.0, "step": 25.0},
		{"key": "hitter_crack_length", "label": "...this far each way (px)", "default": 520.0, "step": 20.0},
		{"key": "hitter_crack_share", "label": "it hits you: this share of his heavy hit's sync (0.33: a normal hit)", "default": 0.33, "step": 0.01},
		{"header": "THE STAND-IN (F1: bifrons_stand_in)", "tab": "stand-in"},
		{"key": "hitter_stand_in_parry", "label": "it parries his strikes this often", "default": 0.75, "step": 0.05},
		{"key": "hitter_stand_in_block", "label": "...only blocks them this often (the rest hit it)", "default": 0.15, "step": 0.05},
	]


func _ready():
	super()
	rules = SyncRules.new()
	rules.boss = self
	add_child(rules)
	GameManager.rules = rules
	# Testing alone: the stand-in (it does nothing while Moves "bifrons_stand_in" is off). As his
	# child it runs after him and before the players, who see its presses that same frame.
	var stand_in = HitterStandIn.new()
	stand_in.boss = self
	add_child(stand_in)


func _exit_tree():
	if rules != null and GameManager.rules == rules:
		GameManager.rules = null


func get_max_hp() -> float:
	return MAX_HP


func get_display_name() -> String:
	return "HEAVY HITTER"


# One attack per entry of ATTACKS.
func get_attack_pool() -> Array:
	var pool = []
	for attack_name in ATTACKS:
		var entry = ATTACKS[attack_name]
		if entry.get("turn", false):
			pool.append(TURN.new(attack_name))
			continue
		var links = entry.get("links", [])
		if entry.has("motif"):
			links = MOTIFS[entry.motif]
		elif entry.has("finale"):
			links = FINALES[entry.finale]
		pool.append(SWINGS.new(attack_name, links, entry.get("chain", false), entry.has("finale")))
	return pool


# Only the chain comes by itself (the rest: the F5 lab's).
func get_attack_weights() -> Dictionary:
	return {"CHAIN": 1.0}


func get_repeatable_attacks() -> Array:
	return ["CHAIN"]


# THE BREATH, after his recovery: he turns, if he will (THE TURN), and doesn't attack for a while.
func get_idle_pause() -> float:
	_face_the_players()
	var breath = randf_range(Tuning.value("hitter_breath_min"), Tuning.value("hitter_breath_max"))
	return breath * (Tuning.value("sync_mode_tempo") if in_sync_mode() else 1.0)


# The players keep their eyes on him (see _face() in player_body.gd): they go over and under him.
func holds_facing() -> bool:
	return hp > 0.0


# None of his attacks homes on one player, so a player he pushes may always shove the partner along
# (see _keep_out_of_boss() in player_body.gd).
func is_attacking(_player) -> bool:
	return false


func _physics_process(delta):
	# Nobody near: no chain (he walks up to them instead), but the one the dev tools ask for.
	if state == State.IDLE and timer <= delta and dev_next == "" \
			and not get_players().any(func(p): return distance_to(p) <= ATTACK_RANGE):
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
	if state == State.IDLE and is_instance_valid(_provoked_by) and not dev_hold:
		_answer()


# --- Sync as life (core/sync_rules.gd) ---

func max_posture() -> float:
	return Tuning.value("hitter_posture_max")


# Posture is his rage meter (the rage: step 2). Broken, for now: staggered long, and his sync stays.
func on_posture_broken() -> bool:
	stagger_now(Tuning.value("hitter_break_stagger"))
	return false


# The players' sync mode (core/sync_rules.gd): slower, the together motif only.
func in_sync_mode() -> bool:
	return rules != null and rules.sync_mode


# The two bound in it (core/sync_bond.gd).
func is_bound() -> bool:
	return rules != null and rules.bond != null and rules.bond.bound


# One beat of his in seconds just now (F2 "hitter_beat"): his tempo; slower in the players' sync mode.
func beat() -> float:
	return Tuning.value("hitter_beat") * (Tuning.value("sync_mode_tempo") if in_sync_mode() else 1.0)


# source: the player whose sword hit landed. His guard (in his breath) parries it by chance, else
# blocks it; otherwise it lands: in a window their partner's parry opened, a sync hit. On his pommel
# side (in their layer) it costs him more posture, and angers that head. What each costs is the sync
# rules'.
func take_damage(amount: float, source = null):
	if rules != null and source != null and hp > 0.0:
		_struck_by_rules(source)
		return
	super(amount, source)


func _struck_by_rules(source):
	var side = side_of(source)
	var times = 1.0
	if not at_blade(source):
		times = Tuning.value("hitter_pommel_posture")
		_pommel_hitter = source
		anger_head(side)
	var window = open_window_of(source)
	if window != null:
		window.used = true  # tried: whatever comes of it, it wasn't left unused
	var at = flank(side, source.global_position.y)
	if is_guarding():
		if randf() < Tuning.value("boss_parry_chance"):
			guard_parry(source)
			rules.boss_parried(source, false, times)
		else:
			guard_block(source)
			rules.boss_blocked(false, times)
		_provoke(source)
		return
	if window != null:
		var on_beat = anim_time - window.from <= Tuning.value("sync_beat_time")
		rules.sync_hit(on_beat)
		Dev.sync_hit(source, anim_time - window.from, on_beat)
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
	var lethal = rules.boss_struck(false, times)
	super.take_damage(hp if lethal else 0.0, source)


# Sync mode: the bound pair's strike, let go together on the big cue (core/sync_bond.gd). His guard
# can't stop it: met by it, it still costs him a normal hit's sync and he reels ("sync_strike_reel");
# else it lands heavy. Either way a big blow.
func take_pair_strike(source):
	if rules == null or hp <= 0.0:
		return
	var at = flank(side_of(source), source.global_position.y)
	shake(14.0)
	spawn_sparks(at, 28, SyncWave.COLOR)
	spawn_sparks(at, 18, SyncWave.CORE)
	Sfx.play("grand_impact", -2.0)
	var lethal = false
	if is_guarding():
		_flick_until = anim_time + PARRY_FLICK_TIME
		Sfx.play("parry_strong", -2.0)
		lethal = rules.pair_strike_parried()
		if not lethal and state != State.STAGGER:
			stagger_now(Tuning.value("sync_strike_reel"))
	else:
		lethal = rules.boss_struck(true)
	super.take_damage(hp if lethal else 0.0, source)


# --- His strikes landing (used by attacks/swings.gd) ---

# A blade strike comes down, in both layers at once (THE RULES, 1 and 2): in each layer the player in
# front of the blade, in its reach, meets it. Both parry: a co-op parry, and each opens the other's
# window. Only one: their parry has a block's effect. Where nobody of a layer is in front of it: a
# crack. `hammer`: the great hammer, which throws harder. Returns the players whose parries counted
# (both, or nobody).
func land_blade(hammer = false) -> Array:
	var players = get_players()
	var under = players.filter(func(p): return in_front_of_blade(p))
	var parriers = under.filter(func(p): return p.is_perfect_parry())
	var together = parriers.size() >= 2
	var knock = BLADE_KNOCKBACK * (HAMMER_KNOCKBACK if hammer else 1.0)
	rules.landing_heavy = true  # the players' hooks lead to the rules while it lands
	for p in under:
		if together:
			p.on_perfect_parry(true)
			spawn_sparks(p.global_position + Vector2(0.0, -24.0), 12, COLOR_PLAYER_PARRY)
		elif p.is_blocking() or p in parriers:  # (a lone parry: a block's effect)
			p.take_damage(knockback_for(p, knock), true)
		else:
			p.take_damage(knockback_for(p, knock))
	rules.landing_heavy = false
	var cracked = false
	for layer in LAYERS:
		var p = player_of(layer)
		if p != null and not p in under:
			_crack(layer)
			cracked = true
	if cracked:
		Sfx.play("glass_crack", -2.0)
	if together:
		for p in parriers:
			open_window(p.partner(), p)
		Sfx.play("counter_hit", -4.0)
	shake(12.0 if hammer else 8.0)
	Sfx.play("thunk", -2.0 if hammer else -5.0)
	return parriers if together else []


# A pommel jab lands (THE RULES, 3), in each layer at the player in front of the pommel, in its
# reach: a normal strike, so a lone parry is a parry and opens the partner's window. Parried, it
# costs him more posture. Returns the players who parried it.
func land_jab() -> Array:
	var parriers = []
	rules.landing_heavy = false
	rules.landing_posture = Tuning.value("hitter_pommel_posture")
	for p in get_players().filter(func(q): return in_front_of_pommel(q)):
		if p.is_perfect_parry():
			p.on_perfect_parry(false)
			spawn_sparks(p.global_position + Vector2(0.0, -24.0), 8, COLOR_PLAYER_PARRY)
			parriers.append(p)
		elif p.is_blocking():
			p.take_damage(knockback_for(p, BLOCKED_KNOCKBACK), true)
		else:
			p.take_damage(knockback_for(p, BLADE_KNOCKBACK))
	rules.landing_posture = 1.0
	for p in parriers:
		open_window(p.partner(), p)
	return parriers


# A crack's front catches its player on the floor: a hit, whatever they hold. It costs
# "hitter_crack_share" of his heavy hit's sync.
func crack_hits(p, from_x: float):
	if rules == null or hp <= 0.0:
		return
	rules.landing_heavy = false
	rules.landing_share = Tuning.value("hitter_crack_share")
	var away = 1.0 if p.global_position.x >= from_x else -1.0
	p.take_damage(Vector2(away * CRACK_KNOCKBACK.x, CRACK_KNOCKBACK.y))
	rules.landing_share = -1.0
	shake(4.0)


# A blade into the mirror, in that layer: a crack runs from where it came down.
func _crack(layer: int):
	var crack = HitterCrack.new()
	crack.boss = self
	crack.layer = layer
	crack.origin = clampf(impact_x(layer), ARENA_LEFT, ARENA_RIGHT)
	crack.floor_y = ARENA_FLOOR_Y
	get_parent().add_child(crack)


# Seconds until his next strike lands on that player; INF if none is coming at them.
func time_to_strike(player) -> float:
	if current_attack == null or not state in [State.TELEGRAPH, State.ATTACKING]:
		return INF
	return current_attack.time_to_strike(player)


# --- The fields and the chains (THE FIELDS, THE CHAINS) ---

func field() -> String:
	var players = get_players()
	var at = players.filter(func(p): return at_blade(p)).size()
	if at == players.size():
		return "together"
	return "pommel" if at == 0 else "split"


# The motif a chain lays out next: the field's (the together one, in the players' sync mode).
func chain_motif() -> String:
	return "together" if in_sync_mode() else field()


# Which finale a chain ends with (THE CHAINS), by the field as its last repetition ends. Why is left
# in finale_reason.
func chain_finale() -> String:
	if in_sync_mode():
		finale_reason = "sync mode"
		return "HAMMER"
	var now = field()
	if now != "together":
		_together_for = 0
		finale_reason = now
		return "STOMP"
	_together_for += 1
	if _together_for >= int(Tuning.value("hitter_together_stale")):
		_together_for = 0
		finale_reason = "together too long"
		return "STOMP"
	finale_reason = "together"
	return "HAMMER"


# How long a finale parried together staggers him: longer the more blades of the chain were parried.
func chain_stagger(blades: int) -> float:
	return Tuning.value("hitter_stagger_least") + Tuning.value("hitter_stagger_per_parry") * blades


# His answer's first strike, if it isn't the motif's own (THE BREATH): a jab at an attacker at his
# pommel. [] for none.
func answer_link() -> Array:
	if is_instance_valid(_answering) and not at_blade(_answering):
		return [ANSWER_BEATS, POMMEL]
	return []


# THE BREATH: a hit at his guard calls up the next chain.
func _provoke(player):
	if state in [State.IDLE, State.RECOVER] and not dev_hold:
		_provoked_by = player


# ...at once, its first strike at the attacker.
func _answer():
	_answering = _provoked_by
	_provoked_by = null
	_choose_target()
	_begin_telegraph(find_attack("CHAIN"))
	_answering = null


# THE TURN, as his breath begins: round, if that puts more of them in front of the blade; with as
# many either way, to whoever hit his pommel side last since he last turned, else round anyway.
func _face_the_players():
	var players = get_players()
	var at = players.filter(func(p): return at_blade(p)).size()
	var turn = players.size() - at > at
	if players.size() - at == at:
		turn = not at_blade(_pommel_hitter) if is_instance_valid(_pommel_hitter) else true
	_pommel_hitter = null
	if turn and not players.is_empty():
		turn_round()


# --- Where he stands (WHERE HE STANDS) ---

func _idle_motion(delta: float):
	_settle(delta)
	walk(delta)


func _recover_motion(delta: float):
	_settle(delta)
	walk(delta)


# Back down on the floor (a stomp leap cut short).
func _settle(delta: float):
	global_position.y = move_toward(global_position.y, home_position.y, STAGGER_SINK_SPEED * delta)


# As far left and right as he goes.
func clamp_x(x: float) -> float:
	var edge = WALL_ROOM + body.size.x / 2.0
	return clampf(x, ARENA_LEFT + edge, ARENA_RIGHT - edge)


# One frame of walking to his place, at `pace` times his speed.
func walk(delta: float, pace = 1.0):
	var goal = clamp_x(_place())
	global_position.x = move_toward(global_position.x, goal, Tuning.value("hitter_walk_speed") * pace * delta)


# Where he's headed, walls aside; where he is, if he's fine there.
func _place() -> float:
	var x = global_position.x
	var players = get_players().filter(func(p): return not p.is_dead())
	if players.is_empty():
		return x
	players.sort_custom(func(a, b): return distance_to(a) < distance_to(b))
	var near = players[0]
	var side = side_of(near)
	if players.size() > 1 and side_of(players[1]) != side:
		_backing = false
		_closing = false
		return (near.global_position.x + players[1].global_position.x) / 2.0
	var gap = distance_to(near)
	if gap < CROWD_DISTANCE:
		_backing = true
	elif gap >= FIT_DISTANCE:
		_backing = false
	if gap > BLADE_REACH:
		_closing = true
	elif gap <= BLADE_REACH - REACH_MARGIN:
		_closing = false
	if _backing:
		return near.global_position.x - side * FIT_DISTANCE
	if _closing:
		return near.global_position.x - side * (BLADE_REACH - REACH_MARGIN)
	return x


# --- Testing alone ---

# The player Moves "bifrons_stand_in" has the stand-in play ("left": P1, "right": P2), or null.
func stand_in_player():
	var id = {"left": 1, "right": 2}.get(Moves.value("bifrons_stand_in"), 0)
	return player_of(id) if id != 0 else null
