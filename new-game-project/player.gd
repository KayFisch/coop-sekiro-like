extends CharacterBody2D

signal parry_attempted(player)
signal health_changed(player, hp)
signal damaged(player)
signal player_downed(player)
signal bled_out(player)
signal revived(player)

const SPEED = 360.0
const GRAVITY = 1800.0
const MAX_FALL_SPEED = 1100.0
const JUMP_VELOCITY = -700.0
const DOUBLE_JUMP_VELOCITY = -620.0
const JUMP_CUT = 0.5  # releasing jump early keeps this fraction of upward speed
const DASH_SPEED = 1000.0
const DASH_TIME = 0.14
const DASH_COOLDOWN = 0.6
const MAX_HP = 3
const BLEED_OUT_TIME = 4.0
const HIT_INVULN_TIME = 0.6
const REVIVE_INVULN_TIME = 1.0
const PARRY_LOCKOUT_TIME = 0.25  # pressing early while targeted costs you the start of the window
const DROP_THROUGH_TIME = 0.3
const PLATFORM_LAYER = 4  # one-way platforms live on physics layer 4
const SWORD_FLASH_TIME = 0.1
const REVIVE_FLASH_TIME = 0.4
const CLANG_DURATION = 0.25

@export var player_id: int = 1  # set to 1 or 2 in the inspector

var hp = MAX_HP
var is_downed = false
var is_grabbed = false
var bleed_timer = 0.0
var facing = 1.0
var body_color: Color

var _air_jumps = 1
var _dash_dir = 1.0
var _dash_timer = 0.0
var _dash_cooldown = 0.0
var _invuln_timer = 0.0
var _parry_lockout = 0.0
var _drop_timer = 0.0
var _sword_flash = 0.0
var _revive_flash = 0.0
var _has_bled_out = false
var _sword_color: Color
var _boss = null
var _sfx: AudioStreamPlayer

@onready var body: ColorRect = $ColorRect
@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: ColorRect = $SwordPivot/Sword


func _ready():
	body_color = body.color
	_sword_color = sword.color
	if player_id == 2:
		facing = -1.0
	_setup_audio()
	_boss = get_tree().get_first_node_in_group("boss")
	if _boss:
		_boss.parry_success.connect(_on_boss_parry_success)
	GameManager.register_player(self)


func _physics_process(delta):
	_tick_timers(delta)
	if is_grabbed:
		velocity = Vector2.ZERO  # the boss carries us
	elif is_downed:
		_process_downed(delta)
		move_and_slide()
	else:
		_process_movement(delta)
		_process_actions()
		move_and_slide()
	_update_visuals()


func _action(action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]


func _process_movement(delta):
	var direction = Input.get_axis(_action("left"), _action("right"))
	if direction != 0.0:
		facing = signf(direction)
	if is_on_floor():
		_air_jumps = 1

	if _dash_timer > 0.0:
		velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
		return

	velocity.x = direction * SPEED
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if Input.is_action_just_released(_action("jump")) and velocity.y < 0.0:
		velocity.y *= JUMP_CUT


func _process_actions():
	# Jump and parry share a key; a press only becomes a parry when the boss has a window open for us.
	if Input.is_action_just_pressed(_action("parry")) and _try_parry():
		pass
	elif Input.is_action_just_pressed(_action("jump")):
		_jump()

	if Input.is_action_just_pressed(_action("dash")) and _dash_cooldown <= 0.0:
		_dash_dir = facing
		_dash_timer = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
		velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)

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


# Returns true when the press was spent on a parry (successful or locked out).
func _try_parry() -> bool:
	if _boss == null or not is_instance_valid(_boss):
		return false
	if not _boss.is_parry_window_open(self):
		if _boss.is_threatening(self):
			_parry_lockout = PARRY_LOCKOUT_TIME
		return false
	if _parry_lockout > 0.0:
		return true
	parry_attempted.emit(self)
	return true


func _process_downed(delta):
	velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	bleed_timer = maxf(bleed_timer - delta, 0.0)
	if bleed_timer <= 0.0 and not _has_bled_out:
		_has_bled_out = true
		bled_out.emit(self)


func _tick_timers(delta):
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_parry_lockout = maxf(_parry_lockout - delta, 0.0)
	_sword_flash = maxf(_sword_flash - delta, 0.0)
	_revive_flash = maxf(_revive_flash - delta, 0.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER, true)


func take_damage(amount: int):
	if is_downed or _invuln_timer > 0.0:
		return
	hp = maxi(hp - amount, 0)
	_invuln_timer = HIT_INVULN_TIME
	_dash_timer = 0.0
	velocity = Vector2(-facing * 250.0, -350.0)
	health_changed.emit(self, hp)
	damaged.emit(self)
	if hp == 0:
		_go_down()


func _go_down():
	is_downed = true
	is_grabbed = false
	bleed_timer = BLEED_OUT_TIME
	_has_bled_out = false
	player_downed.emit(self)


func revive():
	if not is_downed:
		return
	is_downed = false
	hp = 1
	_invuln_timer = REVIVE_INVULN_TIME
	_revive_flash = REVIVE_FLASH_TIME
	health_changed.emit(self, hp)
	revived.emit(self)


func set_grabbed(grabbed: bool):
	is_grabbed = grabbed
	velocity = Vector2.ZERO
	_dash_timer = 0.0


func _on_boss_parry_success(player, kind):
	if player != self:
		return
	_sword_flash = SWORD_FLASH_TIME
	var pitch = 660.0 if player_id == 1 else 880.0
	if kind == "relay_final":
		pitch *= 1.5
	_play_clang(pitch)
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(7.0 if kind == "relay_final" else 4.0)


func _update_visuals():
	sword_pivot.scale.x = facing
	sword.visible = not is_downed
	sword.color = Color.WHITE if _sword_flash > 0.0 else _sword_color

	var color = body_color
	if is_downed:
		# Blink faster as the bleed-out timer runs down.
		var period = lerpf(0.1, 0.35, bleed_timer / BLEED_OUT_TIME)
		color = Color.RED if fmod(bleed_timer, period) < period * 0.5 else Color(0.35, 0.0, 0.0)
	elif _revive_flash > 0.0:
		color = Color(0.4, 1.0, 0.5)
	elif _dash_timer > 0.0:
		color = body_color.lightened(0.5)
	body.color = color

	var flicker = _invuln_timer > 0.0 and not is_downed and fmod(_invuln_timer, 0.12) < 0.06
	body.modulate.a = 0.4 if flicker else 1.0


func _setup_audio():
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.5
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = generator
	_sfx.volume_db = -4.0
	# The winning parry pauses the tree; let its clang finish anyway.
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
