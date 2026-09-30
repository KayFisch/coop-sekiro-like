class_name Grab
extends Attack
## Purple -> red. Cubus Maximus charges at one player, homing in all the way. Once he's on
## them, he lets go of his sword and his hands scoop in from both sides, tracking the target
## until they close. It can't be blocked: the target escapes only by dashing (either way, even
## into him) as the hands reach them, slipping out of his grasp, which leaves him tumbling.
## A caught player is lifted overhead as he jumps, carried down, and thrown steeply into the
## floor for the last stretch, bouncing off it toward the side of the arena with more room.

signal grab_dodged

enum Phase { NONE, GRAB_WINDUP, GRAB_CHARGE, GRAB_REACH, GRAB_CLAP, GRAB_LIFT, GRAB_APEX, GRAB_SLAM }

# --- Tuning ---
const TELEGRAPH_TIME = 0.9
const WINDUP_TIME = 0.25  # red lean-back before the charge (no crouch: he dashes, not jumps)
const WINDUP_REAR_BACK = 10.0  # leaning away from the target
const CHARGE_STRETCH = Vector2(1.3, 0.8)
# The charge: homing straight at the target until he's close enough to reach for them. It
# bursts off from CHARGE_START_SPEED and accelerates up to CHARGE_SPEED.
const CHARGE_START_SPEED = 300.0
const CHARGE_ACCEL = 6000.0
const CHARGE_SPEED = 1300.0  # faster than a dash: you can't outrun it, only slip the hands
const CHARGE_MAX_TIME = 0.8  # gives up after this long (e.g. the target is out of reach)
const WHIFF_RECOVER_TIME = 0.4
const REACH_DISTANCE = 85.0  # center-to-center distance at which he stops and reaches
const FOLLOW_SPEED = 500.0  # keeping up with the target while the hands close
# The hands: they start out wide and low and scoop in, tracking the target exactly.
const CLOSE_TIME = 0.4  # from reaching out until the hands meet the target
const HAND_OPEN_OFFSET = Vector2(75.0, 18.0)  # from the target's center (x mirrors per hand)
# The dodge window: a dash slips out of the grasp if pressed from DODGE_TOLERANCE (player.gd)
# before the dodge is judged, up to the judgment. The judgment comes DODGE_LATE_WINDOW after the
# hands shut, so the window runs from (DODGE_TOLERANCE - DODGE_LATE_WINDOW) before the hands
# meet the target to DODGE_LATE_WINDOW after. Raise it if the window feels too early.
const DODGE_LATE_WINDOW = 0.07
const CLAP_TIME = 0.12  # the hands snapping shut on empty air after a dodge
const DUST_COUNT = 8  # specks puffing out of the clap
const DUST_COLOR = Color(0.75, 0.75, 0.8)
const TUMBLE_TIME = 0.8  # his stagger after a dodged grab
# The slam: jump up with the target held overhead, come down, throw them the last stretch.
const LIFT_TIME = 0.35
const JUMP_HEIGHT = 180.0
const MIN_JUMP_TOP_Y = 160.0  # never jumps higher than this (keeps the held player on screen)
const APEX_TIME = 0.12  # held overhead at the top
const SLAM_GRAVITY = 5000.0  # his fall's acceleration
const WIND_BACK = Vector2(22.0, 14.0)  # held player pulled back over his head as he falls
const THROW_HEIGHT = 45.0  # he lets go this far above his landing spot
const THROW_SWING_TIME = 0.12  # hands whipping forward and down through the throw
const THROW_SWING_END = Vector2(70.0, 12.0)  # hands' end point, from his center (x toward the throw)
const THROW_TILT = 0.2  # his body leans into the throw (radians)
# The thrown player's flight: hurled almost straight down, so they hit the floor fast at a slight
# angle; only the bounce off the floor carries them away (toward the roomier side). They pass
# through the one-way platforms; only the floor stops them.
const THROW_VELOCITY = Vector2(250.0, 1500.0)  # x: sideways, y: down. More x = a flatter angle
const BOUNCE_SPEED = 450.0  # sideways speed off the floor: how far the bounce carries them
const BOUNCE_HEIGHT = 90.0  # how high (px) the bounce off the floor lifts them
const GET_UP_TIME = 0.1  # once they land from the bounce, they're back in control this fast
const DAMAGE = 40.0  # dealt when the thrown player hits the floor
const LAND_HOLD_TIME = 0.15  # follow-through pose after landing
# He stays where he landed, straightening up, until the thrown player is back on their feet,
# and then this long, before heading back to the middle.
const RETURN_DELAY = 0.3
const STRAIGHTEN_SPEED = 1.5  # how fast his throw tilt eases off while he waits (radians/s)
const RECOVER_TIME = 0.45  # after the slam

const COLOR = Color(0.62, 0.2, 0.95)

var _charge_speed = CHARGE_START_SPEED
var _reach_time = 0.0  # time since the hands started reaching
var _shut_point = Vector2.ZERO  # the target's center when the hands shut
var _clap_point = Vector2.ZERO  # where the hands snap shut after a dodge
var _clap_from: Array = []  # hand positions when the clap started
var _held_offset = Vector2.ZERO  # target's offset from him when caught, eased overhead in the lift
var _lift_from_y = 0.0
var _fall_from_y = 0.0
var _fall_speed = 0.0
var _throw_side = 1.0
var _swing_time = -1.0  # time since the throw, < 0 before it
var _swing_from: Array = []  # hand offsets from him when the throw started
var _land_time = -1.0  # time since landing, < 0 before it
var _victim_up_time = 0.0  # time since the thrown player got back up


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
			boss.face(target.global_position.x)
			var coil = ease(1.0 - clampf(timer / WINDUP_TIME, 0.0, 1.0), 0.6)
			boss.squash_body(Vector2.ONE, -boss.facing * WINDUP_REAR_BACK * coil)
			if timer <= 0.0:
				phase = Phase.GRAB_CHARGE
				timer = CHARGE_MAX_TIME
				_charge_speed = CHARGE_START_SPEED
				boss.pop_body(CHARGE_STRETCH, 0.25)

		Phase.GRAB_CHARGE:
			boss.face(target.global_position.x)
			_charge_speed = minf(_charge_speed + CHARGE_ACCEL * delta, CHARGE_SPEED)
			var to_target = _reach_spot() - boss.global_position
			if to_target.length() <= _charge_speed * delta:
				boss.global_position = _reach_spot()
				_start_reach()
			elif timer <= 0.0:
				finish(WHIFF_RECOVER_TIME)
			else:
				boss.velocity = to_target.normalized() * _charge_speed
				boss.move_and_slide()

		Phase.GRAB_REACH:
			_reach_time += delta
			if _reach_time < CLOSE_TIME:
				# Scooping in, tracking the target.
				boss.global_position = boss.global_position.move_toward(_reach_spot(), FOLLOW_SPEED * delta)
				_place_open_hands(_reach_time / CLOSE_TIME, target.global_position)
				_shut_point = target.global_position
			else:
				# Shut where the target was; a late dash slips out from between them.
				_place_open_hands(1.0, _shut_point)
			# Judged once, a moment after the hands shut.
			if _reach_time >= CLOSE_TIME + DODGE_LATE_WINDOW:
				if target.is_perfect_dodge():
					_dodged()
				else:
					_catch()

		Phase.GRAB_CLAP:
			var t = 1.0 - clampf(timer / CLAP_TIME, 0.0, 1.0)
			for i in 2:
				boss.place_hand(i, _clap_from[i].lerp(_clap_point + _hand_side(i) * Vector2(boss.hands[i].size.x / 2, 0.0), ease(t, 2.0)))
			if timer <= 0.0:
				# Shut on nothing: a clap and a puff of dust.
				Sfx.play("clap")
				_spawn_dust(_clap_point)
				finish_with_stagger(TUMBLE_TIME, true)

		Phase.GRAB_LIFT:
			var t = 1.0 - clampf(timer / LIFT_TIME, 0.0, 1.0)
			var top_y = minf(_lift_from_y, maxf(_lift_from_y - JUMP_HEIGHT, MIN_JUMP_TOP_Y))
			boss.global_position.y = lerpf(_lift_from_y, top_y, ease(t, 0.4))
			_hold(_held_offset.lerp(_overhead_offset(), ease(minf(t * 1.5, 1.0), 0.5)))
			if timer <= 0.0:
				phase = Phase.GRAB_APEX
				timer = APEX_TIME

		Phase.GRAB_APEX:
			_hold(_overhead_offset())
			if timer <= 0.0:
				phase = Phase.GRAB_SLAM
				_fall_speed = 0.0
				_fall_from_y = boss.global_position.y
				_swing_time = -1.0
				_land_time = -1.0
				_victim_up_time = 0.0
				var room_left = boss.global_position.x - boss.ARENA_LEFT
				var room_right = boss.ARENA_RIGHT - boss.global_position.x
				_throw_side = 1.0 if room_right >= room_left else -1.0

		Phase.GRAB_SLAM:
			_update_slam(delta)


func get_marker(telegraphing: bool):
	if telegraphing or phase in [Phase.GRAB_WINDUP, Phase.GRAB_CHARGE, Phase.GRAB_REACH]:
		return {"who": boss.target_player}
	return null


func cleanup():
	_release()
	boss.hands_free = false
	boss.body.rotation = 0.0


# --- Charging in and reaching ---

# Where he stands to reach for the target: beside them, on his side.
func _reach_spot() -> Vector2:
	var target = boss.target_player
	var at = target.global_position
	var side = signf(at.x - boss.global_position.x)
	if side == 0.0:
		side = boss.facing
	# Bottoms level with each other: he's taller than the player.
	return Vector2(at.x - side * REACH_DISTANCE, at.y - (boss.body.size.y - target.body.size.y) / 2.0)


func _start_reach():
	phase = Phase.GRAB_REACH
	boss.velocity = Vector2.ZERO
	boss.hands_free = true
	boss.reset_sword()
	_reach_time = 0.0
	_shut_point = boss.target_player.global_position
	_place_open_hands(0.0, _shut_point)
	boss.shake(2.0)


# -1 for the hand on the target's left, 1 for the one on their right.
func _hand_side(index: int) -> float:
	return -1.0 if index == 0 else 1.0


# Hands scooping in on a target centered at `center`: wide and low at t = 0, pressed against
# their sides at t = 1.
func _place_open_hands(t: float, center: Vector2):
	var target = boss.target_player
	var eased = ease(t, 1.8)  # slow start, snapping shut
	for i in 2:
		var side = _hand_side(i)
		var closed = Vector2(side * (target.body.size.x / 2.0 + boss.hands[i].size.x / 2.0), 0.0)
		var open = Vector2(side * HAND_OPEN_OFFSET.x, HAND_OPEN_OFFSET.y)
		boss.place_hand(i, center + open.lerp(closed, eased), side * 0.4 * (1.0 - eased))


func _dodged():
	boss.body.color = boss.COLOR_EXECUTE
	boss.target_player.on_grab_dodged(true)
	grab_dodged.emit()
	boss.shake(3.0)
	# The hands snap shut on the spot the target just slipped out of. If the dash left them close
	# to it (a dash into his body stops short), they shut just behind them: always on empty air.
	phase = Phase.GRAB_CLAP
	timer = CLAP_TIME
	_clap_point = _shut_point
	var target = boss.target_player
	var clear = target.body.size.x / 2.0 + boss.hands[0].size.x
	var moved = target.global_position.x - _shut_point.x
	if absf(moved) < clear:
		var away = signf(moved) if moved != 0.0 else signf(target.global_position.x - boss.global_position.x)
		_clap_point.x = target.global_position.x - away * clear
	_clap_from = [boss.hands[0].global_position + boss.hands[0].size / 2,
		boss.hands[1].global_position + boss.hands[1].size / 2]


func _catch():
	var target = boss.target_player
	boss.body.color = boss.COLOR_EXECUTE
	target.set_grabbed(true)
	boss.shake(5.0)
	_held_offset = target.global_position - boss.global_position
	_lift_from_y = boss.global_position.y
	phase = Phase.GRAB_LIFT
	timer = LIFT_TIME


# --- Lift and slam ---

func _overhead_offset() -> Vector2:
	return Vector2(0.0, -(boss.body.size.y / 2.0 + boss.target_player.body.size.y / 2.0 + 6.0))


# Keeps the caught player at an offset from him, a hand pressed to each side.
func _hold(offset: Vector2):
	var target = boss.target_player
	target.global_position = boss.global_position + offset
	for i in 2:
		var side = _hand_side(i)
		boss.place_hand(i, target.global_position + Vector2(side * (target.body.size.x / 2.0 + boss.hands[i].size.x / 2.0), 0.0))


func _update_slam(delta: float):
	var ground_y = boss.home_position.y
	var throw_y = ground_y - THROW_HEIGHT
	if _land_time < 0.0:
		_fall_speed += SLAM_GRAVITY * delta
		boss.global_position.y = minf(boss.global_position.y + _fall_speed * delta, ground_y)

	if _swing_time < 0.0:
		# Coming down with the target overhead, pulling them back behind his head for the throw.
		var span = maxf(throw_y - _fall_from_y, 1.0)
		var t = clampf((boss.global_position.y - _fall_from_y) / span, 0.0, 1.0)
		var back = Vector2(-_throw_side * WIND_BACK.x, -WIND_BACK.y) * ease(t, 0.6)
		_hold(_overhead_offset() + back)
		if boss.global_position.y >= throw_y:
			_throw()
	else:
		# The throw: hands whip forward and down, his body leaning into it.
		var swinging = _swing_time < THROW_SWING_TIME
		_swing_time += delta
		var t = ease(clampf(_swing_time / THROW_SWING_TIME, 0.0, 1.0), 0.5)
		for i in 2:
			var end = Vector2(_throw_side * THROW_SWING_END.x + _hand_side(i) * 12.0, THROW_SWING_END.y)
			boss.place_hand(i, boss.global_position + _swing_from[i].lerp(end, t))
		if swinging:  # afterwards, he straightens up (see below)
			boss.body.rotation = _throw_side * THROW_TILT * t

	if _land_time < 0.0 and boss.global_position.y >= ground_y:
		_land_time = 0.0
		boss.shake(8.0)
		boss.pop_body(Vector2(1.3, 0.7), 0.3)
	elif _land_time >= 0.0:
		_land_time += delta
		if _land_time >= LAND_HOLD_TIME and _swing_time >= THROW_SWING_TIME:
			# Straighten up and watch the thrown player land before heading back.
			boss.body.rotation = move_toward(boss.body.rotation, 0.0, STRAIGHTEN_SPEED * delta)
			if boss.target_player.is_tumbling():
				_victim_up_time = 0.0
			else:
				_victim_up_time += delta
				if _victim_up_time >= RETURN_DELAY:
					finish(RECOVER_TIME)


# Let go the last stretch down, hurling the target into the floor toward the roomier side.
# The floor impact (damage, bounce, getting up) is handled by the player's tumble.
func _throw():
	var victim = boss.target_player
	_swing_from = []
	for hand in boss.hands:
		_swing_from.append(hand.global_position + hand.size / 2 - boss.global_position)
	_swing_time = 0.0
	_release()
	victim.tumble(Vector2(_throw_side * THROW_VELOCITY.x, THROW_VELOCITY.y), DAMAGE,
		Vector2(_throw_side * BOUNCE_SPEED, BOUNCE_HEIGHT), GET_UP_TIME)
	Sfx.play("slash")
	boss.shake(4.0)


func _release():
	var target = boss.target_player
	if target and target.is_grabbed:
		target.set_grabbed(false)


# Grey specks puffing out where the hands met.
func _spawn_dust(point: Vector2):
	for i in DUST_COUNT:
		var speck = ColorRect.new()
		speck.top_level = true
		speck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speck.size = Vector2(4, 4)
		speck.color = DUST_COLOR
		boss.add_child(speck)
		speck.global_position = point
		var fly = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 60.0)
		var tween = speck.create_tween().set_parallel()
		tween.tween_property(speck, "global_position", point + fly, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(speck, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(speck.queue_free)
