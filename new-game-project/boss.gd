extends CharacterBody2D

signal parry_success(player, kind)  # kind: "relay", "relay_final", "grand" or "shockwave"
signal relay_completed
signal grab_dodged
signal grand_slash_parried
signal shockwave_parried(player)
signal counterattack_landed(both_players)
signal health_changed(hp, max_hp)
signal defeated

enum State { IDLE, TELEGRAPH, ATTACK, RECOVER, STAGGER }
enum AttackType { SWORD_RELAY, GRAB, GROUND_SLAM, GRAND_SLASH, SHOCKWAVE_SLASHES }
# Sub-steps inside the ATTACK state.
enum Phase { NONE, SWORD_APPROACH, SWORD_SWING, RELAY_BOUNCE, GRAB_WINDUP, GRAB_REACH, GRAB_HOLD,
	SLAM_FALL, SLAM_IMPACT, GRAND_RISE, GRAND_EXTEND, GRAND_DIVE, VOLLEY, VOLLEY_WAIT, COUNTER_TRAVEL }

# Shockwave slashes fire on a fixed metronome, independent of projectile travel.
const SHOCKWAVE_SLASH_INTERVAL = 0.8

const MAX_HP = 20.0
const ARENA_LEFT = 24.0
const ARENA_RIGHT = 1128.0
const ARENA_FLOOR_Y = 600.0

const SWORD_DAMAGE = 1.0
const CHIP_DAMAGE = 0.5
const SWORD_APPROACH_TIME = 0.25
const RELAY_APPROACH_TIME = 0.3  # the second leg may have to cross the arena
const SWORD_SWING_TIME = 0.15
const RELAY_BOUNCE_TIME = 0.2
const STRIKE_DISTANCE = 70.0
const RELAY_STAGGER_TIME = 1.0

const GRAB_TELEGRAPH_TIME = 0.9
const GRAB_WINDUP_TIME = 0.25  # red crouch before the lunge, so even point-blank grabs can be read
const GRAB_REACH_TIME = 0.6
const GRAB_HOLD_TIME = 0.5
const GRAB_DAMAGE = 2.0
const TUMBLE_TIME = 0.8

const SLAM_TELEGRAPH_TIME = 1.1
const SLAM_RISE_HEIGHT = 170.0
const SLAM_FALL_TIME = 0.1
const SLAM_ACTIVE_TIME = 0.3
const SLAM_DAMAGE = 1.0

# Center charge: the telegraph for both the grand slash and the shockwave slashes.
const CENTER_CHARGE_TIME = 1.2
const CENTER_HOVER_HEIGHT = 310.0  # above the boss's floor position

const GRAND_TOP_Y = 60.0
const GRAND_RISE_TIME = 0.35
const GRAND_EXTEND_TIME = 0.35
const GRAND_WAVE_SPEED = 700.0  # px/s downward, so higher players are hit earlier
const GRAND_SYNC_WINDOW = 0.2  # after the first parry, the second must land within this
const GRAND_DAMAGE = 1.0
const GRAND_STAGGER_TIME = 2.5

const SHOCKWAVE_SLASH_COUNT = 6  # alternating P1, P2, ... so 3 each
const SHOCKWAVE_SPEED = 650.0
const SHOCKWAVE_SIZE = Vector2(14, 70)
const SHOCKWAVE_DAMAGE = 0.5
const SHOCKWAVE_WAIT_TIME = 1.0
const COUNTER_TRAVEL_TIME = 0.5  # every counter takes this long, so simultaneous ones land together
const COUNTER_DAMAGE = 2.0  # both players countering deal double this in total
const COUNTER_STAGGER_TIME = 2.0

# Sword angles in radians, for a boss facing right (mirrored when facing left).
const SWORD_REST_ANGLE = 1.05
const SWORD_RAISED_ANGLE = -1.9
const SWORD_FOLLOW_ANGLE = 0.7

const COLOR_IDLE = Color.WHITE
const COLOR_EXECUTE = Color.RED
const COLOR_RELAY = Color.YELLOW
const COLOR_GRAB = Color(0.62, 0.2, 0.95)
const COLOR_SLAM = Color(0.2, 0.9, 0.3)
const COLOR_GRAND = Color(0.25, 0.45, 1.0)
const COLOR_SHOCKWAVE_CHARGE = Color(1.0, 0.15, 0.15)
const COLOR_STAGGER = Color(0.5, 0.5, 0.55)
const COLOR_DEAD = Color(0.25, 0.25, 0.3)
const COLOR_SWORD = Color(0.7, 0.7, 0.75)

var state = State.IDLE
var timer = 2.0  # grace period before the first attack
var target_player = null
var attack_type = AttackType.SWORD_RELAY
var phase = Phase.NONE
var hp = MAX_HP
var home_position = Vector2.ZERO

var _last_attack = -1
var _facing = 1.0
var _sword_scale = Vector2.ONE
var _relay_stage = 0
var _approach_time = SWORD_APPROACH_TIME
var _lunge_from = Vector2.ZERO
var _lunge_side = 1.0
var _bounce_velocity = Vector2.ZERO
var _swing_hit: Array = []
var _target_parried = false
var _slam_from = Vector2.ZERO
var _slam_hit: Array = []
var _tumbling = false
var _anim_time = 0.0
var _body_rest = Vector2.ZERO
var _marker: ColorRect

var _rise_from = Vector2.ZERO
var _grand_blade: ColorRect
var _grand_wave_y = 0.0
var _grand_resolved: Array = []
var _grand_first_parrier = null
var _grand_first_time = 0.0
var _grand_failed = false

var _volley_order: Array = []
var _volley_index = 0
var _projectiles: Array = []  # Dictionaries: node, target, dir
var _counters: Array = []  # Dictionaries: node, from
var _counter_both = false
var _slash_anim = 0.0

@onready var body = $ColorRect
@onready var glow = $Glow
@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: ColorRect = $SwordPivot/Sword
@onready var sword_hitbox: Area2D = $SwordPivot/SwordHitbox
@onready var grab_area: Area2D = $GrabArea
@onready var grand_wave_area: Area2D = $GrandWaveArea


@export var telegraph_time = 1  # seconds of warning (sword relay)
@export var attack_speed = 2000.0


func _ready():
	home_position = global_position
	_body_rest = body.position
	body.pivot_offset = body.size / 2
	body.color = COLOR_IDLE
	glow.color.a = 0.0
	_reset_sword()

	# Diamond floating over whichever player is being targeted.
	_marker = ColorRect.new()
	_marker.size = Vector2(14, 14)
	_marker.pivot_offset = _marker.size / 2
	_marker.rotation = PI / 4
	_marker.top_level = true
	_marker.visible = false
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marker)

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
					sword.color = _telegraph_color()

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
			if _tumbling:
				body.rotation += 14.0 * delta
			else:
				body.position = _body_rest + Vector2(randf_range(-3.0, 3.0), 0.0)
			global_position.y = move_toward(global_position.y, home_position.y, 900.0 * delta)
			if timer <= 0.0:
				_enter_recover(0.6)

	_update_marker()


func _choose_target():
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		target_player = players[randi() % players.size()]
	else:
		target_player = null


func _choose_attack():
	var options = [AttackType.SWORD_RELAY, AttackType.SWORD_RELAY, AttackType.GRAB,
		AttackType.GROUND_SLAM, AttackType.GRAND_SLASH, AttackType.SHOCKWAVE_SLASHES]
	if _last_attack != AttackType.SWORD_RELAY:
		options.erase(_last_attack)
	attack_type = options.pick_random()
	_last_attack = attack_type


func _telegraph_duration() -> float:
	match attack_type:
		AttackType.GRAB:
			return GRAB_TELEGRAPH_TIME
		AttackType.GROUND_SLAM:
			return SLAM_TELEGRAPH_TIME
		AttackType.GRAND_SLASH, AttackType.SHOCKWAVE_SLASHES:
			return CENTER_CHARGE_TIME
	return float(telegraph_time)


func _telegraph_color() -> Color:
	match attack_type:
		AttackType.GRAB:
			return COLOR_GRAB
		AttackType.GROUND_SLAM:
			return COLOR_SLAM
		AttackType.GRAND_SLASH:
			return COLOR_GRAND
		AttackType.SHOCKWAVE_SLASHES:
			return COLOR_SHOCKWAVE_CHARGE
	return COLOR_RELAY


func _process_telegraph():
	var progress = 1.0 - clampf(timer / _telegraph_duration(), 0.0, 1.0)
	match attack_type:
		AttackType.SWORD_RELAY:
			_face(target_player.global_position.x)
			_set_sword_angle(lerpf(SWORD_REST_ANGLE, SWORD_RAISED_ANGLE, progress))
			# Quiver harder as the strike approaches.
			var shake = 3.0 * progress
			body.position = _body_rest + Vector2(randf_range(-shake, shake), 0.0)
			_set_glow(COLOR_RELAY, 0.25)
		AttackType.GRAB:
			_face(target_player.global_position.x)
			var pulse = 0.5 + 0.5 * sin(_anim_time * 22.0)
			body.color = COLOR_GRAB.lerp(COLOR_GRAB.darkened(0.5), pulse)
			_set_glow(COLOR_GRAB, 0.15 + 0.35 * pulse)
		AttackType.GROUND_SLAM:
			global_position.y = lerpf(global_position.y, home_position.y - SLAM_RISE_HEIGHT, 0.08)
			global_position.x = lerpf(global_position.x, home_position.x, 0.08)
			_set_glow(COLOR_SLAM, 0.35 + 0.25 * sin(_anim_time * 14.0))
		AttackType.GRAND_SLASH, AttackType.SHOCKWAVE_SLASHES:
			# Center charge: fly to mid-arena and float there; the charge color says what's coming.
			_hover()
			var charge = _telegraph_color()
			var pulse = 0.5 + 0.5 * sin(_anim_time * 16.0)
			body.color = charge.lerp(Color.WHITE, 0.35 * pulse)
			sword.color = charge
			_set_glow(charge, 0.25 + 0.35 * pulse * progress)


func _begin_attack():
	body.position = _body_rest
	body.color = COLOR_EXECUTE
	sword.color = COLOR_EXECUTE
	_set_glow(COLOR_EXECUTE, 0.3)
	match attack_type:
		AttackType.SWORD_RELAY:
			_relay_stage = 0
			_start_sword_approach(SWORD_APPROACH_TIME)
		AttackType.GRAB:
			phase = Phase.GRAB_WINDUP
			timer = GRAB_WINDUP_TIME
		AttackType.GROUND_SLAM:
			phase = Phase.SLAM_FALL
			timer = SLAM_FALL_TIME
			_slam_from = global_position
		AttackType.GRAND_SLASH:
			phase = Phase.GRAND_RISE
			timer = GRAND_RISE_TIME
			_rise_from = global_position
			sword_pivot.visible = false  # the arena-wide blade stands in for the sword
		AttackType.SHOCKWAVE_SLASHES:
			_start_volley()


func _process_attack(delta):
	match phase:
		Phase.SWORD_APPROACH:
			var t = 1.0 - clampf(timer / _approach_time, 0.0, 1.0)
			var goal = target_player.global_position + Vector2(_lunge_side * STRIKE_DISTANCE, 0.0)
			global_position = _lunge_from.lerp(goal, ease(t, 0.4))
			if timer <= 0.0:
				phase = Phase.SWORD_SWING
				timer = SWORD_SWING_TIME
				_swing_hit.clear()
				_target_parried = false

		Phase.SWORD_SWING:
			var t = 1.0 - clampf(timer / SWORD_SWING_TIME, 0.0, 1.0)
			_set_sword_angle(lerpf(SWORD_RAISED_ANGLE, SWORD_FOLLOW_ANGLE, t))
			# Contact is judged on the frame the blade actually overlaps a player.
			for hit in sword_hitbox.get_overlapping_bodies():
				if hit.is_in_group("players") and not hit in _swing_hit:
					_swing_hit.append(hit)
					_resolve_sword_contact(hit)
			if timer <= 0.0:
				_end_sword_swing()

		Phase.RELAY_BOUNCE:
			global_position += _bounce_velocity * delta
			_bounce_velocity = _bounce_velocity.move_toward(Vector2.ZERO, 3500.0 * delta)
			_face(target_player.global_position.x)
			_set_sword_angle(SWORD_RAISED_ANGLE)
			if timer <= 0.0:
				body.color = COLOR_EXECUTE
				sword.color = COLOR_EXECUTE
				_start_sword_approach(RELAY_APPROACH_TIME)

		Phase.GRAB_WINDUP:
			# Pull back from the target before lunging; the grab hitbox isn't live yet.
			global_position.x -= _facing * 80.0 * delta
			if timer <= 0.0:
				phase = Phase.GRAB_REACH
				timer = GRAB_REACH_TIME

		Phase.GRAB_REACH:
			if target_player:
				var direction = (target_player.global_position - global_position).normalized()
				velocity = direction * attack_speed
				move_and_slide()
			if target_player in grab_area.get_overlapping_bodies():
				if target_player.is_dodging_grab():
					_on_grab_dodged()
				else:
					_start_grab_hold()
			elif timer <= 0.0:
				_enter_recover(0.6)  # whiffed

		Phase.GRAB_HOLD:
			target_player.global_position = global_position + Vector2(0.0, -75.0)
			if timer <= 0.0:
				_grab_crush()

		Phase.SLAM_FALL:
			var t = 1.0 - clampf(timer / SLAM_FALL_TIME, 0.0, 1.0)
			global_position.y = lerpf(_slam_from.y, home_position.y, t)
			if timer <= 0.0:
				global_position.y = home_position.y
				_slam_impact()

		Phase.SLAM_IMPACT:
			for p in get_tree().get_nodes_in_group("players"):
				if p in _slam_hit or p.is_grabbed:
					continue
				if p.is_on_main_floor():  # one-way platforms are safe
					_slam_hit.append(p)
					p.take_damage(SLAM_DAMAGE, Vector2(0.0, -350.0))
			if timer <= 0.0:
				_enter_recover(0.9)

		Phase.GRAND_RISE:
			var t = 1.0 - clampf(timer / GRAND_RISE_TIME, 0.0, 1.0)
			global_position = _rise_from.lerp(Vector2(home_position.x, GRAND_TOP_Y), ease(t, 0.5))
			if timer <= 0.0:
				_start_grand_extend()

		Phase.GRAND_EXTEND:
			var t = 1.0 - clampf(timer / GRAND_EXTEND_TIME, 0.0, 1.0)
			_grand_blade.scale.x = t
			if timer <= 0.0:
				phase = Phase.GRAND_DIVE

		Phase.GRAND_DIVE:
			_grand_wave_y += GRAND_WAVE_SPEED * delta
			_place_grand_wave()
			# Contact comes from the moving band itself, so higher players are reached first.
			var contacts = grand_wave_area.get_overlapping_bodies().filter(
				func(b): return b.is_in_group("players") and not b in _grand_resolved)
			contacts.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
			for p in contacts:
				if state != State.ATTACK:
					break  # a completed double parry already staggered us
				if not p in _grand_resolved:  # a failure earlier this frame may have hit them already
					_grand_contact(p)
			if state == State.ATTACK and _grand_first_parrier != null and not _grand_failed \
					and _anim_time - _grand_first_time > GRAND_SYNC_WINDOW:
				_grand_fail_all()  # the partner didn't parry in time
			if state == State.ATTACK and _grand_wave_y >= ARENA_FLOOR_Y:
				_enter_recover(0.8)

		Phase.VOLLEY:
			_hover()
			_update_projectiles(delta)
			_update_slash_anim()
			if timer <= 0.0:
				_volley_slash()
				if _volley_index >= SHOCKWAVE_SLASH_COUNT:
					phase = Phase.VOLLEY_WAIT
					timer = SHOCKWAVE_WAIT_TIME
				else:
					timer += SHOCKWAVE_SLASH_INTERVAL  # metronome: keep the beat exact

		Phase.VOLLEY_WAIT:
			_hover()
			_update_projectiles(delta)
			_update_slash_anim()
			if timer <= 0.0:
				_launch_counters()

		Phase.COUNTER_TRAVEL:
			_hover()
			var t = 1.0 - clampf(timer / COUNTER_TRAVEL_TIME, 0.0, 1.0)
			for c in _counters:
				c.node.global_position = c.from.lerp(global_position, t) - c.node.size / 2
			if timer <= 0.0:
				_counters_land()


# --- Sword relay -------------------------------------------------------------

func _start_sword_approach(duration: float):
	phase = Phase.SWORD_APPROACH
	timer = duration
	_approach_time = duration
	_lunge_from = global_position
	_lunge_side = signf(global_position.x - target_player.global_position.x)
	if _lunge_side == 0.0:
		_lunge_side = 1.0
	_face(target_player.global_position.x)
	_set_sword_angle(SWORD_RAISED_ANGLE)
	_set_glow(COLOR_EXECUTE, 0.3)


func _resolve_sword_contact(player):
	if player.is_perfect_parry():
		player.on_perfect_parry(_relay_stage == 1)
		if player == target_player:
			_target_parried = true
		parry_success.emit(player, "relay_final" if _relay_stage == 1 else "relay")
	elif player.is_blocking():
		player.take_damage(CHIP_DAMAGE, _knockback_for(player, 150.0), true)
	else:
		player.take_damage(SWORD_DAMAGE, _knockback_for(player, 320.0))
		_shake(7.0)


func _end_sword_swing():
	if not _target_parried:
		_enter_recover(0.8)
		return
	if _relay_stage == 0:
		var partner = _partner_of(target_player)
		if partner == null:
			_enter_recover(0.6)
			return
		# Deflected: bounce back and redirect the strike at the partner.
		_relay_stage = 1
		target_player = partner
		phase = Phase.RELAY_BOUNCE
		timer = RELAY_BOUNCE_TIME
		_bounce_velocity = Vector2(_lunge_side * 700.0, -200.0)
		body.color = COLOR_RELAY
		sword.color = COLOR_RELAY
		_set_glow(COLOR_RELAY, 0.35)
	else:
		relay_completed.emit()
		_enter_stagger(RELAY_STAGGER_TIME, false)


# --- Grab --------------------------------------------------------------------

func _on_grab_dodged():
	target_player.on_grab_dodged()
	grab_dodged.emit()
	_enter_stagger(TUMBLE_TIME, true)


func _start_grab_hold():
	phase = Phase.GRAB_HOLD
	timer = GRAB_HOLD_TIME
	velocity = Vector2.ZERO
	target_player.set_grabbed(true)
	_shake(4.0)


func _grab_crush():
	var victim = target_player
	_release_grab()
	victim.take_damage(GRAB_DAMAGE, Vector2(randf_range(-250.0, 250.0), -450.0))
	_shake(10.0)
	_enter_recover(0.8)


func _release_grab():
	if target_player and target_player.is_grabbed:
		target_player.set_grabbed(false)


# --- Ground slam -------------------------------------------------------------

func _slam_impact():
	phase = Phase.SLAM_IMPACT
	timer = SLAM_ACTIVE_TIME
	_slam_hit.clear()
	glow.color.a = 0.0
	_shake(10.0)
	_spawn_wave(home_position.y + body.size.y / 2, COLOR_EXECUTE)


# --- Center charge -----------------------------------------------------------

func _hover():
	var center = Vector2(home_position.x, home_position.y - CENTER_HOVER_HEIGHT)
	center.y += sin(_anim_time * 3.0) * 8.0
	global_position = global_position.lerp(center, 0.1)


# --- Grand slash -------------------------------------------------------------

func _start_grand_extend():
	phase = Phase.GRAND_EXTEND
	timer = GRAND_EXTEND_TIME
	_grand_resolved.clear()
	_grand_first_parrier = null
	_grand_failed = false
	_grand_wave_y = global_position.y
	# The extended sword: a blade spanning the full arena width, growing out from the boss.
	_grand_blade = ColorRect.new()
	_grand_blade.top_level = true
	_grand_blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grand_blade.size = Vector2(ARENA_RIGHT - ARENA_LEFT, 8.0)
	_grand_blade.pivot_offset = Vector2(home_position.x - ARENA_LEFT, 4.0)
	_grand_blade.scale.x = 0.0
	_grand_blade.color = COLOR_GRAND.lerp(Color.WHITE, 0.3)
	add_child(_grand_blade)
	_place_grand_wave()
	_shake(3.0)


func _place_grand_wave():
	global_position.y = minf(_grand_wave_y, home_position.y)
	_grand_blade.global_position = Vector2(ARENA_LEFT, _grand_wave_y - 4.0)
	grand_wave_area.global_position = Vector2(home_position.x, _grand_wave_y)


# No partial success: the first parry opens a GRAND_SYNC_WINDOW for the partner, and
# anything short of both parrying in time hurts everyone.
func _grand_contact(player):
	_grand_resolved.append(player)
	if _grand_failed:
		_grand_hit(player)
		return
	if not player.is_perfect_parry():
		if _grand_first_parrier != null:
			_grand_fail_all()  # reached inside the window but didn't parry
		else:
			_grand_fail()
			_grand_hit(player)
		return
	player.on_perfect_parry(_grand_first_parrier != null)
	parry_success.emit(player, "grand")
	if _grand_first_parrier == null and _partner_of(player) != null:
		_grand_first_parrier = player
		_grand_first_time = _anim_time
	else:
		grand_slash_parried.emit()
		_grand_blade.color = Color.WHITE
		_enter_stagger(GRAND_STAGGER_TIME, false)


func _grand_fail():
	_grand_failed = true
	_grand_blade.color = COLOR_EXECUTE
	_shake(8.0)


# Full damage to everyone, including a player who already parried.
func _grand_fail_all():
	_grand_fail()
	for p in get_tree().get_nodes_in_group("players"):
		if not p in _grand_resolved:
			_grand_resolved.append(p)
		p.take_damage(GRAND_DAMAGE, _knockback_for(p, 300.0))


func _grand_hit(player):
	if player.is_blocking():
		player.take_damage(CHIP_DAMAGE, _knockback_for(player, 150.0), true)
	else:
		player.take_damage(GRAND_DAMAGE, _knockback_for(player, 300.0))


# --- Shockwave slashes -------------------------------------------------------

func _start_volley():
	phase = Phase.VOLLEY
	timer = 0.0  # first slash right on the downbeat
	_volley_index = 0
	_volley_order = get_tree().get_nodes_in_group("players")
	_volley_order.sort_custom(func(a, b): return a.player_id < b.player_id)
	var per_player = int(float(SHOCKWAVE_SLASH_COUNT) / _volley_order.size())
	for p in _volley_order:
		p.start_gather(per_player)


func _volley_slash():
	var target = _volley_order[_volley_index % _volley_order.size()]
	_volley_index += 1
	target_player = target
	_face(target.global_position.x)
	_slash_anim = SWORD_SWING_TIME
	_fire_shockwave(target)


func _update_slash_anim():
	_slash_anim = maxf(_slash_anim - get_physics_process_delta_time(), 0.0)
	_set_sword_angle(lerpf(SWORD_RAISED_ANGLE, SWORD_FOLLOW_ANGLE, 1.0 - _slash_anim / SWORD_SWING_TIME))


func _fire_shockwave(target):
	var dir = signf(target.global_position.x - global_position.x)
	if dir == 0.0:
		dir = _facing
	var wave = Area2D.new()
	wave.top_level = true
	wave.collision_layer = 0
	wave.collision_mask = 2  # players
	wave.monitorable = false
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = SHOCKWAVE_SIZE
	wave.add_child(shape)
	var visual = ColorRect.new()
	visual.size = SHOCKWAVE_SIZE
	visual.position = -SHOCKWAVE_SIZE / 2
	visual.color = COLOR_EXECUTE
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.add_child(visual)
	add_child(wave)
	# Travels horizontally at the target's height, out from under the boss.
	wave.global_position = Vector2(global_position.x, target.global_position.y)
	_projectiles.append({"node": wave, "target": target, "dir": dir})


func _update_projectiles(delta):
	for proj in _projectiles.duplicate():
		var node = proj.node
		node.global_position.x += proj.dir * SHOCKWAVE_SPEED * delta
		if proj.target in node.get_overlapping_bodies():
			_remove_projectile(proj)
			_shockwave_contact(proj.target)
		elif node.global_position.x < ARENA_LEFT or node.global_position.x > ARENA_RIGHT:
			# Dodged rather than parried: no damage, but no counterattack either.
			_remove_projectile(proj)
			proj.target.fail_gather()


func _remove_projectile(proj):
	_projectiles.erase(proj)
	proj.node.queue_free()


# Each shockwave only interacts with the player it was aimed at.
func _shockwave_contact(player):
	if player.is_perfect_parry():
		player.on_perfect_parry(false)
		player.add_gather()
		parry_success.emit(player, "shockwave")
		shockwave_parried.emit(player)
		return
	player.fail_gather()
	if player.is_blocking():
		player.take_damage(SHOCKWAVE_DAMAGE * 0.5, _knockback_for(player, 150.0), true)
	else:
		player.take_damage(SHOCKWAVE_DAMAGE, _knockback_for(player, 250.0))


func _launch_counters():
	for proj in _projectiles.duplicate():
		_remove_projectile(proj)  # still in flight at the deadline: not parried
		proj.target.fail_gather()
	var ready = _volley_order.filter(func(p): return p.has_full_gather())
	for p in _volley_order:
		p.end_gather()
	if ready.is_empty():
		_enter_recover(0.8)
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
		add_child(node)
		node.global_position = p.global_position - node.size / 2
		_counters.append({"node": node, "from": p.global_position})
	phase = Phase.COUNTER_TRAVEL
	timer = COUNTER_TRAVEL_TIME


func _counters_land():
	# Read the multiplier before the counter's sync bonus is applied.
	var damage = COUNTER_DAMAGE * GameManager.damage_multiplier() * (2.0 if _counter_both else 1.0)
	counterattack_landed.emit(_counter_both)
	_shake(10.0 if _counter_both else 5.0)
	take_damage(damage)
	if hp <= 0.0:
		return
	if _counter_both:
		_enter_stagger(COUNTER_STAGGER_TIME, false)
	else:
		_enter_recover(0.8)


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
	_release_grab()
	phase = Phase.NONE
	body.color = COLOR_DEAD
	body.position = _body_rest
	body.rotation = 0.0
	glow.color.a = 0.0
	_clear_attack_fx()
	_reset_sword()
	_marker.visible = false
	defeated.emit()


func _enter_recover(duration: float):
	state = State.RECOVER
	phase = Phase.NONE
	timer = duration
	velocity = Vector2.ZERO
	body.color = COLOR_IDLE
	body.position = _body_rest
	body.rotation = 0.0
	glow.color.a = 0.0
	_clear_attack_fx()
	_reset_sword()


func _enter_stagger(duration: float, tumble: bool):
	state = State.STAGGER
	phase = Phase.NONE
	timer = duration
	velocity = Vector2.ZERO
	_tumbling = tumble
	glow.color.a = 0.0
	_clear_attack_fx()
	_reset_sword()


# Tear down whatever the last attack left in the arena.
func _clear_attack_fx():
	for proj in _projectiles:
		proj.node.queue_free()
	_projectiles.clear()
	for c in _counters:
		c.node.queue_free()
	_counters.clear()
	for p in _volley_order:
		if is_instance_valid(p):
			p.end_gather()
	_volley_order.clear()
	if _grand_blade:
		var blade = _grand_blade
		blade.create_tween().tween_property(blade, "modulate:a", 0.0, 0.3).finished.connect(blade.queue_free)
		_grand_blade = null
	sword_pivot.visible = true


func _reset_sword():
	_sword_scale = Vector2.ONE
	sword.color = COLOR_SWORD
	_set_sword_angle(SWORD_REST_ANGLE)


func _face(x: float):
	var side = signf(x - global_position.x)
	if side != 0.0:
		_facing = side


func _set_sword_angle(angle: float):
	sword_pivot.scale = Vector2(_sword_scale.x * _facing, _sword_scale.y)
	sword_pivot.rotation = angle * _facing


func _set_glow(color: Color, alpha: float):
	glow.color = Color(color, clampf(alpha, 0.0, 1.0))


func _knockback_for(player, strength: float) -> Vector2:
	var side = signf(player.global_position.x - global_position.x)
	if side == 0.0:
		side = _facing
	return Vector2(side * strength, -strength * 0.6)


func _spawn_wave(floor_y: float, color: Color):
	var wave = ColorRect.new()
	wave.top_level = true
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.color = Color(color, 0.8)
	wave.size = Vector2(1200.0, 14.0)
	wave.pivot_offset = wave.size / 2
	wave.scale = Vector2(0.07, 1.0)
	add_child(wave)
	wave.global_position = Vector2(global_position.x - wave.size.x / 2, floor_y - wave.size.y)
	var tween = wave.create_tween().set_parallel()
	tween.tween_property(wave, "scale", Vector2.ONE, 0.15)
	tween.tween_property(wave, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(wave.queue_free)


func _update_marker():
	var who = null
	if state == State.TELEGRAPH and attack_type in [AttackType.SWORD_RELAY, AttackType.GRAB]:
		who = target_player
	elif state == State.ATTACK and phase in [Phase.SWORD_APPROACH, Phase.SWORD_SWING,
			Phase.RELAY_BOUNCE, Phase.GRAB_WINDUP, Phase.GRAB_REACH]:
		who = target_player
	elif state == State.ATTACK and phase == Phase.VOLLEY:
		who = _volley_order[_volley_index % _volley_order.size()]  # next on the metronome
	_marker.visible = who != null
	if _marker.visible:
		_marker.color = body.color
		_marker.global_position = who.global_position + Vector2(-7.0, -52.0)


func _shake(strength: float):
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(strength)


func _partner_of(player):
	for other in get_tree().get_nodes_in_group("players"):
		if other != player:
			return other
	return null
