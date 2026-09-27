class_name Grab
extends Attack
## Purple -> red. Cubus Maximus winds up, then lunges to grab one player. It can't be
## blocked: the target dodges by dashing as the grab connects, which sends him tumbling.
## A caught player is lifted and crushed for heavy damage.

signal grab_dodged

enum Phase { NONE, GRAB_WINDUP, GRAB_REACH, GRAB_HOLD }

# --- Tuning ---
const TELEGRAPH_TIME = 0.9
const WINDUP_TIME = 0.25  # red crouch before the lunge, so even point-blank grabs can be read
const WINDUP_BACKSTEP_SPEED = 80.0  # drifting away from the target during the windup
const LUNGE_SPEED = 2000.0
const REACH_TIME = 0.6  # how long the lunge lasts before it whiffs
const HOLD_TIME = 0.5  # carrying the caught player before the crush
const DAMAGE = 40.0
const CRUSH_KNOCKBACK = Vector2(250.0, -450.0)  # x is randomized between -x and x
const TUMBLE_TIME = 0.8  # his stagger after a dodged grab
const RECOVER_TIME = 0.8  # after a crush
const WHIFF_RECOVER_TIME = 0.6

const COLOR = Color(0.62, 0.2, 0.95)


func get_attack_name() -> String:
	return "GRAB"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func update_telegraph(_progress: float):
	boss.face(boss.target_player.global_position.x)
	var pulse = 0.5 + 0.5 * sin(boss.anim_time * 22.0)
	boss.body.color = COLOR.lerp(COLOR.darkened(0.5), pulse)
	boss.set_glow(COLOR, 0.15 + 0.35 * pulse)


func execute():
	phase = Phase.GRAB_WINDUP
	timer = WINDUP_TIME


func update(delta: float):
	timer -= delta
	var target = boss.target_player
	match phase:
		Phase.GRAB_WINDUP:
			# Pull back from the target before lunging; the grab hitbox isn't live yet.
			boss.global_position.x -= boss.facing * WINDUP_BACKSTEP_SPEED * delta
			if timer <= 0.0:
				phase = Phase.GRAB_REACH
				timer = REACH_TIME

		Phase.GRAB_REACH:
			if target:
				var direction = (target.global_position - boss.global_position).normalized()
				boss.velocity = direction * LUNGE_SPEED
				boss.move_and_slide()
			if target in boss.grab_area.get_overlapping_bodies():
				if target.is_dodging_grab():
					_dodged()
				else:
					_start_hold()
			elif timer <= 0.0:
				finish(WHIFF_RECOVER_TIME)

		Phase.GRAB_HOLD:
			target.global_position = boss.global_position + Vector2(0.0, -75.0)
			if timer <= 0.0:
				_crush()


func get_marker(telegraphing: bool):
	if telegraphing or phase in [Phase.GRAB_WINDUP, Phase.GRAB_REACH]:
		return {"who": boss.target_player}
	return null


func cleanup():
	_release()


func _dodged():
	boss.target_player.on_grab_dodged()
	grab_dodged.emit()
	finish_with_stagger(TUMBLE_TIME, true)


func _start_hold():
	phase = Phase.GRAB_HOLD
	timer = HOLD_TIME
	boss.velocity = Vector2.ZERO
	boss.target_player.set_grabbed(true)
	boss.shake(4.0)


func _crush():
	var victim = boss.target_player
	_release()
	victim.take_damage(DAMAGE, Vector2(randf_range(-CRUSH_KNOCKBACK.x, CRUSH_KNOCKBACK.x), CRUSH_KNOCKBACK.y))
	boss.shake(10.0)
	finish(RECOVER_TIME)


func _release():
	var target = boss.target_player
	if target and target.is_grabbed:
		target.set_grabbed(false)
