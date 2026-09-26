extends CharacterBody2D

signal parry_success(player, kind)  # kind: "relay", "relay_final" or "grab_break"
signal parry_failed(player)
signal relay_completed
signal grab_broken
signal health_changed(hp, max_hp)
signal defeated

enum State { IDLE, TELEGRAPH, ATTACK, RECOVER, STAGGER }
enum AttackType { PARRY_RELAY, AOE_SLAM, GRAB }
# Sub-steps inside the ATTACK state.
enum Phase { NONE, RELAY_LUNGE, RELAY_BOUNCE, SLAM_FALL, SLAM_IMPACT, GRAB_REACH, GRAB_HOLD }

const MAX_HP = 10.0

const PARRY_WINDOW = 0.4
const RELAY_BOUNCE_TIME = 0.15
const RELAY_DAMAGE = 1.0
const CONTACT_DISTANCE = 62.0
const STAGGER_TIME = 1.3

const SLAM_TELEGRAPH_TIME = 1.1
const SLAM_RISE_HEIGHT = 170.0
const SLAM_FALL_TIME = 0.1
const SLAM_ACTIVE_TIME = 0.15

const GRAB_TELEGRAPH_TIME = 0.9
const GRAB_REACH_TIME = 0.6
const GRAB_RANGE = 70.0
const GRAB_BREAK_WINDOW = 0.5
const GRAB_BREAK_DAMAGE = 0.5
const GRAB_DAMAGE = 2

const COLOR_IDLE = Color(0.85, 0.85, 0.9)
const COLOR_RELAY_TELEGRAPH = Color.YELLOW
const COLOR_RELAY_STRIKE = Color.RED
const COLOR_SLAM = Color(0.62, 0.2, 0.95)
const COLOR_GRAB = Color(1.0, 0.55, 0.1)
const COLOR_STAGGER = Color(0.45, 0.5, 0.65)
const COLOR_DEAD = Color(0.25, 0.25, 0.3)

var state = State.IDLE
var timer = 2.0  # grace period before the first attack
var target_player = null
var attack_type = AttackType.PARRY_RELAY
var phase = Phase.NONE
var hp = MAX_HP
var home_position = Vector2.ZERO

var _last_attack = -1
var _relay_stage = 0
var _lunge_from = Vector2.ZERO
var _lunge_side = 1.0
var _bounce_velocity = Vector2.ZERO
var _slam_from = Vector2.ZERO
var _slam_hit: Array = []
var _grab_helper = null
var _anim_time = 0.0
var _body_rest = Vector2.ZERO
var _marker: ColorRect
@onready var body = $ColorRect
@onready var glow = $Glow


@export var telegraph_time = 1  # seconds of warning (parry relay)
@export var attack_speed = 2000.0


func _ready():
	home_position = global_position
	_body_rest = body.position
	body.pivot_offset = body.size / 2
	body.color = COLOR_IDLE
	glow.color.a = 0.0

	# Diamond floating over whichever player has to react.
	_marker = ColorRect.new()
	_marker.size = Vector2(14, 14)
	_marker.pivot_offset = _marker.size / 2
	_marker.rotation = PI / 4
	_marker.top_level = true
	_marker.visible = false
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker)

	for p in get_tree().get_nodes_in_group("players"):
		p.parry_attempted.connect(_on_parry_attempted)
	GameManager.register_boss(self)


func _physics_process(delta):
	if hp <= 0.0:
		return
	timer -= delta
	_anim_time += delta

	match state:
		State.IDLE:
			global_position = global_position.lerp(home_position, 0.05)
			if timer <= 0.0:
				_choose_target()
				if target_player == null:
					timer = 0.5
				else:
					_choose_attack()
					state = State.TELEGRAPH
					timer = _telegraph_duration()
					body.color = _telegraph_color()

		State.TELEGRAPH:
			_process_telegraph()
			if timer <= 0.0:
				state = State.ATTACK
				_begin_attack()

		State.ATTACK:
			_process_attack(delta)

		State.RECOVER:
			global_position = global_position.lerp(home_position, 0.08)
			if timer <= 0.0:
				state = State.IDLE
				timer = randf_range(0.8, 1.4)  # pause before next attack

		State.STAGGER:
			var flash = fmod(_anim_time, 0.16) < 0.08
			body.color = COLOR_STAGGER if flash else COLOR_IDLE
			body.position = _body_rest + Vector2(randf_range(-3.0, 3.0), 0.0)
			global_position.y = move_toward(global_position.y, home_position.y, 900.0 * delta)
			if timer <= 0.0:
				_enter_recover(0.6)

	_update_marker()


func _choose_target():
	var players = _living_players()
	if players.size() > 0:
		target_player = players[randi() % players.size()]
	else:
		target_player = null


func _choose_attack():
	var options = [AttackType.PARRY_RELAY, AttackType.PARRY_RELAY, AttackType.AOE_SLAM]
	# A grab nobody can break is just a free hit, so only grab when both players are up.
	if _living_players().size() >= 2:
		options.append(AttackType.GRAB)
	if _last_attack != AttackType.PARRY_RELAY:
		options.erase(_last_attack)
	attack_type = options.pick_random()
	_last_attack = attack_type


func _telegraph_duration() -> float:
	match attack_type:
		AttackType.AOE_SLAM:
			return SLAM_TELEGRAPH_TIME
		AttackType.GRAB:
			return GRAB_TELEGRAPH_TIME
	return float(telegraph_time)


func _telegraph_color() -> Color:
	match attack_type:
		AttackType.AOE_SLAM:
			return COLOR_SLAM
		AttackType.GRAB:
			return COLOR_GRAB
	return COLOR_RELAY_TELEGRAPH


func _process_telegraph():
	match attack_type:
		AttackType.PARRY_RELAY:
			# Quiver harder as the strike approaches.
			var shake = 3.0 * (1.0 - timer / float(telegraph_time))
			body.position = _body_rest + Vector2(randf_range(-shake, shake), 0.0)
			_set_glow(COLOR_RELAY_TELEGRAPH, 0.25)
		AttackType.AOE_SLAM:
			global_position.y = lerpf(global_position.y, home_position.y - SLAM_RISE_HEIGHT, 0.08)
			global_position.x = lerpf(global_position.x, home_position.x, 0.08)
			_set_glow(COLOR_SLAM, 0.35 + 0.25 * sin(_anim_time * 14.0))
		AttackType.GRAB:
			var pulse = 0.5 + 0.5 * sin(_anim_time * 22.0)
			body.color = COLOR_GRAB.lerp(COLOR_GRAB.darkened(0.5), pulse)
			_set_glow(COLOR_GRAB, 0.15 + 0.35 * pulse)


func _begin_attack():
	body.position = _body_rest
	match attack_type:
		AttackType.PARRY_RELAY:
			_relay_stage = 0
			_start_lunge()
		AttackType.AOE_SLAM:
			phase = Phase.SLAM_FALL
			timer = SLAM_FALL_TIME
			_slam_from = global_position
		AttackType.GRAB:
			phase = Phase.GRAB_REACH
			timer = GRAB_REACH_TIME
			body.color = COLOR_GRAB


func _process_attack(delta):
	match phase:
		Phase.RELAY_LUNGE:
			# The whole lunge is the parry window: contact lands exactly when it closes.
			var t = 1.0 - clampf(timer / PARRY_WINDOW, 0.0, 1.0)
			var goal = target_player.global_position + Vector2(_lunge_side * CONTACT_DISTANCE, 0.0)
			global_position = _lunge_from.lerp(goal, ease(t, 2.2))
			if timer <= 0.0:
				_relay_hit()

		Phase.RELAY_BOUNCE:
			global_position += _bounce_velocity * delta
			_bounce_velocity = _bounce_velocity.move_toward(Vector2.ZERO, 4000.0 * delta)
			if timer <= 0.0:
				_start_lunge()

		Phase.SLAM_FALL:
			var t = 1.0 - clampf(timer / SLAM_FALL_TIME, 0.0, 1.0)
			global_position.y = lerpf(_slam_from.y, home_position.y, t)
			if timer <= 0.0:
				global_position.y = home_position.y
				_slam_impact()

		Phase.SLAM_IMPACT:
			for p in get_tree().get_nodes_in_group("players"):
				if p.is_downed or p in _slam_hit:
					continue
				if p.is_on_floor():
					_slam_hit.append(p)
					p.take_damage(1)
			if timer <= 0.0:
				_enter_recover(0.9)

		Phase.GRAB_REACH:
			if target_player:
				var direction = (target_player.global_position - global_position).normalized()
				velocity = direction * attack_speed
				move_and_slide()
			if global_position.distance_to(target_player.global_position) <= GRAB_RANGE:
				_start_grab_hold()
			elif timer <= 0.0:
				_enter_recover(0.6)  # whiffed

		Phase.GRAB_HOLD:
			target_player.global_position = global_position + Vector2(0.0, -75.0)
			_set_glow(COLOR_GRAB, 0.3 + 0.3 * sin(_anim_time * 30.0))
			if timer <= 0.0:
				_grab_crush()


# --- Parry relay -------------------------------------------------------------

func _start_lunge():
	phase = Phase.RELAY_LUNGE
	timer = PARRY_WINDOW
	_lunge_from = global_position
	_lunge_side = signf(global_position.x - target_player.global_position.x)
	if _lunge_side == 0.0:
		_lunge_side = 1.0
	body.color = COLOR_RELAY_STRIKE
	_set_glow(COLOR_RELAY_STRIKE, 0.3)


func _relay_parried(player):
	if _relay_stage == 0:
		parry_success.emit(player, "relay")
		# Revival (if any) happens synchronously on parry_success, so a downed partner is back up here.
		var partner = _partner_of(player)
		if partner == null or partner.is_downed:
			_enter_recover(0.6)
			return
		_relay_stage = 1
		target_player = partner
		phase = Phase.RELAY_BOUNCE
		timer = RELAY_BOUNCE_TIME
		_bounce_velocity = Vector2(_lunge_side * 900.0, -250.0)
		body.color = COLOR_RELAY_TELEGRAPH
		_set_glow(COLOR_RELAY_TELEGRAPH, 0.35)
	else:
		parry_success.emit(player, "relay_final")
		# Read the multiplier before the completed relay raises sync.
		var damage = RELAY_DAMAGE * GameManager.damage_multiplier()
		relay_completed.emit()
		take_damage(damage)
		if hp > 0.0:
			_enter_stagger()


func _relay_hit():
	var victim = target_player
	parry_failed.emit(victim)
	victim.take_damage(1)
	_shake(7.0)
	_enter_recover(0.8)


# --- AoE slam ----------------------------------------------------------------

func _slam_impact():
	phase = Phase.SLAM_IMPACT
	timer = SLAM_ACTIVE_TIME
	_slam_hit.clear()
	glow.color.a = 0.0
	_shake(10.0)

	var floor_y = home_position.y + body.size.y / 2
	var wave = ColorRect.new()
	wave.top_level = true
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.color = Color(COLOR_SLAM, 0.8)
	wave.size = Vector2(1200.0, 14.0)
	wave.pivot_offset = wave.size / 2
	wave.scale = Vector2(0.07, 1.0)
	add_child(wave)
	wave.global_position = Vector2(global_position.x - wave.size.x / 2, floor_y - wave.size.y)
	var tween = wave.create_tween().set_parallel()
	tween.tween_property(wave, "scale", Vector2.ONE, SLAM_ACTIVE_TIME)
	tween.tween_property(wave, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(wave.queue_free)


# --- Grab --------------------------------------------------------------------

func _start_grab_hold():
	phase = Phase.GRAB_HOLD
	timer = GRAB_BREAK_WINDOW
	velocity = Vector2.ZERO
	_grab_helper = _partner_of(target_player)
	target_player.set_grabbed(true)
	_shake(4.0)


func _break_grab(helper):
	parry_success.emit(helper, "grab_break")
	var damage = GRAB_BREAK_DAMAGE * GameManager.damage_multiplier()
	grab_broken.emit()
	# Fling the freed player toward their rescuer.
	_release_grab(Vector2(signf(helper.global_position.x - global_position.x) * 300.0, -450.0))
	take_damage(damage)
	if hp > 0.0:
		_enter_recover(0.8)


func _grab_crush():
	var victim = target_player
	_release_grab(Vector2(randf_range(-250.0, 250.0), -450.0))
	parry_failed.emit(_grab_helper if _grab_helper else victim)
	victim.take_damage(GRAB_DAMAGE)
	_shake(10.0)
	_enter_recover(0.8)


func _release_grab(toss: Vector2):
	if target_player and target_player.is_grabbed:
		target_player.set_grabbed(false)
		target_player.velocity = toss


# --- Parry hooks used by players --------------------------------------------

func is_parry_window_open(player) -> bool:
	if state != State.ATTACK or hp <= 0.0:
		return false
	match phase:
		Phase.RELAY_LUNGE:
			return player == target_player
		Phase.GRAB_HOLD:
			return player != target_player and not player.is_downed
	return false


# True while an incoming relay strike is announced for this player but not yet parryable.
func is_threatening(player) -> bool:
	if player != target_player or attack_type != AttackType.PARRY_RELAY:
		return false
	return state == State.TELEGRAPH or (state == State.ATTACK and phase == Phase.RELAY_BOUNCE)


func _on_parry_attempted(player):
	if not is_parry_window_open(player):
		return
	if attack_type == AttackType.PARRY_RELAY:
		_relay_parried(player)
	elif attack_type == AttackType.GRAB:
		_break_grab(player)


# --- Health & state helpers -------------------------------------------------

func take_damage(amount: float):
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, MAX_HP)
	body.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(body, "scale", Vector2.ONE, 0.2)
	if hp <= 0.0:
		_die()


func _die():
	_release_grab(Vector2.ZERO)
	phase = Phase.NONE
	body.color = COLOR_DEAD
	body.position = _body_rest
	glow.color.a = 0.0
	_marker.visible = false
	defeated.emit()


func _enter_recover(duration: float):
	state = State.RECOVER
	phase = Phase.NONE
	timer = duration
	velocity = Vector2.ZERO
	body.color = COLOR_IDLE
	body.position = _body_rest
	glow.color.a = 0.0


func _enter_stagger():
	state = State.STAGGER
	phase = Phase.NONE
	timer = STAGGER_TIME
	velocity = Vector2.ZERO
	glow.color.a = 0.0


func _set_glow(color: Color, alpha: float):
	glow.color = Color(color, clampf(alpha, 0.0, 1.0))


func _update_marker():
	var who = null
	var color = body.color
	if state == State.TELEGRAPH and attack_type != AttackType.AOE_SLAM:
		who = target_player
	elif state == State.ATTACK:
		match phase:
			Phase.RELAY_LUNGE, Phase.RELAY_BOUNCE:
				who = target_player
			Phase.GRAB_HOLD:
				# Point at the partner who has to break the grab.
				who = _grab_helper
				color = Color.WHITE if fmod(_anim_time, 0.1) < 0.05 else COLOR_GRAB
	_marker.visible = who != null and not who.is_downed
	if _marker.visible:
		_marker.color = color
		_marker.global_position = who.global_position + Vector2(-7.0, -52.0)


func _shake(strength: float):
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(strength)


func _living_players() -> Array:
	return get_tree().get_nodes_in_group("players").filter(func(p): return not p.is_downed)


func _partner_of(player):
	for other in get_tree().get_nodes_in_group("players"):
		if other != player:
			return other
	return null
