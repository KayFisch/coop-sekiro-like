class_name Hook
extends Attack
## Purple -> red. A hook unfolds from Sphaera Pendula's underside and shoots out on a chain at
## one player, homing in. It can't be blocked: the target escapes by dashing as it reaches them
## (the grab's timing, DODGE_TOLERANCE in player.gd), which yanks it back empty and leaves the
## sphere spinning.
## A caught player is dragged off into the pit and dangles there, a pendulum on the chain, while
## the sphere reels itself up toward the beam to crush them against it. Both players can do
## something about it: the hooked one swings the dangle left and right (move input) toward the
## partner's pan, and the partner cuts them loose with RESCUE_HITS sword hits on the taut chain.

signal hook_dodged
signal hook_rescued

enum Phase { NONE, THROW, CLOSING, RETRACT, REEL }

# --- Tuning ---
const TELEGRAPH_TIME = 0.9
const HOOK_SPEED = 1400.0  # faster than a dash: you slip it, you don't outrun it
const THROW_MAX_TIME = 0.6  # gives up after this long
# The dodge is judged this long after the hook reaches the target, like the grab: a dash from
# DODGE_TOLERANCE before that, up to it, slips free.
const DODGE_LATE_WINDOW = 0.07
const RETRACT_TIME = 0.2
const TUMBLE_TIME = 0.8  # its stagger after a dodge
const WHIFF_RECOVER_TIME = 0.4
# Caught: dangling over the pit, a pendulum pivoting on the sphere as it reels up.
const YANK_TIME = 0.3  # the chain snaps from wherever they were caught to DANGLE_LENGTH
const DANGLE_LENGTH = 240.0
const CRUSH_LENGTH = 50.0  # reeled in this far, they're crushed against the sphere and the beam
const REEL_TIME = 1.8  # caught -> crushed: the partner's window
const REEL_TOP = Vector2(576, 110)  # where the sphere reels itself up to
const DANGLE_GRAVITY = 1800.0
const DANGLE_PUMP = 1300.0  # the hooked player's swinging, px/s² along the arc
const DANGLE_DAMPING = 0.6  # fraction of the swing's speed lost per second
const DANGLE_MAX_ANGLE = 0.55  # radians either side of straight down
const CHAIN_HIT_RADIUS = 26.0  # a blade this close to the chain strikes it
const RESCUE_HITS = 2
const RESCUE_HOP = -350.0  # the freed player's upward speed as the chain parts
const RESCUE_RECOIL_TIME = 0.6  # its stagger, the cut chain whipping back
const CRUSH_DAMAGE = 40.0
const CRUSH_KNOCKBACK = Vector2(420.0, -250.0)  # x points toward the higher pan
const RECOVER_TIME = 0.6

const COLOR = Color(0.7, 0.3, 1.0)
const COLOR_RESCUE = Color(1.0, 0.78, 0.2)  # the partner's marker: cut the chain!
const TIP_SIZE = Vector2(18, 18)

var _tip: ColorRect
var _tip_pos = Vector2.ZERO
var _shut_point = Vector2.ZERO
var _close_time = 0.0
var _finish_after_retract = Callable()
var _victim = null
var _helper = null
var _pivot_from = Vector2.ZERO
var _theta = 0.0  # the dangle's angle from straight down (positive: to the right)
var _theta_from = 0.0
var _omega = 0.0
var _length = 0.0
var _length_from = 0.0
var _reel_elapsed = 0.0
var _hits = 0
var _last_serial = -1


func get_attack_name() -> String:
	return "HOOK"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func start(boss_node, player_nodes: Array):
	super(boss_node, player_nodes)
	_victim = null
	_helper = null


# Hanging still, the hook unfolding below it; the chain coils.
func update_telegraph(progress: float):
	var pulse = 0.5 + 0.5 * sin(boss.anim_time * 22.0)
	boss.body.color = COLOR.lerp(COLOR.darkened(0.5), pulse)
	boss.set_glow(COLOR, 0.15 + 0.35 * pulse)
	var below = boss.global_position + Vector2(0.0, boss.RADIUS + 26.0 * ease(progress, 0.5))
	boss.draw_chain(boss.global_position, below, COLOR)


func execute():
	phase = Phase.THROW
	timer = THROW_MAX_TIME
	_tip_pos = boss.global_position
	_tip = ColorRect.new()
	_tip.top_level = true
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.size = TIP_SIZE
	_tip.pivot_offset = TIP_SIZE / 2.0
	_tip.rotation = PI / 4.0
	_tip.color = COLOR
	boss.add_child(_tip)
	_place_tip()
	Sfx.play("chain")


func update(delta: float):
	timer -= delta
	var target = boss.target_player
	match phase:
		Phase.THROW:
			var to_target = target.global_position - _tip_pos
			if to_target.length() <= HOOK_SPEED * delta:
				_tip_pos = target.global_position
				_shut_point = _tip_pos
				_close_time = 0.0
				phase = Phase.CLOSING
			elif timer <= 0.0:
				_retract(finish.bind(WHIFF_RECOVER_TIME))
			else:
				_tip_pos += to_target.normalized() * HOOK_SPEED * delta
			_place_tip()

		Phase.CLOSING:
			# Shut where the target was; a late dash slips out of it.
			_close_time += delta
			_place_tip()
			if _close_time >= DODGE_LATE_WINDOW:
				if target.is_perfect_dodge():
					_dodged()
				else:
					_catch()

		Phase.RETRACT:
			var t = 1.0 - clampf(timer / RETRACT_TIME, 0.0, 1.0)
			_tip_pos = _shut_point.lerp(boss.global_position, ease(t, 0.5))
			_place_tip()
			if timer <= 0.0:
				_finish_after_retract.call()

		Phase.REEL:
			_update_reel(delta)


func get_marker(telegraphing: bool):
	if phase == Phase.REEL:
		# "Your turn": the partner who can cut the chain.
		if _helper:
			return {"who": _helper, "color": COLOR_RESCUE if fmod(boss.anim_time, 0.2) < 0.1 else Color.WHITE}
		return null
	if telegraphing or phase in [Phase.THROW, Phase.CLOSING]:
		return {"who": boss.target_player}
	return null


func cleanup():
	if _tip:
		_tip.queue_free()
		_tip = null
	_release()
	_helper = null


# --- Throw, dodge, catch ---

func _place_tip():
	_tip.global_position = _tip_pos - TIP_SIZE / 2.0
	boss.draw_chain(boss.global_position, _tip_pos, COLOR)


func _retract(then: Callable):
	phase = Phase.RETRACT
	timer = RETRACT_TIME
	_shut_point = _tip_pos
	_finish_after_retract = then


func _dodged():
	boss.target_player.on_grab_dodged()
	hook_dodged.emit()
	boss.shake(3.0)
	Sfx.play("chain", -3.0)
	_retract(finish_with_stagger.bind(TUMBLE_TIME, true))


func _catch():
	_victim = boss.target_player
	_helper = boss.partner_of(_victim)
	_victim.set_grabbed(true)
	_hits = 0
	_last_serial = _helper.swing_serial if _helper else -1
	_pivot_from = boss.global_position
	var rel = _victim.global_position - _pivot_from
	_length = rel.length()
	_length_from = _length
	_theta = atan2(rel.x, rel.y)
	_theta_from = _theta
	_omega = 0.0
	_reel_elapsed = 0.0
	phase = Phase.REEL
	boss.shake(5.0)
	Sfx.play("chain")


# --- Dangling: reeled up toward the beam, unless the partner cuts the chain ---

func _update_reel(delta: float):
	_reel_elapsed += delta
	var r = clampf(_reel_elapsed / REEL_TIME, 0.0, 1.0)
	boss.global_position = _pivot_from.lerp(REEL_TOP, ease(r, 0.6))

	var limit = DANGLE_MAX_ANGLE
	if _reel_elapsed < YANK_TIME:
		# Yanked off their feet: in to the dangle's length and swung in under the sphere.
		var y = ease(_reel_elapsed / YANK_TIME, 0.5)
		_length = lerpf(_length_from, DANGLE_LENGTH, y)
		limit = lerpf(maxf(absf(_theta_from), DANGLE_MAX_ANGLE), DANGLE_MAX_ANGLE, y)
	else:
		_length = lerpf(DANGLE_LENGTH, CRUSH_LENGTH, r)
	# A pendulum the hooked player pumps with left/right.
	var pump = _victim.move_axis() * DANGLE_PUMP
	_omega += (-DANGLE_GRAVITY * sin(_theta) + pump) / maxf(_length, 1.0) * delta
	_omega *= 1.0 - DANGLE_DAMPING * delta
	_theta += _omega * delta
	if absf(_theta) > limit:
		_theta = signf(_theta) * limit
		_omega *= -0.3
	var at = boss.global_position + Vector2(sin(_theta), cos(_theta)) * _length
	_victim.global_position = at
	_tip_pos = at
	_place_tip()

	if _check_rescue(at):
		return
	if r >= 1.0:
		_crush()


# True if the partner's blade cut the chain this frame (the attack is over).
func _check_rescue(at: Vector2) -> bool:
	if _helper == null or not is_instance_valid(_helper):
		return false
	var point = _helper.active_sword_point()
	if point == null or _helper.swing_serial == _last_serial:
		return false
	var on_chain = Geometry2D.get_closest_point_to_segment(point, boss.global_position, at)
	if on_chain.distance_to(point) > CHAIN_HIT_RADIUS:
		return false
	_last_serial = _helper.swing_serial  # one hit per swing
	_hits += 1
	boss.spawn_sparks(on_chain, 10, COLOR_RESCUE)
	boss.shake(4.0)
	Sfx.play("parry")
	if _hits < RESCUE_HITS:
		return false
	# Cut: the hooked player drops free, with their air moves back to reach a pan.
	var freed = _victim
	_release()
	freed.velocity = Vector2(0.0, RESCUE_HOP)
	freed.refresh_air_moves()
	hook_rescued.emit()
	Sfx.play("parry_strong")
	boss.shake(8.0)
	finish_with_stagger(RESCUE_RECOIL_TIME)
	return true


func _crush():
	var victim = _victim
	_release()
	var side = boss.scales.higher_side()
	var dir = signf(Scales.RESPAWN_X[side] - victim.global_position.x)
	victim.take_damage(CRUSH_DAMAGE, Vector2(dir * CRUSH_KNOCKBACK.x, CRUSH_KNOCKBACK.y), false, true)
	boss.shake(10.0)
	Sfx.play("thunk")
	finish(RECOVER_TIME)


func _release():
	if _victim and is_instance_valid(_victim) and _victim.is_grabbed:
		_victim.set_grabbed(false)
	_victim = null
