class_name Sweep
extends Attack
## Yellow blade, held out to the side -> red. Columna Bifrons sweeps one blade flat from its
## own player's side through to the other: it reaches its own player first, and the other one
## TRAVEL_TIME later. Each has to perfect parry it as it reaches them; blocking only softens the
## hit. It breaks no guard, as a parried strike does: what a parry wins is where his blades are
## afterwards (and a blade that isn't at its flank guards nothing, see
## ColumnaBifrons.is_guarding()):
##   nobody        the blade swings back at once: he's guarded against both again.
##   first only    knocked off its course, the blade doesn't come back for a while: no sword
##                 against the first player.
##   second only   stopped dead, he has to prop himself up on his other sword, which guards
##                 nothing meanwhile; the swept blade swings back to its own player.
##   both          both of those: the blade lies where it was stopped and he leans on the other.
##                 No guard at all: staggered.
## It's for a player on each side (pep); with both on one side it doesn't come.

signal strike_parried(player)
signal both_parried

enum Phase { NONE, SWEEPING, AFTER }

const LEFT = StrikePattern.LEFT
const RIGHT = StrikePattern.RIGHT

# --- Tuning ---
const WINDUP_UNITS = 6  # StrikePattern.TIME_UNITs until the blade reaches the first player
const TRAVEL_TIME = 0.4  # from the first player through to the second
const AWAY_TIME = 1.4  # parried by the first only: how long the blade stays away from its side
const PROP_TIME = 1.4  # parried by the second only: how long he leans on his other sword
const RETURN_TIME = 0.3  # the blade swinging back to its own side
const STAGGER_TIME = 2.2  # parried by both
const RECOVER_TIME = 0.6
const TREMBLE = 0.04  # radians the drawn-back blade shakes by, just before it comes down

var _name: String
var _first = LEFT  # the sword that sweeps: its player is the first it reaches
var _time = 0.0  # seconds into the attack
var _first_at = 0.0  # when the blade reaches the first player...
var _second_at = 0.0  # ...and the second
var _landed = 0  # how many of the two it has reached
var _first_parried = false
var _second_parried = false
var _after_since = 0.0
var _after_for = 0.0
var _sounded = false


func _init(attack_name: String):
	_name = attack_name


func get_attack_name() -> String:
	return _name


# It needs a player on each side, and that's where it comes (see ColumnaBifrons.ATTACKS).
func fits(_boss_node) -> bool:
	return true


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	# As written it goes from left to right; the boss says which way round this run goes.
	_first = LEFT * boss.orient([[WINDUP_UNITS, LEFT], [TRAVEL_TIME / StrikePattern.TIME_UNIT, RIGHT]])
	_time = 0.0
	_first_at = WINDUP_UNITS * StrikePattern.TIME_UNIT
	_second_at = _first_at + TRAVEL_TIME
	_landed = 0
	_first_parried = false
	_second_parried = false
	_sounded = false


func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


# The telegraph is the windup, up to the blade coming down level.
func get_telegraph_duration() -> float:
	return _first_at - StrikePattern.FALL_TIME


func update_telegraph(progress: float):
	_time = progress * get_telegraph_duration()
	_animate()


func execute():
	phase = Phase.SWEEPING
	_time = get_telegraph_duration()
	boss.body.color = boss.COLOR_IDLE
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	_animate()


func update(delta: float):
	_time += delta
	if phase == Phase.SWEEPING:
		if _landed == 0 and _time >= _first_at:
			_landed = 1
			_first_parried = _reach(_first)
			Sfx.play("swing", -3.0)  # on through to the other side
		if _landed == 1 and _time >= _second_at:
			_landed = 2
			_second_parried = _reach(-_first)
			_settle()
			if completed:
				return
	elif _time >= _after_since + _after_for:
		finish(RECOVER_TIME)
		return
	_animate()


# Seconds until the sweep reaches that player; INF once it's past them.
func time_to_strike(player) -> float:
	if _landed == 0 and boss.ward_of(_first) == player:
		return _first_at - _time
	if _landed < 2 and boss.ward_of(-_first) == player:
		return _second_at - _time
	return INF


# The blade reaches that sword's player: true if it was parried there.
func _reach(blade: int) -> bool:
	var judged = boss.judge(blade)
	boss.land(judged)
	for p in judged.parriers:
		parry_success.emit(p, "bifrons_sweep")
		strike_parried.emit(p)
	return judged.parried


# The sweep is over: what it leaves him with (see the top of this file).
func _settle():
	if _first_parried and _second_parried:
		both_parried.emit()
		boss.set_stagger_pose(_first, boss.POSE_LIMP, -1.0)  # lying where it was stopped
		boss.set_stagger_pose(-_first, boss.POSE_PROP)
		Sfx.play("counter_hit", -2.0)
		boss.shake(12.0)
		finish_with_stagger(STAGGER_TIME)
		return
	phase = Phase.AFTER
	_after_since = _time
	if _first_parried:
		_after_for = AWAY_TIME + RETURN_TIME
	elif _second_parried:
		_after_for = maxf(PROP_TIME, RETURN_TIME)
		boss.shake(6.0)
	else:
		_after_for = RETURN_TIME


# --- The blades, as a function of the time into the attack ---

func _animate():
	var swept = _first  # the blade that sweeps
	var other = -_first  # the one that stays at its flank
	boss.tint_side(other, StrikePattern.COLOR, 0.0)
	if phase == Phase.AFTER:
		var since = _time - _after_since
		boss.tint_sword(swept, boss.COLOR_SWORD)
		boss.tint_side(swept, StrikePattern.COLOR, 0.0)
		# The swept blade: away for a while if the first player knocked it off its course, then
		# (or at once) swinging back the way it came.
		var back_since = since - (AWAY_TIME if _first_parried else 0.0)
		if back_since < 0.0:
			boss.pose_sword(swept, boss.POSE_LIMP, false, -1.0)
			boss.tint_sword(swept, boss.COLOR_SWORD_LIMP)
		elif back_since < RETURN_TIME:
			boss.pose_sword(swept, boss.POSE_SWEEP, true, lerpf(-1.0, 1.0, back_since / RETURN_TIME))
		else:
			boss.pose_sword(swept, boss.POSE_GUARD)
		# The other blade: his prop if the second player stopped the sweep.
		if _second_parried and since < PROP_TIME:
			boss.pose_sword(other, boss.POSE_PROP)
		else:
			boss.pose_sword(other, boss.POSE_GUARD)
		boss.tint_sword(other, boss.COLOR_SWORD)
		return

	boss.pose_sword(other, boss.POSE_GUARD)
	boss.tint_sword(other, boss.COLOR_SWORD)
	var down_from = _first_at - StrikePattern.FALL_TIME
	if _time >= _first_at:
		# Through, flat, from its own player's side to the other.
		var across = clampf((_time - _first_at) / TRAVEL_TIME, 0.0, 1.0)
		boss.pose_sword(swept, boss.POSE_SWEEP, true, lerpf(1.0, -1.0, across))
		boss.tint_sword(swept, boss.COLOR_EXECUTE)
		boss.tint_side(swept, boss.COLOR_EXECUTE, 0.45 * (1.0 - across))
		boss.tint_side(other, boss.COLOR_EXECUTE, 0.45 * across)
	elif _time >= down_from:
		# Down from where it was held, to level: it reaches the first player as it gets there.
		if not _sounded:
			_sounded = true
			Sfx.play("swing", -3.0)
		var drop = pow(clampf((_time - down_from) / StrikePattern.FALL_TIME, 0.0, 1.0), StrikePattern.FALL_POWER)
		boss.pose_sword(swept, boss.POSE_SWEEP_BACK.lerp(boss.POSE_SWEEP, drop), true)
		boss.tint_sword(swept, boss.COLOR_EXECUTE)
		boss.tint_side(swept, boss.COLOR_EXECUTE, 0.45)
	else:
		# Held out to the side and drawn back, trembling as the sweep gets close.
		var tension = clampf(_time / maxf(down_from, 0.01), 0.0, 1.0)
		var pose: Vector3 = boss.POSE_SWEEP_BACK
		pose.z += randf_range(-TREMBLE, TREMBLE) * tension
		boss.pose_sword(swept, pose)
		boss.tint_sword(swept, boss.COLOR_SWORD.lerp(StrikePattern.COLOR, 0.4 + 0.6 * tension))
		boss.tint_side(swept, StrikePattern.COLOR, 0.1 + 0.3 * tension)
