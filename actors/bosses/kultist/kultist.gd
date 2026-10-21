class_name Kultist
extends KultistBody
## The Kultist (a working name): a cultist of fire, lightning and demonic magic, fought in
## Bifrons's room on the mirrored screen, one player in each half. Part 2 of 2, the boss himself:
## his attacks and their order, where he stands between them, and the sync rules' hooks (his blows
## landing on the players, theirs on him). Part 1, his look, his staff, his guard and his flight:
## kultist_body.gd. The design and what's open: docs/boss_kultist.md.
##
## HIS ATTACKS (attacks/), each blow answered as its element says (kultist_element.gd):
## - STAFF: his staff in melee, strike after strike, each at the player of the half it's in.
## - FIRE_AND_LIGHTNING: he flies up over the middle of the room, fire runs in from the walls
##   (into the middle with you), and lightning strikes down between his two images through the
##   axis: parried by both, it goes back into him.
## - STAFF_AND_SPELLS: in one half his staff fights player A, in the other he casts lightning at
##   player B; what B doesn't stop runs through the axis and strikes A from below.
## - FLIGHT: the flight alone, for the lab (F5).
## They come in a set order (attack_order), round and round: a placeholder. A boss's attacks are
## to come in chains, with a finale and a breath (docs/concept.md, "Boss design principles").
##
## His numbers (times, distances, how hard a blow is) are exports, set in the inspector of
## kultist.tscn. TODO(design): not on F2, as every other fight's are (core/tuning.gd): F2 changes
## them while playing; an export is shared through git but needs the editor.

enum Victim { RANDOM, P1, P2 }

const RANGE_RECHECK = 0.2  # an attack that needs someone in reach, and nobody is: he looks again this much later

@export_group("Order")
## His attacks, in turn, round and round: STAFF, FIRE_AND_LIGHTNING, STAFF_AND_SPELLS, FLIGHT.
## One that can't come just now (STAFF_AND_SPELLS without two players) is passed over.
@export var attack_order: PackedStringArray = ["STAFF", "FIRE_AND_LIGHTNING", "STAFF", "STAFF_AND_SPELLS"]
## After an attack, once recovered, he waits from (s)...
@export var pause_min = 0.4
## ...to (s) before the next.
@export var pause_max = 0.8

@export_group("Moving")
## Walking between his attacks (px/s).
@export var walk_speed = 110.0
## He keeps the nearer player at least this far (px, center to center)...
@export var stand_near = 100.0
## ...and walks up to them when they're further than this. Between two players on either side of
## him he takes the middle, if that's no further from either.
@export var stand_far = 150.0
## His flanks stay this far from the walls (px).
@export var wall_room = 60.0

@export_group("Blows")
## A blow of his that lands throws its player back this hard (px/s; and 0.6 of that up)...
@export var hit_knockback = 300.0
## ...a blocked one, this hard.
@export var block_knockback = 150.0

@export_group("Staff strikes")
## A player this close as a strike lands is struck (px, center to center).
@export var staff_reach = 190.0
## As the staff drops he lunges at its player, by up to this much (px)...
@export var staff_lunge = 90.0
## ...to stand this far from them as it lands (px).
@export var strike_distance = 120.0
## Strikes in a row.
@export var staff_strikes = 3
## The first one: from the attack's start until it lands (s).
@export var staff_windup = 1.0
## Each one after it lands this long after the one before (s).
@export var staff_gap = 0.75
## The drop, from drawn back to landing: the cue to parry (s).
@export var staff_fall_time = 0.28
## A landed staff lies where it fell this long (s)...
@export var staff_rest_time = 0.15
## ...a parried one is thrown back this long (s).
@export var staff_recoil_time = 0.35
## A staff strike is a heavy attack for the sync rules.
@export var staff_heavy = false
## After the last strike he recovers this long (s).
@export var staff_recover = 0.6

@export_group("Fire and lightning")
## He flies to the middle of the room and up (flight_height) in this long: the telegraph (s).
@export var channel_rise_time = 1.0
## Then embers glow where the fire will burn, this long (s): get to the middle.
@export var fire_tell_time = 1.4
## The fire erupts at the walls and runs inward at this speed (px/s)...
@export var fire_speed = 700.0
## ...and each place it reaches burns this long (s).
@export var fire_burn_time = 2.2
## The safe place in the middle of the room, where nothing burns (px wide).
@export var safe_width = 180.0
## Caught in the fire (it can't be parried or blocked): a heavy attack for the sync rules?
@export var fire_heavy = false
## The fire throws its player toward the middle this hard (px/s; and 0.6 of that up).
@export var fire_knockback = 260.0
## Once the fire has reached the safe place, lightning crackles between his images this long (s)...
@export var bolt_tell_time = 0.9
## ...then flashes red, the cue, and strikes as that ends (s). Lightning is fast.
@export var bolt_cue_time = 0.18
## The bolt is this wide, round his middle (px): whoever stands in it has to parry it.
@export var bolt_width = 120.0
## The bolt is a heavy attack for the sync rules, on whoever doesn't parry it.
@export var bolt_heavy = false
## A parry of the bolt: the player's blade holds its energy this long (s).
@export var absorb_time = 0.6
## Both parried, it goes back into him: a heavy hit (else a normal one).
@export var reflect_heavy = true
## After the bolt he stays up this long before coming down (descend_time) (s).
@export var bolt_after_time = 0.4
## Back on the floor he recovers this long (s).
@export var fire_recover = 0.8

@export_group("Staff and spells")
## A, whom his staff fights while he casts at the other (B).
@export var spells_victim: Victim = Victim.RANDOM
## Turning on them, the telegraph (s).
@export var spells_turn_time = 0.8
## Staff strikes at A...
@export var spells_strikes = 4
## ...one landing every this long (s), the first as the telegraph ends.
@export var spells_strike_gap = 0.9
## Spells at B...
@export var spells_count = 3
## ...one cast every this long (s)...
@export var spells_gap = 1.1
## ...the first this long after the telegraph (s).
@export var spells_first = 0.2
## A spell: conjured at his staff, flying at B this long, the tell (s)...
@export var spell_tell_time = 0.6
## ...then a red flash, the cue: it strikes B as that ends (s).
@export var spell_cue_time = 0.16
## Not parried or blocked by B, it dives into the axis and runs along it to A in this long (s)...
@export var spell_cross_time = 0.45
## ...and rises under A, flashing red as it comes: it strikes A as that ends (s).
@export var spell_rise_time = 0.22
## A spell that reaches A can be parried or blocked by A too, as any lightning.
## TODO(design): or should only B be able to stop it?
@export var spell_victim_defends = true
## A spell is a heavy attack for the sync rules.
@export var spell_heavy = false
## After the last strike and spell he recovers this long (s).
@export var spells_recover = 0.8

@export_group("Flight (lab)")
## FLIGHT, the lab's: he hovers this long before coming down (s).
@export var flight_hover_time = 1.5

var _order_at = 0  # the next attack in attack_order


func _ready():
	super()
	rules = SyncRules.new()
	rules.boss = self
	add_child(rules)
	GameManager.rules = rules


func _exit_tree():
	if rules != null and GameManager.rules == rules:
		GameManager.rules = null


func get_display_name() -> String:
	return "KULTIST"


func get_attack_pool() -> Array:
	return [KultistStaffStrikes.new(), KultistFlight.new()]


# The next attack in attack_order that can come just now; the lab's pick (dev_next) first.
func pick_attack() -> Attack:
	if dev_next != "":
		return super()
	var attack = _next_in_order(true)
	return attack if attack != null else find_attack("STAFF")


# The next attack in attack_order that can come just now (its fits()), or null; `take`: and the
# order moves on past it.
func _next_in_order(take: bool) -> Attack:
	var at = _order_at
	for i in attack_order.size():
		var attack = find_attack(attack_order[at % attack_order.size()])
		at += 1
		if attack != null and attack.fits(self):
			if take:
				_order_at = at % attack_order.size()
			return attack
	return null


func get_idle_pause() -> float:
	return randf_range(pause_min, maxf(pause_max, pause_min))


# Players keep their eyes on him (see _face() in player_body.gd): each half's staff faces its
# player wherever they are, and they'd turn their backs on it otherwise.
func holds_facing() -> bool:
	return hp > 0.0


# His whole body blocks, as Bifrons's does (Moves "boss_body"), up in the air too.
func body_block() -> Rect2:
	if not Moves.on("boss_body") or hp <= 0.0:
		return Rect2()
	return Rect2(global_position - body.size / 2.0, body.size)


func _physics_process(delta):
	# An attack that wants someone in his staff's reach waits until they are; meanwhile he walks up
	# to them. The lab's comes at once.
	if state == State.IDLE and timer <= delta and dev_next == "" and hp > 0.0:
		var next = _next_in_order(false)
		if next != null and next.needs_reach() and not get_players().any(in_reach):
			timer = RANGE_RECHECK
	super(delta)


func _die():
	_flight = null
	_aloft = false
	global_position.y = home_position.y  # not left hanging in the air
	super()


# --- Where he stands ---

# Close enough for a staff strike, with its lunge.
func in_reach(player) -> bool:
	return distance_to(player) <= staff_reach + staff_lunge


func nearest_player():
	var nearest = null
	for p in get_players():
		if nearest == null or distance_to(p) < distance_to(nearest):
			nearest = p
	return nearest


# Between his attacks he walks to his place.
func _idle_motion(delta: float):
	walk_toward(_place(), walk_speed, delta)


# Recovering he stands.
func _recover_motion(_delta: float):
	pass


# He walks toward `x` at `speed`, inside the room; not while he's up in the air.
func walk_toward(x: float, speed: float, delta: float):
	if _aloft:
		return
	global_position.x = move_toward(global_position.x, clamp_x(x), speed * delta)


# `x` kept inside the room: his flanks wall_room from the walls.
func clamp_x(x: float) -> float:
	var room = body.size.x / 2.0 + wall_room
	return clampf(x, ARENA_LEFT + room, ARENA_RIGHT - room)


# Where he wants to stand: between two players on either side of him, the middle, if that's no
# further than stand_far from either; else by the nearer one, up to stand_far from them, back to
# stand_near if they come closer, and staying on his side of them.
# TODO(design): placeholder moving, no drift and no making room as Bifrons has.
func _place() -> float:
	var players = get_players()
	if players.is_empty():
		return global_position.x
	var x = global_position.x
	var left = players.filter(func(p): return p.global_position.x < x).map(func(p): return p.global_position.x)
	var right = players.filter(func(p): return p.global_position.x >= x).map(func(p): return p.global_position.x)
	if not left.is_empty() and not right.is_empty() and (right.min() - left.max()) / 2.0 <= stand_far:
		return (left.max() + right.min()) / 2.0
	var nearest = nearest_player()
	var away = -side_of(nearest)  # his side of them
	var distance = distance_to(nearest)
	if distance > stand_far:
		return nearest.global_position.x + away * stand_far
	if distance < stand_near:
		return nearest.global_position.x + away * stand_near
	return x


# A point on that side's flank, at height y (world coordinates).
func _flank(side: int, y: float) -> Vector2:
	return Vector2(global_position.x + side * body.size.x / 2.0, y)


# --- His blows landing on the players (his attacks call this) ---

# A blow of `element` (KultistElement) reaches player `p` and comes to what that element's rule
# says: parried, blocked or hit. `heavy`: a heavy attack for the sync rules. `knockback`: how a hit
# throws them (null: away from him, hit_knockback; a block, block_knockback). `strong`: the
# heavier kind of parry, as a blow that wants both players' parries. Returns what came of it
# (KultistElement.PARRIED, BLOCKED or HIT).
func land_on(p, element: int, heavy = false, knockback = null, strong = false) -> String:
	if rules != null:
		rules.landing_heavy = heavy  # the players' hooks lead to the rules while it lands
	var outcome = KultistElement.judge(element, p)
	match outcome:
		KultistElement.PARRIED:
			p.on_perfect_parry(strong)
			spawn_sparks(p.blade_point(0.8), 10, COLOR_PLAYER_PARRY)
		KultistElement.BLOCKED:
			var blocked = knockback * block_knockback / maxf(hit_knockback, 1.0) if knockback != null \
				else knockback_for(p, block_knockback)
			p.take_damage(blocked, true)
		_:
			p.take_damage(knockback if knockback != null else knockback_for(p, hit_knockback))
			shake(5.0)
	if rules != null:
		rules.landing_heavy = false
	return outcome


# --- The players' hits landing on him ---

# source: the player whose sword hit landed. His staff in their half parries it if it's guarding
# (or blocks it, see staff_parry_chance); anything else lands. What each costs is the sync rules'.
func take_damage(amount: float, source = null):
	if rules != null and source != null and hp > 0.0:
		_struck_by_rules(source)
		return
	super(amount, source)


func _struck_by_rules(source):
	var at = _flank(side_of(source), source.global_position.y)
	if is_guarding(source):
		if randf() < staff_parry_chance:
			source.on_swing_parried()
			flick_staff(layer_of(source))
			Sfx.play("parry", -4.0)
			shake(3.0)
			spawn_sparks(at, 10, COLOR_PARRY)
			rules.boss_parried(source)
		else:
			Sfx.play("chip", -4.0)
			shake(2.0)
			spawn_sparks(at, 6, COLOR_BLOCK)
			rules.boss_blocked()
		return
	Sfx.play("sync_hit", -6.0)
	shake(3.0)
	spawn_sparks(at, 8, COLOR_EXECUTE)
	var lethal = rules.boss_struck()
	super.take_damage(hp if lethal else 0.0, source)


# A blow of his own sent back into him (the bolt both players parried): it lands whatever he's
# doing. Returns true if it killed him (in chaos).
func take_reflection(heavy: bool) -> bool:
	if rules == null or hp <= 0.0:
		return false
	shake(10.0)
	Sfx.play("counter_hit", -2.0)
	var lethal = rules.boss_struck(heavy)
	super.take_damage(hp if lethal else 0.0)
	return lethal


# Sync mode: the bound pair's strike, let go together on the big cue (core/sync_bond.gd). As
# Bifrons's, his guard can't stop it: met by a guarding staff it still costs him a normal hit's
# sync and he reels ("sync_strike_reel"); else it lands heavy.
func take_pair_strike(source):
	if rules == null or hp <= 0.0:
		return
	var at = _flank(side_of(source), source.global_position.y)
	var guards = get_players().filter(is_guarding)
	shake(14.0)
	spawn_sparks(at, 28, SyncWave.COLOR)
	spawn_sparks(at, 18, SyncWave.CORE)
	Sfx.play("grand_impact", -2.0)
	var lethal = false
	if not guards.is_empty():
		flick_staff(layer_of(guards[0]))
		Sfx.play("parry_strong", -2.0)
		lethal = rules.pair_strike_parried()
		if not lethal and state != State.STAGGER:
			stagger_now(Tuning.value("sync_strike_reel"))
	else:
		lethal = rules.boss_struck(true)
	super.take_damage(hp if lethal else 0.0, source)
