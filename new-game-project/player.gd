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
const MAX_HP = 3.0
const HIT_INVULN_TIME = 0.6
const CHIP_INVULN_TIME = 0.2
const PARRY_WINDOW = 0.2  # block must be pressed at most this long before a boss attack connects
const PARRY_SPAM_LOCK = 0.3  # a block press this soon after the previous one can't parry
const DODGE_WINDOW = 0.15  # dash must be pressed at most this long before the grab connects
const ATTACK_ACTIVE_TIME = 0.15
const ATTACK_RETURN_TIME = 0.1
const ATTACK_COOLDOWN = 0.3
const ATTACK_DAMAGE = 0.5
const SWING_START_ANGLE = -1.05  # -60 degrees
const SWING_END_ANGLE = 0.52  # +30 degrees, a 90 degree arc
const GUARD_ANGLE = -1.3
const DROP_THROUGH_TIME = 0.3
const WORLD_LAYER = 1  # floor and walls
const PLATFORM_LAYER = 4  # one-way platforms live on physics layer 4
const SWORD_FLASH_TIME = 0.1
const DODGE_FLASH_TIME = 0.25
const CLANG_DURATION = 0.25

@export var player_id: int = 1  # set to 1 or 2 in the inspector

var hp = MAX_HP
var is_grabbed = false
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
var _is_dead = false
var _sword_color: Color
var _sfx: AudioStreamPlayer

@onready var body: ColorRect = $ColorRect
@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: ColorRect = $SwordPivot/Sword
@onready var sword_hitbox: Area2D = $SwordPivot/SwordHitbox


func _ready():
	body_color = body.color
	_sword_color = sword.color
	if player_id == 2:
		facing = -1.0
	_setup_audio()
	_setup_gather_label()
	GameManager.register_player(self)


func _physics_process(delta):
	_tick_timers(delta)
	if is_grabbed:
		velocity = Vector2.ZERO  # the boss carries us
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

	if Input.is_action_just_pressed(_action("down")) and is_on_floor():
		set_collision_mask_value(PLATFORM_LAYER, false)
		_drop_timer = DROP_THROUGH_TIME


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


func _process_attack():
	if _attack_timer <= 0.0 or _attack_landed or _swing_elapsed() >= ATTACK_ACTIVE_TIME:
		return
	for hit in sword_hitbox.get_overlapping_bodies():
		if hit.is_in_group("boss"):
			_attack_landed = true
			hit.take_damage(ATTACK_DAMAGE * GameManager.damage_multiplier())
			return


func _swing_elapsed() -> float:
	return ATTACK_ACTIVE_TIME + ATTACK_RETURN_TIME - _attack_timer


func _tick_timers(delta):
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_sword_flash = maxf(_sword_flash - delta, 0.0)
	_dodge_flash = maxf(_dodge_flash - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER, true)


# --- Defensive queries used by the boss at the moment its hitbox connects ---

func is_blocking() -> bool:
	return not is_grabbed and Input.is_action_pressed(_action("block"))


func is_perfect_parry() -> bool:
	return not is_grabbed and _now() - parry_press_time <= PARRY_WINDOW


func is_dodging_grab() -> bool:
	return _dash_timer > 0.0 or _now() - _dash_press_time <= DODGE_WINDOW


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
	_sword_flash = SWORD_FLASH_TIME
	_play_clang(990.0 if strong else 660.0 * (1.0 if player_id == 1 else 1.33))
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(7.0 if strong else 4.0)


func on_grab_dodged():
	_dodge_flash = DODGE_FLASH_TIME


func take_damage(amount: float, knockback = Vector2.ZERO, chip = false):
	if _is_dead or _invuln_timer > 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_invuln_timer = CHIP_INVULN_TIME if chip else HIT_INVULN_TIME
	_dash_timer = 0.0
	velocity = knockback
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


func _sword_angle() -> float:
	if _attack_timer > 0.0:
		var elapsed = _swing_elapsed()
		if elapsed < ATTACK_ACTIVE_TIME:
			return lerpf(SWING_START_ANGLE, SWING_END_ANGLE, elapsed / ATTACK_ACTIVE_TIME)
		return lerpf(SWING_END_ANGLE, 0.0, (elapsed - ATTACK_ACTIVE_TIME) / ATTACK_RETURN_TIME)
	if is_blocking():
		return GUARD_ANGLE
	return 0.0


func _update_visuals():
	sword_pivot.scale.x = facing
	sword_pivot.rotation = _sword_angle() * facing
	sword.color = Color.WHITE if _sword_flash > 0.0 else _sword_color

	var color = body_color
	if _dodge_flash > 0.0:
		color = Color(0.5, 1.0, 1.0)
	elif _dash_timer > 0.0:
		color = body_color.lightened(0.5)
	elif is_blocking():
		color = body_color.darkened(0.35)
	body.color = color

	var flicker = _invuln_timer > 0.0 and fmod(_invuln_timer, 0.12) < 0.06
	body.modulate.a = 0.4 if flicker else 1.0

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


func _setup_audio():
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.5
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = generator
	_sfx.volume_db = -4.0
	# A parry that ends the fight pauses the tree; let its clang finish anyway.
	_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx)


# Synthesized metallic clang: a click transient plus a few inharmonic partials with fast decay.
func _play_clang(pitch: float):
	_sfx.stop()
	_sfx.play()
	var playback = _sfx.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var rate = _sfx.stream.mix_rate
	var frame_count = mini(int(rate * CLANG_DURATION), playback.get_frames_available())
	var frames = PackedVector2Array()
	frames.resize(frame_count)
	for i in frame_count:
		var t = i / rate
		var sample = sin(TAU * pitch * t) * 0.5 \
			+ sin(TAU * pitch * 2.76 * t) * 0.3 \
			+ sin(TAU * pitch * 5.4 * t) * 0.2 * exp(-t * 40.0)
		sample *= exp(-t * 16.0)
		if t < 0.004:
			sample += randf_range(-1.0, 1.0) * 0.6
		frames[i] = Vector2.ONE * sample * 0.5
	playback.push_buffer(frames)
