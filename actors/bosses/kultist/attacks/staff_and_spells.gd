class_name KultistStaffAndSpells
extends KultistStaffStrikes
## Staff at A, spells at B. STAFF_AND_SPELLS, the Kultist's second great attack (kultist.gd, "Staff
## and spells"). One player is A (spells_victim: at random, by default), the other B.
## - In A's half his staff fights A: spells_strikes strikes, one every spells_strike_gap, struck as
##   STAFF's are (staff_strikes.gd: yellow, red, parry), and between them he walks after A.
## - In B's half he holds his staff up at B and casts: a spell every spells_gap (magic/spell.gd), a
##   short tell of lightning that B can parry or block. Its core has A's color: it's for A.
## - What B doesn't stop dives into the axis, runs along it to A and strikes A from below, between
##   A's own strikes.
## His turning on them (spells_turn_time) is the telegraph: A's staff rising, B's held up.
## TODO(design): it comes in its turn whenever both players are there (a placeholder for what sets
## it off). A's parries count as any (TODO(design): should they do more here?).

const CHARGE_TIME = 0.35  # s: his staff's head glows up this long before each spell

var victim = null  # A, whom his staff fights
var caster_target = null  # B, whom his spells fly at
var stopped = 0  # this run's spells B stopped...
var through = 0  # ...and those that got past B to A
var _casts = []  # when each spell is cast (s from the attack's start)
var _cast_next = 0
var _spells = []  # this run's spells
var _cut_short = false


func get_attack_name() -> String:
	return "STAFF_AND_SPELLS"


# It wants both players: one for his staff, one for his spells.
func fits(boss_node) -> bool:
	return boss_node.get_players().size() >= 2


# He walks after A himself.
func needs_reach() -> bool:
	return false


func start(boss_node, player_nodes: Array):
	_choose(boss_node)
	super(boss_node, player_nodes)
	stopped = 0
	through = 0
	_cast_next = 0
	_spells = []
	_cut_short = false
	_casts = []
	for i in maxi(boss.spells_count, 0):
		_casts.append(boss.spells_turn_time + boss.spells_first + i * boss.spells_gap)


# A and B: A as spells_victim says (at random, or P1, or P2), B the other.
func _choose(boss_node):
	var players = boss_node.get_players()
	var wanted = boss_node.spells_victim
	victim = null
	if wanted == boss_node.Victim.P1:
		victim = boss_node.player_of(1)
	elif wanted == boss_node.Victim.P2:
		victim = boss_node.player_of(2)
	if victim == null and not players.is_empty():
		victim = players.pick_random()
	caster_target = null
	for p in players:
		if p != victim:
			caster_target = p
			break


# --- His staff at A (the strikes are STAFF's) ---

func _schedule() -> Array:
	var contacts = []
	for i in maxi(boss.spells_strikes, 1):
		contacts.append(boss.spells_turn_time + i * boss.spells_strike_gap)
	return contacts


func _first_target():
	return victim


func _pick_next():
	return victim if is_instance_valid(victim) else boss.nearest_player()


# Before each drop he walks after A, up to strike_distance from them.
func _approach(player, delta: float):
	boss.walk_toward(player.global_position.x - boss.side_of(player) * boss.strike_distance, boss.walk_speed, delta)


func _recover_time() -> float:
	return boss.spells_recover


# --- His spells at B ---

func update(delta: float):
	while _cast_next < _casts.size() and _time + delta >= _casts[_cast_next]:
		_cast()
		_cast_next += 1
	super(delta)


# Seconds until a blow of his meets that player: his staff (A), or a spell (B as it reaches them,
# A as it rises under them); INF if none is coming at them.
func time_to_strike(player) -> float:
	var soonest = super(player)
	for spell in _spells:
		if is_instance_valid(spell):
			soonest = minf(soonest, spell.time_to_strike(player))
	return soonest


# Over once the strikes are, and every spell has come to something.
func _done() -> bool:
	return super() and _cast_next >= _casts.size() \
		and _spells.all(func(spell): return not is_instance_valid(spell) or spell.outcome != "")


func _cast():
	if not is_instance_valid(caster_target) or not is_instance_valid(victim):
		return
	var spell = KultistSpell.cast(boss, caster_target, victim, boss.staff_head(boss.layer_of(caster_target)), boss.get_parent())
	spell.resolved.connect(_on_resolved)
	_spells.append(spell)
	Sfx.play("call_tick", -4.0)


func _on_resolved(what: String):
	if what == KultistSpell.STOPPED:
		stopped += 1
	elif what in [KultistElement.PARRIED, KultistElement.BLOCKED, KultistElement.HIT]:
		through += 1


# In B's half his staff is held up at B, casting, its head glowing up before each spell; in A's,
# it strikes (STAFF's poses).
func _pose(layer: int):
	if is_instance_valid(caster_target) and layer == boss.layer_of(caster_target):
		boss.pose_staff(layer, boss.POSE_CAST)
		boss.tint_staff(layer, null)
		var charge = 0.0
		if _cast_next < _casts.size():
			charge = clampf(1.0 - (_casts[_cast_next] - _time) / CHARGE_TIME, 0.0, 1.0)
		boss.light_head(layer, KultistElement.tell(KultistElement.LIGHTNING), 0.25 + 0.75 * charge)
		return
	super(layer)


func interrupt():
	_cut_short = true
	super()


# Cut short (staggered, dead), his spells under way are gone.
func cleanup():
	if _cut_short:
		for spell in _spells:
			if is_instance_valid(spell):
				spell.fizzle()
	_spells = []
	_cut_short = false
	super()
