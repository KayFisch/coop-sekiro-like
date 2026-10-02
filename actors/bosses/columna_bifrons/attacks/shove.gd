class_name Shove
extends Attack
## White blades, lowered and drawn back -> thrust. Columna Bifrons making room without giving
## ground: he draws both swords back, level, and thrusts them out at the players they fight.
## It's no strike: no damage, nothing to parry, no guard broken. It throws back every player a
## blade reaches (a dash carries a player through it). It comes when he wants room and a hop
## back would take him away from the middle of the room (see "MAKING ROOM" in
## columna_bifrons.gd).

enum Phase { NONE, THRUSTING }

const LEFT = StrikePattern.LEFT
const RIGHT = StrikePattern.RIGHT

# --- Tuning ---
const WINDUP_TIME = 0.5  # the swords drawn back: the cue
const THRUST_TIME = 0.08  # ...and out
const HOLD_TIME = 0.25  # held out, before they come back
const NEAR = 150.0  # he only shoves while a player is this close to him: it's for making room
const REACH = 215.0  # a player this close, on a side a blade is thrust to, is thrown back...
const PUSH = Vector2(700.0, -160.0)  # ...at this speed (px/s): about 130 px, and off the floor
const PUSH_TIME = 0.05  # the thrust keeps pushing this long
const RECOVER_TIME = 0.4
const LEAN = 16.0  # px his body rears back by, and then into the thrust (players on one side)
const PULL_IN = Vector2(0.92, 1.05)  # his body, drawn in (a player on each side)
const SPREAD = Vector3(0.0, -18.0, 0.0)  # the sword that reaches across thrusts above the other
const COLOR = Color(0.95, 0.97, 1.0)  # white: nothing to parry

var _name: String
var _time = 0.0  # seconds into the thrust
var _thrown = []  # the players it has thrown back


func _init(attack_name: String):
	_name = attack_name


func get_attack_name() -> String:
	return _name


# Only while a player he's fighting is close to him.
func fits(boss_node) -> bool:
	for blade in [LEFT, RIGHT]:
		var ward = boss_node.ward_of(blade)
		if ward != null and boss_node.distance_to(ward) <= NEAR:
			return true
	return false


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_time = 0.0
	_thrown = []


func get_telegraph_color() -> Color:
	return boss.COLOR_IDLE


func get_telegraph_duration() -> float:
	return WINDUP_TIME


# Both swords lowered at the players, then drawn far back, his body with them.
func update_telegraph(progress: float):
	var draw = smoothstep(0.1, 0.8, progress)
	_pose(boss.POSE_LANCE_LOW.lerp(boss.POSE_LANCE_BACK, draw), false)
	_lean(-draw)
	for blade in [LEFT, RIGHT]:
		boss.tint_sword(blade, boss.COLOR_SWORD.lerp(COLOR, 0.4 + 0.6 * progress))
		boss.tint_side(blade, COLOR, 0.1 + 0.3 * progress)


func execute():
	phase = Phase.THRUSTING
	_time = 0.0
	boss.body.color = boss.COLOR_IDLE
	boss.set_glow(boss.COLOR_EXECUTE, 0.0)
	Sfx.play("stab", -2.0)


func update(delta: float):
	_time += delta
	var out = clampf(_time / THRUST_TIME, 0.0, 1.0)
	_pose(boss.POSE_LANCE_BACK.lerp(boss.POSE_LANCE, out), true)
	_lean(lerpf(-1.0, 0.6, out))
	for blade in [LEFT, RIGHT]:
		boss.tint_sword(blade, COLOR)
		boss.tint_side(blade, COLOR, 0.45 * (1.0 - clampf((_time - THRUST_TIME) / HOLD_TIME, 0.0, 1.0)))
	if out >= 1.0 and _time < THRUST_TIME + PUSH_TIME:
		_push()
	if _time >= THRUST_TIME + HOLD_TIME:
		finish(RECOVER_TIME)


# Nothing to parry.
func time_to_strike(_player) -> float:
	return INF


# Every player on a side a blade is thrust to, and within its reach, is thrown back. It pushes
# for a few frames (PUSH_TIME): a player with their partner right behind them can't move until
# the partner has.
func _push():
	var sides = [boss.blade_side(LEFT), boss.blade_side(RIGHT)]
	for p in boss.get_players():
		var side = boss.side_of(p)
		if not side in sides or (boss.distance_to(p) > REACH and not p in _thrown):
			continue
		if p.velocity.x * side < PUSH.x * 0.8:
			p.apply_knockback(Vector2(side * PUSH.x, PUSH.y))
		if not p in _thrown:
			_thrown.append(p)
			boss.spawn_sparks(p.global_position + Vector2(-side * 16.0, -8.0), 8, COLOR)
			if _thrown.size() == 1:
				Sfx.play("thunk", -3.0)
				boss.shake(6.0)


# Both blades in that pose, each on its player's side; the one that reaches across above the
# other, so they're two.
func _pose(pose: Vector3, snap: bool):
	for blade in [LEFT, RIGHT]:
		boss.pose_sword(blade, pose + (SPREAD if boss.reaches_across(blade) else Vector3.ZERO), snap)


# His body: `amount` -1 reared back from the players, 1 leaning into them. With a player on
# each side he can't lean: he draws himself in instead.
func _lean(amount: float):
	var left = boss.blade_side(LEFT)
	if left == boss.blade_side(RIGHT):
		boss.squash_body(Vector2.ONE, left * LEAN * amount)
	else:
		boss.squash_body(Vector2.ONE.lerp(PULL_IN, maxf(-amount, 0.0)))
