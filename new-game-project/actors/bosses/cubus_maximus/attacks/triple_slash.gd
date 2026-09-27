class_name TripleSlash
extends Attack
## Yellow -> red. Winds up like the sword relay, but with the sword drawn back behind him,
## then lunges at one player and stabs three times in quick succession. Each stab must be
## perfect parried; a stab that lands staggers the target, so every stab after it lands too.
## Parry all three and the target locks blades with him: a short clash in which the partner
## can strike him into a stagger.

signal stab_parried(player)
signal clash_started
signal clash_countered

enum Phase { NONE, APPROACH, STABS, CLASH }

# --- Tuning ---
const TRIPLE_SLASH_INTERVAL = 0.25  # between stab contacts
const TELEGRAPH_TIME = 1.0  # seconds of warning before the lunge
const APPROACH_TIME = 0.25  # the lunge to the target
const STRIKE_DISTANCE = 70.0  # how far from the target he stops to stab
const TRACKING = 0.25  # how hard he follows a moving target between stabs (0..1 per frame)
const STAB_COUNT = 3
const STAB_EXTEND_TIME = 0.06  # thrust out; the stab connects at full extension
const STAB_DAMAGE = 12.0
const HIT_STAGGER_TIME = 0.3  # the target can't act; longer than the interval, so the chain lands
const CLASH_TIME = 0.6  # the partner's opening after all three stabs are parried
const CLASH_STAGGER_TIME = 1.2  # when the partner lands the hit
const RECOVER_TIME = 0.8  # any stab missed, or the clash ran out

const COLOR = Color.YELLOW
const COLOR_CLASH = Color(1.0, 0.95, 0.6)
const CLASH_BAR_WIDTH = 80.0

# Sword pose, for a boss facing right: drawn back behind him, low (the relay raises it overhead).
const DRAWN_BACK_ANGLE = PI - 0.35
const UNDERSWING_PULL = 0.65  # the blade pulls in as it passes under him, clear of the floor
const RETRACTED_SCALE = 0.6  # blade pulled in between stabs
const EXTENDED_SCALE = 1.25  # blade at full thrust

var _lunge_from = Vector2.ZERO
var _lunge_side = 1.0
var _stab = 0  # index of the stab in progress
var _stab_time = 0.0  # time into the current stab
var _contact_done = false
var _parried = 0
var _holder = null  # the target, locked in the clash
var _helper = null  # the partner, who gets the opening
var _clash_bar: ColorRect
var _hum = null  # Sfx handle


func get_attack_name() -> String:
	return "TRIPLE_SLASH"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func update_telegraph(progress: float):
	boss.face(boss.target_player.global_position.x)
	_pose_sword(progress, boss.SWORD_REST_ANGLE, 1.0)
	# Quiver harder as the strike approaches, like the relay.
	var shake = 3.0 * progress
	boss.body.position = boss.body_rest + Vector2(randf_range(-shake, shake), 0.0)
	boss.set_glow(COLOR, 0.25)


func execute():
	phase = Phase.APPROACH
	timer = APPROACH_TIME
	_parried = 0
	_lunge_from = boss.global_position
	_lunge_side = signf(boss.global_position.x - boss.target_player.global_position.x)
	if _lunge_side == 0.0:
		_lunge_side = 1.0


func update(delta: float):
	timer -= delta
	match phase:
		Phase.APPROACH:
			var t = 1.0 - clampf(timer / APPROACH_TIME, 0.0, 1.0)
			boss.global_position = _lunge_from.lerp(_strike_point(), ease(t, 0.4))
			boss.face(boss.target_player.global_position.x)
			# Hold the sword back, then bring it around to point at the target for the first stab.
			var turn = clampf((t - 0.6) / 0.4, 0.0, 1.0)
			_pose_sword(1.0 - turn, 0.0, RETRACTED_SCALE)
			if timer <= 0.0:
				phase = Phase.STABS
				_stab = 0
				_start_stab(0.0)

		Phase.STABS:
			_stab_time += delta
			# Stay on the target through the whole chain.
			boss.global_position = boss.global_position.lerp(_strike_point(), TRACKING)
			boss.face(boss.target_player.global_position.x)
			var extend = clampf(_stab_time / STAB_EXTEND_TIME, 0.0, 1.0)
			var retract = clampf((_stab_time - STAB_EXTEND_TIME) / (TRIPLE_SLASH_INTERVAL - STAB_EXTEND_TIME), 0.0, 1.0)
			boss.sword_scale.x = lerpf(lerpf(RETRACTED_SCALE, EXTENDED_SCALE, extend), RETRACTED_SCALE, retract)
			boss.set_sword_angle(0.0)
			if not _contact_done and _stab_time >= STAB_EXTEND_TIME:
				_contact_done = true
				_stab_contact(boss.target_player)
			if _stab_time >= TRIPLE_SLASH_INTERVAL:
				_stab += 1
				if _stab < STAB_COUNT:
					_start_stab(_stab_time - TRIPLE_SLASH_INTERVAL)  # carry the remainder: keep the beat exact
				elif _parried == STAB_COUNT:
					_start_clash()
				else:
					finish(RECOVER_TIME)

		Phase.CLASH:
			_process_clash()
			if timer <= 0.0:
				# Nobody took the opening: he pulls free and recovers normally.
				_end_clash()
				finish(RECOVER_TIME)


func get_marker(telegraphing: bool):
	if phase == Phase.CLASH:
		# "Your turn": point at the partner who can strike him now.
		if _helper:
			return {"who": _helper, "color": COLOR_CLASH if fmod(boss.anim_time, 0.2) < 0.1 else Color.WHITE}
		return null
	if telegraphing or phase in [Phase.APPROACH, Phase.STABS]:
		return {"who": boss.target_player}
	return null


func on_struck(player):
	if phase == Phase.CLASH and player == _helper:
		_countered()


func cleanup():
	_end_clash()  # never leave a player locked in a clash
	_holder = null
	_helper = null


# Swings the sword between from_angle (back = 0) and drawn back behind him (back = 1), low.
func _pose_sword(back: float, from_angle: float, from_scale: float):
	boss.sword_scale.x = lerpf(from_scale, 1.0, back) * (1.0 - UNDERSWING_PULL * sin(PI * back))
	boss.set_sword_angle(lerpf(from_angle, DRAWN_BACK_ANGLE, back))


# --- The stabs ---

# Where Cubus Maximus stands to stab the target, on the side he lunged in from.
func _strike_point() -> Vector2:
	return boss.target_player.global_position + Vector2(_lunge_side * STRIKE_DISTANCE, 0.0)


func _start_stab(elapsed: float):
	_stab_time = elapsed
	_contact_done = false
	Sfx.play("stab", -1.0)


func _stab_contact(target):
	if target.is_staggered():
		_stab_hit(target)  # still reeling from the last stab: this one lands whatever they press
	elif not target in boss.sword_hitbox.get_overlapping_bodies():
		return  # whiffed; no hit, but the clash is lost
	elif target.is_perfect_parry():
		_parried += 1
		target.on_perfect_parry(_stab == STAB_COUNT - 1)
		parry_success.emit(target, "triple_slash")
		stab_parried.emit(target)
		boss.shake(3.0)
	else:
		_stab_hit(target)


func _stab_hit(target):
	target.take_damage(STAB_DAMAGE, Vector2.ZERO, false, true)  # stabs come faster than invulnerability
	target.stagger(HIT_STAGGER_TIME)
	boss.shake(5.0)


# --- The clash: blades locked, the partner's opening ---

func _start_clash():
	phase = Phase.CLASH
	timer = CLASH_TIME
	_holder = boss.target_player
	_helper = boss.partner_of(_holder)
	var side = signf(boss.global_position.x - _holder.global_position.x)
	_holder.facing = side if side != 0.0 else 1.0
	_holder.set_clashing(true, false)
	boss.sword_scale.x = 1.0
	boss.set_sword_angle(0.0)
	boss.shake(6.0)
	clash_started.emit()
	_hum = Sfx.play("clash_hum", -2.0)
	# Shrinking window bar over him: how long the partner has.
	_clash_bar = ColorRect.new()
	_clash_bar.top_level = true
	_clash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clash_bar.color = Color.WHITE
	boss.add_child(_clash_bar)


func _process_clash():
	var left = clampf(timer / CLASH_TIME, 0.0, 1.0)
	var flash = fmod(boss.anim_time, 0.1) < 0.05
	boss.body.color = COLOR_CLASH if flash else Color.WHITE
	boss.body.position = boss.body_rest + Vector2(randf_range(-2.0, 2.0), randf_range(-1.5, 1.5))
	boss.set_glow(COLOR_CLASH, 0.3 + 0.3 * (1.0 - left))
	var width = CLASH_BAR_WIDTH * left
	_clash_bar.size = Vector2(width, 5.0)
	_clash_bar.global_position = boss.global_position + Vector2(-width / 2, -62.0)


func _end_clash():
	Sfx.stop(_hum)
	_hum = null
	if _clash_bar:
		_clash_bar.queue_free()
		_clash_bar = null
	if _holder and is_instance_valid(_holder):
		_holder.set_clashing(false)
	boss.body.position = boss.body_rest


# The partner struck him mid-clash; the sword hit's damage has already been dealt.
func _countered():
	_end_clash()
	clash_countered.emit()
	Sfx.play("counter_hit", 2.0)
	boss.shake(12.0)
	finish_with_stagger(CLASH_STAGGER_TIME)
