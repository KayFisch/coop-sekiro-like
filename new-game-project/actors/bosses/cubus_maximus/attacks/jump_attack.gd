class_name JumpAttack
extends Attack
## Yellow -> red. Cubus Maximus leaps at one player and slashes on the way down, landing so
## the blade (not his body) sweeps through them. A perfect parry deflects him back into the
## air, curving over to leap-slash the partner the same way, and so on, alternating: P1, P2,
## P1. The final parry completes the parry relay and knocks him airborne into the arena's
## middle, staggered.
## Blocking takes chip damage; anything else takes the full hit.

signal relay_completed

enum Phase { NONE, RELAY_JUMP, RELAY_LAUNCH }

# --- Tuning ---
# (The parry window is PARRY_TOLERANCE in player.gd, shared by every attack.)
const TELEGRAPH_TIME = 1.0  # seconds of warning before the leap
const LEAPS = 3  # leap-slashes in a full relay, alternating targets; each needs a parry
const JUMP_TIME = 0.5  # the leap at the first target
const JUMP_HEIGHT = 350.0  # apex above the straight line between take-off and landing
const RELAY_JUMP_TIME = 0.6  # deflected at the partner: longer and higher, it may cross the arena
const RELAY_JUMP_HEIGHT = 350.0
# Leap shape (same total time): a quick rise that slows into a hang, then an accelerating drop
# into the slash, so the long read ends in a fast strike.
const JUMP_APEX_AT = 0.65  # fraction of the leap's time at which he peaks (0.5 = symmetric arc)
const JUMP_FALL_POWER = 10.0  # how sharply the fall accelerates (1 = linear fall, higher = snappier)
const SWING_TIME = 0.15  # the slash, ending as he lands; contact is judged throughout
const SWING_FOLLOW_THROUGH = 0.35  # radians the slash carries on past the target's direction
# Charge-up: squashing down like a loaded spring, then stretching as he leaps.
const SQUASH = Vector2(1.25, 0.7)  # body scale at the end of the telegraph
const LEAP_STRETCH = Vector2(0.85, 1.2)
const LEAP_STRETCH_TIME = 0.2
const LAND_SQUASH = Vector2(1.25, 0.75)  # the impact of landing, settling back after
const LAND_SQUASH_TIME = 0.25
# He lands this far to the side of the target (center to center), so the sweeping blade (the
# hitbox spans 28-112 px out) passes through them rather than his body landing on them.
const STRIKE_DISTANCE = 85.0
const DEFLECT_FLASH_TIME = 0.15  # yellow flash as a parry sends him back up
const HIT_DAMAGE = 25.0
const HIT_KNOCKBACK = 320.0
const BLOCKED_DAMAGE = 12.0
const BLOCKED_KNOCKBACK = 150.0
# Relay completed: knocked up and away in an arc that comes down in the arena's middle, where
# he lands staggered.
const LAUNCH_TIME = 0.7
const LAUNCH_HEIGHT = 200.0  # the arc's apex above the straight line to the landing spot
const LAUNCH_SPIN = TAU  # one full turn on the way
const STAGGER_TIME = 1.2
const RECOVER_TIME = 0.45  # after an unparried slash
const SOLO_RECOVER_TIME = 0.45  # parried, but there's no partner to relay to

const COLOR = Color.YELLOW

var _stage = 0  # which leap: 0 at the first target, then alternating between the players
var _jump_time = JUMP_TIME
var _jump_height = JUMP_HEIGHT
var _jump_elapsed = 0.0
var _jump_from = Vector2.ZERO
var _jump_side = 1.0  # which side of the target he lands on
var _goal = Vector2.ZERO  # landing spot; locked once the slash starts
var _swinging = false
var _swing_hit: Array = []
var _launch_from = Vector2.ZERO


func get_attack_name() -> String:
	return "JUMP_ATTACK"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func update_telegraph(progress: float):
	boss.face(boss.target_player.global_position.x)
	# Squash down like a loading spring, quivering harder toward the leap. The sword's draw-back
	# rides along: same easing as the squash, pivot sinking and quivering with the body's center.
	var coil = ease(progress, 1.6)
	var shake = 3.0 * progress
	boss.squash_body(Vector2.ONE.lerp(SQUASH, coil), randf_range(-shake, shake))
	var center = boss.body_center_offset()
	boss.set_sword_offset(Vector2(center.x * boss.facing, center.y))
	boss.set_sword_angle(lerpf(boss.SWORD_REST_ANGLE, boss.SWORD_RAISED_ANGLE, coil))
	boss.set_glow(COLOR, 0.25)


func execute():
	_stage = 0
	boss.set_sword_offset(Vector2.ZERO)  # the body springs back to its center as he leaps
	boss.pop_body(LEAP_STRETCH, LEAP_STRETCH_TIME)  # the spring lets go
	_start_jump(JUMP_TIME, JUMP_HEIGHT)


func update(delta: float):
	match phase:
		Phase.RELAY_JUMP:
			_update_jump(delta)

		Phase.RELAY_LAUNCH:
			# A ballistic arc (straight line + parabola) down to the middle of the arena.
			timer -= delta
			var t = 1.0 - clampf(timer / LAUNCH_TIME, 0.0, 1.0)
			var arc = Vector2(0.0, -4.0 * LAUNCH_HEIGHT * t * (1.0 - t))
			boss.global_position = _launch_from.lerp(boss.home_position, t) + arc
			boss.body.rotation = LAUNCH_SPIN * t * _launch_spin_dir()
			if timer <= 0.0:
				boss.body.rotation = 0.0
				boss.shake(6.0)
				boss.pop_body(LAND_SQUASH, LAND_SQUASH_TIME)
				finish_with_stagger(STAGGER_TIME, true)


func get_marker(_telegraphing: bool):
	# The current target, from the telegraph through the leap (and the redirect).
	if phase == Phase.RELAY_LAUNCH:
		return null
	return {"who": boss.target_player}


func cleanup():
	boss.body.rotation = 0.0


# Tumbling forward along the arc toward the middle.
func _launch_spin_dir() -> float:
	var dir = signf(boss.home_position.x - _launch_from.x)
	return dir if dir != 0.0 else 1.0


# --- The leap ---

func _start_jump(duration: float, height: float):
	phase = Phase.RELAY_JUMP
	_jump_time = duration
	_jump_height = height
	_jump_elapsed = 0.0
	_jump_from = boss.global_position
	_jump_side = signf(boss.global_position.x - boss.target_player.global_position.x)
	if _jump_side == 0.0:
		_jump_side = -boss.facing
	_swinging = false
	_swing_hit.clear()
	_goal = _strike_spot()
	boss.face(boss.target_player.global_position.x)
	boss.set_sword_angle(boss.SWORD_RAISED_ANGLE)
	boss.set_glow(boss.COLOR_EXECUTE, 0.3)


# Height along the leap, 0 at take-off and landing, 1 at the apex (at JUMP_APEX_AT): decelerating
# up into the hang, then falling faster and faster.
func _leap_height(t: float) -> float:
	if t < JUMP_APEX_AT:
		var rise = (JUMP_APEX_AT - t) / JUMP_APEX_AT
		return 1.0 - rise * rise
	var fall = (t - JUMP_APEX_AT) / (1.0 - JUMP_APEX_AT)
	return 1.0 - pow(fall, JUMP_FALL_POWER)


# Where he lands: beside the target, bottoms level, so the slash's blade sweeps through them.
func _strike_spot() -> Vector2:
	var target = boss.target_player
	var half_width = boss.body.size.x / 2.0
	var x = clampf(target.global_position.x + _jump_side * STRIKE_DISTANCE,
		boss.ARENA_LEFT + half_width, boss.ARENA_RIGHT - half_width)
	return Vector2(x, target.global_position.y - (boss.body.size.y - target.body.size.y) / 2.0)


func _update_jump(delta: float):
	_jump_elapsed += delta
	var t = clampf(_jump_elapsed / _jump_time, 0.0, 1.0)
	var left = _jump_time - _jump_elapsed

	# Homing on the target until the slash starts; then the landing spot is committed.
	if not _swinging and left <= SWING_TIME:
		_swinging = true
	if not _swinging:
		_goal = _strike_spot()
		boss.face(boss.target_player.global_position.x)

	var arc = Vector2(0.0, -_jump_height * _leap_height(t))
	boss.global_position = _jump_from.lerp(_goal, t) + arc

	if _stage > 0:
		var flash = _jump_elapsed < DEFLECT_FLASH_TIME
		boss.body.color = COLOR if flash else boss.COLOR_EXECUTE
		boss.sword.color = COLOR if flash else boss.COLOR_EXECUTE

	if _swinging:
		# The slash ends a little past the target's direction, so however fast he's dropping,
		# the blade sweeps through them just before he lands.
		var s = 1.0 - clampf(left / SWING_TIME, 0.0, 1.0)
		var to_target = boss.target_player.global_position - boss.global_position
		var end_angle = atan2(to_target.y, absf(to_target.x)) + SWING_FOLLOW_THROUGH
		boss.set_sword_angle(lerpf(boss.SWORD_RAISED_ANGLE, end_angle, s))
		# Contact is judged on the frame the blade actually overlaps a player.
		for hit in boss.sword_hitbox.get_overlapping_bodies():
			if hit.is_in_group("players") and not hit in _swing_hit:
				_swing_hit.append(hit)
				if hit.is_perfect_parry():
					if _parried(hit):
						return  # deflected into the next leap or the launch
				else:
					_struck(hit)
	else:
		boss.set_sword_angle(boss.SWORD_RAISED_ANGLE)

	if t >= 1.0:  # landed without being parried
		boss.shake(3.0)
		boss.pop_body(LAND_SQUASH, LAND_SQUASH_TIME)
		finish(RECOVER_TIME)


# Returns true if this parry redirected the attack (the rest of this frame is moot).
func _parried(player) -> bool:
	var final = _stage == LEAPS - 1
	player.on_perfect_parry(final)
	parry_success.emit(player, "relay_final" if final else "relay")
	if player != boss.target_player:
		return false
	_deflected()
	return true


func _struck(player):
	if player.is_blocking():
		player.take_damage(BLOCKED_DAMAGE, boss.knockback_for(player, BLOCKED_KNOCKBACK), true)
	else:
		player.take_damage(HIT_DAMAGE, boss.knockback_for(player, HIT_KNOCKBACK))
		boss.shake(7.0)


# The target parried: redirect at the partner, or, on the final parry, get knocked up into
# the middle.
func _deflected():
	if _stage < LEAPS - 1:
		var partner = boss.partner_of(boss.target_player)
		if partner == null:
			finish(SOLO_RECOVER_TIME)
			return
		_stage += 1
		boss.target_player = partner
		boss.set_glow(COLOR, 0.35)
		boss.pop_body(LEAP_STRETCH, LEAP_STRETCH_TIME)
		_start_jump(RELAY_JUMP_TIME, RELAY_JUMP_HEIGHT)
	else:
		relay_completed.emit()
		phase = Phase.RELAY_LAUNCH
		timer = LAUNCH_TIME
		_launch_from = boss.global_position
		boss.body.color = COLOR
		boss.sword.color = COLOR
		boss.set_glow(COLOR, 0.4)
		boss.shake(8.0)
