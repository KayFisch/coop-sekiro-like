class_name PlayerSword
extends PlayerBody
## A player, part 2 of 5: the sword. THE SWORD's rules (below): the slash, the upslash, the
## dash-slash (charged, let go on a beat), block and the parry window, the pogo;
## the blade's angle every frame, and the sparks of blades meeting.
## Part 1, the body: player_body.gd. Part 3, walls and ledges: player_walls.gd.

enum Swing { SLASH, UPSLASH, DOWNSLASH }

# PARRY WINDOW (every boss attack), Sekiro-style: a block press opens a window of this length,
# and a hit connecting inside it is a perfect parry. So the press must come at most this long
# *before* contact; pressing after the hit has landed is too late. Raise for easier parries.
const PARRY_TOLERANCE = 0.133
const PARRY_SPAM_LOCK = 0.3  # a block press this soon after the previous one can't parry
# THE SWORD, the rules every blade in the game follows (the bosses' too):
# A blade either guards or swings. At rest it's held diagonally, up and forward. Block holds it
# diagonally down in front; a perfect parry beats it up from there.
# THE SLASH is a real swing: drawn back (windup), cut down (active: only then can it hit), and
# brought back to rest (return). It commits: from the press until the blade is back at rest,
# block does nothing, and a parry window opened just before the swing is given up; so there's
# no attacking and parrying at once (see is_swinging()). There's no cooldown beyond that: the
# blade back at rest is ready again, and an attack pressed up to ATTACK_BUFFER_TIME before it's
# back comes as soon as it is.
const ATTACK_WINDUP_TIME = 0.05  # short: the cut has to follow the press
const ATTACK_ACTIVE_TIME = 0.12
const ATTACK_RETURN_TIME = 0.24  # the price of a swing: this long until the next one, or a block
const ATTACK_COOLDOWN = ATTACK_WINDUP_TIME + ATTACK_ACTIVE_TIME + ATTACK_RETURN_TIME
const ATTACK_BUFFER_TIME = 0.15
const ATTACK_DAMAGE = 10.0
const SWORD_REST_ANGLE = -0.7  # -40 degrees: up and forward
const SWING_START_ANGLE = -1.4  # drawn back to here, nearly upright...
const SWING_END_ANGLE = 0.6  # ...and cut down to here
const GUARD_ANGLE = 0.55  # blocking: the sword held diagonally down...
const GUARD_OFFSET = Vector2(6, -12)  # ...in front, from the chest (x mirrors with facing)
const BLOCK_SPEED_FACTOR = 0.4  # top speed while blocking, as a fraction of SPEED
const PARRY_FLICK_ANGLE = -1.3  # a perfect parry beats the blade up, to past its rest
const PARRY_FLICK_TIME = 0.12
const SWORD_EASE = 25.0  # how fast the blade moves between rest and guard (1/s)
const SWORD_FLASH_TIME = 0.1
# PARRIED: an enemy blade that meets the swing knocks it back (on_swing_parried()). The blade
# then takes PARRIED_RECOIL to come back to rest, instead of the usual return, and until it's
# there the swing isn't over: no block, no parry, no attack.
const PARRIED_RECOIL = 0.45
const RECOIL_ANGLE = -2.4  # thrown back over the shoulder
const RECOIL_KNOCK_TIME = 0.06  # how fast it's thrown there
# Dash-slash: dash and attack together (or attack a moment before the dash) to dash with the
# sword thrust out level in front, hitting all the way through the dash. It charges first, held
# in place with the blade drawn back, for as long as attack is held; the blade flares on every
# beat of the clock (Beat; a dash-slash starts it where no level has). Let go on a beat, it runs
# half a run before the next one, quickly, so the blades meet on that beat wherever a partner
# stands in reach: the moment for their launch or relay (see player_partner.gd). Let go off the
# beat, the blade fumbles and the dash is spent.
const DASH_SLASH_RELEASE_TOLERANCE = PARRY_TOLERANCE  # the release counts this far off a beat, early or late
const DASH_SLASH_RUN_TIME = 0.04  # the run, DASH_DISTANCE in this long (a plain dash: DASH_TIME)
const DASH_SLASH_FLARE = 0.15  # s: charging, the blade flares white on every beat and fades over this
const DASH_SLASH_COOLDOWN = 0.5  # from the charge's start until the next attack
const DASH_SLASH_WINDUP_DRAW = 14.0  # the blade drawn back this far behind the usual grip
const DASH_SLASH_LEAD = 0.1  # an attack pressed at most this long before a dash turns into one...
const DASH_SLASH_LATE = 0.06  # ...and so does one pressed at most this long after the dash starts
const DASH_SLASH_DAMAGE = 15.0  # a plain slash is 10
const DASH_SLASH_THRUST = 10.0  # the sword pushed this far forward of the usual grip...
const DASH_SLASH_REACH = 1.5  # ...and drawn out to this times its length (the hitbox too)
const DASH_SLASH_GLOW = 0.6  # the blade this far toward white-hot
const DASH_SLASH_TRAIL_INTERVAL = 0.02  # an afterimage of the body this often through the dash
const DASH_SLASH_TRAIL_FADE = 0.18
# Upslash: attack while holding up, a rising cut. Up pressed at most UPSLASH_LATE after the
# attack still counts, as for the dash-slash.
const UPSLASH_LATE = 0.06
const UPSLASH_WINDUP_TIME = 0.05  # the blade dipping from rest to where the cut starts
const UPSLASH_ACTIVE_TIME = 0.15
const UPSLASH_RETURN_TIME = 0.12
const UPSLASH_COOLDOWN = 0.35
const UPSLASH_DAMAGE = 10.0
const UPSLASH_START_ANGLE = 0.6  # low in front...
const UPSLASH_END_ANGLE = -1.9  # ...up past vertical
# POGO: down + attack in the air slashes below you (a downslash; it never hurts the boss). What
# is in POGO_REACH under you from the press on, for POGO_WINDOW, can bounce you up to POGO_HEIGHT
# however fast you were falling. The blade's swing is only the look.
# POGO CLASH (Moves "pogo"): the only bounce in a fight, off the partner, mirroring the launch.
# The partner below upslashes as you arrive: at most POGO_CLASH_TOLERANCE before your pogo box
# reaches them, or while it's still checking. Both blades flash, you bounce; nothing is refreshed.
# A downslash onto a partner who didn't upslash does nothing special.
# POGO POINTS: things a level puts there to be pogoed off (in the group "pogo", e.g. a gym's
# lanterns) bounce it too, and give the dash back if Moves "pogo_refresh_dash" says so. One may
# take a pogo only at certain moments (accepts_pogo(), e.g. the relay gym's lantern: on beat 4).
# Nothing else does: not the boss, not spikes, not targets.
const DOWNSLASH_ACTIVE_TIME = 0.06  # just the look: the pogo is the box (POGO_WINDOW)
const DOWNSLASH_RETURN_TIME = 0.08
const DOWNSLASH_START_ANGLE = 0.0  # level in front...
const DOWNSLASH_END_ANGLE = PI  # ...sweeping under you to level behind
const DOWNSLASH_DAMAGE = 10.0
const POGO_HEIGHT = 110.0
const POGO_RISE_GRAVITY = 1.6  # gravity times this on a pogo's rise: same height, a quicker bounce
# A pogo point (or the partner) in this box under you (width, depth below your feet) bounces a
# downslash right away, checked before you move, so falling fast can't carry you past it first.
# It's centered and it's the downslash's whole reach (the swinging blade doesn't count), so
# facing doesn't matter.
const POGO_REACH = Vector2(80.0, 28.0)
const POGO_WINDOW = 0.15  # the box is checked this long from the press, whatever the blade is doing
const POGO_GRACE = 0.1  # spikes touched this soon after a pogo don't count (see just_pogoed())
const POGO_CLASH_TOLERANCE = 0.15
# The swings side by side: the lengths of their three parts (windup, active: the cut, back: the
# return to rest), how soon the next attack may follow the press, the damage, and the blade's
# angle where the cut starts and ends; their names for readouts.
const SWINGS = {
	Swing.SLASH: {"windup": ATTACK_WINDUP_TIME, "active": ATTACK_ACTIVE_TIME, "back": ATTACK_RETURN_TIME,
		"cooldown": ATTACK_COOLDOWN, "damage": ATTACK_DAMAGE, "from": SWING_START_ANGLE, "to": SWING_END_ANGLE,
		"name": "slash"},
	Swing.UPSLASH: {"windup": UPSLASH_WINDUP_TIME, "active": UPSLASH_ACTIVE_TIME, "back": UPSLASH_RETURN_TIME,
		"cooldown": UPSLASH_COOLDOWN, "damage": UPSLASH_DAMAGE, "from": UPSLASH_START_ANGLE, "to": UPSLASH_END_ANGLE,
		"name": "upslash"},
	Swing.DOWNSLASH: {"windup": 0.0, "active": DOWNSLASH_ACTIVE_TIME, "back": DOWNSLASH_RETURN_TIME,
		"cooldown": ATTACK_COOLDOWN, "damage": DOWNSLASH_DAMAGE, "from": DOWNSLASH_START_ANGLE, "to": DOWNSLASH_END_ANGLE,
		"name": "downslash"},
}

@export var sword_color = Color(0.62, 0.8, 1)  # a lighter shade of the body color

var parry_press_time = -100.0  # when the last block press that can still parry happened
var swing_serial = 0  # bumped by every new swing and dash-slash (see active_sword_point())
var _sword_color: Color
var _sword_flash = 0.0
var last_block_press = -100.0
var _swing_kind = Swing.SLASH
var _attack_timer = 0.0  # counts down through the swing and its return
var _attack_cooldown = 0.0
var _attack_landed = false
var _attack_buffer = 0.0  # > 0 while an attack press is waiting for the blade to be back
var _recoil_timer = 0.0  # > 0 while the blade comes back from being parried (PARRIED_RECOIL)
var _sword_idle_angle = SWORD_REST_ANGLE  # the blade's angle when it isn't swinging, eased
var _swing_from_angle = SWORD_REST_ANGLE  # where the blade was when the swing (or recoil) began
var _parry_flick = 0.0  # > 0 while a perfect parry beats the blade up
var _slash_press_time = -100.0
var _upslash_press_time = -100.0
var _dash_slash = false  # this dash is a dash-slash (also true through its charge and windup)
var _windup_timer = 0.0  # > 0 while a dash-slash charges and winds up, until its run
var _windup_length = 1.0  # s from the charge's release to the run (_release_charge())
var _charging = false  # a dash-slash's charge held, not let go yet (_windup_timer > 0 meanwhile)
var relay_beat = -1  # the Beat count of the beat the last dash-slash was let go on (a relay's 1)
var _trail_timer = 0.0  # the dash-slash's afterimages (see the look in player.gd)
var _pogoed = false  # this downslash already bounced
var pogo_time = -100.0
var downslash_time = -100.0  # when the current downslash was pressed (see POGO_WINDOW)

@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: ColorRect = $SwordPivot/Sword
@onready var sword_hitbox: Area2D = $SwordPivot/SwordHitbox
@onready var _sword_shape: CollisionShape2D = $SwordPivot/SwordHitbox/CollisionShape2D


func _ready():
	super()
	sword.color = sword_color
	_sword_color = sword_color


# --- Buttons: block and attack -----------------------------------------------------

func _process_other_buttons():
	super()
	if _pressed("block") and not is_swinging():
		var t = now()
		# Mashing doesn't parry: a press too soon after the previous one isn't a parry attempt.
		parry_press_time = t if t - last_block_press >= PARRY_SPAM_LOCK else -100.0
		last_block_press = t
	_process_attack_buttons()


# Attack: a swing now, or one pressed a moment too early coming now; up a moment after a slash
# makes it an upslash.
func _process_attack_buttons():
	if _pressed("attack"):
		_press_attack()
	elif _attack_buffer > 0.0 and _attack_cooldown <= 0.0:
		_press_attack()  # pressed a moment too early: it comes now
	elif _pressed("up") and _attack_timer > 0.0 \
			and _swing_kind == Swing.SLASH and not _attack_landed \
			and _since(_slash_press_time) <= UPSLASH_LATE:
		_press_upslash()  # up came a moment after the attack: it's an upslash after all


func _press_attack():
	if Moves.on("dash_slash") and _dash_timer > 0.0 and not _dash_slash \
			and _since(dash_press_time) <= DASH_SLASH_LATE:
		_begin_dash_slash()  # attacking right as the dash starts
		return
	if _attack_cooldown > 0.0:
		_attack_buffer = ATTACK_BUFFER_TIME
		return
	_attack_buffer = 0.0
	if is_blocking():
		return
	if _held("up") and _dash_timer <= 0.0:
		_press_upslash()
		return
	if Moves.on("pogo") and not is_on_floor() and _dash_timer <= 0.0 \
			and _held("down"):
		_start_swing(Swing.DOWNSLASH)
		Sfx.play("slash", -4.0)
		return
	_start_swing(Swing.SLASH)
	_slash_press_time = now()
	Sfx.play("slash", -4.0)


# Attack while holding up (also reached from a slash that up followed a moment later).
func _press_upslash():
	_start_swing(Swing.UPSLASH)
	_upslash_press_time = now()
	Sfx.play("slash", -4.0)


func _start_swing(kind: Swing):
	var swing = SWINGS[kind]
	_swing_from_angle = _sword_angle()
	_swing_kind = kind
	_attack_timer = swing.windup + swing.active + swing.back
	_attack_cooldown = swing.cooldown
	_attack_landed = false
	_pogoed = false
	downslash_time = now() if kind == Swing.DOWNSLASH else -100.0
	parry_press_time = -100.0  # a swing gives up the parry window
	swing_serial += 1


# --- The swing ---------------------------------------------------------------------

# s into the current swing, from its press.
func _swing_elapsed() -> float:
	var swing = SWINGS[_swing_kind]
	return swing.windup + swing.active + swing.back - _attack_timer


# True from the attack press until the blade is back at rest: a swing from its windup to the end
# of its return (or of its recoil, if it was parried), or a dash-slash from its charge to the end
# of the dash. No blocking or parrying meanwhile.
func is_swinging() -> bool:
	return _attack_timer > 0.0 or _recoil_timer > 0.0 or _windup_timer > 0.0 \
		or (_dash_slash and _dash_timer > 0.0)


# True while the blade can hit: a swing's active part, or all through a dash-slash.
func is_sword_active() -> bool:
	if _dash_slash and _dash_timer > 0.0:
		return true
	var swing = SWINGS[_swing_kind]
	var cutting = _swing_elapsed() - swing.windup
	return _attack_timer > 0.0 and cutting >= 0.0 and cutting < swing.active


# The enemy's blade met this swing and knocked it back (PARRIED_RECOIL): the hit is lost, and so
# is the time until the blade is back.
func on_swing_parried():
	_swing_from_angle = _sword_angle()
	_attack_timer = 0.0
	_recoil_timer = PARRIED_RECOIL
	_attack_cooldown = maxf(_attack_cooldown, PARRIED_RECOIL)


func _swing_damage() -> float:
	if _dash_slash and _dash_timer > 0.0:
		return DASH_SLASH_DAMAGE
	return SWINGS[_swing_kind].damage


# The middle of the blade's hitbox while it can hit, else null. For attacks with parts that
# are struck without being the boss's body (e.g. a chain), together with swing_serial so each
# swing counts once.
func active_sword_point():
	if not is_sword_active():
		return null
	return _sword_shape.global_position


# Sword hits: damage on the boss (or a target). A downslash never hits the boss; on a pogo point
# its hit is _check_pogo()'s.
func _process_attack():
	if not is_sword_active() or _is_downslash():
		return
	for hit in sword_hitbox.get_overlapping_bodies():
		if hit.is_in_group("boss") and not _attack_landed:
			_attack_landed = true
			hit.take_damage(_swing_damage(), self)


func _is_downslash() -> bool:
	return _swing_kind == Swing.DOWNSLASH and not (_dash_slash and _dash_timer > 0.0)


# The last swing, for readouts: "dash-slash", or its name in SWINGS ("slash", "upslash"...).
func swing_name() -> String:
	return "dash-slash" if _dash_slash else SWINGS[_swing_kind].name


# Upslashing, pressed at most `tolerance` ago (the launch and the pogo clash).
func is_upslash_fresh(tolerance: float) -> bool:
	return _swing_kind == Swing.UPSLASH and _attack_timer > 0.0 \
		and _since(_upslash_press_time) <= tolerance and not is_staggered()


# --- The dash-slash ----------------------------------------------------------------

# A slash pressed a moment before the dash turns into a dash-slash.
func _start_dash(direction: float) -> bool:
	var slash_lead = Moves.on("dash_slash") and _attack_timer > 0.0 and _swing_kind == Swing.SLASH \
		and _since(_slash_press_time) <= DASH_SLASH_LEAD
	if not super(direction):
		return false
	_dash_slash = false
	if slash_lead:
		var already_hit = _attack_landed
		_attack_timer = 0.0
		_begin_dash_slash()
		_attack_landed = already_hit  # a slash that already hit doesn't hit again as a dash-slash
	return true


# The dash-slash's charge: held in place, blade drawn back, until attack is let go
# (_release_charge()), then the windup to the run (_process_windup()).
func _begin_dash_slash():
	_dash_slash = true
	_charging = true
	_windup_timer = INF  # held while charging: the release sets the real windup
	if not Beat.running:
		Beat.start(Beat.DEFAULT_BPM, get_tree().current_scene)  # its release needs a clock
	_dash_timer = 0.0
	_attack_timer = 0.0
	_attack_landed = false
	downslash_time = -100.0
	_attack_cooldown = DASH_SLASH_COOLDOWN
	parry_press_time = -100.0  # as a swing does
	facing = _dash_dir
	velocity = Vector2.ZERO


func _process_windup(delta):
	velocity = Vector2.ZERO  # hanging still, even in the air
	facing = _dash_dir
	if _charging:
		if not _held("attack"):
			_release_charge()
		return
	_windup_timer -= delta
	if _windup_timer > 0.0:
		return
	_windup_timer = 0.0
	_dash_timer = DASH_SLASH_RUN_TIME
	velocity = Vector2(_dash_dir * _dash_speed(), 0.0)
	if _dash_slash_passes() and _boss_ahead():
		_passing = true  # through him (DASH-SLASH THROUGH)
	swing_serial += 1
	_trail_timer = 0.0
	_squash(DASH_STRETCH, DASH_STRETCH_TIME)
	Sfx.play("slash", -10.0)  # quiet: the beat it meets on is a partner's (a relay's parry on 2)


# The dash-slash let go: on a beat (a relay's 1), the run starts half a run before the next, so
# the blades meet on that one (a relay's 2). Off the beat, the blade fumbles and the dash is spent.
func _release_charge():
	_charging = false
	var t = Beat.time()
	if absf(Beat.offset_to_beat(t)) > DASH_SLASH_RELEASE_TOLERANCE:
		_windup_timer = 0.0
		_dash_slash = false
		_swing_from_angle = _sword_angle()
		_recoil_timer = PARRIED_RECOIL
		_fumble_fx(sword_pivot.global_position)
		return
	relay_beat = roundi(Beat.beats_at(t))
	_windup_length = Beat.beat_time(relay_beat + 1) - DASH_SLASH_RUN_TIME / 2.0 - t
	_windup_timer = _windup_length
	Sfx.play("relay_beat")  # the beat it was let go on


# Holding a dash-slash's charge, not let go yet.
func is_charging() -> bool:
	return _charging


# A dash-slash covers the dash's ground faster (DASH_SLASH_RUN_TIME).
func _dash_speed() -> float:
	return DASH_DISTANCE / DASH_SLASH_RUN_TIME if _dash_slash else super()


func _end_dash():
	super()
	_dash_slash = false


# DASH-SLASH THROUGH (Moves "dash_slash_pass"): a dash-slash at the boss goes through him the
# way a dash-parry does (DASH-PARRY in player_body.gd): in the players' sync mode only (so the
# two can always get together to bind), always, or never. A dash-slash too short to get past him
# is pushed back out the nearer side. Whether it does just now:
func _dash_slash_passes() -> bool:
	match Moves.value("dash_slash_pass"):
		"always":
			return true
		"sync":
			return GameManager.rules != null and GameManager.rules.sync_mode
	return false


# --- Pogo ----------------------------------------------------------------------------

# Before moving: a downslash's pogo box, POGO_REACH under you (stretched by how far you fall this
# frame), so the bounce comes before you'd land. From the press (that same frame) for
# POGO_WINDOW; the blade's position and timing don't matter. The partner in it with a fresh
# upslash is a pogo clash; a pogo point in it (POGO POINTS) bounces it.
func _check_pogo(delta):
	if _pogoed or _since(downslash_time) > POGO_WINDOW:
		return
	var half = body.size / 2.0
	var depth = POGO_REACH.y + maxf(velocity.y * delta, 0.0)
	if _try_pogo_clash(depth):
		return
	var shape = RectangleShape2D.new()
	shape.size = Vector2(POGO_REACH.x, half.y + depth)
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, (half.y + depth) / 2.0))
	query.collision_mask = 1 << 2  # the boss's layer, where pogo points are too
	query.exclude = [get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var hit = result.collider
		if not hit.is_in_group("pogo"):
			continue  # only pogo points: not the boss, spikes or targets
		if hit.has_method("accepts_pogo") and not hit.accepts_pogo(self):
			continue  # e.g. a lantern that only takes a pogo on the beat
		if hit.is_in_group("boss") and not _attack_landed:
			_attack_landed = true
			hit.take_damage(_swing_damage(), self)  # a lantern lights up, as struck
		_pogo()


# The pogo box, `depth` below the feet, on the partner: a pogo clash (player_partner.gd). True if
# it clashed.
func _try_pogo_clash(_depth: float) -> bool:
	return false


# Spikes touched this soon after a pogo are forgiven (the bounce is already carrying you out).
func just_pogoed() -> bool:
	return _since(pogo_time) <= POGO_GRACE


# A bounce off a pogo point, giving the dash back if Moves "pogo_refresh_dash" says so.
func _pogo():
	if _pogoed:
		return
	_pogo_bounce()
	if Moves.on("pogo_refresh_dash"):
		refresh_dash()
	Fx.sparks(self, global_position + Vector2(0.0, body.size.y / 2.0 + 6.0), 6, _sword_color.lightened(0.5))
	Sfx.play("parry", -8.0)


# The bounce off a downslash: up to POGO_HEIGHT, whatever the fall.
func _pogo_bounce():
	_pogoed = true
	pogo_time = now()
	bounce(POGO_HEIGHT, POGO_RISE_GRAVITY)
	_sword_flash = SWORD_FLASH_TIME


# --- Defensive queries used by the boss at the moment its hitbox connects ---

func is_blocking() -> bool:
	return not is_staggered() and not is_swinging() and _held("block") \
		and (GameManager.rules == null or GameManager.rules.can_block())  # no blocking in chaos


func is_perfect_parry() -> bool:
	return not is_staggered() and _since(parry_press_time) <= PARRY_TOLERANCE


# --- The blade: its angle, sparks ------------------------------------------------------

# The blade's angle right now: 0 is level, pointing the way the player faces; negative is up.
func _sword_angle() -> float:
	if _dash_slash and _dash_timer > 0.0:
		return 0.0  # thrust out level through the whole dash
	if _windup_timer > 0.0:
		return -0.35  # drawn back, tip raised a little
	if _attack_timer > 0.0:
		var swing = SWINGS[_swing_kind]
		var elapsed = _swing_elapsed()
		if elapsed < swing.windup:
			return lerpf(_swing_from_angle, swing.from, elapsed / swing.windup)  # drawn back to where the cut starts
		elapsed -= swing.windup
		if elapsed < swing.active:
			return lerpf(swing.from, swing.to, elapsed / swing.active)
		# Back to rest. A downslash comes back over the top, finishing the circle, rather than
		# swiping under again.
		var rest = SWORD_REST_ANGLE + (TAU if _swing_kind == Swing.DOWNSLASH else 0.0)
		return lerpf(swing.to, rest, (elapsed - swing.active) / swing.back)
	if _recoil_timer > 0.0:
		# Parried: thrown back over the shoulder, then brought forward again, slowly at first.
		var since = PARRIED_RECOIL - _recoil_timer
		if since < RECOIL_KNOCK_TIME:
			return lerpf(_swing_from_angle, RECOIL_ANGLE, since / RECOIL_KNOCK_TIME)
		var back = (since - RECOIL_KNOCK_TIME) / (PARRIED_RECOIL - RECOIL_KNOCK_TIME)
		return lerpf(RECOIL_ANGLE, SWORD_REST_ANGLE, ease(back, 2.0))
	return _sword_idle_angle


# The blade when nothing above is going on: at rest, down in front while blocking, beaten up by
# a perfect parry; eased from one to the other, so releasing block swings it back up.
func _update_sword_idle(delta: float):
	if is_swinging() or _blade_taken():
		_sword_idle_angle = wrapf(_sword_angle(), -PI, PI)  # it carries on from wherever that leaves it
		return
	var target = SWORD_REST_ANGLE
	if _parry_flick > 0.0:
		target = PARRY_FLICK_ANGLE
	elif is_blocking():
		target = GUARD_ANGLE
	_sword_idle_angle = lerpf(_sword_idle_angle, target, 1.0 - exp(-SWORD_EASE * delta))


# True while something else holds the blade (a lock with another blade, the pair's draw; see
# player.gd).
func _blade_taken() -> bool:
	return false


# Blades meeting between this player and `other`: sparks in both their colors, a clang, a shake.
func _clash_fx(other, sparks: int, shake = 4.0):
	var point = (global_position + other.global_position) / 2.0
	Fx.sparks(self, point, sparks, body_color.lerp(other.body_color, 0.5).lightened(0.5))
	Sfx.play("parry_strong")
	Fx.shake(self, shake)


# A dull clang at `point`: a blade fumbled, blocked or let go, and nothing came of it.
func _fumble_fx(point: Vector2):
	Fx.sparks(self, point, 5, Color(0.6, 0.6, 0.6))
	Sfx.play("chip")


# --- What the sword adds to the body --------------------------------------------------

func _face(direction: float):
	super(direction)
	if _dash_slash and _dash_timer > 0.0:
		facing = _dash_dir  # the thrust points the way of the dash


func _speed_scale() -> float:
	return super() * (BLOCK_SPEED_FACTOR if is_blocking() else 1.0)


func _tick_timers(delta):
	if _dash_timer > 0.0 and _dash_timer <= delta:
		_dash_slash = false  # the dash-slash ends with its dash
	super(delta)
	_sword_flash = maxf(_sword_flash - delta, 0.0)
	_recoil_timer = maxf(_recoil_timer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_parry_flick = maxf(_parry_flick - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)


func interrupt_movement():
	super()
	_windup_timer = 0.0
	_charging = false
	downslash_time = -100.0


func movement_state() -> String:
	if _windup_timer > 0.0:
		return "dash-slash charge" if _charging else "dash-slash windup"
	if _dash_slash and _dash_timer > 0.0:
		return "dash-slash"
	return super()
