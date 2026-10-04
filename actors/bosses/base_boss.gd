class_name BaseBoss
extends CharacterBody2D
## Shared boss behavior: health, the attack state machine, the stagger, the center-charge
## telegraph, and the movement/animation helpers attacks use. A concrete boss supplies its
## attacks by overriding get_attack_pool(), and how often each comes with get_attack_weights().
## Anything beyond the body (a sword, hands, a chain) belongs to the concrete boss, which poses
## it through the pose hooks (reset_pose(), tint_weapon(), _update_pose()).
##
## State machine: IDLE -> TELEGRAPH -> ATTACKING -> RECOVER -> IDLE, with STAGGER in place of
## RECOVER when an attack ends in a stagger. All attack-specific logic lives in the Attack objects.

signal parry_success(player, kind)  # forwarded from whichever attack produced it
signal sync_event(kind)  # a coordinated success; GameManager turns it into sync (see SYNC_GAINS)
signal health_changed(hp, max_hp)
signal defeated

enum State { IDLE, TELEGRAPH, ATTACKING, RECOVER, STAGGER }

# --- Tuning (shared by every boss) ---
const FIRST_ATTACK_DELAY = 2.0  # grace period at the start of the fight
const IDLE_PAUSE_MIN = 0.25  # pause between attacks, picked at random in this range
const IDLE_PAUSE_MAX = 0.5
const STAGGER_RECOVER_TIME = 0.6  # getting back up after a stagger, before the idle pause

const ARENA_LEFT = 24.0
const ARENA_RIGHT = 1128.0
const ARENA_FLOOR_Y = 600.0

# Center charge: attacks that use it fly the boss to mid-arena and pulse their color there.
const CENTER_HOVER_HEIGHT = 310.0  # above the boss's floor position

const STAGGER_TILT = 0.087  # radians, about 5 degrees
const TUMBLE_TILT = 0.2
const KNOCK_MIN_Y = 90.0  # a knocked-back stagger never carries the boss above this
const KNOCK_DECELERATION = 2400.0
const STAGGER_SINK_SPEED = 900.0

const COLOR_IDLE = Color(0.27, 0.27, 0.3)
const COLOR_EXECUTE = Color.RED
const COLOR_STAGGER = Color(0.55, 0.55, 0.62)
const COLOR_DEAD = Color(0.25, 0.25, 0.3)

var state = State.IDLE
var timer = FIRST_ATTACK_DELAY
var target_player = null
var attack_pool: Array = []
var current_attack: Attack = null
var hp = 0.0
var home_position = Vector2.ZERO
var facing = 1.0
var anim_time = 0.0
var body_rest = Vector2.ZERO

var _last_attack: Attack = null
var _tumbling = false
var _stagger_knock = Vector2.ZERO
var _marker: ColorRect
var _pop_tween: Tween

@onready var body: ColorRect = $ColorRect
@onready var glow: ColorRect = $Glow


# --- Overridden by concrete bosses ---

func get_max_hp() -> float:
	return 100.0


# Shown over the boss health bar.
func get_display_name() -> String:
	return "BOSS"


# Fresh Attack instances this boss can use. Called once, in _ready().
func get_attack_pool() -> Array:
	return []


# Relative odds per attack name (see get_attack_name()); 0, or a missing name, disables it.
func get_attack_weights() -> Dictionary:
	return {}


# For testing: a player_id (1 or 2) makes the boss target only that player and leaves the
# other unable to lose health. 0 targets both as normal.
func get_forced_target_id() -> int:
	return 0


# Attack names that may be picked twice in a row.
func get_repeatable_attacks() -> Array:
	return []


# How long he idles between two attacks, once recovered from the first.
func get_idle_pause() -> float:
	return randf_range(IDLE_PAUSE_MIN, IDLE_PAUSE_MAX)


# A weighted random pick. The last attack isn't repeated unless it's repeatable or it's the
# only one enabled.
func pick_attack() -> Attack:
	var weights = get_attack_weights()
	var options = attack_pool.filter(func(a): return weights.get(a.get_attack_name(), 0.0) > 0.0)
	if options.is_empty():
		push_warning("%s: no attack has a weight above 0; picking from all of them." % name)
		return attack_pool.pick_random()
	if options.size() > 1 and _last_attack in options \
			and not _last_attack.get_attack_name() in get_repeatable_attacks():
		options.erase(_last_attack)
	var total = 0.0
	for attack in options:
		total += weights[attack.get_attack_name()]
	var roll = randf() * total
	_last_attack = options.back()
	for attack in options:
		roll -= weights[attack.get_attack_name()]
		if roll < 0.0:
			_last_attack = attack
			break
	return _last_attack


# --- Pose hooks: a boss with a sword, hands or a chain poses them here ---

# Called once in _ready(), before the first reset_pose().
func _setup_pose():
	pass


# Back to the resting pose: after every attack and stagger, and on death.
func reset_pose():
	pass


# The telegraph and execute colors, for whatever the boss carries (the body is colored already).
func tint_weapon(_color: Color):
	pass


# Called every physics frame, after the state machine.
func _update_pose():
	pass


# The zone players can't enter (see _keep_out_of_boss() in player.gd), in world coordinates;
# an empty Rect2 for none. It must move with the boss.
func body_block() -> Rect2:
	return Rect2()


# True for a boss the players keep facing, whichever way they walk (see _process_movement() in
# player.gd): one that changes sides on them.
func holds_facing() -> bool:
	return false


# Where the center charge floats.
func hover_point() -> Vector2:
	return Vector2(home_position.x, home_position.y - CENTER_HOVER_HEIGHT)


# Movement between attacks: drifting home while idle and recovering, and the stagger's rocking.
func _idle_motion(_delta: float):
	global_position = global_position.lerp(home_position, 0.05)


func _recover_motion(_delta: float):
	global_position = global_position.lerp(home_position, 0.08)


func _stagger_motion(delta: float):
	# Rock back and forth; a dodged grab's tumble rocks harder.
	var tilt = TUMBLE_TILT if _tumbling else STAGGER_TILT
	body.rotation = tilt * sin(anim_time * 12.0)
	# A knock (the overpowered grand slash) carries the boss off first, then it sinks home.
	if _stagger_knock != Vector2.ZERO:
		global_position += _stagger_knock * delta
		global_position.y = clampf(global_position.y, KNOCK_MIN_Y, ARENA_FLOOR_Y)
		_stagger_knock = _stagger_knock.move_toward(Vector2.ZERO, KNOCK_DECELERATION * delta)
	else:
		global_position.y = move_toward(global_position.y, home_position.y, STAGGER_SINK_SPEED * delta)


# --- Lifecycle ---

func _ready():
	hp = get_max_hp()
	home_position = global_position
	body_rest = body.position
	body.pivot_offset = body.size / 2
	body.color = COLOR_IDLE
	glow.color.a = 0.0
	_setup_pose()
	reset_pose()

	# Diamond floating over whichever player is being targeted.
	_marker = ColorRect.new()
	_marker.size = Vector2(14, 14)
	_marker.pivot_offset = _marker.size / 2
	_marker.rotation = PI / 4
	_marker.top_level = true
	_marker.visible = false
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker)
	_update_pose()

	attack_pool = get_attack_pool()
	for attack in attack_pool:
		attack.parry_success.connect(parry_success.emit)
	for attack_name in get_attack_weights():
		if find_attack(attack_name) == null:
			push_warning("%s: attack weight for unknown attack \"%s\" (typo?)" % [name, attack_name])

	GameManager.register_boss(self)


func _physics_process(delta):
	if hp <= 0.0:
		return
	timer -= delta
	anim_time += delta

	match state:
		State.IDLE:
			_idle_motion(delta)
			if timer <= 0.0:
				_choose_target()
				if target_player == null:
					timer = 0.5
				else:
					_begin_telegraph(pick_attack())

		State.TELEGRAPH:
			_process_telegraph()
			if timer <= 0.0:
				_begin_attack()

		State.ATTACKING:
			var attack = current_attack
			attack.update(delta)
			if hp > 0.0 and attack == current_attack and attack.completed:
				_finish_attack()

		State.RECOVER:
			_recover_motion(delta)
			if timer <= 0.0:
				state = State.IDLE
				timer = get_idle_pause()

		State.STAGGER:
			var flash = fmod(anim_time, 0.16) < 0.08
			body.color = COLOR_STAGGER if flash else COLOR_IDLE
			_stagger_motion(delta)
			if timer <= 0.0:
				_enter_recover(STAGGER_RECOVER_TIME)

	# Telegraphs pulse the body's alpha between 0.7 and 1.0 at 3 Hz.
	body.modulate.a = 0.85 + 0.15 * sin(anim_time * TAU * 3.0) if state == State.TELEGRAPH else 1.0
	_update_marker()
	_update_pose()


func _choose_target():
	var players = get_players()
	var forced_id = get_forced_target_id()
	if forced_id != 0:
		# Testing: only this player is targeted; the other still gets hit by attacks aimed at
		# both, but loses no health.
		for p in players:
			p.invincible = p.player_id != forced_id
		players = players.filter(func(p): return p.player_id == forced_id)
	if players.size() > 0:
		target_player = players[randi() % players.size()]
	else:
		target_player = null


func _begin_telegraph(attack: Attack):
	current_attack = attack
	attack.start(self, get_players())
	state = State.TELEGRAPH
	timer = attack.get_telegraph_duration()
	body.color = attack.get_telegraph_color()
	tint_weapon(attack.get_telegraph_color())


func _process_telegraph():
	var progress = 1.0 - clampf(timer / current_attack.get_telegraph_duration(), 0.0, 1.0)
	if current_attack.uses_center_charge():
		# Fly to mid-arena and float there, turning once; the charge color says what's coming.
		hover()
		var charge = current_attack.get_telegraph_color()
		var pulse = 0.5 + 0.5 * sin(anim_time * 16.0)
		body.color = charge.lerp(Color.WHITE, 0.35 * pulse)
		body.rotation = TAU * progress
		tint_weapon(charge)
		set_glow(charge, 0.25 + 0.35 * pulse * progress)
	current_attack.update_telegraph(progress)


func _begin_attack():
	state = State.ATTACKING
	body.position = body_rest
	body.rotation = 0.0
	body.color = COLOR_EXECUTE
	tint_weapon(COLOR_EXECUTE)
	set_glow(COLOR_EXECUTE, 0.3)
	current_attack.execute()


func _finish_attack():
	var attack = current_attack
	current_attack = null
	if attack.stagger_time > 0.0:
		_enter_stagger(attack, attack.stagger_time, attack.stagger_tumble, attack.stagger_knock)
	else:
		_enter_recover(attack.recover_time, attack)


func _enter_recover(duration: float, finished_attack: Attack = null):
	state = State.RECOVER
	timer = duration
	velocity = Vector2.ZERO
	body.color = COLOR_IDLE
	body.position = body_rest
	body.rotation = 0.0
	glow.color.a = 0.0
	if finished_attack:
		finished_attack.cleanup()
	reset_pose()
	_reset_body_shape()


func _enter_stagger(finished_attack: Attack, duration: float, tumble: bool, knock: Vector2):
	state = State.STAGGER
	timer = duration
	velocity = Vector2.ZERO
	_tumbling = tumble
	_stagger_knock = knock
	body.position = body_rest
	glow.color.a = 0.0
	finished_attack.cleanup()
	reset_pose()
	_reset_body_shape()
	Sfx.play("stagger", -2.0)


# --- Health ---

# source: the player whose sword hit landed, if any; the active attack is told about it.
func take_damage(amount: float, source = null):
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, get_max_hp())
	body.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(body, "scale", Vector2.ONE, 0.2)
	if hp <= 0.0:
		_die()
	elif source and current_attack and state == State.ATTACKING:
		current_attack.on_struck(source)


func _die():
	if current_attack:
		current_attack.interrupt()
		current_attack = null
	body.color = COLOR_DEAD
	body.position = body_rest
	body.rotation = 0.0
	glow.color.a = 0.0
	reset_pose()
	if _pop_tween:
		_pop_tween.kill()
	body.scale = Vector2.ONE
	_marker.visible = false
	_update_pose()
	defeated.emit()


# --- Helpers used by attacks ---

func get_players() -> Array:
	return get_tree().get_nodes_in_group("players")


# True while an attack aimed at `player` is telegraphed or running.
func is_attacking(player) -> bool:
	return state in [State.TELEGRAPH, State.ATTACKING] and target_player == player


func partner_of(player):
	for other in get_players():
		if other != player:
			return other
	return null


func find_attack(attack_name: String) -> Attack:
	for attack in attack_pool:
		if attack.get_attack_name() == attack_name:
			return attack
	return null


# Floats over the arena's center (hover_point()) with a gentle bob.
func hover():
	var center = hover_point()
	center.y += sin(anim_time * 3.0) * 8.0
	global_position = global_position.lerp(center, 0.1)


func face(x: float):
	var side = signf(x - global_position.x)
	if side != 0.0:
		facing = side


# How far the squash_body() pose has moved the body's center from rest (unmirrored).
func body_center_offset() -> Vector2:
	return body.position - body_rest


# --- Squash and stretch (the Sekiro-style read: a slow, loaded anticipation, then a snap) ---

# Holds the body squashed or stretched, bottom kept in place (e.g. crouching to spring).
# x_offset leans the body sideways (e.g. rearing back from the target).
func squash_body(amount: Vector2, x_offset = 0.0):
	if _pop_tween:
		_pop_tween.kill()
		_pop_tween = null
	body.scale = amount
	body.position = body_rest + Vector2(x_offset, body.size.y * (1.0 - amount.y) / 2.0)


# The spring lets go (or an impact lands): snap to `shape`, then settle back to normal.
func pop_body(shape: Vector2, duration = 0.2):
	if _pop_tween:
		_pop_tween.kill()
	body.position = body_rest
	_pop_tween = create_tween()
	_pop_tween.tween_property(body, "scale", shape, duration * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(body, "scale", Vector2.ONE, duration * 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Back to the normal shape, unless a pop is still settling on its own.
func _reset_body_shape():
	if _pop_tween and _pop_tween.is_running():
		return
	body.scale = Vector2.ONE


func set_glow(color: Color, alpha: float):
	glow.color = Color(color, clampf(alpha, 0.0, 1.0))


func knockback_for(player, strength: float) -> Vector2:
	var side = signf(player.global_position.x - global_position.x)
	if side == 0.0:
		side = facing
	return Vector2(side * strength, -strength * 0.6)


func shake(strength: float):
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(strength)


func _update_marker():
	var marker = null
	if current_attack and state in [State.TELEGRAPH, State.ATTACKING]:
		marker = current_attack.get_marker(state == State.TELEGRAPH)
	_marker.visible = marker != null
	if marker:
		_marker.color = marker.get("color", body.color)
		_marker.global_position = marker.who.global_position + Vector2(-7.0, -52.0)
