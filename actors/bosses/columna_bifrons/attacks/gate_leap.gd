class_name GateLeap
extends Attack
## Yellow blade, raised and pointing forward -> red. The gate leap: the Warden's way from ppe back
## to pep (docs/boss_bifrons_warden.md, "Gate leap"), tried out on Columna Bifrons next to his
## leap. With the leap the players choose where they end up; here he sets it. A is the player in
## front of him (the nearer), B the one behind; A's sword (the one that fights A) is the one he
## rams into the floor, B's strikes B.
##   0. He crouches and raises A's sword, pointing it forward and down: he's about to ram it in.
##   1. He rams it into the floor between them: a thrust each of them near it parries for
##      themselves. It throws them a little apart, A back toward him, B away (a parry half as far:
##      A THROW BY OUTCOME in columna_bifrons.gd). There it stands, a wall, until he pulls it out
##      (A SWORD IN THE FLOOR in bifrons_swords.gd).
##   2. On it he vaults over A and comes down between the two, the sword upright at his flank. His
##      body is no obstacle meanwhile; whoever is under him as he lands is pushed out to their side.
##   3. As he lands, B's sword strikes B.
##   4. He rips A's sword out of the floor: an upward cut at A that throws A back.
##   5. Its swing carries on up into the windup of a heavy strike of both swords (F2
##      "bifrons_gate_lift": A's time to come back). Is A in his blades' reach as they start to
##      come down, one comes down on each (both parry: staggered); if not, both on B's side: two
##      blades on one place, and a lone parry there has only a block's effect (ONE PARRY PER BLADE).
## A parried strike at one of them (3, 4) breaks the other sword's guard, as any strike does: the
## partner's sync hit. Nothing in 1 to 4 changes what he does; only the finish goes by what came of
## it. Only in ppe: started anywhere else (F5), he does nothing.

signal both_parried

enum Phase { NONE, LEAPING }

const LEFT = StrikePattern.LEFT
const RIGHT = StrikePattern.RIGHT

# --- Tuning ---
const RAM_UNITS = 5  # boss.time_unit()s until the ram lands; its drop (StrikePattern.fall_time()) is the cue
const RAM_DISTANCE = 120.0  # he lunges in until the spot is this far from him (no closer to A than CLOSEST)...
const RAM_LUNGE = 160.0  # ...this far at most
const SPOT_PAST_A = 12.0  # the spot: halfway between the two, and at least this far past A
const RAM_REACH = 60.0  # a player this close to the spot is under the thrust
const RAM_KNOCKBACK = 1.0  # times a strike's knockback: a light throw, apart
const RAM_PARRIED_PUSH = 150.0  # with A THROW BY OUTCOME off, a parry still pushes apart this fast (px/s)
const HAND_OUT = 40.0  # his hand, ramming it in: this far out from his center
const PLANT_TIME = 0.15  # the sword in the floor, before he vaults
const VAULT_TIME = 0.45  # over A and down
const VAULT_HEIGHT = 100.0  # px up at the top: over A's head
const LAND_PAST = HAND_OUT  # he comes down this far past the sword: it stands upright at his flank
const RIP_UNITS = 3  # time units from his landing until the rip lands on A
const RIP_KNOCKBACK = 3.0  # times a strike's knockback: a hit or a block throws A out of his reach (~180 px), a parry not (~65)
const STAGGER_TIME = 2.2  # parried by both: the fallback (see ColumnaBifrons.coop_stagger())
const RECOVER_TIME = 0.6
const CROUCH = Vector2(1.1, 0.82)  # his body, loaded for the vault
const REAR = 10.0  # px he rears back by as he raises the sword
const TREMBLE = 0.05  # radians a drawn blade shakes by, just before it comes
const POSE_RAM_RAISED = Vector3(30.0, -70.0, 0.45)  # sword 1 raised at his shoulder, pointing forward and down
const POSE_RIPPED = Vector3(44.0, -36.0, -1.05)  # sword 1 ripped out: up and out

var _name: String
var _time = 0.0  # seconds into the attack
var _skip = false  # not in ppe: nothing to do
var _a = null  # the player in front...
var _b = null  # ...and the one behind
var _sword_a = LEFT  # their swords
var _sword_b = RIGHT
var _way = LEFT  # the side of him they're on as it starts: the way he leaps
var _from_x = 0.0  # where he stands as the ram's drop starts...
var _ram_x = 0.0  # ...where he rams it in from...
var _land_x = 0.0  # ...and where he comes down
var _spot = 0.0  # where the sword goes in (x): settled as its drop starts
var _rammed = Vector3.ZERO  # sword 1's pose as it goes in
var _lean_from = 0.0  # the planted sword's lean as it goes in (it's upright once he's over)
var _pulled = Vector3.ZERO  # sword 1's pose as he pulls it out
var _ram_at = 0.0  # when each part lands
var _vault_at = 0.0
var _land_at = 0.0
var _rip_at = 0.0
var _drop_at = 0.0
var _heavy_at = 0.0
var _landed = 0  # how many of its four landings (ram, strike at B, rip, heavy strike) are done
var _vaulting = false
var _sounded = {}  # what's made its sound
var _parried_b = false  # how B's strike went (the blade recoils)
var _decided = false  # the heavy strike's place is settled (as its drop starts)...
var _on_back = false  # ...both swords on B's side: A was out of his reach


func _init(attack_name: String):
	_name = attack_name


func get_attack_name() -> String:
	return _name


# Both players on one side of him, both in his range, and room for him to come down past the spot.
func fits(boss_node) -> bool:
	var roles = roles_of(boss_node)
	if roles.is_empty() or not boss_node.in_range(roles[0]) or not boss_node.in_range(roles[1]):
		return false
	var plan = plan_for(boss_node, roles[0], roles[1])
	return absf(boss_node.clamp_x(plan.land) - plan.land) <= 1.0


# [A, B, A's sword, B's sword]: the two on one side of him, the nearer first; [] if they aren't.
static func roles_of(boss_node) -> Array:
	var a = boss_node.ward_of(LEFT)
	var b = boss_node.ward_of(RIGHT)
	if a == null or b == null or a == b or boss_node.side_of(a) != boss_node.side_of(b):
		return []
	if boss_node.distance_to(b) < boss_node.distance_to(a):
		return [b, a, RIGHT, LEFT]
	return [a, b, LEFT, RIGHT]


# Where it goes, with A and B where they are now: {way, spot, ram (where he rams it in from), land
# (where he comes down)}. The spot is halfway between them, at least SPOT_PAST_A past A, and within
# the sword's reach from where he can lunge to.
static func plan_for(boss_node, a, b) -> Dictionary:
	var x = boss_node.global_position.x
	var way = boss_node.side_of(a)
	var spot = (a.global_position.x + b.global_position.x) / 2.0
	if (spot - a.global_position.x) * way < SPOT_PAST_A:
		spot = a.global_position.x + way * SPOT_PAST_A
	var ram = spot - way * RAM_DISTANCE
	if (a.global_position.x - ram) * way < boss_node.CLOSEST:
		ram = a.global_position.x - way * boss_node.CLOSEST
	ram = x + way * clampf((ram - x) * way, 0.0, RAM_LUNGE)  # only forward
	var most = HAND_OUT + 0.95 * boss_node.SWORD_LENGTH
	if (spot - ram) * way > most:
		spot = ram + way * most
	return {"way": way, "spot": spot, "ram": ram, "land": spot + way * LAND_PAST}


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	boss.orient([[RAM_UNITS, StrikePattern.BOTH]])
	_time = 0.0
	_landed = 0
	_vaulting = false
	_sounded = {}
	_parried_b = false
	_decided = false
	_on_back = false
	_from_x = boss.global_position.x
	_ram_x = _from_x
	var roles = roles_of(boss)
	_skip = roles.is_empty()
	if not _skip:
		_a = roles[0]
		_b = roles[1]
		_sword_a = roles[2]
		_sword_b = roles[3]
		_way = boss.side_of(_a)
	var unit = boss.time_unit()
	_ram_at = RAM_UNITS * unit
	_vault_at = _ram_at + PLANT_TIME
	_land_at = _vault_at + VAULT_TIME
	_rip_at = _land_at + RIP_UNITS * unit
	_drop_at = _rip_at + Tuning.value("bifrons_gate_lift")
	_heavy_at = _drop_at + StrikePattern.fall_time()


func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


# The telegraph is everything up to the ram's drop.
func get_telegraph_duration() -> float:
	return 0.01 if _skip else _ram_at - StrikePattern.fall_time()


func update_telegraph(progress: float):
	if _skip:
		return
	var duration = get_telegraph_duration()
	_time = minf(progress * duration, duration - 0.001)  # the drop is execute()'s: its spot isn't settled yet
	_animate()


func execute():
	phase = Phase.LEAPING
	boss.body.color = boss.COLOR_IDLE
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	if _skip:
		finish(0.1)
		return
	_time = get_telegraph_duration()
	# Where it goes is settled now, as the drop starts.
	var plan = plan_for(boss, _a, _b)
	_from_x = boss.global_position.x
	_ram_x = plan.ram
	_spot = plan.spot
	_land_x = boss.clamp_x(plan.land)
	_rammed = _rammed_pose(absf(_spot - _ram_x))
	_animate()


func update(delta: float):
	if _skip or completed:
		return
	_time += delta
	if _landed == 0 and _time >= _ram_at:
		_landed = 1
		_ram()
	if _landed == 1 and _time >= _land_at:
		_landed = 2
		_come_down()
	if _landed == 2 and _time >= _rip_at:
		_landed = 3
		_rip()
	if _landed == 3 and not _decided and _time >= _drop_at:
		_decide()
	if _landed == 3 and _time >= _heavy_at:
		_landed = 4
		_finish()
		return
	_animate()


# Seconds until a blade of his lands on that player; INF if none is coming at them.
func time_to_strike(player) -> float:
	if _skip or completed:
		return INF
	var heavy_on = [_b] if _decided and _on_back and not _a_with_b() else [_a, _b]
	var landings = [[_ram_at, [_a, _b]], [_land_at, [_b]], [_rip_at, [_a]], [_heavy_at, heavy_on]]
	for i in range(_landed, landings.size()):
		if player in landings[i][1]:
			return landings[i][0] - _time
	return INF


# The screen halves show sword 1 in both while it's raised at both players and going in (in the
# floor, it's there anyway: see bifrons_swords.gd), and both swords as they come down on B's side.
func shows_in_both(blade: int) -> bool:
	if _skip:
		return false
	if blade == _sword_a and _landed == 0:
		return true
	return _decided and _on_back and _landed == 3


func cleanup():
	if boss.is_planted(_sword_a):
		boss.pull_sword(_sword_a)
	boss.global_position.y = boss.home_position.y


# --- What lands ---

# 1. The ram: each player near the spot meets it; it throws them apart.
func _ram():
	boss.global_position.x = _ram_x
	var under = [_a, _b].filter(func(p): return absf(p.global_position.x - _spot) <= RAM_REACH)
	var judged = _judged(_sword_a, under)
	judged["away"] = {_a: -_way, _b: _way}  # A back toward him, B away: the sword between them
	boss.land(judged, false, RAM_KNOCKBACK, false, true)
	for p in judged.parriers:
		if not Moves.on("bifrons_throw_by_outcome"):
			p.apply_knockback(Vector2(judged.away[p] * RAM_PARRIED_PUSH, 0.0))
		parry_success.emit(p, "bifrons_gate_ram")
	var hand_x = _ram_x + _way * HAND_OUT
	_lean_from = asin(clampf((hand_x - _spot) / boss.SWORD_LENGTH, -1.0, 1.0))
	boss.plant_sword(_sword_a, Vector2(_spot, boss.ARENA_FLOOR_Y), _lean_from)
	boss.shake(7.0)
	Sfx.play("thunk", -2.0)


# 3. He's down, between them: B's sword strikes B.
func _come_down():
	boss.global_position = Vector2(_land_x, boss.home_position.y)
	boss.plant_sword(_sword_a, Vector2(_spot, boss.ARENA_FLOOR_Y), 0.0)
	boss.pop_body(Vector2(1.2, 0.85), 0.25)
	boss.ghost(0.0)  # he's there: whoever is under him is pushed out to their side
	boss.shake(6.0)
	var judged = _judged(_sword_b, [_b].filter(func(p): return boss.distance_to(p) <= boss.BLADE_REACH))
	boss.land(judged)
	_parried_b = judged.parried
	for p in judged.parriers:
		parry_success.emit(p, "bifrons_gate_strike")
	if judged.parried:
		boss.break_guard(_sword_a, StrikePattern.window_time(), StrikePattern.window_delay(), _b)


# 4. The rip: an upward cut at A that throws them back.
func _rip():
	var judged = _judged(_sword_a, [_a].filter(func(p): return boss.distance_to(p) <= boss.BLADE_REACH))
	boss.land(judged, false, RIP_KNOCKBACK, false, true)
	for p in judged.parriers:
		parry_success.emit(p, "bifrons_gate_rip")
	if judged.parried:
		boss.break_guard(_sword_b, StrikePattern.window_time(), StrikePattern.window_delay(), _a)


# 5, as the swords start down: one on each, or, with A out of his reach, both on B's side.
func _decide():
	_decided = true
	_on_back = boss.side_of(_a) == boss.side_of(_b) or boss.distance_to(_a) > boss.BLADE_REACH
	Sfx.play("swing", -3.0)


# 5. The heavy strike lands.
func _finish():
	var both = false
	if _on_back:
		# Two blades on one place: everyone on B's side within reach, and it takes both of them.
		var side = boss.side_of(_b)
		var under = [_a, _b].filter(func(p): return boss.side_of(p) == side and boss.distance_to(p) <= boss.BLADE_REACH)
		var judged = _judged(_sword_b, under)
		both = judged.parriers.size() >= 2
		if Moves.on("bifrons_blade_parries") and not both:
			judged["blocked"] = judged.parriers
			judged["parriers"] = []
			judged["parried"] = false
		boss.land(judged, both, StrikePattern.HEAVY_KNOCKBACK, true, true)
		for p in judged.parriers:
			parry_success.emit(p, "bifrons_gate_heavy")
	else:
		# One on each: two normal strikes at once (ONE PARRY PER BLADE; off: any strike of both is heavy).
		var heavy = not Moves.on("bifrons_blade_parries")
		var on_a = _judged(_sword_a, [_a].filter(func(p): return boss.distance_to(p) <= boss.BLADE_REACH))
		var on_b = _judged(_sword_b, [_b].filter(func(p): return boss.distance_to(p) <= boss.BLADE_REACH))
		both = on_a.parried and on_b.parried
		for judged in [on_a, on_b]:
			boss.land(judged, both, 1.0, heavy)
			for p in judged.parriers:
				parry_success.emit(p, "bifrons_gate_heavy")
	boss.shake(12.0 if both else 9.0)
	if both:
		both_parried.emit()
		Sfx.play("counter_hit", -2.0)
		finish_with_stagger(boss.coop_stagger(STAGGER_TIME))
	else:
		finish(RECOVER_TIME)


func _judged(blade: int, under: Array) -> Dictionary:
	var parriers = under.filter(func(p): return p.is_perfect_parry())
	return {"blade": blade, "under": under, "parriers": parriers, "parried": not parriers.is_empty()}


# A has come over to B's side, in reach: the heavy strike on B's side is on them both.
func _a_with_b() -> bool:
	return boss.side_of(_a) == boss.side_of(_b) and boss.distance_to(_a) <= boss.BLADE_REACH


# Sword 1 going in at `distance` from his center: the hand HAND_OUT out, the blade reaching just
# to the floor there (a pose, as the POSE_s are, for a sword on the side it points to).
func _rammed_pose(distance: float) -> Vector3:
	var floor_y = boss.ARENA_FLOOR_Y - boss.home_position.y
	var out = distance - HAND_OUT
	var down = sqrt(maxf(boss.SWORD_LENGTH * boss.SWORD_LENGTH - out * out, 0.0))
	return Vector3(HAND_OUT, floor_y - down, atan2(down, out))


# --- His body and blades, as a function of the time into the attack ---

func _animate():
	var fall = StrikePattern.fall_time()
	_move(fall)
	_pose_ram_sword(fall)
	_pose_strike_sword(fall)


func _move(fall: float):
	var home_y = boss.home_position.y
	if _time < _ram_at - fall:
		# Crouching, rearing back from them as the sword goes up.
		var tension = clampf(_time / maxf(_ram_at - fall, 0.01), 0.0, 1.0)
		boss.squash_body(Vector2.ONE.lerp(CROUCH, ease(tension, 0.5)), -_way * REAR * tension)
	elif _time < _ram_at:
		# The lunge, as the sword comes.
		var drop = pow(clampf((_time - (_ram_at - fall)) / fall, 0.0, 1.0), StrikePattern.FALL_POWER)
		boss.global_position.x = lerpf(_from_x, _ram_x, drop)
		boss.squash_body(CROUCH)
	elif _time < _vault_at:
		boss.squash_body(CROUCH)
	elif _time < _land_at:
		# Over A on it, the hilt in his hand: the sword stands up as he goes.
		if not _vaulting:
			_vaulting = true
			boss.ghost(_land_at - _time + 0.05)
			boss.pop_body(Vector2(0.85, 1.2), 0.25)
			Sfx.play("launch", -4.0)
		var over = clampf((_time - _vault_at) / VAULT_TIME, 0.0, 1.0)
		boss.global_position.x = lerpf(_ram_x, _land_x, smoothstep(0.0, 1.0, over))
		boss.global_position.y = home_y - VAULT_HEIGHT * sin(PI * over)
		boss.plant_sword(_sword_a, Vector2(_spot, boss.ARENA_FLOOR_Y), lerpf(_lean_from, 0.0, smoothstep(0.0, 1.0, over)))


# Sword 1, A's: raised, rammed in, standing in the floor, ripped out at A, lifted, and down.
func _pose_ram_sword(fall: float):
	var blade = _sword_a
	if _time < _ram_at - fall:
		var tension = clampf(_time / maxf(_ram_at - fall, 0.01), 0.0, 1.0)
		var pose = boss.POSE_GUARD.lerp(POSE_RAM_RAISED, smoothstep(0.1, 0.7, tension))
		pose.z += randf_range(-TREMBLE, TREMBLE) * tension
		_pose(blade, pose, _way)
		_tint(blade, StrikePattern.COLOR, tension)
	elif _time < _ram_at:
		if _sound("ram"):
			Sfx.play("stab", -3.0)
		var drop = pow(clampf((_time - (_ram_at - fall)) / fall, 0.0, 1.0), StrikePattern.FALL_POWER)
		_pose(blade, POSE_RAM_RAISED.lerp(_rammed, drop), _way, true)
		_strike_tint(blade)
	elif _landed < 2 or _time < _rip_at - fall:
		# In the floor (bifrons_swords.gd poses it); once he's down, trembling as the rip comes.
		var tension = clampf((_time - _land_at) / maxf(_rip_at - fall - _land_at, 0.01), 0.0, 1.0) if _landed >= 2 else 0.0
		if _landed >= 2:
			boss.plant_sword(blade, Vector2(_spot, boss.ARENA_FLOOR_Y), randf_range(-TREMBLE, TREMBLE) * 0.3 * tension)
		boss.tint_sword(blade, boss.COLOR_SWORD.lerp(StrikePattern.COLOR, 0.4 + 0.6 * tension) if tension > 0.0 else boss.COLOR_SWORD)
		boss.tint_side(blade, StrikePattern.COLOR, 0.3 * tension)
	elif _time < _rip_at:
		# Ripped out, up at A.
		if boss.is_planted(blade):
			_pulled = boss.planted_pose(blade)
			boss.pull_sword(blade)
			Sfx.play("swing", -3.0)
		var rip = pow(clampf((_time - (_rip_at - fall)) / fall, 0.0, 1.0), StrikePattern.FALL_POWER)
		_pose(blade, _pulled.lerp(POSE_RIPPED, rip), -_way, true)
		_strike_tint(blade)
	elif _time < _drop_at:
		# The cut's swing carries on up, over his head: the heavy strike's windup.
		var lift = clampf((_time - _rip_at) / maxf(_drop_at - _rip_at, 0.01), 0.0, 1.0)
		var pose = POSE_RIPPED.lerp(boss.POSE_COILED, smoothstep(0.0, 1.0, lift))
		pose.z += randf_range(-TREMBLE, TREMBLE) * lift
		_pose(blade, pose, -_way, true)
		_tint(blade, StrikePattern.COLOR_TOGETHER, lift)
	else:
		# Down: on A, or over onto B's side.
		var drop = pow(clampf((_time - _drop_at) / fall, 0.0, 1.0), StrikePattern.FALL_POWER)
		var toward = lerpf(-_way, _way, drop) if _on_back else -_way
		_pose(blade, boss.POSE_COILED.lerp(boss.POSE_DOWN, drop), toward, true)
		_strike_tint(blade)


# Sword 2, B's: on guard, drawn back over the vault, down on B as he lands, lifted, and down again.
func _pose_strike_sword(fall: float):
	var blade = _sword_b
	var strike_from = _land_at - fall
	var rest = StrikePattern.RECOIL_TIME if _parried_b else StrikePattern.STICK_TIME
	if _time < _vault_at:
		_pose(blade, boss.POSE_GUARD, _way)
		boss.tint_sword(blade, boss.COLOR_SWORD)
		boss.tint_side(blade, StrikePattern.COLOR, 0.0)
	elif _time < strike_from:
		var tension = clampf((_time - _vault_at) / maxf(strike_from - _vault_at, 0.01), 0.0, 1.0)
		var pose = boss.POSE_RAISED.lerp(boss.POSE_COILED, ease(tension, 2.0))
		pose.z += randf_range(-TREMBLE, TREMBLE) * tension
		_pose(blade, pose, _way)
		_tint(blade, StrikePattern.COLOR, tension)
	elif _time < _land_at:
		if _sound("strike"):
			Sfx.play("swing", -3.0)
		var drop = pow(clampf((_time - strike_from) / fall, 0.0, 1.0), StrikePattern.FALL_POWER)
		_pose(blade, boss.POSE_COILED.lerp(boss.POSE_DOWN, drop), _way, true)
		_strike_tint(blade)
	elif _time < _land_at + rest:
		_pose(blade, boss.POSE_RECOIL if _parried_b else boss.POSE_DOWN, _way)
		boss.tint_sword(blade, boss.COLOR_SWORD if _parried_b else boss.COLOR_EXECUTE)
		boss.tint_side(blade, StrikePattern.COLOR, 0.0)
	elif _time < _drop_at:
		# Up with the other one, for the heavy strike.
		var lift = clampf((_time - _land_at - rest) / maxf(_drop_at - _land_at - rest, 0.01), 0.0, 1.0)
		var pose = boss.POSE_COILED
		pose.z += randf_range(-TREMBLE, TREMBLE) * lift
		_pose(blade, pose, _way)
		_tint(blade, StrikePattern.COLOR_TOGETHER, lift)
	else:
		var drop = pow(clampf((_time - _drop_at) / fall, 0.0, 1.0), StrikePattern.FALL_POWER)
		_pose(blade, boss.POSE_COILED.lerp(boss.POSE_DOWN, drop), _way, true)
		_strike_tint(blade)


# That sword in `pose`, on the side `toward` (±1, or between: passing in front of him), whichever
# side of him its player is on just now.
func _pose(blade: int, pose: Vector3, toward: float, snap = false):
	boss.pose_sword(blade, pose, snap, toward * boss.blade_side(blade))


# Drawn back for a strike: the steel and that half of him going over to `color` as it nears.
func _tint(blade: int, color: Color, tension: float):
	boss.tint_sword(blade, boss.COLOR_SWORD.lerp(color, 0.4 + 0.6 * tension))
	boss.tint_side(blade, color, 0.1 + 0.3 * tension)


# Coming: red.
func _strike_tint(blade: int):
	boss.tint_sword(blade, boss.COLOR_EXECUTE)
	boss.tint_side(blade, boss.COLOR_EXECUTE, 0.45)


# True the first time it's asked for that sound in this run.
func _sound(what: String) -> bool:
	if _sounded.has(what):
		return false
	_sounded[what] = true
	return true
