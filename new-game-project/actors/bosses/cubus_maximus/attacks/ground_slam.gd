class_name GroundSlam
extends Attack
## Green -> red. Cubus Maximus crouches, springs up over the arena's center, hangs there with
## his sword raised, then drops, faster and faster, and slams the floor. It can't be blocked:
## anyone standing on the main floor during the shockwave takes damage. Players in the air or
## on the one-way platforms are safe.

enum Phase { NONE, SLAM_FALL, SLAM_IMPACT }

# --- Tuning ---
const TELEGRAPH_TIME = 1.1
# The telegraph, as fractions of TELEGRAPH_TIME: crouch, then spring up, then hang at the top.
const CROUCH_PART = 0.3
const RISE_PART = 0.45  # the rise ends at CROUCH_PART + RISE_PART; the rest is the hang
const CROUCH_SQUASH = Vector2(1.3, 0.65)
const LEAP_STRETCH = Vector2(0.8, 1.3)
const RISE_HEIGHT = 170.0
const HANG_CREEP = 14.0  # drifting a little higher while hanging, the tension before the drop
const FALL_TIME = 0.15
const FALL_POWER = 3.0  # how sharply the drop accelerates (1 = constant speed)
const IMPACT_SQUASH = Vector2(1.4, 0.6)
const ACTIVE_TIME = 0.3  # how long the floor shockwave can hit after impact
const DAMAGE = 25.0
const KNOCKBACK = Vector2(0.0, -350.0)
const RECOVER_TIME = 0.5

const COLOR = Color(0.2, 0.9, 0.3)

var _telegraph_from = Vector2.ZERO
var _leapt = false
var _fall_from = Vector2.ZERO
var _hit: Array = []


func get_attack_name() -> String:
	return "GROUND_SLAM"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_telegraph_from = boss_node.global_position
	_leapt = false


func update_telegraph(progress: float):
	var home = boss.home_position
	boss.set_glow(COLOR, 0.35 + 0.25 * sin(boss.anim_time * 14.0))
	boss.global_position.x = lerpf(_telegraph_from.x, home.x, ease(minf(progress / CROUCH_PART, 1.0), -2.0))
	if progress < CROUCH_PART:
		# Crouching, loading the spring.
		var c = progress / CROUCH_PART
		boss.squash_body(Vector2.ONE.lerp(CROUCH_SQUASH, ease(c, 0.6)))
		boss.global_position.y = lerpf(_telegraph_from.y, home.y, c)
		return
	if not _leapt:
		_leapt = true
		boss.pop_body(LEAP_STRETCH, 0.25)
	var rise_end = CROUCH_PART + RISE_PART
	var top = home.y - RISE_HEIGHT
	if progress < rise_end:
		# Springing up, slowing into the hang.
		var r = (progress - CROUCH_PART) / RISE_PART
		boss.global_position.y = lerpf(home.y, top, ease(r, 0.3))
		boss.set_sword_angle(lerpf(boss.SWORD_REST_ANGLE, boss.SWORD_RAISED_ANGLE, ease(r, 0.5)))
	else:
		# Hanging, sword overhead, creeping up.
		var h = (progress - rise_end) / (1.0 - rise_end)
		boss.global_position.y = top - HANG_CREEP * ease(h, 0.6)
		boss.set_sword_angle(boss.SWORD_RAISED_ANGLE)


func execute():
	phase = Phase.SLAM_FALL
	timer = FALL_TIME
	_fall_from = boss.global_position
	boss.set_sword_angle(boss.SWORD_RAISED_ANGLE)


func update(delta: float):
	timer -= delta
	match phase:
		Phase.SLAM_FALL:
			# Slow off the top, then faster and faster: the sword comes down with him.
			var t = pow(1.0 - clampf(timer / FALL_TIME, 0.0, 1.0), FALL_POWER)
			boss.global_position.y = lerpf(_fall_from.y, boss.home_position.y, t)
			boss.set_sword_angle(lerpf(boss.SWORD_RAISED_ANGLE, boss.SWORD_FOLLOW_ANGLE, t))
			if timer <= 0.0:
				boss.global_position.y = boss.home_position.y
				_impact()

		Phase.SLAM_IMPACT:
			for p in players:
				if p in _hit or p.is_grabbed:
					continue
				if p.is_on_main_floor():  # one-way platforms are safe
					_hit.append(p)
					p.take_damage(DAMAGE, KNOCKBACK)
			if timer <= 0.0:
				finish(RECOVER_TIME)


func _impact():
	phase = Phase.SLAM_IMPACT
	timer = ACTIVE_TIME
	_hit.clear()
	boss.glow.color.a = 0.0
	boss.shake(10.0)
	boss.pop_body(IMPACT_SQUASH, 0.3)
	_spawn_floor_wave(boss.home_position.y + boss.body.size.y / 2, boss.COLOR_EXECUTE)


# A flat band that shoots out along the floor and fades (visual only).
func _spawn_floor_wave(floor_y: float, color: Color):
	var wave = ColorRect.new()
	wave.top_level = true
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.color = Color(color, 0.8)
	wave.size = Vector2(1200.0, 14.0)
	wave.pivot_offset = wave.size / 2
	wave.scale = Vector2(0.07, 1.0)
	boss.add_child(wave)
	wave.global_position = Vector2(boss.global_position.x - wave.size.x / 2, floor_y - wave.size.y)
	var tween = wave.create_tween().set_parallel()
	tween.tween_property(wave, "scale", Vector2.ONE, 0.15)
	tween.tween_property(wave, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(wave.queue_free)
