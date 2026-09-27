class_name GroundSlam
extends Attack
## Green -> red. Cubus Maximus rises, then slams the floor. It can't be blocked: anyone
## standing on the main floor during the shockwave takes damage. Players in the air or on
## the one-way platforms are safe.

enum Phase { NONE, SLAM_FALL, SLAM_IMPACT }

# --- Tuning ---
const TELEGRAPH_TIME = 1.1  # rising into the air
const RISE_HEIGHT = 170.0
const FALL_TIME = 0.1
const ACTIVE_TIME = 0.3  # how long the floor shockwave can hit after impact
const DAMAGE = 25.0
const KNOCKBACK = Vector2(0.0, -350.0)
const RECOVER_TIME = 0.9

const COLOR = Color(0.2, 0.9, 0.3)

var _fall_from = Vector2.ZERO
var _hit: Array = []


func get_attack_name() -> String:
	return "GROUND_SLAM"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func update_telegraph(_progress: float):
	var home = boss.home_position
	boss.global_position.y = lerpf(boss.global_position.y, home.y - RISE_HEIGHT, 0.08)
	boss.global_position.x = lerpf(boss.global_position.x, home.x, 0.08)
	boss.set_glow(COLOR, 0.35 + 0.25 * sin(boss.anim_time * 14.0))


func execute():
	phase = Phase.SLAM_FALL
	timer = FALL_TIME
	_fall_from = boss.global_position


func update(delta: float):
	timer -= delta
	match phase:
		Phase.SLAM_FALL:
			var t = 1.0 - clampf(timer / FALL_TIME, 0.0, 1.0)
			boss.global_position.y = lerpf(_fall_from.y, boss.home_position.y, t)
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
