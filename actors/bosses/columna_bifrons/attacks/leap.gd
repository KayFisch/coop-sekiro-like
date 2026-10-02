class_name Leap
extends Attack
## Blue blades, pointing down -> red. Columna Bifrons's way out of having both players on one
## side of him (ppe): he crouches, jumps, hangs over them and comes down between them, a sword
## stabbing down on each. Each player has to perfect parry the one that's theirs as he lands;
## both do, and he's staggered. Either way he's between them now (whoever is under him is pushed
## out to their side): a player on each side again (pep).

signal strike_parried(player)
signal both_parried

enum Phase { NONE, FALLING }

const NAME = "LEAP"
const LEFT = StrikePattern.LEFT
const RIGHT = StrikePattern.RIGHT

# --- Tuning ---
const WINDUP_UNITS = 7  # StrikePattern.TIME_UNITs until he lands
const RISE_TIME = 0.3  # from the floor up to HEIGHT
const HANG_TIME = 0.3  # up there, over the players, before he drops (in StrikePattern.FALL_TIME)
const HEIGHT = 200.0  # how high he gets: his feet clear the players' heads
const TRACK_SPEED = 600.0  # px/s he follows the spot he's going to land on, until he drops
const AHEAD = 50.0  # he lands at most this far past the nearer player, between the two
const REACH = 80.0  # a player this close to where he lands is under the swords
const STAGGER_TIME = 2.2  # parried by both
const RECOVER_TIME = 0.6
const CROUCH = Vector2(1.12, 0.78)  # his body, loaded for the jump
const TREMBLE = 0.04  # radians the blades shake by as he hangs

var _time = 0.0  # seconds into the attack
var _jump_at = 0.0
var _fall_at = 0.0
var _land_at = 0.0
var _from_x = 0.0  # where he jumped off
var _jumped = false
var _dropping = false


func get_attack_name() -> String:
	return NAME


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	boss.orient([[WINDUP_UNITS, StrikePattern.BOTH]])
	_time = 0.0
	_land_at = WINDUP_UNITS * StrikePattern.TIME_UNIT
	_fall_at = _land_at - StrikePattern.FALL_TIME
	_jump_at = _fall_at - HANG_TIME - RISE_TIME
	_from_x = boss.global_position.x
	_jumped = false
	_dropping = false


func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


# The telegraph is everything up to the drop.
func get_telegraph_duration() -> float:
	return _fall_at


func update_telegraph(progress: float):
	_time = progress * get_telegraph_duration()
	_animate()


func execute():
	phase = Phase.FALLING
	_time = get_telegraph_duration()
	boss.body.color = boss.COLOR_IDLE
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	_animate()


func update(delta: float):
	_time += delta
	if _time < _land_at:
		_animate()
		return
	# He lands.
	boss.global_position.y = boss.home_position.y
	boss.pop_body(Vector2(1.25, 0.8), 0.25)
	var judged = {}
	for blade in [LEFT, RIGHT]:
		judged[blade] = boss.judge(blade, REACH)
	var both = judged[LEFT].parried and judged[RIGHT].parried
	for blade in [LEFT, RIGHT]:
		boss.land(judged[blade], both)
		for p in judged[blade].parriers:
			parry_success.emit(p, "bifrons_leap")
			strike_parried.emit(p)
	boss.shake(12.0 if both else 9.0)
	boss.ghost(0.0)  # he's there: whoever is under him is pushed out to their side
	if both:
		both_parried.emit()
		Sfx.play("counter_hit", -2.0)
		finish_with_stagger(STAGGER_TIME)
	else:
		finish(RECOVER_TIME)


func cleanup():
	boss.global_position.y = boss.home_position.y


# Where he comes down: between the two players, at most AHEAD past the nearer one.
func _landing_x() -> float:
	var wards = [boss.ward_of(LEFT), boss.ward_of(RIGHT)].filter(func(ward): return ward != null)
	if wards.is_empty():
		return boss.global_position.x
	wards.sort_custom(func(a, b): return absf(a.global_position.x - _from_x) < absf(b.global_position.x - _from_x))
	var near = wards[0].global_position.x
	if wards.size() == 1:
		return boss.clamp_x(near)
	var gap = wards[1].global_position.x - near
	return boss.clamp_x(near + signf(gap) * minf(absf(gap) / 2.0, AHEAD))


# --- His body and blades, as a function of the time into the attack ---

func _animate():
	var floor_y = boss.home_position.y
	var tension = clampf(_time / maxf(_fall_at, 0.01), 0.0, 1.0)
	var pose: Vector3 = boss.POSE_STAB
	pose.z += randf_range(-TREMBLE, TREMBLE) * tension
	if _time < _jump_at:
		# Crouching, the blades going up.
		boss.squash_body(Vector2.ONE.lerp(CROUCH, ease(_time / maxf(_jump_at, 0.01), 0.5)))
	elif _time < _fall_at:
		# Up, and over the spot he'll land on.
		if not _jumped:
			_jumped = true
			boss.pop_body(Vector2(0.85, 1.2), 0.25)
			Sfx.play("launch", -4.0)
		var rise = clampf((_time - _jump_at) / RISE_TIME, 0.0, 1.0)
		boss.global_position.y = floor_y - HEIGHT * (1.0 - (1.0 - rise) * (1.0 - rise))
		boss.global_position.x = move_toward(boss.global_position.x, _landing_x(),
			TRACK_SPEED * boss.get_physics_process_delta_time())
	else:
		# Down, both blades first. His body is no obstacle until he's landed.
		if not _dropping:
			_dropping = true
			boss.ghost(_land_at - _time + 0.05)
			Sfx.play("swing", -3.0)
		var drop = pow(clampf((_time - _fall_at) / StrikePattern.FALL_TIME, 0.0, 1.0), StrikePattern.FALL_POWER)
		boss.global_position.y = floor_y - HEIGHT * (1.0 - drop)
	for blade in [LEFT, RIGHT]:
		boss.pose_sword_home(blade, pose, _dropping)
		if _dropping:
			boss.tint_sword(blade, boss.COLOR_EXECUTE)
			boss.tint_side(blade, boss.COLOR_EXECUTE, 0.45)
		else:
			boss.tint_sword(blade, boss.COLOR_SWORD.lerp(StrikePattern.COLOR_TOGETHER, 0.4 + 0.6 * tension))
			boss.tint_side(blade, StrikePattern.COLOR_TOGETHER, 0.1 + 0.3 * tension)
