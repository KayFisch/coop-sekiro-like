class_name ShockwaveSlashes
extends Attack
## Red center charge -> red. Hovering at center, Cubus Maximus slashes on a fixed metronome,
## firing a shockwave at P1, P2, P1, ... (3 each). Each perfectly parried shockwave is
## "gathered"; a player who gathers all of theirs counterattacks after a short wait. Both
## counters are timed to land together for double damage and a stagger.

signal shockwave_parried(player)
signal counterattack_landed(both_players)

enum Phase { NONE, VOLLEY, VOLLEY_WAIT, COUNTER_TRAVEL }

# --- Tuning ---
const TELEGRAPH_TIME = 1.2  # the center charge
const SLASH_INTERVAL = 0.2  # the metronome: seconds between slashes, independent of travel
const SLASH_COUNT = 6  # alternating P1, P2, ... so 3 each
const WAVE_SPEED = 650.0
const WAVE_SIZE = Vector2(14, 70)
const WAVE_DAMAGE = 20.0
const WAVE_KNOCKBACK = 250.0
const BLOCKED_DAMAGE = 10.0
const BLOCKED_KNOCKBACK = 150.0
const WAIT_TIME = 1.0  # after the last slash, before the counters launch
const COUNTER_TRAVEL_TIME = 0.5  # every counter takes this long, so simultaneous ones land together
const COUNTER_DAMAGE = 40.0  # per counter (x the sync multiplier); both together deal double
const COUNTER_STAGGER_TIME = 2.0  # only when both players counter
const RECOVER_TIME = 0.45  # no counter, or only one

const COLOR = Color(1.0, 0.15, 0.15)
# Each slash's swing: between beats the sword winds back up past overhead and holds there; the
# last SNAP_TIME before each beat it whips down, and the shockwave leaves on the beat.
const SNAP_TIME = 0.06
const SNAP_POWER = 2.0  # the whip accelerates into the release (1 = constant speed)
const WOUND_EXTRA = 0.35  # radians past the raised angle when fully wound up
const SLASH_POP = Vector2(1.12, 0.9)  # a small body jolt on each release

var projectiles: Array = []  # Dictionaries: node, target, dir, hum

var _order: Array = []  # players in slash order
var _index = 0
var _counters: Array = []  # Dictionaries: node, from
var _counter_both = false
var _wait_elapsed = 0.0


func get_attack_name() -> String:
	return "SHOCKWAVE_SLASHES"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func uses_center_charge() -> bool:
	return true


func update_telegraph(progress: float):
	# Winding the sword up over the charge.
	boss.set_sword_angle(lerpf(boss.SWORD_REST_ANGLE, _wound_angle(), ease(progress, 1.5)))


func execute():
	phase = Phase.VOLLEY
	timer = SNAP_TIME  # the first slash's whip, then on the metronome
	_index = 0
	_order = players.duplicate()
	_order.sort_custom(func(a, b): return a.player_id < b.player_id)
	var per_player = int(float(SLASH_COUNT) / _order.size())
	for p in _order:
		p.start_gather(per_player)


func update(delta: float):
	timer -= delta
	match phase:
		Phase.VOLLEY:
			boss.hover()
			_update_projectiles(delta)
			if timer <= 0.0:
				_slash()
				if _index >= SLASH_COUNT:
					phase = Phase.VOLLEY_WAIT
					timer = WAIT_TIME
					_wait_elapsed = 0.0
				else:
					timer += SLASH_INTERVAL  # metronome: keep the beat exact
			if phase == Phase.VOLLEY:
				_pose_slash()

		Phase.VOLLEY_WAIT:
			boss.hover()
			_update_projectiles(delta)
			# Follow-through, then easing the sword back down to rest.
			_wait_elapsed += delta
			var settle = clampf(_wait_elapsed / 0.4, 0.0, 1.0)
			boss.set_sword_angle(lerpf(boss.SWORD_FOLLOW_ANGLE, boss.SWORD_REST_ANGLE, ease(settle, -2.0)))
			if timer <= 0.0:
				_launch_counters()

		Phase.COUNTER_TRAVEL:
			boss.hover()
			var t = 1.0 - clampf(timer / COUNTER_TRAVEL_TIME, 0.0, 1.0)
			for c in _counters:
				c.node.global_position = c.from.lerp(boss.global_position, t) - c.node.size / 2
			if timer <= 0.0:
				_counters_land()


func get_marker(_telegraphing: bool):
	if phase == Phase.VOLLEY:
		return {"who": _order[_index % _order.size()]}  # next on the metronome
	return null


func cleanup():
	for proj in projectiles:
		proj.node.queue_free()
		Sfx.stop(proj.hum)
	projectiles.clear()
	for c in _counters:
		c.node.queue_free()
	_counters.clear()
	for p in _order:
		if is_instance_valid(p):
			p.end_gather()
	_order.clear()


func _slash():
	var target = _order[_index % _order.size()]
	_index += 1
	boss.target_player = target
	boss.face(target.global_position.x)
	boss.pop_body(SLASH_POP, 0.12)
	_fire_shockwave(target)


func _wound_angle() -> float:
	return boss.SWORD_RAISED_ANGLE - WOUND_EXTRA


# The sword against the metronome: whipping down in the last SNAP_TIME before each beat,
# otherwise winding back up from the follow-through (quickly at first, then holding).
func _pose_slash():
	if timer <= SNAP_TIME:
		var snap = pow(1.0 - clampf(timer / SNAP_TIME, 0.0, 1.0), SNAP_POWER)
		boss.set_sword_angle(lerpf(_wound_angle(), boss.SWORD_FOLLOW_ANGLE, snap))
	else:
		var since = SLASH_INTERVAL - timer  # time since the last release
		var windup = clampf(since / (SLASH_INTERVAL - SNAP_TIME), 0.0, 1.0)
		var from = boss.SWORD_FOLLOW_ANGLE if _index > 0 else _wound_angle()
		boss.set_sword_angle(lerpf(from, _wound_angle(), ease(windup, 0.4)))


func _fire_shockwave(target):
	# Fired from Cubus Maximus, straight at where the target is right now.
	var dir = (target.global_position - boss.global_position).normalized()
	var wave = _make_wave(WAVE_SIZE, boss.COLOR_EXECUTE)
	wave.global_position = boss.global_position
	wave.rotation = dir.angle()
	projectiles.append({"node": wave, "target": target, "dir": dir, "hum": Sfx.play("hum", -6.0)})


# A shockwave projectile: an Area2D (detecting players) with a colored bar as its visual.
# Its local x axis is the direction of travel.
func _make_wave(wave_size: Vector2, color: Color) -> Area2D:
	var wave = Area2D.new()
	wave.top_level = true
	wave.collision_layer = 0
	wave.collision_mask = 2  # players
	wave.monitorable = false
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = wave_size
	wave.add_child(shape)
	var visual = ColorRect.new()
	visual.size = wave_size
	visual.position = -wave_size / 2
	visual.color = color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.add_child(visual)
	boss.add_child(wave)
	return wave


func _update_projectiles(delta: float):
	for proj in projectiles.duplicate():
		var node = proj.node
		node.global_position += proj.dir * WAVE_SPEED * delta
		var pos = node.global_position
		if proj.target in node.get_overlapping_bodies():
			_remove_projectile(proj)
			_contact(proj.target)
		elif pos.x < boss.ARENA_LEFT or pos.x > boss.ARENA_RIGHT or pos.y > boss.ARENA_FLOOR_Y or pos.y < 0.0:
			# Dodged rather than parried: no damage, but no counterattack either.
			_remove_projectile(proj)
			proj.target.fail_gather()


func _remove_projectile(proj):
	projectiles.erase(proj)
	proj.node.queue_free()
	Sfx.stop(proj.hum)


# Each shockwave only interacts with the player it was aimed at.
func _contact(player):
	if player.is_perfect_parry():
		player.on_perfect_parry(false)
		player.add_gather()
		parry_success.emit(player, "shockwave")
		shockwave_parried.emit(player)
		return
	player.fail_gather()
	if player.is_blocking():
		player.take_damage(BLOCKED_DAMAGE, boss.knockback_for(player, BLOCKED_KNOCKBACK), true)
	else:
		player.take_damage(WAVE_DAMAGE, boss.knockback_for(player, WAVE_KNOCKBACK))


func _launch_counters():
	for proj in projectiles.duplicate():
		_remove_projectile(proj)  # still in flight at the deadline: not parried
		proj.target.fail_gather()
	var ready = _order.filter(func(p): return p.has_full_gather())
	for p in _order:
		p.end_gather()
	if ready.is_empty():
		finish(RECOVER_TIME)
		return
	_counter_both = ready.size() >= 2
	# Every counter gets the same travel time, so speed scales with distance and
	# simultaneous counters land on the same frame.
	for p in ready:
		var node = ColorRect.new()
		node.top_level = true
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.size = Vector2(26, 26)
		node.color = p.body_color.lightened(0.4)
		boss.add_child(node)
		node.global_position = p.global_position - node.size / 2
		_counters.append({"node": node, "from": p.global_position})
	Sfx.play("counter_fire")
	phase = Phase.COUNTER_TRAVEL
	timer = COUNTER_TRAVEL_TIME


func _counters_land():
	# Read the multiplier before the counter's sync bonus is applied.
	var damage = COUNTER_DAMAGE * GameManager.damage_multiplier() * (2.0 if _counter_both else 1.0)
	counterattack_landed.emit(_counter_both)
	Sfx.play("counter_hit", 2.0 if _counter_both else 0.0)
	boss.shake(10.0 if _counter_both else 5.0)
	boss.take_damage(damage)
	if boss.hp <= 0.0:
		return
	if _counter_both:
		finish_with_stagger(COUNTER_STAGGER_TIME)
	else:
		finish(RECOVER_TIME)
