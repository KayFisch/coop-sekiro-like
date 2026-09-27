extends CharacterBody2D

signal health_changed(player, hp)
signal damaged(player)
signal blocked(player)
signal died(player)

const SPEED = 360.0
const BLOCK_SPEED_FACTOR = 0.4
const GRAVITY = 1800.0
const MAX_FALL_SPEED = 1100.0
const JUMP_VELOCITY = -700.0
const DOUBLE_JUMP_VELOCITY = -620.0
const JUMP_CUT = 0.5  # releasing jump early keeps this fraction of upward speed
const DASH_SPEED = 1000.0
const DASH_TIME = 0.14
const DASH_COOLDOWN = 0.6
const MAX_HP = 100.0
const POTION_CHARGES = 3
const POTION_HEAL = 50.0
const DRINK_TIME = 1.5
const KNOCKBACK_TIME = 0.25  # input can't steer and potions can't be drunk while this runs
const KNOCKBACK_FRICTION = 1500.0
const HIT_INVULN_TIME = 0.6
const CHIP_INVULN_TIME = 0.2
# PARRY WINDOW (every boss attack), Sekiro-style: a block press opens a window of this length,
# and a hit connecting inside it is a perfect parry. So the press must come at most this long
# *before* contact; pressing after the hit has landed is too late. Raise for easier parries.
const PARRY_TOLERANCE = 0.10
# DODGE WINDOW (the grab), same idea: a dash press opens a window of this length, and the
# boss's hands shutting inside it is a clean dodge. Press at most this long before they shut.
const DODGE_TOLERANCE = 0.1
const PARRY_SPAM_LOCK = 0.3  # a block press this soon after the previous one can't parry
const ATTACK_ACTIVE_TIME = 0.15
const ATTACK_RETURN_TIME = 0.1
const ATTACK_COOLDOWN = 0.3
const ATTACK_DAMAGE = 10.0
const SWING_START_ANGLE = -1.05  # -60 degrees
const SWING_END_ANGLE = 0.52  # +30 degrees, a 90 degree arc
const GUARD_ANGLE = -1.571  # sword held upright...
const GUARD_OFFSET = Vector2(24, 30)  # ...in front of the body (x mirrors with facing)
const DROP_THROUGH_TIME = 0.3
const WORLD_LAYER = 1  # floor and walls
const PLATFORM_LAYER = 4  # one-way platforms live on physics layer 4
const SWORD_FLASH_TIME = 0.1
const DODGE_FLASH_TIME = 0.25
const HURT_FLASH_TIME = 0.5  # three 0.1s white flashes with 0.1s gaps
const IDLE_BOB_HEIGHT = 3.0
const IDLE_BOB_HZ = 0.6
const DASH_STRETCH = Vector2(1.3, 0.7)
const DASH_STRETCH_TIME = 0.1
const DRINK_ORB_SIZE = 14.0
# Tumbling: thrown by the boss, bouncing and sliding with no control until it settles.
const TUMBLE_MAX_TIME = 1.4
const TUMBLE_BOUNCE = 0.4  # fraction of speed kept off each floor or wall bounce
const TUMBLE_MIN_BOUNCE_SPEED = 220.0  # softer landings don't bounce, they slide
const TUMBLE_FRICTION = 700.0  # sliding along the floor
const TUMBLE_SETTLE_SPEED = 30.0  # sliding slower than this ends the tumble
const TUMBLE_SPIN = 0.012  # body rotation per pixel travelled sideways
const TUMBLE_IMPACT_SHAKE = 10.0
# Hands: same proportions as the boss's (a fifth of the body, gripping the hilt).
const HAND_SIZE_RATIO = 0.2
const HAND_GRIPS = [0.075, 0.275]  # where each hand holds the sword, as a fraction of its length
const HAND_DARKEN = 0.25

@export var player_id: int = 1  # set to 1 or 2 in the inspector
@export var player_color = Color(0.25, 0.5, 1)  # body; P1 blue, P2 orange
@export var sword_color = Color(0.62, 0.8, 1)  # a lighter shade of the body color

var hp = MAX_HP
var potions = POTION_CHARGES
var is_grabbed = false
var is_clashing = false  # blades locked with the boss, held in place
var invincible = false  # testing: hits still land (flash, knockback) but take no health
var facing = 1.0
var body_color: Color
var parry_press_time = -100.0  # when the last block press that can still parry happened
var gathered = 0  # shockwaves parried in the current volley

var _gather_needed = 0  # 0 while no volley is running
var _gather_failed = false
var _gather_label: Label

var _air_jumps = 1
var _dash_dir = 1.0
var _dash_timer = 0.0
var _dash_cooldown = 0.0
var _dash_press_time = -100.0
var _invuln_timer = 0.0
var _drop_timer = 0.0
var _sword_flash = 0.0
var _dodge_flash = 0.0
var _last_block_press = -100.0
var _attack_timer = 0.0  # counts down through the swing and its return
var _attack_cooldown = 0.0
var _attack_landed = false
var _knockback_timer = 0.0
var _stagger_timer = 0.0  # > 0 while reeling from a hit: no movement, no input
var _tumble_timer = 0.0  # > 0 while tumbling (see tumble())
var _tumble_damage = 0.0  # dealt when the tumble first hits the floor; 0 once dealt
var _clash_overhead = true  # grand slash clash: sword flat overhead; otherwise level, at the boss
var _drink_timer = 0.0  # > 0 while drinking a potion
var _drink_bar: ColorRect
var _drink_orb: Panel
var _drink_sound = null  # Sfx handle, cut short if the drink is interrupted
var _hurt_flash = 0.0
var _bob_time = 0.0
var _body_rest = Vector2.ZERO
var _stretch_tween: Tween
var _is_dead = false
var _sword_color: Color
var _hands: Array = []  # [ColorRect, ColorRect]

@onready var body: ColorRect = $ColorRect
@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: ColorRect = $SwordPivot/Sword
@onready var sword_hitbox: Area2D = $SwordPivot/SwordHitbox


func _ready():
	body.color = player_color
	sword.color = sword_color
	body_color = player_color
	_sword_color = sword_color
	if player_id == 2:
		facing = -1.0
	_body_rest = body.position
	body.pivot_offset = body.size / 2  # stretch around the center
	_setup_gather_label()
	_setup_drink_bar()
	_setup_hands()
	GameManager.register_player(self)


func _physics_process(delta):
	_tick_timers(delta)
	if is_grabbed or is_clashing:
		velocity = Vector2.ZERO  # carried by the boss, or braced holding him back
	elif is_tumbling():
		_process_tumble(delta)
	elif is_staggered():
		velocity.x = 0.0
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		move_and_slide()
	elif is_drinking():
		_process_drinking(delta)
		move_and_slide()
	else:
		_process_movement(delta)
		_process_actions()
		move_and_slide()
	_process_attack()
	_update_visuals()


func _action(action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process_movement(delta):
	var direction = Input.get_axis(_action("left"), _action("right"))
	if direction != 0.0:
		facing = signf(direction)
	if is_on_floor():
		_air_jumps = 1

	if _dash_timer > 0.0:
		velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
		return

	if _knockback_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
	else:
		var speed = SPEED * (BLOCK_SPEED_FACTOR if is_blocking() else 1.0)
		velocity.x = direction * speed
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if Input.is_action_just_released(_action("jump")) and velocity.y < 0.0:
		velocity.y *= JUMP_CUT


func _process_actions():
	if Input.is_action_just_pressed(_action("jump")):
		_jump()

	# Dashes always go left or right, independent of facing.
	if Input.is_action_just_pressed(_action("dash_left")):
		_start_dash(-1.0)
	elif Input.is_action_just_pressed(_action("dash_right")):
		_start_dash(1.0)

	if Input.is_action_just_pressed(_action("block")):
		var now = _now()
		# Mashing doesn't parry: a press too soon after the previous one isn't a parry attempt.
		parry_press_time = now if now - _last_block_press >= PARRY_SPAM_LOCK else -100.0
		_last_block_press = now

	if Input.is_action_just_pressed(_action("attack")) and _attack_cooldown <= 0.0 and not is_blocking():
		_attack_timer = ATTACK_ACTIVE_TIME + ATTACK_RETURN_TIME
		_attack_cooldown = ATTACK_COOLDOWN
		_attack_landed = false
		Sfx.play("slash", -4.0)

	if Input.is_action_just_pressed(_action("down")) and is_on_floor():
		set_collision_mask_value(PLATFORM_LAYER, false)
		_drop_timer = DROP_THROUGH_TIME

	if Input.is_action_just_pressed(_action("potion")) and potions > 0 and _knockback_timer <= 0.0:
		_drink_timer = DRINK_TIME
		_dash_timer = 0.0
		_attack_timer = 0.0
		velocity.x = 0.0
		_drink_sound = Sfx.play("drink", -3.0)  # same length as the drink


# --- Potions ------------------------------------------------------------------

func is_drinking() -> bool:
	return _drink_timer > 0.0


# Rooted in place while drinking; gravity still applies and hits still land.
func _process_drinking(delta):
	velocity.x = 0.0
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	_drink_timer = maxf(_drink_timer - delta, 0.0)
	if _drink_timer <= 0.0:
		potions -= 1
		hp = minf(hp + POTION_HEAL, MAX_HP)
		health_changed.emit(self, hp)


# An interrupted drink still uses up the charge.
func _cancel_drink():
	if is_drinking():
		_drink_timer = 0.0
		potions -= 1
		Sfx.stop(_drink_sound)


func _jump():
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
	elif _air_jumps > 0:
		_air_jumps -= 1
		velocity.y = DOUBLE_JUMP_VELOCITY
	else:
		return
	_dash_timer = 0.0  # jumping cancels a dash


func _start_dash(direction: float):
	if _dash_cooldown > 0.0:
		return
	_dash_dir = direction
	_dash_timer = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	_dash_press_time = _now()
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	# Squash-and-stretch: snap wide and short, then spring back.
	if _stretch_tween:
		_stretch_tween.kill()
	body.scale = DASH_STRETCH
	_stretch_tween = create_tween()
	_stretch_tween.tween_property(body, "scale", Vector2.ONE, DASH_STRETCH_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process_attack():
	if _attack_timer <= 0.0 or _attack_landed or _swing_elapsed() >= ATTACK_ACTIVE_TIME:
		return
	for hit in sword_hitbox.get_overlapping_bodies():
		if hit.is_in_group("boss"):
			_attack_landed = true
			hit.take_damage(ATTACK_DAMAGE * GameManager.damage_multiplier(), self)
			return


func _swing_elapsed() -> float:
	return ATTACK_ACTIVE_TIME + ATTACK_RETURN_TIME - _attack_timer


func _tick_timers(delta):
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_sword_flash = maxf(_sword_flash - delta, 0.0)
	_dodge_flash = maxf(_dodge_flash - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_knockback_timer = maxf(_knockback_timer - delta, 0.0)
	_stagger_timer = maxf(_stagger_timer - delta, 0.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER, true)


# --- Defensive queries used by the boss at the moment its hitbox connects ---

func is_blocking() -> bool:
	return not is_grabbed and not is_drinking() and not is_staggered() and not is_tumbling() \
		and Input.is_action_pressed(_action("block"))


func is_perfect_parry() -> bool:
	return not is_grabbed and not is_drinking() and not is_staggered() and not is_tumbling() \
		and _now() - parry_press_time <= PARRY_TOLERANCE


func is_staggered() -> bool:
	return _stagger_timer > 0.0


func is_perfect_dodge() -> bool:
	return not is_grabbed and _now() - _dash_press_time <= DODGE_TOLERANCE


# Standing on the arena floor itself, not on a one-way platform.
func is_on_main_floor() -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collision.get_normal().y < -0.7 and collider is CollisionObject2D \
				and collider.get_collision_layer_value(WORLD_LAYER):
			return true
	return false


# --- Shockwave gathering: all-or-nothing per volley --------------------------

func start_gather(needed: int):
	gathered = 0
	_gather_needed = needed
	_gather_failed = false


func add_gather():
	if not _gather_failed:
		gathered += 1


func fail_gather():
	gathered = 0
	_gather_failed = true


func has_full_gather() -> bool:
	return _gather_needed > 0 and not _gather_failed and gathered >= _gather_needed


func end_gather():
	_gather_needed = 0
	gathered = 0
	_gather_failed = false


func on_perfect_parry(strong: bool):
	parry_press_time = -100.0  # one press parries one hit
	_last_block_press = -100.0  # a landed parry isn't mashing: the next press may parry at once
	_sword_flash = SWORD_FLASH_TIME
	Sfx.play("parry_strong" if strong else "parry")
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(7.0 if strong else 4.0)


func on_grab_dodged():
	_dodge_flash = DODGE_FLASH_TIME


# ignore_invuln: for hits chained faster than the post-hit invulnerability (the triple slash).
func take_damage(amount: float, knockback = Vector2.ZERO, chip = false, ignore_invuln = false):
	if _is_dead or (_invuln_timer > 0.0 and not ignore_invuln):
		return
	if not invincible:
		hp = maxf(hp - amount, 0.0)
	_invuln_timer = CHIP_INVULN_TIME if chip else HIT_INVULN_TIME
	_dash_timer = 0.0
	_cancel_drink()
	_hurt_flash = HURT_FLASH_TIME
	velocity = knockback
	if chip:
		Sfx.play("chip")
	else:
		Sfx.play("hurt")
	if knockback != Vector2.ZERO:
		_knockback_timer = KNOCKBACK_TIME
		if not chip:
			Sfx.play_delayed("knockback", 0.06, -4.0)  # the tumble, just behind the impact
	health_changed.emit(self, hp)
	if chip:
		blocked.emit(self)
	else:
		damaged.emit(self)
	if hp <= 0.0:
		_is_dead = true
		died.emit(self)


func set_grabbed(grabbed: bool):
	is_grabbed = grabbed
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	if grabbed:
		_cancel_drink()  # being carried off interrupts the drink like a hit would


# Reeling from a hit: can't move, block, parry or act until it wears off.
func stagger(duration: float):
	_stagger_timer = maxf(_stagger_timer, duration)
	velocity.x = 0.0
	_dash_timer = 0.0
	_attack_timer = 0.0


func set_clashing(clashing: bool, overhead = true):
	is_clashing = clashing
	_clash_overhead = overhead
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	_attack_timer = 0.0


func apply_knockback(push: Vector2):
	velocity = push
	_knockback_timer = KNOCKBACK_TIME


# Thrown: flies, bounces off the floor and walls and slides to a stop, with no control until it
# settles. impact_damage (if any) lands when the floor is first hit.
func tumble(launch: Vector2, impact_damage = 0.0):
	velocity = launch
	_tumble_timer = TUMBLE_MAX_TIME
	_tumble_damage = impact_damage
	_dash_timer = 0.0
	_attack_timer = 0.0
	_knockback_timer = 0.0
	_cancel_drink()


func is_tumbling() -> bool:
	return _tumble_timer > 0.0


func _process_tumble(delta):
	_tumble_timer = maxf(_tumble_timer - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, TUMBLE_FRICTION * delta)
	var before = velocity
	move_and_slide()
	body.rotation += before.x * delta * TUMBLE_SPIN

	var hit_floor = is_on_floor() and before.y > 0.0
	if hit_floor and before.y >= TUMBLE_MIN_BOUNCE_SPEED:
		velocity = Vector2(before.x, -before.y * TUMBLE_BOUNCE)
	if is_on_wall():
		velocity.x = -before.x * TUMBLE_BOUNCE
	if hit_floor and _tumble_damage > 0.0:
		var damage = _tumble_damage
		_tumble_damage = 0.0
		take_damage(damage, velocity, false, true)  # keeps the bounce going
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("shake"):
			cam.shake(TUMBLE_IMPACT_SHAKE)

	var settled = is_on_floor() and velocity.y >= 0.0 and absf(velocity.x) < TUMBLE_SETTLE_SPEED
	if settled or _tumble_timer <= 0.0 or _is_dead:
		_tumble_timer = 0.0
		body.rotation = 0.0


func _sword_angle() -> float:
	if is_clashing:
		return 0.0  # held flat against the boss's blade
	if _attack_timer > 0.0:
		var elapsed = _swing_elapsed()
		if elapsed < ATTACK_ACTIVE_TIME:
			return lerpf(SWING_START_ANGLE, SWING_END_ANGLE, elapsed / ATTACK_ACTIVE_TIME)
		return lerpf(SWING_END_ANGLE, 0.0, (elapsed - ATTACK_ACTIVE_TIME) / ATTACK_RETURN_TIME)
	if is_blocking():
		return GUARD_ANGLE
	return 0.0


func _update_visuals():
	# Idle bob while standing still on the ground; ease back to rest otherwise.
	var bob = 0.0
	if is_on_floor() and absf(velocity.x) < 1.0 and not is_grabbed:
		_bob_time += get_physics_process_delta_time()
		# Rises from rest and back, never dipping into the floor.
		bob = -IDLE_BOB_HEIGHT * (0.5 - 0.5 * cos(_bob_time * TAU * IDLE_BOB_HZ))
	else:
		_bob_time = 0.0
	body.position.y = lerpf(body.position.y, _body_rest.y + bob, 0.3)
	# Straining to hold the boss back: tremble.
	body.position.x = _body_rest.x + (randf_range(-2.0, 2.0) if is_clashing else 0.0)

	# Guard pose: sword upright in front of the body while blocking; in a clash, flat overhead
	# (grand slash) or level against the boss's blade (triple slash); otherwise held at the side.
	var sword_offset = Vector2(0.0, body.position.y - _body_rest.y)
	if is_clashing:
		sword_offset = Vector2(-38.0 * facing, -28.0) if _clash_overhead else Vector2(0.0, -4.0)
	elif is_blocking() and _attack_timer <= 0.0:
		sword_offset = Vector2(GUARD_OFFSET.x * facing, GUARD_OFFSET.y)
	sword_pivot.position = sword_pivot.position.lerp(sword_offset, 0.4)
	sword_pivot.scale.x = facing
	sword_pivot.rotation = _sword_angle() * facing
	sword.color = Color.WHITE if _sword_flash > 0.0 else _sword_color

	var color = body_color
	if _hurt_flash > 0.0 and fmod(HURT_FLASH_TIME - _hurt_flash, 0.2) < 0.1:
		color = Color.WHITE
	elif _dodge_flash > 0.0:
		color = Color(0.5, 1.0, 1.0)
	elif _dash_timer > 0.0:
		color = body_color.lightened(0.5)
	elif is_clashing:
		color = body_color.lerp(Color(1.0, 0.8, 0.3), 0.35 + 0.25 * sin(_now() * 30.0))
	elif is_staggered():
		color = body_color.lerp(Color(0.6, 0.6, 0.6), 0.6)
	elif is_blocking():
		color = body_color.darkened(0.3)
	body.color = color
	_update_hands()

	# Drinking cues: a bar under the feet and an orb over the head, both shrinking with the timer.
	var drink_left = _drink_timer / DRINK_TIME
	_drink_bar.visible = is_drinking()
	_drink_orb.visible = is_drinking()
	if is_drinking():
		var width = 44.0 * drink_left
		_drink_bar.size.x = width
		_drink_bar.position.x = -width / 2
		var d = maxf(DRINK_ORB_SIZE * drink_left, 2.0)
		_drink_orb.size = Vector2(d, d)
		_drink_orb.position = Vector2(-d / 2, -40.0 - d / 2)

	_gather_label.visible = _gather_needed > 0
	if _gather_label.visible:
		_gather_label.text = "%d/%d" % [gathered, _gather_needed]
		if _gather_failed:
			_gather_label.modulate = Color(0.5, 0.5, 0.5, 0.7)
		elif has_full_gather():
			# Counter ready: pulse between the player's color and white.
			var pulse = 0.5 + 0.5 * sin(_now() * 20.0)
			_gather_label.modulate = body_color.lerp(Color.WHITE, pulse)
		else:
			_gather_label.modulate = body_color.lerp(Color.WHITE, 0.5)


func _setup_drink_bar():
	_drink_bar = ColorRect.new()
	_drink_bar.size = Vector2(44, 5)
	_drink_bar.position = Vector2(-22, 24)
	_drink_bar.color = Color(0.4, 1.0, 0.55)
	_drink_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drink_bar.visible = false
	add_child(_drink_bar)

	var style = StyleBoxFlat.new()
	style.bg_color = _drink_bar.color
	style.set_corner_radius_all(int(DRINK_ORB_SIZE))  # clamps to a circle at any size
	_drink_orb = Panel.new()
	_drink_orb.add_theme_stylebox_override("panel", style)
	_drink_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drink_orb.visible = false
	add_child(_drink_orb)


func _setup_hands():
	for i in 2:
		var hand = ColorRect.new()
		hand.size = body.size * HAND_SIZE_RATIO
		hand.pivot_offset = hand.size / 2
		hand.top_level = true
		hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hand)
		_hands.append(hand)
	_update_hands()


# The hands grip the hilt and follow every swing and guard.
func _update_hands():
	var hilt = sword.position.x
	var length = sword.size.x
	var blade_y = sword.position.y + sword.size.y / 2
	for i in _hands.size():
		var hand = _hands[i]
		var grip = sword_pivot.to_global(Vector2(hilt + length * HAND_GRIPS[i], blade_y))
		hand.global_position = grip - hand.size / 2
		hand.rotation = sword_pivot.rotation
		hand.color = body.color.darkened(HAND_DARKEN)


func _setup_gather_label():
	_gather_label = Label.new()
	_gather_label.size = Vector2(60, 20)
	_gather_label.position = Vector2(-30, -82)  # above the boss's target marker
	_gather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gather_label.add_theme_font_size_override("font_size", 16)
	_gather_label.add_theme_constant_override("outline_size", 4)
	_gather_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_gather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gather_label.visible = false
	add_child(_gather_label)
