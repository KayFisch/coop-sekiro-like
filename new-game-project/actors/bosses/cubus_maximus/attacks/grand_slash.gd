class_name GrandSlash
extends Attack
## Blue center charge -> red. Cubus Maximus rises over the arena's center and lunges straight
## down. Players parry him directly: the first parry only holds him in a clash, and the
## partner's parry during that window overpowers him (damage + stagger). If the partner
## doesn't make it, he breaks free, drives his sword into the center, and a red, unblockable
## shockwave ring expands from the impact.

signal grand_slash_parried

enum Phase { NONE, GRAND_RISE, GRAND_DIVE, GRAND_CLASH, GRAND_IMPACT }

const COLOR = Color(0.25, 0.45, 1.0)
const COLOR_CLASH = Color(1.0, 0.78, 0.2)  # held by one player: partner, join in!
const COLOR_OVERPOWER = Color(1.0, 1.0, 0.85)  # both players together

const TOP_Y = 90.0  # height at the top of the rise
const RISE_TIME = 0.35
const DIVE_SPEED = 750.0  # the downward lunge the players parry
const BREAK_FREE_SPEED = 1400.0  # finishing the lunge after the hold breaks
const CLASH_TIME = 1.5  # second player's window, starting at the first parry
const COUNTER_STAGGER_TIME = 1.5
const COUNTER_KNOCK = Vector2(0, -900)  # overpowered: thrown back up off the lunge
const RING_SPEED = 650.0
const RING_MAX_RADIUS = 520.0  # the far corners of the arena are out of reach
const RING_WIDTH = 14.0

var ring: Node2D  # the failure shockwave

var _rise_from = Vector2.ZERO
var _dive_speed = DIVE_SPEED
var _resolved: Array = []  # players the lunge has already dealt with
var _holder = null  # the player holding Cubus Maximus in the clash
var _helper = null  # the partner who has to come and parry
var _clash_bar: ColorRect
var _spark_timer = 0.0
var _ring_hit: Array = []
var _drone = null  # Sfx handles
var _grind = null


func get_attack_name() -> String:
	return "GRAND_SLASH"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return boss.CENTER_CHARGE_TIME


func uses_center_charge() -> bool:
	return true


func update_telegraph(progress: float):
	# The sword swells and rises as the grand slash winds up.
	boss.sword_scale = Vector2.ONE * lerpf(1.0, boss.GRAND_SWORD_SCALE, progress)
	boss.set_sword_angle(lerpf(boss.SWORD_REST_ANGLE, boss.SWORD_RAISED_ANGLE, progress))


func execute():
	phase = Phase.GRAND_RISE
	timer = RISE_TIME
	_rise_from = boss.global_position


func update(delta: float):
	timer -= delta
	match phase:
		Phase.GRAND_RISE:
			# Up above the arena's center, turning the sword point-down.
			var t = 1.0 - clampf(timer / RISE_TIME, 0.0, 1.0)
			boss.global_position = _rise_from.lerp(Vector2(boss.home_position.x, TOP_Y), ease(t, 0.5))
			boss.set_sword_angle(lerpf(boss.SWORD_RAISED_ANGLE, PI / 2, t))
			if timer <= 0.0:
				_start_dive()

		Phase.GRAND_DIVE:
			boss.global_position.y += _dive_speed * delta
			# The players parry Cubus Maximus himself: his blade or his body reaching them.
			for p in _contacts():
				if not p in _resolved:
					_resolved.append(p)
					_dive_contact(p)
					if phase != Phase.GRAND_DIVE:
						break  # a parry turned this into a clash
			if phase == Phase.GRAND_DIVE and boss.global_position.y >= _dive_end_y():
				_impact()

		Phase.GRAND_CLASH:
			_process_clash(delta)

		Phase.GRAND_IMPACT:
			_update_ring(delta)


func get_marker(_telegraphing: bool):
	if phase == Phase.GRAND_CLASH:
		# "Your turn": point at the partner who has to come and parry the held boss.
		return {"who": _helper, "color": COLOR_CLASH if fmod(boss.anim_time, 0.2) < 0.1 else Color.WHITE}
	return null


func cleanup():
	Sfx.stop(_drone)
	_drone = null
	_end_clash()  # never leave a player locked in a clash
	_holder = null
	_helper = null
	if ring:
		# Let the failure shockwave fade where it stopped rather than blink away.
		var fading = ring
		fading.create_tween().tween_property(fading, "modulate:a", 0.0, 0.25).finished.connect(fading.queue_free)
		ring = null


# --- The lunge ---

func _start_dive():
	phase = Phase.GRAND_DIVE
	_dive_speed = DIVE_SPEED
	_resolved.clear()
	_holder = null
	_helper = null
	_drone = Sfx.play("grand_drone")


# Height at which the sword tip meets the floor.
func _dive_end_y() -> float:
	return boss.ARENA_FLOOR_Y - boss.SWORD_REACH * boss.sword_scale.y


# Players touching Cubus Maximus's blade or body right now.
func _contacts() -> Array:
	var found = []
	for area in [boss.sword_hitbox, boss.grab_area]:
		for b in area.get_overlapping_bodies():
			if b.is_in_group("players") and not b in found:
				found.append(b)
	return found


func _dive_contact(player):
	if player.is_perfect_parry():
		_start_clash(player)
	elif player.is_blocking():
		player.take_damage(boss.CHIP_DAMAGE, boss.knockback_for(player, 200.0), true)
	else:
		player.take_damage(boss.GRAND_DAMAGE, boss.knockback_for(player, 350.0))
		boss.shake(7.0)


# --- The clash: one player holding Cubus Maximus back ---

func _start_clash(holder):
	phase = Phase.GRAND_CLASH
	timer = CLASH_TIME
	_holder = holder
	_helper = boss.partner_of(holder)
	holder.on_perfect_parry(false)
	holder.set_clashing(true)
	parry_success.emit(holder, "grand_hold")
	Sfx.stop(_drone)
	_drone = null
	_grind = Sfx.play("clash_grind", -2.0)
	boss.shake(8.0)
	_spawn_sparks(_clash_point(), 14, COLOR_CLASH)
	# Countdown bar over him: how long the holder can keep him there.
	_clash_bar = ColorRect.new()
	_clash_bar.top_level = true
	_clash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clash_bar.color = COLOR_CLASH
	boss.add_child(_clash_bar)


func _process_clash(delta: float):
	var left = clampf(timer / CLASH_TIME, 0.0, 1.0)
	# Straining against the holder: shaking, flashing gold, throwing sparks.
	var flash = fmod(boss.anim_time, 0.1) < 0.05
	boss.body.color = COLOR_CLASH if flash else Color.WHITE
	boss.body.position = boss.body_rest + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	boss.set_glow(COLOR_CLASH, 0.35 + 0.3 * (1.0 - left))
	_clash_bar.size = Vector2(120.0 * left, 6.0)
	_clash_bar.global_position = boss.global_position + Vector2(-60.0, -62.0)
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = 0.05
		_spawn_sparks(_clash_point(), 2, COLOR_CLASH)
		boss.shake(1.5)

	if _helper and _helper in _contacts() and _helper.is_perfect_parry():
		_overpowered(_helper)
	elif timer <= 0.0:
		_break_free()


# Where the blade meets the holder's guard.
func _clash_point() -> Vector2:
	if _holder:
		return _holder.global_position + Vector2(0.0, -20.0)
	return boss.global_position


func _end_clash():
	Sfx.stop(_grind)
	_grind = null
	if _clash_bar:
		_clash_bar.queue_free()
		_clash_bar = null
	if _holder and is_instance_valid(_holder):
		_holder.set_clashing(false)
	boss.body.position = boss.body_rest


# Both players together: the lunge is thrown back and Cubus Maximus takes the hit.
func _overpowered(helper):
	var point = _clash_point()
	helper.on_perfect_parry(true)
	parry_success.emit(helper, "grand_overpower")
	_end_clash()
	# Read the multiplier before the counter's sync bonus is applied.
	var damage = boss.GRAND_COUNTER_DAMAGE * GameManager.damage_multiplier()
	grand_slash_parried.emit()
	Sfx.play("counter_hit", 3.0)
	boss.shake(14.0)
	_spawn_sparks(point, 40, COLOR_OVERPOWER)
	_spawn_ring_burst(point, COLOR_OVERPOWER, 300.0, 0.4)
	_spawn_ring_burst(point, COLOR_CLASH, 180.0, 0.3)
	boss.body.color = COLOR_OVERPOWER
	boss.take_damage(damage)
	if boss.hp > 0.0:
		finish_with_stagger(COUNTER_STAGGER_TIME, false, COUNTER_KNOCK)


# The partner didn't make it: the hold breaks and the lunge finishes, faster.
func _break_free():
	var holder = _holder
	_end_clash()
	var side = signf(holder.global_position.x - boss.global_position.x)
	holder.apply_knockback(Vector2((side if side != 0.0 else 1.0) * 450.0, -300.0))
	Sfx.play("knockback")
	boss.shake(6.0)
	_resolved = players.duplicate()  # the lunge is past them now
	boss.body.color = boss.COLOR_EXECUTE
	boss.set_glow(boss.COLOR_EXECUTE, 0.4)
	phase = Phase.GRAND_DIVE
	_dive_speed = BREAK_FREE_SPEED


# --- Failure: the sword hits the center and a red shockwave ring expands ---

func _impact():
	boss.global_position.y = _dive_end_y()
	phase = Phase.GRAND_IMPACT
	Sfx.stop(_drone)
	_drone = null
	Sfx.play("grand_impact", 2.0)
	boss.shake(12.0)
	var center = Vector2(boss.global_position.x, boss.ARENA_FLOOR_Y)
	_spawn_sparks(center, 24, boss.COLOR_EXECUTE)
	_ring_hit.clear()
	ring = _make_ring(center, boss.COLOR_EXECUTE, true)


func _update_ring(delta: float):
	var radius = ring.get_meta("radius") + RING_SPEED * delta
	ring.set_meta("radius", radius)
	ring.queue_redraw()
	# Unblockable: blocking and parrying do nothing. Only distance or a well-timed dash through it.
	for p in players:
		if p in _ring_hit:
			continue
		var d = p.global_position.distance_to(ring.global_position)
		if absf(d - radius) <= RING_WIDTH / 2.0 + 20.0:
			_ring_hit.append(p)
			if not p.is_dodging_grab():
				var out = (p.global_position - ring.global_position).normalized()
				p.take_damage(boss.GRAND_DAMAGE, Vector2(out.x * 400.0, -300.0))
	if radius >= RING_MAX_RADIUS:
		finish(0.8)


# --- Effects ---

# A circle outline drawn in code (upper half only when it sits on the floor).
func _make_ring(center: Vector2, color: Color, upper_half: bool) -> Node2D:
	var new_ring = Node2D.new()
	new_ring.top_level = true
	new_ring.set_meta("radius", 0.0)
	var from_angle = PI if upper_half else 0.0
	new_ring.draw.connect(func():
		new_ring.draw_arc(Vector2.ZERO, new_ring.get_meta("radius"), from_angle, TAU, 96, color, RING_WIDTH, true))
	boss.add_child(new_ring)
	new_ring.global_position = center
	return new_ring


# A self-animating ring that expands and fades (no gameplay effect).
func _spawn_ring_burst(center: Vector2, color: Color, max_radius: float, duration: float):
	var burst = _make_ring(center, color, false)
	var tween = burst.create_tween().set_parallel()
	tween.tween_method(func(r): burst.set_meta("radius", r); burst.queue_redraw(), 10.0, max_radius, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(burst, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(burst.queue_free)


func _spawn_sparks(point: Vector2, count: int, color: Color):
	for i in count:
		var spark = ColorRect.new()
		spark.top_level = true
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.size = Vector2(4, 4)
		spark.color = color.lerp(Color.WHITE, randf() * 0.6)
		boss.add_child(spark)
		spark.global_position = point
		var fly = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0)
		var tween = spark.create_tween().set_parallel()
		tween.tween_property(spark, "global_position", point + fly, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(spark.queue_free)
