class_name SwordRelay
extends Attack
## Yellow -> red. Cubus Maximus lunges and swings at one player. A perfect parry deflects
## the swing to the partner; the partner's perfect parry completes the relay and staggers
## him. Blocking takes chip damage; anything else takes the full hit.

signal relay_completed

enum Phase { NONE, SWORD_APPROACH, SWORD_SWING, RELAY_BOUNCE }

# --- Tuning ---
const TELEGRAPH_TIME = 1.0  # seconds of warning before the lunge
const APPROACH_TIME = 0.25  # lunge to the first target
const RELAY_APPROACH_TIME = 0.3  # the second leg may have to cross the arena
const SWING_TIME = 0.15  # the swing's arc; contact is judged throughout
const STRIKE_DISTANCE = 70.0  # how far from the target he stops to swing
const BOUNCE_TIME = 0.2  # knocked back by the first parry before redirecting
const BOUNCE_VELOCITY = Vector2(700.0, -200.0)  # x points away from the parrying player
const BOUNCE_DECELERATION = 3500.0
const HIT_DAMAGE = 25.0
const HIT_KNOCKBACK = 320.0
const BLOCKED_DAMAGE = 12.0
const BLOCKED_KNOCKBACK = 150.0
const STAGGER_TIME = 1.0  # after a completed relay
const RECOVER_TIME = 0.8  # after an unparried swing
const SOLO_RECOVER_TIME = 0.6  # parried, but there's no partner to relay to

const COLOR = Color.YELLOW

var _stage = 0  # 0: first target, 1: redirected at the partner
var _approach_time = APPROACH_TIME
var _lunge_from = Vector2.ZERO
var _lunge_side = 1.0
var _bounce_velocity = Vector2.ZERO
var _swing_hit: Array = []
var _target_parried = false


func get_attack_name() -> String:
	return "SWORD_RELAY"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func update_telegraph(progress: float):
	boss.face(boss.target_player.global_position.x)
	boss.set_sword_angle(lerpf(boss.SWORD_REST_ANGLE, boss.SWORD_RAISED_ANGLE, progress))
	# Quiver harder as the strike approaches.
	var shake = 3.0 * progress
	boss.body.position = boss.body_rest + Vector2(randf_range(-shake, shake), 0.0)
	boss.set_glow(COLOR, 0.25)


func execute():
	_stage = 0
	_start_approach(APPROACH_TIME)


func update(delta: float):
	timer -= delta
	match phase:
		Phase.SWORD_APPROACH:
			var t = 1.0 - clampf(timer / _approach_time, 0.0, 1.0)
			var goal = boss.target_player.global_position + Vector2(_lunge_side * STRIKE_DISTANCE, 0.0)
			boss.global_position = _lunge_from.lerp(goal, ease(t, 0.4))
			if timer <= 0.0:
				phase = Phase.SWORD_SWING
				timer = SWING_TIME
				_swing_hit.clear()
				_target_parried = false

		Phase.SWORD_SWING:
			var t = 1.0 - clampf(timer / SWING_TIME, 0.0, 1.0)
			boss.set_sword_angle(lerpf(boss.SWORD_RAISED_ANGLE, boss.SWORD_FOLLOW_ANGLE, t))
			# Contact is judged on the frame the blade actually overlaps a player.
			for hit in boss.sword_hitbox.get_overlapping_bodies():
				if hit.is_in_group("players") and not hit in _swing_hit:
					_swing_hit.append(hit)
					_resolve_contact(hit)
			if timer <= 0.0:
				_end_swing()

		Phase.RELAY_BOUNCE:
			boss.global_position += _bounce_velocity * delta
			_bounce_velocity = _bounce_velocity.move_toward(Vector2.ZERO, BOUNCE_DECELERATION * delta)
			boss.face(boss.target_player.global_position.x)
			boss.set_sword_angle(boss.SWORD_RAISED_ANGLE)
			if timer <= 0.0:
				boss.body.color = boss.COLOR_EXECUTE
				boss.sword.color = boss.COLOR_EXECUTE
				_start_approach(RELAY_APPROACH_TIME)


func get_marker(_telegraphing: bool):
	# The current target, from the telegraph through the swing (and the redirect).
	return {"who": boss.target_player}


func _start_approach(duration: float):
	phase = Phase.SWORD_APPROACH
	timer = duration
	_approach_time = duration
	_lunge_from = boss.global_position
	_lunge_side = signf(boss.global_position.x - boss.target_player.global_position.x)
	if _lunge_side == 0.0:
		_lunge_side = 1.0
	boss.face(boss.target_player.global_position.x)
	boss.set_sword_angle(boss.SWORD_RAISED_ANGLE)
	boss.set_glow(boss.COLOR_EXECUTE, 0.3)


func _resolve_contact(player):
	if player.is_perfect_parry():
		player.on_perfect_parry(_stage == 1)
		if player == boss.target_player:
			_target_parried = true
		parry_success.emit(player, "relay_final" if _stage == 1 else "relay")
	elif player.is_blocking():
		player.take_damage(BLOCKED_DAMAGE, boss.knockback_for(player, BLOCKED_KNOCKBACK), true)
	else:
		player.take_damage(HIT_DAMAGE, boss.knockback_for(player, HIT_KNOCKBACK))
		boss.shake(7.0)


func _end_swing():
	if not _target_parried:
		finish(RECOVER_TIME)
		return
	if _stage == 0:
		var partner = boss.partner_of(boss.target_player)
		if partner == null:
			finish(SOLO_RECOVER_TIME)
			return
		# Deflected: bounce back and redirect the strike at the partner.
		_stage = 1
		boss.target_player = partner
		phase = Phase.RELAY_BOUNCE
		timer = BOUNCE_TIME
		_bounce_velocity = Vector2(_lunge_side * BOUNCE_VELOCITY.x, BOUNCE_VELOCITY.y)
		boss.body.color = COLOR
		boss.sword.color = COLOR
		boss.set_glow(COLOR, 0.35)
	else:
		relay_completed.emit()
		finish_with_stagger(STAGGER_TIME)
