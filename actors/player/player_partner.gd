class_name PlayerPartner
extends PlayerWalls
## A player, part 4 of 5: moves with the partner. The launch, the pogo clash, the relay (a bar of
## the clock: let go, parry, strike, throw) and the tell, the ring that shows the partner when to
## press. Part 3, walls and ledges: player_walls.gd. Part 5, the player itself: player.gd.

signal launched(player)  # sent up by a partner's upslash (see _check_clashes())
signal relayed(player)  # the blades locked with a partner's parry, on a relay's beat 2 (see _start_relay())
signal pogo_clashed(player)  # bounced off a partner's upslash (see _pogo_clash())

# Held in place for a moment by a clash with the partner (see _begin_hold()).
enum Hold { NONE, RELAY_DASHER, RELAY_ANCHOR }

# THE TELL: a dash-slash headed at the partner puts a ring in the dasher's color around them,
# shrinking at a steady rate and closing TELL_LEAD before the blades meet: the moment to press
# (block for a relay, upslash for a launch; inside both windows). The contact is predicted every
# frame (see predict_contact()). A short sound ends on the close.
const TELL_LEAD = 0.08
const TELL_CLOSED_RADIUS = 30.0  # just around the partner's body
const TELL_SHRINK_SPEED = 380.0  # px/s
const TELL_WIDTH = 3.0
const TELL_FADE = 0.15  # fading out once the dash-slash is over
const TELL_SOUND_TIME = 0.12  # the sound's length (see "tell" in sfx.gd): started this long before the close
# LAUNCH: a dash-slash that runs into the partner's upslash clashes the two blades, and the
# dash's momentum is turned upward: the dashing player shoots up, keeping only a sliver of
# their sideways speed. The upslash must come at most LAUNCH_TOLERANCE before the blades meet
# (like a parry), or while the dash-slash is still passing through.
const LAUNCH_TOLERANCE = 0.15
const LAUNCH_REACH = Vector2(70.0, 50.0)  # center-to-center distance at which the blades meet
const LAUNCH_HEIGHT = 340.0  # 2.5x a jump
const LAUNCH_CARRY = 0.15  # fraction of the dash's sideways speed kept (~150 px/s)
const LAUNCH_STRETCH = Vector2(0.7, 1.4)
const LAUNCH_STRETCH_TIME = 0.3
# RELAY (Moves "relay"): a dash-slash into a partner who parries it, as a bar of the clock (Beat),
# the partners taking turns: 1 the dasher lets go, 2 the anchor's parry (the blades lock), 3 the
# anchor's strike, which throws the dasher the way the anchor's stick points (4 ways: up, down,
# left, right; none: straight on; the arrow on the dasher shows it), 4 the top of the throw, where
# the level asks the dasher for something (a dash, a pogo point). The dasher doesn't aim.
# The dash-slash charges as long as attack is held (blade drawn back, flaring on every beat), and
# its release has to land on a beat, within a parry's window (RHYTHM_RELEASE_TOLERANCE): that beat
# is 1, whichever of the bar it is. Off the beat the blade fumbles and the dash is spent. After
# the release the blade heats up through the beat, and the run takes hardly any time, so the
# blades meet on beat 2 wherever the partner stands within reach; the parry press has to be close
# to it too (RHYTHM_PARRY_TOLERANCE). Only holding block, or pressing too early, stops the dash
# with a dull clang and bounces the dasher off (RELAY_FAIL_BOUNCE). A strike off beat 3, or none,
# drops the dasher. Every beat sounds: 1 a tick, 2 the parry, 3 the strike, 4 a high tick. The
# throw stops a little before beat 4 and the dasher hangs still around it (gravity off), so a move
# on 4 has as much room early as late; any move ends the hang. The throw gives the dash back (beat
# 4 may ask for one), never the air jump. Charging in the air hangs you still, as the windup does.
# (While the switch is on, every dash-slash is this one, at a boss too; it starts the clock where
# no level has.)
const RELAY_RECOIL = 220.0  # px/s the anchor is pushed back, the other way, as it throws
const RELAY_FAIL_BOUNCE = Vector2(260.0, -220.0)  # the dasher, off a block that wasn't a parry
const RHYTHM_TOLERANCE = 0.08  # the strike counts this far off beat 3, early or late
# The hang at the top: from this long before beat 4 to this long after it. Longer before than
# after, as falling the first few px after it barely counts as missing the top.
const RHYTHM_HANG_BEFORE = 0.06
const RHYTHM_HANG_AFTER = 0.02
const RHYTHM_THROW_HEIGHT = 190.0  # px the throw covers, reached RHYTHM_HANG_BEFORE before beat 4
const RHYTHM_PARRY_TOLERANCE = 0.1  # the block press at most this long before the blades meet

var _hold_kind = Hold.NONE
var _hold_timer = 0.0
var _relay_dir = Vector2.RIGHT
var _relay_arrow: ColorRect
var rhythm_top_time = -100.0  # beat 4 of the last rhythm relay thrown (when it belongs)
var _tell_ring: Node2D  # drawn around the partner (see _update_tell())
var _tell_left = 0.0  # seconds to the ring's close
var _tell_alpha = 0.0
var _tell_sounded = false


func _ready():
	super()
	_relay_arrow = ColorRect.new()
	_relay_arrow.size = Vector2(38, 5)
	_relay_arrow.pivot_offset = Vector2(0, 2.5)
	_relay_arrow.position = Vector2(0, -2.5)
	_relay_arrow.color = Color.WHITE
	_relay_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relay_arrow.visible = false
	add_child(_relay_arrow)
	_tell_ring = Node2D.new()
	_tell_ring.top_level = true
	_tell_ring.z_index = 5
	_tell_ring.visible = false
	_tell_ring.draw.connect(_draw_tell)
	add_child(_tell_ring)


# --- Clashes with the partner: launch, relay, pogo clash ----------------------------

# Checked every frame after moving: a dash-slash meeting the partner's upslash (launch) or block
# (relay). True if it clashed.
func _check_clashes() -> bool:
	var other = partner()
	if other == null or other.is_held():
		return false
	var gap = other.global_position - global_position
	if _dash_slash and _dash_timer > 0.0 and absf(gap.x) <= LAUNCH_REACH.x and absf(gap.y) <= LAUNCH_REACH.y:
		if Moves.on("launch") and other.is_launch_ready():
			_launch(other)
			return true
		if _rhythm_dash and other.is_relay_parry():
			_start_relay(other)
			return true
		if _rhythm_dash and other.is_blocking():
			_relay_blocked(other)
			return true
	return false


# The upslash side of a launch: pressed recently enough to meet a dash-slash.
func is_launch_ready() -> bool:
	return is_upslash_fresh(LAUNCH_TOLERANCE)


# The blades clash: the dash's momentum turns upward.
func _launch(other):
	var rise = rise_speed(LAUNCH_HEIGHT)
	velocity = Vector2(_dash_dir * DASH_SPEED * LAUNCH_CARRY, -rise)
	_end_dash()
	_launch_timer = rise / GRAVITY  # until the top of the rise
	_coyote_timer = 0.0
	_jump_buffer = 0.0
	refresh_air_moves()
	_sword_flash = SWORD_FLASH_TIME
	_squash(LAUNCH_STRETCH, LAUNCH_STRETCH_TIME)
	other.on_launch_clash()
	_clash_fx(other, 16, 6.0)
	Sfx.play("launch", -3.0)
	launched.emit(self)


# The upslash side of a launch.
func on_launch_clash():
	_sword_flash = SWORD_FLASH_TIME
	_upslash_press_time = -100.0  # one upslash launches once


# The pogo box (`depth` below the feet) on the partner, who upslashes as it arrives.
func _try_pogo_clash(depth: float) -> bool:
	var other = partner()
	if not Moves.on("pogo") or other == null:
		return false
	var half = body.size / 2.0
	var gap = other.global_position - global_position
	if absf(gap.x) <= POGO_REACH.x / 2.0 + half.x and gap.y >= half.y and gap.y <= body.size.y + depth \
			and other.is_upslash_fresh(POGO_CLASH_TOLERANCE):
		_pogo_clash(other)
		return true
	return false


# The downslash met the partner's upslash: both blades flash and the downslasher bounces. No
# refreshes. It counts toward the launch's sync gain (see GameManager).
func _pogo_clash(other):
	_pogo_bounce()
	other.on_launch_clash()
	_clash_fx(other, 14)
	pogo_clashed.emit(self)


# --- The relay (see RELAY) ----------------------------------------------------------

# The blades locked on 2: both held until the anchor's strike on 3 throws the dasher (see
# _release_hold()), or until its late end drops them.
func _start_relay(anchor):
	_relay_dir = Vector2(_dash_dir, 0.0)  # thrown straight on, unless the anchor aims
	var clash_time = Beat.beat_time(relay_beat + 2) + RHYTHM_TOLERANCE - Beat.time()
	_begin_hold(Hold.RELAY_DASHER, clash_time)
	# The anchor's hold outlasts the dasher's, so the dasher's release is what frees them.
	anchor._begin_hold(Hold.RELAY_ANCHOR, clash_time + 0.1)
	anchor.parry_press_time = -100.0  # one press parries one dash-slash
	_sword_flash = SWORD_FLASH_TIME
	anchor._sword_flash = SWORD_FLASH_TIME
	Fx.sparks(self, (global_position + anchor.global_position) / 2.0, 12, Color(1.0, 0.85, 0.4))
	Sfx.play("parry_strong")
	Fx.shake(self, 4.0)
	relayed.emit(self)


# The partner parried a dash-slash: blocked, with the press timed to the blades meeting.
func is_relay_parry() -> bool:
	return is_blocking() and _since(parry_press_time) <= RHYTHM_PARRY_TOLERANCE


# Blocked but not parried: the dash stops dead with a dull clang, and the dasher bounces off.
func _relay_blocked(anchor):
	_end_dash()
	var back = -signf(anchor.global_position.x - global_position.x)
	if back == 0.0:
		back = -_dash_dir
	apply_knockback(Vector2(back * RELAY_FAIL_BOUNCE.x, RELAY_FAIL_BOUNCE.y))
	_fumble_fx((global_position + anchor.global_position) / 2.0)


func _begin_hold(kind: Hold, time: float):
	_hold_kind = kind
	_hold_timer = time
	velocity = Vector2.ZERO
	_end_dash()
	_end_carry()
	_windup_timer = 0.0
	_charging = false
	_attack_timer = 0.0
	_wall_side = 0.0
	_wall_flight = 0.0


func _process_hold(delta):
	velocity = Vector2.ZERO
	_hold_timer -= delta
	if _hold_kind == Hold.RELAY_ANCHOR and _process_relay_strike():
		return
	if _hold_timer <= 0.0:
		if _hold_kind == Hold.RELAY_DASHER:
			_relay_dropped()  # no strike on the beat
		else:
			_release_hold()


# The anchor's side of the relay: the stick aims the dasher, and the attack press strikes. On
# beat 3 it throws them; off it, it drops them. True once struck.
func _process_relay_strike() -> bool:
	var dasher = partner()
	if not (dasher and dasher._hold_kind == Hold.RELAY_DASHER):
		return false
	dasher._relay_dir = _aim_4(Vector2(dasher._dash_dir, 0.0))
	if not _pressed("attack"):
		return false
	if absf(Beat.time() - Beat.beat_time(dasher.relay_beat + 2)) <= RHYTHM_TOLERANCE:
		dasher._release_hold()  # the throw; it frees this hold too, and pushes this player back
		_start_swing(Swing.SLASH)
		Sfx.play("relay_strike")  # beat 3
	else:
		dasher._relay_dropped()
	return true


# No strike on the beat: the blades come apart, and the dasher drops.
func _relay_dropped():
	_hold_kind = Hold.NONE
	var anchor = partner()
	if anchor and anchor._hold_kind == Hold.RELAY_ANCHOR:
		anchor._hold_kind = Hold.NONE
	_fumble_fx(global_position)


func _release_hold():
	var kind = _hold_kind
	_hold_kind = Hold.NONE
	if kind == Hold.RELAY_DASHER:
		# The throw, reaching the top RHYTHM_HANG_BEFORE before beat 4, then the hang.
		var to_top = Beat.beat_time(relay_beat + 3) - Beat.time()
		_boost_timer = to_top + RHYTHM_HANG_AFTER
		_throw_left = RHYTHM_THROW_HEIGHT
		_boost_velocity = _relay_dir * RHYTHM_THROW_HEIGHT / maxf(to_top - RHYTHM_HANG_BEFORE, 0.05)
		rhythm_top_time = now() + to_top
		velocity = _boost_velocity
		if _relay_dir.x != 0.0:
			facing = signf(_relay_dir.x)
		refresh_dash()  # beat 4 may ask for a dash
		var anchor = partner()
		if anchor and anchor._hold_kind == Hold.RELAY_ANCHOR:
			anchor._hold_kind = Hold.NONE
			anchor.apply_knockback(-_relay_dir * RELAY_RECOIL)
		Sfx.play("launch", -4.0)


# The direction held right now, snapped to 4 ways (up, down, left, right); `fallback` if none.
func _aim_4(fallback: Vector2) -> Vector2:
	var aim = Vector2(move_axis(), Input.get_axis(action("up"), action("down")))
	if aim.length() < 0.5:
		return fallback
	if absf(aim.x) >= absf(aim.y):
		return Vector2(signf(aim.x), 0.0)
	return Vector2(0.0, signf(aim.y))


# --- The tell: when to press, around the partner of a dash-slash ---------------

# Seconds until this dash-slash's blades meet `other` (LAUNCH_REACH), from where both are now:
# what's left of the windup, then the run at dash speed. -1 if it won't reach them: not winding
# up or dash-slashing, the partner not ahead or too high or low, out of the dash's range, or the
# boss in the way.
func predict_contact(other) -> float:
	var dashing = _dash_slash and _dash_timer > 0.0
	if (_windup_timer <= 0.0 or _charging) and not dashing:
		return -1.0  # a charge has no time to meet yet
	var gap = other.global_position - global_position
	if signf(gap.x) != _dash_dir or absf(gap.y) > LAUNCH_REACH.y:
		return -1.0
	var run = maxf(0.0, absf(gap.x) - LAUNCH_REACH.x)
	var reach = _dash_timer * _dash_speed() if dashing else DASH_DISTANCE
	if run > reach or _boss_in_the_way(other.global_position.x):
		return -1.0
	return _windup_timer + run / _dash_speed()


# Every frame: the ring follows the prediction, and fades once there's none (the dash-slash is
# over, clashed, or can't reach).
func _update_tell(delta):
	var other = partner()
	var contact = predict_contact(other) if other else -1.0
	if contact >= 0.0:
		_tell_left = contact - TELL_LEAD
		_tell_alpha = 1.0
		if not _tell_sounded and _tell_left <= TELL_SOUND_TIME and not _rhythm_dash:  # that has its beats
			_tell_sounded = true
			Sfx.play("tell", -3.0)
	else:
		_tell_alpha = move_toward(_tell_alpha, 0.0, delta / TELL_FADE)
	_tell_ring.visible = _tell_alpha > 0.0 and other != null
	if _tell_ring.visible:
		_tell_ring.global_position = other.global_position
		_tell_ring.queue_redraw()


func tell_radius() -> float:
	return TELL_CLOSED_RADIUS + maxf(_tell_left, 0.0) * TELL_SHRINK_SPEED


# True from the frame the ring closes until it has faded (for tests and readouts).
func is_tell_closed() -> bool:
	return _tell_ring.visible and _tell_left <= 0.0


func _draw_tell():
	var closed = _tell_left <= 0.0
	var color = body_color.lightened(0.6) if closed else body_color.lightened(0.2)
	var width = TELL_WIDTH * (2.0 if closed else 1.0)
	_tell_ring.draw_arc(Vector2.ZERO, tell_radius(), 0.0, TAU, 48, Color(color, _tell_alpha), width, true)


# --- What the partner adds -----------------------------------------------------------

func is_held() -> bool:
	return _hold_kind != Hold.NONE


func _begin_dash_slash():
	super()
	_tell_sounded = false  # a new dash-slash: its tell may sound again


func _tick_timers(delta):
	# The relay's throw hangs around beat 4, and ticks on it.
	if _boost_timer > RHYTHM_HANG_AFTER and _boost_timer - delta <= RHYTHM_HANG_AFTER:
		Sfx.play("relay_peak")
	super(delta)


func interrupt_movement():
	super()
	_hold_kind = Hold.NONE
	_hold_timer = 0.0


func movement_state() -> String:
	if is_held():
		return "clash"
	if _boost_timer > 0.0:
		return "relay boost"
	return super()
