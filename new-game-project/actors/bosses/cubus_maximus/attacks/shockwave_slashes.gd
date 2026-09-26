class_name ShockwaveSlashes
extends Attack
## Red center charge -> red. Hovering at center, Cubus Maximus slashes on a fixed metronome,
## firing a shockwave at P1, P2, P1, ... (3 each). Each perfectly parried shockwave is
## "gathered"; a player who gathers all of theirs counterattacks after a short wait. Both
## counters are timed to land together for double damage and a stagger.

signal shockwave_parried(player)
signal counterattack_landed(both_players)

enum Phase { NONE, VOLLEY, VOLLEY_WAIT, COUNTER_TRAVEL }

# Slashes fire on a fixed metronome, independent of projectile travel.
const SLASH_INTERVAL = 0.8

const COLOR = Color(1.0, 0.15, 0.15)
const SLASH_COUNT = 6  # alternating P1, P2, ... so 3 each
const SPEED = 650.0
const SIZE = Vector2(14, 70)
const WAIT_TIME = 1.0
const COUNTER_TRAVEL_TIME = 0.5  # every counter takes this long, so simultaneous ones land together
const COUNTER_STAGGER_TIME = 2.0

var projectiles: Array = []  # Dictionaries: node, target, dir, hum

var _order: Array = []  # players in slash order
var _index = 0
var _counters: Array = []  # Dictionaries: node, from
var _counter_both = false
var _slash_anim = 0.0


func get_attack_name() -> String:
	return "SHOCKWAVE_SLASHES"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return boss.CENTER_CHARGE_TIME


func uses_center_charge() -> bool:
	return true


func execute():
	phase = Phase.VOLLEY
	timer = 0.0  # first slash right on the downbeat
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
			_update_slash_anim()
			if timer <= 0.0:
				_slash()
				if _index >= SLASH_COUNT:
					phase = Phase.VOLLEY_WAIT
					timer = WAIT_TIME
				else:
					timer += SLASH_INTERVAL  # metronome: keep the beat exact

		Phase.VOLLEY_WAIT:
			boss.hover()
			_update_projectiles(delta)
			_update_slash_anim()
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
	_slash_anim = SwordRelay.SWING_TIME
	_fire_shockwave(target)


func _update_slash_anim():
	_slash_anim = maxf(_slash_anim - boss.get_physics_process_delta_time(), 0.0)
	boss.set_sword_angle(lerpf(boss.SWORD_RAISED_ANGLE, boss.SWORD_FOLLOW_ANGLE,
		1.0 - _slash_anim / SwordRelay.SWING_TIME))


func _fire_shockwave(target):
	# Fired from Cubus Maximus, straight at where the target is right now.
	var dir = (target.global_position - boss.global_position).normalized()
	var wave = _make_wave(SIZE, boss.COLOR_EXECUTE)
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
		node.global_position += proj.dir * SPEED * delta
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
		player.take_damage(boss.SHOCKWAVE_DAMAGE * 0.5, boss.knockback_for(player, 150.0), true)
	else:
		player.take_damage(boss.SHOCKWAVE_DAMAGE, boss.knockback_for(player, 250.0))


func _launch_counters():
	for proj in projectiles.duplicate():
		_remove_projectile(proj)  # still in flight at the deadline: not parried
		proj.target.fail_gather()
	var ready = _order.filter(func(p): return p.has_full_gather())
	for p in _order:
		p.end_gather()
	if ready.is_empty():
		finish(0.8)
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
	var damage = boss.COUNTER_DAMAGE * GameManager.damage_multiplier() * (2.0 if _counter_both else 1.0)
	counterattack_landed.emit(_counter_both)
	Sfx.play("counter_hit", 2.0 if _counter_both else 0.0)
	boss.shake(10.0 if _counter_both else 5.0)
	boss.take_damage(damage)
	if boss.hp <= 0.0:
		return
	if _counter_both:
		finish_with_stagger(COUNTER_STAGGER_TIME)
	else:
		finish(0.8)
