class_name TripleStab
extends Attack
## Yellow -> red. Leans back and draws the sword straight back, level and a
## little below his middle, then lunges at one player and stabs three times in quick
## succession, thrusting the blade straight out like a spear. Each stab must be perfect parried; a stab that lands staggers the target, so every stab after it lands too.
## Parry all three and the target locks blades with him: a short clash in which the partner
## can strike him into a stagger.

signal stab_parried(player)
signal clash_started
signal clash_countered

enum Phase { NONE, APPROACH, STABS, CLASH }

# --- Tuning ---
const STAB_INTERVAL = 0.25  # between stab contacts
const TELEGRAPH_TIME = 1.0  # seconds of warning before the lunge
const APPROACH_TIME = 0.25  # the lunge to the target
const APPROACH_POWER = 2.2  # the lunge starts slow and arrives fast (1 = constant speed)
const REAR_BACK = 10.0  # leaning away from the target during the telegraph (no crouch: it's a dash)
const LUNGE_STRETCH = Vector2(1.3, 0.8)
const THRUST_POWER = 2.0  # each stab accelerates out to full extension
const STRIKE_DISTANCE = 70.0  # how far from the target he stops to stab (center to center)
const TRACKING = 0.25  # how hard he follows a moving target between stabs (0..1 per frame)
const STAB_COUNT = 3
const STAB_EXTEND_TIME = 0.06  # thrust out; the stab connects at full extension
const STAB_DAMAGE = 12.0
const HIT_STAGGER_TIME = 0.3  # the target can't act; longer than the interval, so the chain lands
const CLASH_TIME = 0.6  # the partner's opening after all three stabs are parried
const CLASH_STAGGER_TIME = 1.2  # when the partner lands the hit
const RECOVER_TIME = 0.45  # any stab missed, or the clash ran out

const COLOR = Color.YELLOW
const COLOR_CLASH = Color(1.0, 0.95, 0.6)
const CLASH_BAR_WIDTH = 80.0

# Sword poses: where its pivot sits, relative to his center, for a boss facing right. The blade
# stays level, pointing at the target, and slides back and forth like a spear. y > 0 is below
# his middle (the stab height lines up with the player's center when they're both grounded).
const DRAWN_BACK_OFFSET = Vector2(-45.0, 14.0)  # pulled back at the end of the windup
const RETRACTED_OFFSET = Vector2(-20.0, 14.0)  # pulled back between stabs
const THRUST_OFFSET = Vector2(25.0, 14.0)  # full extension, when the stab connects

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
	return "TRIPLE_STAB"


func get_telegraph_color() -> Color:
	return COLOR


func get_telegraph_duration() -> float:
	return TELEGRAPH_TIME


func update_telegraph(progress: float):
	boss.face(boss.target_player.global_position.x)
	# Level the blade and draw it straight back, quickly, then hold it there under tension.
	var draw = ease(progress, 0.4)
	boss.set_sword_offset(Vector2.ZERO.lerp(DRAWN_BACK_OFFSET, draw))
	boss.set_sword_angle(lerpf(boss.SWORD_REST_ANGLE, 0.0, draw))
	# Rear back from the target, quivering harder as the strike approaches.
	var lean = ease(progress, 1.6)
	var shake = 3.0 * progress
	boss.squash_body(Vector2.ONE, -boss.facing * REAR_BACK * lean + randf_range(-shake, shake))
	boss.set_glow(COLOR, 0.25)


func execute():
	phase = Phase.APPROACH
	timer = APPROACH_TIME
	_parried = 0
	_lunge_from = boss.global_position
	_lunge_side = signf(boss.global_position.x - boss.target_player.global_position.x)
	if _lunge_side == 0.0:
		_lunge_side = 1.0
	boss.pop_body(LUNGE_STRETCH, 0.25)


func update(delta: float):
	timer -= delta
	match phase:
		Phase.APPROACH:
			var t = 1.0 - clampf(timer / APPROACH_TIME, 0.0, 1.0)
			boss.global_position = _lunge_from.lerp(_strike_point(), pow(t, APPROACH_POWER))
			boss.face(boss.target_player.global_position.x)
			# The sword stays drawn back through the lunge; the first stab thrusts from there.
			boss.set_sword_offset(DRAWN_BACK_OFFSET)
			boss.set_sword_angle(0.0)
			if timer <= 0.0:
				phase = Phase.STABS
				_stab = 0
				_start_stab(0.0)

		Phase.STABS:
			_stab_time += delta
			# Stay on the target through the whole chain.
			boss.global_position = boss.global_position.lerp(_strike_point(), TRACKING)
			boss.face(boss.target_player.global_position.x)
			# Thrust out from where the blade is pulled back to, then pull back for the next one.
			var extend = pow(clampf(_stab_time / STAB_EXTEND_TIME, 0.0, 1.0), THRUST_POWER)
			var retract = ease(clampf((_stab_time - STAB_EXTEND_TIME) / (STAB_INTERVAL - STAB_EXTEND_TIME), 0.0, 1.0), 0.5)
			var from = DRAWN_BACK_OFFSET if _stab == 0 else RETRACTED_OFFSET
			boss.set_sword_offset(from.lerp(THRUST_OFFSET, extend).lerp(RETRACTED_OFFSET, retract))
			boss.set_sword_angle(0.0)
			if not _contact_done and _stab_time >= STAB_EXTEND_TIME:
				_contact_done = true
				_stab_contact(boss.target_player)
			if _stab_time >= STAB_INTERVAL:
				_stab += 1
				if _stab < STAB_COUNT:
					_start_stab(_stab_time - STAB_INTERVAL)  # carry the remainder: keep the beat exact
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


# --- The stabs ---

# Where Cubus Maximus stands to stab the target, on the side he lunged in from. Bottoms level
# with each other (he's taller than the player), so he stands on the floor rather than in it.
func _strike_point() -> Vector2:
	var target = boss.target_player
	var height_gap = (boss.body.size.y - target.body.size.y) / 2.0
	return target.global_position + Vector2(_lunge_side * STRIKE_DISTANCE, -height_gap)


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
		parry_success.emit(target, "triple_stab")
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
	boss.set_sword_offset(RETRACTED_OFFSET)
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
