class_name Counterweight
extends Attack
## Orange -> red. The chain lets go and reels up empty; Sphaera Pendula hangs over the target's
## pan, its shadow growing there, then drops onto it. Its weight slams that pan down and
## catapults the other one up, and then the sunk pan keeps sinking toward the pit, taking anyone
## still standing on it along.
## The counter is a seesaw: both players land on the raised pan together, from real jumps,
## within SYNC_LAND_WINDOW of each other. That catapults the sunk pan back up and flings the
## sphere into the beam; it drops into the pit, dazed. A single landing only lifts the sunk pan a
## little, buying time. A player caught on the sunk pan has a long climb to the raised one: a
## partner's Launch (see player.gd) makes it easy.

signal catapulted

enum Phase { NONE, DROP, SINKING, FLUNG, FALL, ROLL_OFF }

# --- Tuning ---
const TELEGRAPH_TIME = 1.2
const HANG_HEIGHT = 200.0  # its center above the pan's surface during the telegraph
const DROP_TIME = 0.22
const DROP_POWER = 2.5  # the drop accelerates (1 = constant speed)
const IMPACT_DAMAGE = 25.0
const IMPACT_BLOCKED_DAMAGE = 10.0
const IMPACT_REACH = 70.0  # players this close (sideways, center to center) to the impact are hit
const IMPACT_KNOCKBACK = 320.0
const SPHERE_WEIGHT = 3.0  # a player weighs 1 (see scales.gd)
const SINK_TIME = 3.5  # from landing until the pan is gone
const SINK_DEPTH = 260.0  # how far below its weighed-down height the pan sinks
const SINK_POWER = 1.6  # sinking slowly at first, then faster
const MIN_LAND_AIR_TIME = 0.35  # a landing only counts after a real jump (no hops or taps)
const SYNC_LAND_WINDOW = 0.15  # both players landing within this of each other: catapult
const SOLO_LAND_REFUND = 0.4  # seconds of sinking a single landing undoes
const SOLO_LAND_KICK = 250.0  # and the jolt it gives the sunk pan (px/s)
const CATAPULT_KICK = 1300.0  # the sunk pan springing back up
const CATAPULT_DAMAGE = 50.0  # the sphere hitting the beam (x the sync multiplier)
const FLING_TIME = 0.35
const FALL_TIME = 0.45
const CATAPULT_STAGGER_TIME = 2.2
const ROLL_OFF_TIME = 0.4  # the pan gone, it rolls off into the pit
const RECOVER_TIME = 0.6

const COLOR = Color(1.0, 0.55, 0.1)
const BAR_WIDTH = 100.0

var _side = Scales.LEFT  # the pan it lands on
var _x = 0.0
var _telegraph_from = Vector2.ZERO
var _from = Vector2.ZERO
var _sink_elapsed = 0.0
var _clock = 0.0
var _landings: Array = []  # {who, time}, on the raised pan, during SINKING
var _pending: Array = []  # landings reported since the last update
var _shadow: ColorRect
var _bar: ColorRect


func get_attack_name() -> String:
	return "COUNTERWEIGHT"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_telegraph_from = boss_node.global_position
	_landings.clear()
	_pending.clear()


# Letting go of the chain, drifting over the target's pan, the shadow growing under it.
func update_telegraph(progress: float):
	boss.chain_attached = false
	var target = boss.target_player
	_side = boss.scales.side_of_x(target.global_position.x)
	var span = boss.scales.pan_span(_side)
	_x = clampf(target.global_position.x, span.x + boss.RADIUS, span.y - boss.RADIUS)
	var goal = Vector2(_x, boss.scales.pan_top(_side) - HANG_HEIGHT)
	boss.global_position = _telegraph_from.lerp(goal, ease(minf(progress * 1.6, 1.0), 0.4))
	boss.draw_chain(boss.ANCHOR, boss.ANCHOR.lerp(_telegraph_from, 1.0 - progress))  # reeling up empty
	boss.set_glow(COLOR, 0.3 + 0.3 * progress)
	if _shadow == null:
		_shadow = _make_rect(COLOR)
	var width = lerpf(20.0, boss.RADIUS * 2.0, progress)
	_shadow.size = Vector2(width, 6.0)
	_shadow.color = Color(COLOR, 0.25 + 0.5 * progress)
	_shadow.global_position = Vector2(boss.global_position.x - width / 2.0, boss.scales.pan_top(_side) - 6.0)


func execute():
	phase = Phase.DROP
	timer = DROP_TIME
	_from = boss.global_position


func update(delta: float):
	timer -= delta
	_clock += delta
	match phase:
		Phase.DROP:
			var t = pow(1.0 - clampf(timer / DROP_TIME, 0.0, 1.0), DROP_POWER)
			boss.global_position = Vector2(_x, lerpf(_from.y, _rest_y(), t))
			if timer <= 0.0:
				_impact()

		Phase.SINKING:
			_sink_elapsed += delta
			var p = clampf(_sink_elapsed / SINK_TIME, 0.0, 1.0)
			boss.scales.sink[_side] = SINK_DEPTH * pow(p, SINK_POWER)
			boss.global_position = Vector2(_x, _rest_y())
			boss.set_glow(COLOR, 0.3 + 0.3 * sin(boss.anim_time * lerpf(8.0, 30.0, p)))
			_update_bar(1.0 - p)
			if _take_landings():
				return
			if p >= 1.0:
				_roll_off()

		Phase.FLUNG:
			var t = 1.0 - clampf(timer / FLING_TIME, 0.0, 1.0)
			var beam = Vector2(Scales.CENTER_X, boss.ANCHOR.y + boss.RADIUS)
			boss.global_position = _from.lerp(beam, ease(t, 0.4))
			boss.body.rotation += 25.0 * delta
			if timer <= 0.0:
				_hit_beam()

		Phase.FALL:
			var t = 1.0 - clampf(timer / FALL_TIME, 0.0, 1.0)
			boss.global_position = _from.lerp(boss.stagger_spot(), ease(t, 2.0))
			if timer <= 0.0:
				boss.pop_body(Vector2(1.25, 0.8), 0.25)
				finish_with_stagger(CATAPULT_STAGGER_TIME)

		Phase.ROLL_OFF:
			var t = 1.0 - clampf(timer / ROLL_OFF_TIME, 0.0, 1.0)
			boss.global_position = _from.lerp(Vector2(Scales.CENTER_X, 760.0), ease(t, 2.0))
			if timer <= 0.0:
				finish(RECOVER_TIME)


func get_marker(telegraphing: bool):
	if telegraphing:
		return {"who": boss.target_player}
	return null


func cleanup():
	boss.chain_attached = true
	for side in [Scales.LEFT, Scales.RIGHT]:
		boss.scales.extra_weight[side] = 0.0
		boss.scales.sink[side] = 0.0
	for p in players:
		if is_instance_valid(p) and p.landed.is_connected(_on_landed):
			p.landed.disconnect(_on_landed)
	for node in [_shadow, _bar]:
		if node:
			node.queue_free()
	_shadow = null
	_bar = null


# Resting on the pan: its bottom on the surface.
func _rest_y() -> float:
	return boss.scales.pan_top(_side) - boss.RADIUS


func _impact():
	boss.global_position = Vector2(_x, _rest_y())
	boss.pop_body(Vector2(1.3, 0.75), 0.3)
	boss.shake(12.0)
	Sfx.play("thunk", 2.0)
	for p in players:
		if boss.scales.is_standing_on(p, _side) and absf(p.global_position.x - _x) <= IMPACT_REACH:
			boss.hit_player(p, IMPACT_DAMAGE, IMPACT_BLOCKED_DAMAGE, boss.knockback_for(p, IMPACT_KNOCKBACK))
	boss.scales.extra_weight[_side] = SPHERE_WEIGHT
	if _shadow:
		_shadow.queue_free()
		_shadow = null
	_bar = _make_rect(COLOR)
	phase = Phase.SINKING
	_sink_elapsed = 0.0
	for p in players:
		p.landed.connect(_on_landed)


# Landings arrive from the players' own physics; they're judged in update().
func _on_landed(player, air_time: float):
	if phase == Phase.SINKING and air_time >= MIN_LAND_AIR_TIME:
		_pending.append(player)


# True if the landings so far catapulted the sphere.
func _take_landings() -> bool:
	for player in _pending:
		if not boss.scales.is_standing_on(player, -_side):
			continue
		for other in _landings:
			if other.who != player and _clock - other.time <= SYNC_LAND_WINDOW:
				_pending.clear()
				_catapult()
				return true
		_landings.append({"who": player, "time": _clock})
		# Alone, it only lifts the sunk pan a little.
		_sink_elapsed = maxf(_sink_elapsed - SOLO_LAND_REFUND, 0.0)
		boss.scales.kick(_side, SOLO_LAND_KICK)
		boss.shake(3.0)
		Sfx.play("chip")
	_pending.clear()
	return false


func _catapult():
	boss.scales.extra_weight[_side] = 0.0
	boss.scales.sink[_side] = 0.0
	boss.scales.kick(_side, CATAPULT_KICK)
	for p in players:
		if boss.scales.is_standing_on(p, -_side):
			p.on_perfect_parry(true)  # the flash and clang of the seesaw coming down together
	catapulted.emit()
	phase = Phase.FLUNG
	timer = FLING_TIME
	_from = boss.global_position
	boss.body.color = COLOR
	Sfx.play("counter_fire")
	if _bar:
		_bar.queue_free()
		_bar = null


func _hit_beam():
	var damage = CATAPULT_DAMAGE * GameManager.damage_multiplier()
	boss.shake(14.0)
	Sfx.play("counter_hit", 2.0)
	boss.spawn_sparks(boss.global_position + Vector2(0.0, -boss.RADIUS), 24, COLOR)
	boss.take_damage(damage)
	if boss.hp <= 0.0:
		return
	boss.chain_attached = true
	phase = Phase.FALL
	timer = FALL_TIME
	_from = boss.global_position


# Nobody lifted it in time: the pan is gone, and it rolls off into the pit.
func _roll_off():
	boss.scales.extra_weight[_side] = 0.0
	boss.scales.sink[_side] = 0.0
	phase = Phase.ROLL_OFF
	timer = ROLL_OFF_TIME
	_from = boss.global_position
	boss.chain_attached = true
	if _bar:
		_bar.queue_free()
		_bar = null


# The time left before the pan is gone, as a shrinking bar over the sphere.
func _update_bar(left: float):
	var width = BAR_WIDTH * left
	_bar.size = Vector2(width, 6.0)
	_bar.global_position = boss.global_position + Vector2(-width / 2.0, -boss.RADIUS - 18.0)


func _make_rect(color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.top_level = true
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = color
	boss.add_child(rect)
	return rect
