extends CharacterBody2D

signal health_changed(player, hp)
signal damaged(player)
signal blocked(player)
signal died(player)
signal launched(player)  # sent up by a partner's upslash (see _check_clashes())
signal relayed(player)  # boosted off a partner's block (momentum relay, see _check_clashes())
signal landed(player, air_time)  # touched down after air_time seconds off the ground
signal pogo_clashed(player)  # bounced off a partner's upslash (see _pogo_clash())

enum Swing { SLASH, UPSLASH, DOWNSLASH }
# Held in place for a moment by a clash with the partner (see _begin_hold()).
enum Hold { NONE, CHIMNEY, RELAY_DASHER, RELAY_ANCHOR }

# Which abilities are on is decided by the Moves autoload (core/moves.gd, F1 in game): every
# ability below checks its switch there.

# --- Movement tuning ---
# Running: a slight ease in and out, never a slide (px/s and px/s²).
const SPEED = 360.0  # top running speed
const BLOCK_SPEED_FACTOR = 0.4  # top speed while blocking, as a fraction of SPEED
const GROUND_ACCEL = 6000.0  # 0 -> SPEED in ~0.06 s
const GROUND_DECEL = 9000.0  # letting go: SPEED -> 0 in ~0.04 s
const AIR_ACCEL = 4500.0  # steering in the air, a touch looser than on the ground
const AIR_DECEL = 4000.0
# Turning around: the speed the old way is dropped at once (1 = instantly, 0 = eased off at the
# decel rate), then you accelerate the new way as usual.
const TURN_SNAP = 1.0
# Jumping: heights in pixels; the launch speed is worked out from them and GRAVITY.
const GRAVITY = 1800.0  # on the way up
const FALL_GRAVITY_MULTIPLIER = 1.7  # heavier on the way down: a snappier, less floaty fall
const MAX_FALL_SPEED = 1300.0
const JUMP_HEIGHT = 136.0
const DOUBLE_JUMP_HEIGHT = 107.0
const AIR_JUMPS = 1  # extra jumps in the air
const JUMP_CUT = 0.5  # releasing jump early keeps this fraction of upward speed
const COYOTE_TIME = 0.1  # a jump this soon after running off a ledge still counts as grounded
const JUMP_BUFFER_TIME = 0.12  # a jump pressed this soon before landing fires on landing
# Dashing: straight ahead, the way you face, ignoring gravity. Holding a direction and pressing
# dash on the same frame dashes that way (movement turns you before actions run). One dash per
# trip into the air: it's only refreshed by landing and by a launch.
const DASH_DISTANCE = 140.0
const DASH_TIME = 0.14
const DASH_SPEED = DASH_DISTANCE / DASH_TIME
const DASH_EXIT_SPEED = 360.0  # speed carried out of a dash (or a jump out of one), then eased off
const DASH_COOLDOWN = 0.6
const MAX_HP = 100.0
const POTION_CHARGES = 3
const POTION_HEAL = 50.0
const DRINK_TIME = 1.5
const KNOCKBACK_TIME = 0.25  # input can't steer and potions can't be drunk while this runs
const KNOCKBACK_FRICTION = 1500.0
const HIT_INVULN_TIME = 0.6
const CHIP_INVULN_TIME = 0.2
# PARRY WINDOW (every boss attack), Sekiro-style: a block press opens a window of this length,
# and a hit connecting inside it is a perfect parry. So the press must come at most this long
# *before* contact; pressing after the hit has landed is too late. Raise for easier parries.
const PARRY_TOLERANCE = 0.133
# DODGE WINDOW (the grab), same idea: a dash press opens a window of this length, and the
# boss's hands shutting inside it is a clean dodge. Press at most this long before they shut.
const DODGE_TOLERANCE = 0.133
const PARRY_SPAM_LOCK = 0.3  # a block press this soon after the previous one can't parry
# THE SWORD, the rules every blade in the game follows (the bosses' too):
# A blade either guards or swings. At rest it's held diagonally, up and forward. Block holds it
# diagonally down in front; a perfect parry beats it up from there.
# THE SLASH is a real swing: drawn back (windup), cut down (active: only then can it hit), and
# brought back to rest (return). It commits: from the press until the blade is back at rest,
# block does nothing, and a parry window opened just before the swing is given up; so there's
# no attacking and parrying at once (see _is_swinging()). There's no cooldown beyond that: the
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
# PARRIED: an enemy blade that meets the swing knocks it back (on_swing_parried()). The blade
# then takes PARRIED_RECOIL to come back to rest, instead of the usual return, and until it's
# there the swing isn't over: no block, no parry, no attack.
const PARRIED_RECOIL = 0.45
const RECOIL_ANGLE = -2.4  # thrown back over the shoulder
const RECOIL_KNOCK_TIME = 0.06  # how fast it's thrown there
# Dash-slash: dash and attack together (or attack a moment before the dash) to dash with the
# sword thrust out level in front, hitting all the way through the dash. It starts with a short
# windup, held in place with the blade drawn back and brightening, so a partner can see it
# coming and time a parry (see the momentum relay).
const DASH_SLASH_WINDUP = 0.2
const DASH_SLASH_COOLDOWN = 0.5  # from the windup's start until the next attack
const DASH_SLASH_WINDUP_DRAW = 14.0  # the blade drawn back this far behind the usual grip
const DASH_SLASH_LEAD = 0.1  # an attack pressed at most this long before a dash turns into one...
const DASH_SLASH_LATE = 0.06  # ...and so does one pressed at most this long after the dash starts
const DASH_SLASH_DAMAGE = 15.0  # a plain slash is 10
const DASH_SLASH_THRUST = 10.0  # the sword pushed this far forward of the usual grip...
const DASH_SLASH_REACH = 1.5  # ...and drawn out to this times its length (the hitbox too)
const DASH_SLASH_GLOW = 0.6  # the blade this far toward white-hot
const DASH_SLASH_TRAIL_INTERVAL = 0.02  # an afterimage of the body this often through the dash
const DASH_SLASH_TRAIL_FADE = 0.18
# THE TELL: a dash-slash headed at the partner puts a ring in the dasher's color around them,
# shrinking at a steady rate and closing TELL_LEAD before the blades meet: the moment to press
# (block for a relay, upslash for a launch; inside both windows). The contact is predicted every
# frame (see _predict_contact()). A short sound ends on the close.
const TELL_LEAD = 0.08
const TELL_CLOSED_RADIUS = 30.0  # just around the partner's body
const TELL_SHRINK_SPEED = 380.0  # px/s
const TELL_WIDTH = 3.0
const TELL_FADE = 0.15  # fading out once the dash-slash is over
const TELL_SOUND_TIME = 0.12  # the sound's length (see "tell" in sfx.gd): started this long before the close
# Upslash: attack while holding up. A rising cut with a little hop, a fifth of a jump's height.
# The hop is once per trip into the air, like the dash; the cut itself can be repeated.
# Up pressed at most UPSLASH_LATE after the attack still counts, as for the dash-slash.
const UPSLASH_LATE = 0.06
const UPSLASH_WINDUP_TIME = 0.05  # the blade dipping from rest to where the cut starts
const UPSLASH_ACTIVE_TIME = 0.15
const UPSLASH_RETURN_TIME = 0.12
const UPSLASH_COOLDOWN = 0.35
const UPSLASH_DAMAGE = 10.0
const UPSLASH_HOP_HEIGHT = JUMP_HEIGHT / 5.0
const UPSLASH_START_ANGLE = 0.6  # low in front...
const UPSLASH_END_ANGLE = -1.9  # ...up past vertical
# LAUNCH: a dash-slash that runs into the partner's upslash clashes the two blades, and the
# dash's momentum is turned upward: the dashing player shoots up, keeping only a sliver of
# their sideways speed. The upslash must come at most LAUNCH_TOLERANCE before the blades meet
# (like a parry), or while the dash-slash is still passing through.
const LAUNCH_TOLERANCE = 0.15
const LAUNCH_REACH = Vector2(70.0, 50.0)  # center-to-center distance at which the blades meet
const LAUNCH_HEIGHT = 340.0  # 2.5x a jump
const LAUNCH_CARRY = 0.15  # fraction of the dash's sideways speed kept (~150 px/s)
const LAUNCH_STRETCH = Vector2(0.7, 1.4)
# FAST FALL: holding down in the air, once falling, pulls you down harder and faster.
const FAST_FALL_GRAVITY = 2.2  # times the usual falling gravity
const FAST_FALL_MAX_SPEED = 1900.0
# WALLS (Moves "wall": off / slide / cling). In the air, press into a wall (or fly into it fast)
# to stick to it, facing away from it; rising, you carry on up along it first. Sliding, you then
# slip down at WALL_SLIDE_SPEED; clinging, you hang still for WALL_CLING_TIME, then slide. Press
# away, or land, to let go. Wall jump: jump off a wall you're on or touching, up and away; for
# WALL_JUMP_LOCK you can't steer back, so it carries you clear of the wall. A wall you jumped off
# is spent until you land, catch a ledge or reach another wall: you can't stick to it, jump off
# it or get refreshed by it again, so one wall alone can't be climbed (two facing ones can).
# A wall you're merely next to only counts if you're moving into it: pressing toward it, or
# still flying from the last wall jump (for WALL_FLIGHT_TIME). In that flight, holding back
# toward the wall you left doesn't steer, so between two walls you can keep one direction held
# and just time the jumps; a gap too wide to cross in that time ends the flight, and you drift back.
# Walls and ledges refresh the dash (Moves "wall_refresh"), never the air jump.
# Partners aren't walls.
const WALL_PROBE = 4.0  # px: how close a wall has to be to stick to or jump off
const WALL_ATTACH_SPEED = 150.0  # flying into a wall this fast sticks without pressing into it
const WALL_SLIDE_SPEED = 140.0
const WALL_CLING_TIME = 1.2
const WALL_COYOTE_TIME = 0.1  # a wall jump this soon after letting go of the wall still works
const WALL_SPENT_RANGE = 24.0  # px: a wall on the spent side this close to where you jumped is the same wall
const WALL_JUMP_HEIGHT = 110.0
const WALL_JUMP_PUSH = 360.0  # px/s away from the wall
const WALL_JUMP_LOCK = 0.15
const WALL_FLIGHT_TIME = 0.26  # how long a wall jump counts as flying at the next wall (~94 px)
# LEDGE GRAB: in the air, pressing into a wall whose top edge is between a little above your
# head and your middle, with room to stand up there: you catch the edge and hang. Up climbs at
# once, and so does holding toward the wall once you've hung for LEDGE_MIN_HANG; jump jumps
# from the hang; down or away lets go.
const LEDGE_REACH_UP = 50.0  # the edge may be this far above your middle (head top + 30)...
const LEDGE_REACH_DOWN = 6.0  # ...down to this far below it
const LEDGE_MAX_RISE = 250.0  # rising faster than this, you fly past edges instead of catching them
const LEDGE_HANG_DROP = 14.0  # hanging, your middle is this far below the edge
const LEDGE_MIN_HANG = 0.1
const LEDGE_CLIMB_TIME = 0.18
const LEDGE_REGRAB_TIME = 0.3  # after letting go or jumping off
# POGO: down + attack in the air slashes below you (a downslash; it never hurts the boss). What
# is in POGO_REACH under you from the press on, for POGO_WINDOW, can bounce you up to POGO_HEIGHT
# however fast you were falling. The blade's swing is only the look.
# POGO CLASH (Moves "pogo"): the only bounce in a fight, off the partner, mirroring the launch.
# The partner below upslashes as you arrive: at most POGO_CLASH_TOLERANCE before your pogo box
# reaches them, or while it's still checking. Both blades flash, you bounce; nothing is refreshed.
# A downslash onto a partner who didn't upslash does nothing special.
# ENVIRONMENT POGO (Moves "pogo_environment", for the gyms): targets, lanterns and spikes bounce
# it too, refreshing what the pogo_refresh switches say. Never the boss.
const DOWNSLASH_ACTIVE_TIME = 0.06  # just the look: the pogo is the box (POGO_WINDOW)
const DOWNSLASH_RETURN_TIME = 0.08
const DOWNSLASH_START_ANGLE = 0.0  # level in front...
const DOWNSLASH_END_ANGLE = PI  # ...sweeping under you to level behind
const DOWNSLASH_DAMAGE = 10.0
const POGO_HEIGHT = 110.0
const POGO_RISE_GRAVITY = 1.6  # gravity times this on a pogo's rise: same height, a quicker bounce
# Anything in this box under you (width, depth below your feet) bounces a downslash right away,
# checked before you move, so a fast fall can't carry you into spikes first. It's centered and
# it's the downslash's whole reach (the swinging blade doesn't count), so facing doesn't matter.
const POGO_REACH = Vector2(80.0, 28.0)
const POGO_WINDOW = 0.15  # the box is checked this long from the press, whatever the blade is doing
const POGO_GRACE = 0.1  # spikes touched this soon after a pogo don't count (see just_pogoed())
const POGO_CLASH_TOLERANCE = 0.15
# CHIMNEY CLASH (Moves "chimney_clash"): two players who both just wall-jumped, flying at each
# other, clash in mid-air: held a moment, then thrown back toward the walls they came from,
# higher than a wall jump goes. A chimney too wide to climb alone becomes a climb for two.
# Players collide, so flying into each other counts as meeting even once the bump has stopped them.
const CHIMNEY_WINDOW = 0.6  # s since each one's wall jump
const CHIMNEY_REACH = Vector2(60.0, 60.0)
const CHIMNEY_CLASH_TIME = 0.1
const CHIMNEY_BOOST_HEIGHT = 160.0
const CHIMNEY_PUSH = 380.0
# MOMENTUM RELAY (Moves "momentum_relay"): a dash-slash into a partner who parries it: their
# block press must come at most RELAY_PARRY_TOLERANCE before the blades meet (the dash-slash's
# windup is the cue). Just holding block, or pressing too early, only stops the dash with a dull
# clang and bounces the dasher off (RELAY_FAIL_BOUNCE). On a parry the blades
# lock for RELAY_CLASH_TIME, both held in place, while the dasher aims (5 directions, sideways
# or upward, with move and up/jump; never downward; no input keeps the dash's direction); then
# the dasher is boosted that way, gravity off, and the partner pushed back the other way. The
# dash comes back only if Moves "relay_refresh_dash" says so; the air jump never does.
const RELAY_CLASH_TIME = 0.25
const RELAY_SPEED = 1000.0
const RELAY_BOOST_TIME = 0.22  # ~220 px
const RELAY_EXIT_FRACTION = 0.45  # of the boost's speed kept once it ends
const RELAY_RECOIL = 220.0
const RELAY_PARRY_TOLERANCE = 0.2
const RELAY_FAIL_BOUNCE = Vector2(260.0, -220.0)  # the dasher, off a block that wasn't a parry
const GUARD_ANGLE = 0.55  # blocking: the sword held diagonally down...
const GUARD_OFFSET = Vector2(6, -12)  # ...in front, from the chest (x mirrors with facing)
const PARRY_FLICK_ANGLE = -1.3  # a perfect parry beats the blade up, to past its rest
const PARRY_FLICK_TIME = 0.12
const SWORD_EASE = 25.0  # how fast the blade moves between rest and guard (1/s)
const DROP_THROUGH_TIME = 0.3
const WORLD_LAYER = 1  # floor and walls
const PLAYER_LAYER = 2  # players; they collide with each other while Moves "players_collide" is on
const PLATFORM_LAYER = 4  # one-way platforms live on physics layer 4
const SWORD_FLASH_TIME = 0.1
const DODGE_FLASH_TIME = 0.25
const DODGE_COLOR = Color(0.5, 1.0, 1.0)
const HURT_FLASH_TIME = 0.5  # three 0.1s white flashes with 0.1s gaps
const IDLE_BOB_HEIGHT = 3.0
const IDLE_BOB_HZ = 0.6
const DASH_STRETCH = Vector2(1.3, 0.7)
const DASH_STRETCH_TIME = 0.1
const DRINK_ORB_SIZE = 14.0
# Tumbling: thrown by the boss into the floor, one bounce, a short slide, back up; no control
# until then. The throw itself (launch, bounce, get-up time) is tuned by the attack (grab.gd).
const TUMBLE_MAX_TIME = 2.0  # safety cap
const TUMBLE_WALL_BOUNCE = 0.4  # fraction of sideways speed kept off a wall
const TUMBLE_FRICTION = 1400.0  # sliding along the floor after landing from the bounce
const TUMBLE_SPIN = 0.012  # body rotation per pixel travelled sideways
const TUMBLE_IMPACT_SHAKE = 10.0
# Tethered to the partner (Sphaera Pendula's shackle): a rope of tether_length. Past it, the rope
# pulls the two together, moving whoever gives more: see _tether_give().
const TETHER_MAX_CORRECTION = 40.0  # px per frame, so a respawn doesn't yank the partner across
# BOSS BODY (Moves "boss_body"): a boss may block players with a zone (BaseBoss.body_block()).
# Nobody walks, dashes or jumps through it, and nobody stands on it; see _keep_out_of_boss().
const BOSS_SLIDE_SPEED = 900.0  # px/s: landing on top, you slide off the side you came from
# CALL (Moves "call"): a 3, 2, 1, GO countdown over the caller's head, one beat per CALL_BEAT, so
# GO lands CALL_COUNT beats after the press. Both players pulse on every beat. Informational only.
const CALL_BEAT = 0.4
const CALL_COUNT = 3
const CALL_GO_HOLD = 0.35  # GO stays up this long
const CALL_FONT_SIZE = 44
const CALL_HEIGHT = 112.0  # the number's center, above the caller's
# Hands: same proportions as the boss's (a fifth of the body, gripping the hilt).
const HAND_SIZE_RATIO = 0.2
const HAND_GRIPS = [0.075, 0.275]  # where each hand holds the sword, as a fraction of its length
const HAND_DARKEN = 0.25

@export var player_id: int = 1  # set to 1 or 2 in the inspector
@export var player_color = Color(0.25, 0.5, 1)  # body; P1 blue, P2 orange
@export var sword_color = Color(0.62, 0.8, 1)  # a lighter shade of the body color

var hp = MAX_HP
var potions = POTION_CHARGES
var is_grabbed = false
var is_clashing = false  # blades locked with the boss, held in place
var invincible = false  # testing: hits still land (flash, knockback) but take no health
var facing = 1.0
var body_color: Color
var parry_press_time = -100.0  # when the last block press that can still parry happened
var gathered = 0  # shockwaves parried in the current volley
var swing_serial = 0  # bumped by every new swing and dash-slash (see active_sword_point())
var tether_partner = null  # set_tether()
var tether_length = 0.0

var _gather_needed = 0  # 0 while no volley is running
var _gather_failed = false
var _gather_label: Label

var _air_jumps = AIR_JUMPS
var _coyote_timer = 0.0  # > 0 while a ground jump is still allowed
var _jump_buffer = 0.0  # > 0 while a jump press is waiting to fire
var _dash_ready = true  # refreshed on the ground
var _dash_dir = 1.0
var _dash_timer = 0.0
var _dash_cooldown = 0.0
var _dash_press_time = -100.0
var _dash_slash = false  # this dash is a dash-slash (also true through its windup)
var _windup_timer = 0.0  # > 0 while winding up a dash-slash
var _invuln_timer = 0.0
var _drop_timer = 0.0
var _sword_flash = 0.0
var _dodge_flash = 0.0
var _last_block_press = -100.0
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
var _upslash_hop_ready = true  # refreshed on the ground
var _trail_timer = 0.0
var _launch_timer = 0.0  # > 0 while rising from a launch: the sideways carry isn't eased off
var _knockback_timer = 0.0
var _stagger_timer = 0.0  # > 0 while reeling from a hit: no movement, no input
var _tumble_timer = 0.0  # > 0 while tumbling (see tumble())
var _tumble_damage = 0.0  # dealt when the tumble first hits the floor; 0 once dealt
var _tumble_bounce = Vector2.ZERO  # off the first floor hit: x = sideways speed, y = height
var _tumble_get_up = 0.0  # counts down once landed from the bounce
var _tumble_floor_hits = 0
var _clash_overhead = true  # grand slash clash: sword flat overhead; otherwise level, at the boss
var _drink_timer = 0.0  # > 0 while drinking a potion
var _drink_bar: ColorRect
var _drink_orb: Panel
var _drink_sound = null  # Sfx handle, cut short if the drink is interrupted
var _hurt_flash = 0.0
var _bob_time = 0.0
var _body_rest = Vector2.ZERO
var _stretch_tween: Tween
var _is_dead = false
var _sword_color: Color
var _hands: Array = []  # [ColorRect, ColorRect]
var _was_on_floor = false
var _air_time = 0.0  # seconds since leaving the ground
var _fast_falling = false
var _uncut_timer = 0.0  # > 0 while releasing jump mustn't cut the rise (a pogo, a bounce)
var _pogoed = false  # this downslash already bounced
var _pogo_rise = 0.0  # > 0 while rising from a pogo (heavier gravity, see POGO_RISE_GRAVITY)
var _pogo_time = -100.0
var _downslash_time = -100.0  # when the current downslash was pressed (see POGO_WINDOW)
var _wall_side = 0.0  # -1 / 1 while stuck to a wall on that side, else 0
var _last_wall_side = 0.0
var _wall_time = 0.0  # time stuck, not counting rising along it
var _wall_coyote = 0.0
var _spent_wall_side = 0.0  # the wall last jumped off (see WALL_SPENT_RANGE), 0 once cleared
var _spent_wall_x = 0.0
var _wall_jump_time = -100.0
var _wall_jump_dir = 0.0  # which way the last wall jump flew
var _wall_jump_lock = 0.0
var _wall_flight = 0.0  # > 0 while flying from a wall jump (see WALL_FLIGHT_TIME)
var _wall_held_away = 0.0  # a key held away from the wall since arriving on it (doesn't let go)
var _ledge = false  # hanging from (or climbing over) a ledge
var _ledge_side = 0.0
var _ledge_hang = Vector2.ZERO
var _ledge_stand = Vector2.ZERO  # where the climb ends
var _ledge_time = 0.0
var _ledge_climb = -1.0  # time into the climb; < 0 while hanging
var _ledge_regrab = 0.0
var _hold_kind = Hold.NONE
var _hold_timer = 0.0
var _hold_release = Vector2.ZERO
var _hold_partner = null
var _relay_dir = Vector2.RIGHT
var _relay_arrow: ColorRect
var _boost_timer = 0.0
var _boost_velocity = Vector2.ZERO
var _tell_ring: Node2D  # drawn around the partner (see _update_tell())
var _tell_partner = null
var _tell_left = 0.0  # seconds to the ring's close
var _tell_alpha = 0.0
var _tell_sounded = false
var _block_side = 1.0  # which side of the boss's block you're on (see _keep_out_of_boss())
var _block_above = false  # clear of the block, above it, last frame
var _block_sliding = false  # landed on top: sliding off
var _block_ignored = false  # grabbed or thrown into it: passing through until clear
var _call_time = -1.0  # time into the countdown; < 0 while there's none
var _call_beat = -1
var _call_label: Label

@onready var body: ColorRect = $ColorRect
@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: ColorRect = $SwordPivot/Sword
@onready var sword_hitbox: Area2D = $SwordPivot/SwordHitbox
@onready var _sword_shape: CollisionShape2D = $SwordPivot/SwordHitbox/CollisionShape2D


func _ready():
	body.color = player_color
	sword.color = sword_color
	body_color = player_color
	_sword_color = sword_color
	# Facing the boss if there is one (it's registered first: it comes before the players).
	if player_id == 2:
		facing = -1.0
	if is_instance_valid(GameManager.boss) and GameManager.boss.global_position.x != global_position.x:
		facing = signf(GameManager.boss.global_position.x - global_position.x)
	_block_side = -facing
	_body_rest = body.position
	body.pivot_offset = body.size / 2  # stretch around the center
	_setup_gather_label()
	_setup_drink_bar()
	_setup_hands()
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
	_setup_call_label()
	_update_player_collision()
	Moves.changed.connect(_update_player_collision)
	GameManager.register_player(self)


func _update_player_collision():
	set_collision_mask_value(PLAYER_LAYER, Moves.on("players_collide"))


func _physics_process(delta):
	_tick_timers(delta)
	_process_call(delta)
	if is_grabbed or is_clashing:
		velocity = Vector2.ZERO  # carried by the boss, or braced holding him back
	elif _hold_kind != Hold.NONE:
		_process_hold(delta)
	elif _ledge:
		_process_ledge(delta)
	elif is_tumbling():
		_process_tumble(delta)
	elif is_staggered():
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
	elif is_drinking():
		_process_drinking(delta)
		move_and_slide()
	elif _windup_timer > 0.0:
		_process_windup(delta)
		move_and_slide()
	else:
		_process_movement(delta)
		_process_actions()
		_check_pogo(delta)
		move_and_slide()
		_check_clashes()
	_keep_out_of_boss(delta)
	if not is_grabbed and not is_clashing:
		_apply_tether()
	_track_landing()
	_process_attack()
	_update_visuals()


# Normal gravity on the way up, heavier on the way down, up to the fall speed cap; heavier and
# faster still when fast falling. (Tumbling uses plain GRAVITY, so the grab's bounce height
# comes out as tuned.)
func _apply_gravity(delta, fast = false):
	var gravity = GRAVITY * (FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else 1.0)
	if _pogo_rise > 0.0 and velocity.y < 0.0:
		gravity *= POGO_RISE_GRAVITY
	if fast:
		velocity.y = minf(velocity.y + gravity * FAST_FALL_GRAVITY * delta, FAST_FALL_MAX_SPEED)
	else:
		velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)


# Each player's input set; "Swap P1 / P2 controls" (Moves) trades them, e.g. to play solo on a pad.
func _action(action_name: String) -> String:
	var id = player_id
	if Moves.on("swap_controls"):
		id = 3 - player_id
	return "p%d_%s" % [id, action_name]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# Left/right input, -1..1, for attacks that let a held player steer (e.g. swinging on a hook).
func move_axis() -> float:
	return Input.get_axis(_action("left"), _action("right"))


func _process_movement(delta):
	var direction = move_axis()
	if direction != 0.0:
		facing = signf(direction)
	# A boss that changes sides keeps your eyes on him, whichever way you walk.
	var boss = GameManager.boss
	if is_instance_valid(boss) and boss.holds_facing() and boss.global_position.x != global_position.x:
		facing = signf(boss.global_position.x - global_position.x)
	if _dash_slash and _dash_timer > 0.0:
		facing = _dash_dir  # the thrust points the way of the dash
	_fast_falling = false
	if is_on_floor():
		_air_jumps = AIR_JUMPS
		_coyote_timer = COYOTE_TIME
		_wall_side = 0.0
		_spent_wall_side = 0.0
		_wall_flight = 0.0
	var holding_back = _wall_flight > 0.0 and direction != 0.0 and signf(direction) == -_wall_jump_dir
	if holding_back:
		facing = _wall_jump_dir  # holding toward the wall you left doesn't turn you around

	if _boost_timer > 0.0:
		velocity = _boost_velocity  # a relay boost: straight, gravity off
		return
	if _dash_timer > 0.0:
		velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
		return
	if not is_on_floor() and _knockback_timer <= 0.0:
		if _try_ledge_grab(direction) or _update_wall(direction, delta):
			return

	if _knockback_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
	elif (_launch_timer > 0.0 and direction == 0.0) or _wall_jump_lock > 0.0 or holding_back:
		pass  # a launch's sideways carry (until steered), or flying off a wall: keep it
	else:
		var target = direction * SPEED * (BLOCK_SPEED_FACTOR if is_blocking() else 1.0)
		if target != 0.0 and velocity.x != 0.0 and signf(target) != signf(velocity.x):
			velocity.x *= 1.0 - TURN_SNAP  # turning around: drop the old way's speed
		# Speeding up toward the target speed; slowing down (letting go) is quicker.
		var same_way = velocity.x == 0.0 or signf(target) == signf(velocity.x)
		var speeding_up = target != 0.0 and same_way and absf(target) > absf(velocity.x)
		var rate: float
		if is_on_floor():
			rate = GROUND_ACCEL if speeding_up else GROUND_DECEL
		else:
			rate = AIR_ACCEL if speeding_up else AIR_DECEL
		velocity.x = move_toward(velocity.x, target, rate * delta)
	_fast_falling = Moves.on("fast_fall") and not is_on_floor() and velocity.y > 0.0 \
		and Input.is_action_pressed(_action("down"))
	_apply_gravity(delta, _fast_falling)
	if Input.is_action_just_released(_action("jump")) and velocity.y < 0.0 and _launch_timer <= 0.0 \
			and _uncut_timer <= 0.0:
		velocity.y *= JUMP_CUT


# --- Walls: slide / cling, wall jump ------------------------------------------

# Sticks to, stays on, or lets go of a wall. True while on one (it has moved the player).
func _update_wall(direction: float, delta: float) -> bool:
	var mode = Moves.value("wall")
	if _wall_side != 0.0:
		if signf(direction) != _wall_held_away:
			_wall_held_away = 0.0  # let go of (or changed) the key held on arrival
		var pressing_away = direction != 0.0 and signf(direction) == -_wall_side and _wall_held_away == 0.0
		if mode == "off" or pressing_away or not _touching_wall(_wall_side):
			_leave_wall()
	elif mode != "off":
		var in_flight = _wall_flight > 0.0
		for side in _sides_moving_into(direction):
			if not _wall_spent(side) and _touching_wall(side):
				_attach_wall(side)
				# Carried here by a wall jump while still holding the other way: that key doesn't
				# pull you off until it's let go, so chained wall jumps need no key switching.
				_wall_held_away = signf(direction) if in_flight and signf(direction) == -side else 0.0
				break
	if _wall_side == 0.0:
		return false
	facing = -_wall_side
	velocity.x = 0.0
	if velocity.y < 0.0:
		_apply_gravity(delta)  # still rising along it
	elif mode == "cling" and _wall_time < WALL_CLING_TIME:
		velocity.y = 0.0
		_wall_time += delta
	else:
		velocity.y = WALL_SLIDE_SPEED
		_wall_time += delta
	return true


# The sides you're moving into: the one pressed, the one you're flying toward fast, and the
# one a wall jump is carrying you to.
func _sides_moving_into(direction: float) -> Array:
	var sides = []
	if direction != 0.0:
		sides.append(signf(direction))
	if absf(velocity.x) >= WALL_ATTACH_SPEED:
		sides.append(signf(velocity.x))
	if _wall_flight > 0.0:
		sides.append(_wall_jump_dir)
	return sides


# A wall right beside you on `side`. Only the world counts: a partner isn't a wall.
func _touching_wall(side: float) -> bool:
	var params = PhysicsTestMotionParameters2D.new()
	params.from = global_transform
	params.motion = Vector2(side * WALL_PROBE, 0.0)
	var partners: Array[RID] = []
	for other in get_tree().get_nodes_in_group("players"):
		if other != self:
			partners.append(other.get_rid())
	params.exclude_bodies = partners
	return PhysicsServer2D.body_test_motion(get_rid(), params)


# The wall on `side` is the one last jumped off (see WALL_SPENT_RANGE).
func _wall_spent(side: float) -> bool:
	return side == _spent_wall_side and absf(global_position.x - _spent_wall_x) <= WALL_SPENT_RANGE


func _attach_wall(side: float):
	_wall_side = side
	_wall_time = 0.0
	_wall_flight = 0.0
	_spent_wall_side = 0.0  # a new wall: the old one is fresh again
	_dash_timer = 0.0
	_dash_slash = false
	_launch_timer = 0.0
	_boost_timer = 0.0
	if Moves.on("wall_refresh"):
		refresh_dash()


func _leave_wall():
	if _wall_side != 0.0:
		_last_wall_side = _wall_side
		_wall_coyote = WALL_COYOTE_TIME
	_wall_side = 0.0


# The wall a jump now would push off: the one you're on, one you just let go of, or one you're
# touching and moving into. 0 if none.
func _wall_jump_side() -> float:
	if _wall_side != 0.0:
		return _wall_side
	if _wall_coyote > 0.0:
		return _last_wall_side
	for side in _sides_moving_into(move_axis()):
		if not _wall_spent(side) and _touching_wall(side):
			return side
	return 0.0


func _wall_jump(side: float):
	velocity = Vector2(-side * WALL_JUMP_PUSH, -sqrt(2.0 * GRAVITY * WALL_JUMP_HEIGHT))
	facing = -side
	_wall_side = 0.0
	_wall_coyote = 0.0
	_spent_wall_side = side
	_spent_wall_x = global_position.x
	_wall_jump_lock = WALL_JUMP_LOCK
	_wall_jump_time = _now()
	_wall_jump_dir = -side
	_wall_flight = WALL_FLIGHT_TIME
	_wall_held_away = 0.0
	_jump_buffer = 0.0
	_launch_timer = 0.0
	_boost_timer = 0.0
	_dash_timer = 0.0


# --- Ledges: grab, hang, climb -------------------------------------------------

# Catches a ledge if one is in reach on the side pressed into (or the wall you're on).
func _try_ledge_grab(direction: float) -> bool:
	if not Moves.on("ledge_grab") or _ledge_regrab > 0.0 or velocity.y < -LEDGE_MAX_RISE:
		return false
	var side = _wall_side if _wall_side != 0.0 else signf(direction)
	if side == 0.0:
		return false
	var edge = _find_ledge(side)
	if edge.is_empty():
		return false
	_ledge = true
	_ledge_side = side
	_ledge_hang = Vector2(edge.face_x - side * body.size.x / 2.0, edge.top + LEDGE_HANG_DROP)
	_ledge_stand = edge.stand
	_ledge_time = 0.0
	_ledge_climb = -1.0
	_wall_side = 0.0
	_wall_flight = 0.0
	_spent_wall_side = 0.0
	_dash_timer = 0.0
	_launch_timer = 0.0
	_boost_timer = 0.0
	velocity = Vector2.ZERO
	global_position = _ledge_hang
	facing = side
	if Moves.on("wall_refresh"):
		refresh_dash()
	return true


# A wall on `side` that ends within reach, with room to stand on top: {face_x, top, stand}.
func _find_ledge(side: float) -> Dictionary:
	var space = get_world_2d().direct_space_state
	var half = body.size.x / 2.0
	var at = global_position
	var reach = side * (half + WALL_PROBE + 2.0)
	if not _ray(space, at + Vector2(0.0, -LEDGE_REACH_UP), at + Vector2(reach, -LEDGE_REACH_UP)).is_empty():
		return {}  # the wall goes on above: no edge in reach
	var low = _ray(space, at + Vector2(0.0, LEDGE_REACH_DOWN), at + Vector2(reach, LEDGE_REACH_DOWN))
	if low.is_empty():
		return {}  # no wall here at all
	var face_x = low.position.x
	var inside = face_x + side * 3.0
	var down = _ray(space, Vector2(inside, at.y - LEDGE_REACH_UP), Vector2(inside, at.y + LEDGE_REACH_DOWN + 1.0))
	if down.is_empty():
		return {}
	var stand = Vector2(face_x + side * (half + 4.0), down.position.y - half - 1.0)
	if not _room_for_body(space, stand):
		return {}
	return {"face_x": face_x, "top": down.position.y, "stand": stand}


func _ray(space, from: Vector2, to: Vector2) -> Dictionary:
	var query = PhysicsRayQueryParameters2D.create(from, to, 1 << (WORLD_LAYER - 1))
	return space.intersect_ray(query)


func _room_for_body(space, center: Vector2) -> bool:
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = RectangleShape2D.new()
	shape.size = body.size - Vector2(2.0, 2.0)
	query.shape = shape
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 1 << (WORLD_LAYER - 1)
	return space.intersect_shape(query, 1).is_empty()


func _process_ledge(delta):
	velocity = Vector2.ZERO
	if _ledge_climb >= 0.0:
		# Up first, then over the edge.
		_ledge_climb += delta
		var t = clampf(_ledge_climb / LEDGE_CLIMB_TIME, 0.0, 1.0)
		var up = Vector2(_ledge_hang.x, _ledge_stand.y)
		global_position = _ledge_hang.lerp(up, minf(t * 2.0, 1.0)) if t < 0.5 else up.lerp(_ledge_stand, t * 2.0 - 1.0)
		if t >= 1.0:
			_ledge = false
		return
	global_position = _ledge_hang
	_ledge_time += delta
	var direction = move_axis()
	var toward = direction != 0.0 and signf(direction) == _ledge_side
	if signf(direction) != _wall_held_away:
		_wall_held_away = 0.0
	var away = direction != 0.0 and signf(direction) == -_ledge_side and _wall_held_away == 0.0
	if Input.is_action_just_pressed(_action("jump")):
		_ledge = false
		_ledge_regrab = LEDGE_REGRAB_TIME
		velocity.y = -sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
	elif Input.is_action_pressed(_action("up")) or (toward and _ledge_time >= LEDGE_MIN_HANG):
		_ledge_climb = 0.0
	elif away or Input.is_action_just_pressed(_action("down")):
		_ledge = false
		_ledge_regrab = LEDGE_REGRAB_TIME


func _process_actions():
	if Input.is_action_just_pressed(_action("jump")):
		_jump_buffer = JUMP_BUFFER_TIME
	if _jump_buffer > 0.0:
		_try_jump()

	# The dash goes the way you face (_process_movement() has already turned you this frame);
	# while a boss holds your facing, the way you hold.
	if Input.is_action_just_pressed(_action("dash")):
		var held = move_axis()
		var boss = GameManager.boss
		var free = held != 0.0 and is_instance_valid(boss) and boss.holds_facing()
		_start_dash(signf(held) if free else facing)

	if Input.is_action_just_pressed(_action("block")) and not _is_swinging():
		var now = _now()
		# Mashing doesn't parry: a press too soon after the previous one isn't a parry attempt.
		parry_press_time = now if now - _last_block_press >= PARRY_SPAM_LOCK else -100.0
		_last_block_press = now

	if Input.is_action_just_pressed(_action("attack")):
		_press_attack()
	elif _attack_buffer > 0.0 and _attack_cooldown <= 0.0:
		_press_attack()  # pressed a moment too early: it comes now
	elif Input.is_action_just_pressed(_action("up")) and _attack_timer > 0.0 \
			and _swing_kind == Swing.SLASH and not _attack_landed \
			and _now() - _slash_press_time <= UPSLASH_LATE:
		_press_upslash()  # up came a moment after the attack: it's an upslash after all

	if Input.is_action_just_pressed(_action("down")) and is_on_floor():
		set_collision_mask_value(PLATFORM_LAYER, false)
		_drop_timer = DROP_THROUGH_TIME

	if Input.is_action_just_pressed(_action("potion")) and potions > 0 and _knockback_timer <= 0.0:
		_drink_timer = DRINK_TIME
		_dash_timer = 0.0
		_attack_timer = 0.0
		velocity.x = 0.0
		_drink_sound = Sfx.play("drink", -3.0)  # same length as the drink


# --- Potions ------------------------------------------------------------------

func is_drinking() -> bool:
	return _drink_timer > 0.0


# Rooted in place while drinking; gravity still applies and hits still land.
func _process_drinking(delta):
	velocity.x = 0.0
	_apply_gravity(delta)
	_drink_timer = maxf(_drink_timer - delta, 0.0)
	if _drink_timer <= 0.0:
		potions -= 1
		hp = minf(hp + POTION_HEAL, MAX_HP)
		health_changed.emit(self, hp)


# An interrupted drink still uses up the charge.
func _cancel_drink():
	if is_drinking():
		_drink_timer = 0.0
		potions -= 1
		Sfx.stop(_drink_sound)


# Jumps if it can: from the ground (or just off a ledge), off a wall, else with an air jump. A
# fresh press with none of those stays buffered, and fires on landing (or on reaching a wall)
# if that comes soon enough.
func _try_jump():
	if _coyote_timer > 0.0:
		velocity.y = -sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
	elif Moves.on("wall_jump") and _wall_jump_side() != 0.0:
		_wall_jump(_wall_jump_side())
		return
	elif Moves.on("double_jump") and _air_jumps > 0 and Input.is_action_just_pressed(_action("jump")):
		_air_jumps -= 1
		velocity.y = -sqrt(2.0 * GRAVITY * DOUBLE_JUMP_HEIGHT)
	else:
		return
	_jump_buffer = 0.0
	_coyote_timer = 0.0
	_launch_timer = 0.0
	_boost_timer = 0.0
	_uncut_timer = 0.0
	if _dash_timer > 0.0:
		# Jumping cancels a dash, carrying only a normal amount of its speed.
		_dash_timer = 0.0
		velocity.x = clampf(velocity.x, -DASH_EXIT_SPEED, DASH_EXIT_SPEED)


func _start_dash(direction: float):
	if not Moves.on("dash") or _dash_cooldown > 0.0 or not _dash_ready:
		return
	# A slash pressed a moment ago turns into a dash-slash.
	var slash_lead = Moves.on("dash_slash") and _attack_timer > 0.0 and _swing_kind == Swing.SLASH \
		and _now() - _slash_press_time <= DASH_SLASH_LEAD
	_leave_wall()
	_wall_flight = 0.0
	_boost_timer = 0.0
	_dash_ready = false
	_dash_dir = direction
	_dash_timer = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	_dash_press_time = _now()
	_dash_slash = false
	_launch_timer = 0.0
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	# Squash-and-stretch: snap wide and short, then spring back.
	if _stretch_tween:
		_stretch_tween.kill()
	body.scale = DASH_STRETCH
	_stretch_tween = create_tween()
	_stretch_tween.tween_property(body, "scale", Vector2.ONE, DASH_STRETCH_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if slash_lead:
		var already_hit = _attack_landed
		_attack_timer = 0.0
		_begin_dash_slash()
		_attack_landed = already_hit  # a slash that already hit doesn't hit again as a dash-slash


# --- Sword: slash, upslash, dash-slash -----------------------------------------

func _press_attack():
	if Moves.on("dash_slash") and _dash_timer > 0.0 and not _dash_slash \
			and _now() - _dash_press_time <= DASH_SLASH_LATE:
		_begin_dash_slash()  # attacking right as the dash starts
		return
	if _attack_cooldown > 0.0:
		_attack_buffer = ATTACK_BUFFER_TIME
		return
	_attack_buffer = 0.0
	if is_blocking():
		return
	if Input.is_action_pressed(_action("up")) and _dash_timer <= 0.0:
		_press_upslash()
		return
	if (Moves.on("pogo") or Moves.on("pogo_environment")) and not is_on_floor() and _dash_timer <= 0.0 \
			and Input.is_action_pressed(_action("down")):
		_start_swing(Swing.DOWNSLASH)
		Sfx.play("slash", -4.0)
		return
	_start_swing(Swing.SLASH)
	_slash_press_time = _now()
	Sfx.play("slash", -4.0)


# Attack while holding up (also reached from a slash that up followed a moment later).
func _press_upslash():
	_start_swing(Swing.UPSLASH)
	_upslash_press_time = _now()
	if _upslash_hop_ready and Moves.on("upslash_hop"):
		_upslash_hop_ready = false
		velocity.y = minf(velocity.y, -sqrt(2.0 * GRAVITY * UPSLASH_HOP_HEIGHT))
		_coyote_timer = 0.0
	Sfx.play("slash", -4.0)


func _start_swing(kind: Swing):
	_swing_from_angle = _sword_angle()
	_swing_kind = kind
	_attack_timer = _swing_windup_time() + _swing_active_time() + _swing_return_time()
	_attack_cooldown = UPSLASH_COOLDOWN if kind == Swing.UPSLASH else ATTACK_COOLDOWN
	_attack_landed = false
	_pogoed = false
	_downslash_time = _now() if kind == Swing.DOWNSLASH else -100.0
	parry_press_time = -100.0  # a swing gives up the parry window
	swing_serial += 1


# The dash-slash's windup: held in place, blade drawn back, then the dash (_process_windup()).
func _begin_dash_slash():
	_dash_slash = true
	_windup_timer = DASH_SLASH_WINDUP
	_dash_timer = 0.0
	_attack_timer = 0.0
	_attack_landed = false
	_downslash_time = -100.0
	_attack_cooldown = DASH_SLASH_COOLDOWN
	parry_press_time = -100.0  # as a swing does
	_tell_sounded = false
	facing = _dash_dir
	velocity = Vector2.ZERO


func _process_windup(delta):
	velocity = Vector2.ZERO  # hanging still, even in the air
	facing = _dash_dir
	_windup_timer -= delta
	if _windup_timer > 0.0:
		return
	_windup_timer = 0.0
	_dash_timer = DASH_TIME
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	swing_serial += 1
	_trail_timer = 0.0
	if _stretch_tween:
		_stretch_tween.kill()
	body.scale = DASH_STRETCH
	_stretch_tween = create_tween()
	_stretch_tween.tween_property(body, "scale", Vector2.ONE, DASH_STRETCH_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("stab", 1.0)
	Sfx.play("slash", -2.0)


func is_winding_up() -> bool:
	return _windup_timer > 0.0


func _swing_windup_time() -> float:
	match _swing_kind:
		Swing.UPSLASH:
			return UPSLASH_WINDUP_TIME
		Swing.DOWNSLASH:
			return 0.0
	return ATTACK_WINDUP_TIME


func _swing_active_time() -> float:
	match _swing_kind:
		Swing.UPSLASH:
			return UPSLASH_ACTIVE_TIME
		Swing.DOWNSLASH:
			return DOWNSLASH_ACTIVE_TIME
	return ATTACK_ACTIVE_TIME


func _swing_return_time() -> float:
	match _swing_kind:
		Swing.UPSLASH:
			return UPSLASH_RETURN_TIME
		Swing.DOWNSLASH:
			return DOWNSLASH_RETURN_TIME
	return ATTACK_RETURN_TIME


func _swing_elapsed() -> float:
	return _swing_windup_time() + _swing_active_time() + _swing_return_time() - _attack_timer


# True from the attack press until the blade is back at rest: a swing from its windup to the end
# of its return (or of its recoil, if it was parried), or a dash-slash from its windup to the end
# of the dash. No blocking or parrying meanwhile.
func _is_swinging() -> bool:
	return _attack_timer > 0.0 or _recoil_timer > 0.0 or _windup_timer > 0.0 \
		or (_dash_slash and _dash_timer > 0.0)


# True while the blade can hit: a swing's active part, or all through a dash-slash.
func _is_sword_active() -> bool:
	if _dash_slash and _dash_timer > 0.0:
		return true
	var cutting = _swing_elapsed() - _swing_windup_time()
	return _attack_timer > 0.0 and cutting >= 0.0 and cutting < _swing_active_time()


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
	match _swing_kind:
		Swing.UPSLASH:
			return UPSLASH_DAMAGE
		Swing.DOWNSLASH:
			return DOWNSLASH_DAMAGE
	return ATTACK_DAMAGE


# The middle of the blade's hitbox while it can hit, else null. For attacks with parts that
# are struck without being the boss's body (e.g. a chain), together with swing_serial so each
# swing counts once.
func active_sword_point():
	if not _is_sword_active():
		return null
	return _sword_shape.global_position


# Sword hits: damage on the boss (or a target). A downslash never hits the boss; on targets its
# hits are _check_pogo()'s.
func _process_attack():
	if not _is_sword_active() or _is_downslash():
		return
	for hit in sword_hitbox.get_overlapping_bodies():
		if hit.is_in_group("boss") and not _attack_landed:
			_attack_landed = true
			hit.take_damage(_swing_damage() * GameManager.damage_multiplier(), self)


func _is_downslash() -> bool:
	return _swing_kind == Swing.DOWNSLASH and not (_dash_slash and _dash_timer > 0.0)


# Before moving: a downslash's pogo box, POGO_REACH under you (stretched by how far you fall this
# frame), so the bounce comes before you'd land. From the press (that same frame) for
# POGO_WINDOW; the blade's position and timing don't matter. The partner in it with a fresh
# upslash is a pogo clash; with Moves "pogo_environment", targets, lanterns and spikes bounce it.
func _check_pogo(delta):
	if _pogoed or _now() - _downslash_time > POGO_WINDOW:
		return
	var half = body.size / 2.0
	var depth = POGO_REACH.y + maxf(velocity.y * delta, 0.0)
	if Moves.on("pogo"):
		for other in get_tree().get_nodes_in_group("players"):
			var gap = other.global_position - global_position
			if other != self and absf(gap.x) <= POGO_REACH.x / 2.0 + half.x \
					and gap.y >= half.y and gap.y <= body.size.y + depth \
					and other.is_upslash_fresh(POGO_CLASH_TOLERANCE):
				_pogo_clash(other)
				return
	if not Moves.on("pogo_environment"):
		return
	var shape = RectangleShape2D.new()
	shape.size = Vector2(POGO_REACH.x, half.y + depth)
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, (half.y + depth) / 2.0))
	query.collision_mask = 1 << 2  # the boss's layer, where spikes and targets are too
	query.exclude = [get_rid()]
	for result in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var hit = result.collider
		if hit is BaseBoss:
			continue  # the boss is never pogoed off
		if hit.is_in_group("boss") and not _attack_landed:
			_attack_landed = true
			hit.take_damage(_swing_damage() * GameManager.damage_multiplier(), self)
			_pogo()
		elif hit.is_in_group("pogo"):
			_pogo()


# Spikes touched this soon after a pogo are forgiven (the bounce is already carrying you out).
func just_pogoed() -> bool:
	return _now() - _pogo_time <= POGO_GRACE


# A bounce off something in the world (Moves "pogo_environment"), refreshing what the Moves
# switches say.
func _pogo():
	if _pogoed:
		return
	_bounce()
	if Moves.on("pogo_refresh_air_jump"):
		_air_jumps = AIR_JUMPS
		_upslash_hop_ready = true
	if Moves.on("pogo_refresh_dash"):
		_dash_ready = true
		_dash_cooldown = 0.0
	_spawn_sparks(global_position + Vector2(0.0, body.size.y / 2.0 + 6.0), 6, _sword_color.lightened(0.5))
	Sfx.play("parry", -8.0)


# The downslash met the partner's upslash: both blades flash and the downslasher bounces. No
# refreshes. It counts toward the launch's sync gain (see GameManager).
func _pogo_clash(partner):
	_bounce()
	partner.on_launch_clash()
	var point = (global_position + partner.global_position) / 2.0
	_spawn_sparks(point, 14, body_color.lerp(partner.body_color, 0.5).lightened(0.5))
	Sfx.play("parry_strong")
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(4.0)
	pogo_clashed.emit(self)


# The bounce off a downslash: up to POGO_HEIGHT, whatever the fall.
func _bounce():
	_pogoed = true
	_pogo_time = _now()
	var rise = sqrt(2.0 * GRAVITY * POGO_RISE_GRAVITY * POGO_HEIGHT)
	velocity.y = -rise
	_pogo_rise = rise / (GRAVITY * POGO_RISE_GRAVITY)
	_uncut_timer = _pogo_rise
	_launch_timer = 0.0
	_boost_timer = 0.0
	_sword_flash = SWORD_FLASH_TIME


# --- Clashes with the partner: launch, momentum relay, chimney clash -----------

# The upslash side of a launch: pressed recently enough to meet a dash-slash.
func is_launch_ready() -> bool:
	return is_upslash_fresh(LAUNCH_TOLERANCE)


# Upslashing, pressed at most `tolerance` ago (the launch and the pogo clash).
func is_upslash_fresh(tolerance: float) -> bool:
	return _swing_kind == Swing.UPSLASH and _attack_timer > 0.0 \
		and _now() - _upslash_press_time <= tolerance \
		and not is_grabbed and not is_staggered() and not is_tumbling()


# Checked every frame: a dash-slash meeting the partner's upslash (launch) or block (relay), or
# two wall jumps meeting (chimney clash).
func _check_clashes():
	for other in get_tree().get_nodes_in_group("players"):
		if other == self or other._hold_kind != Hold.NONE:
			continue
		var gap = other.global_position - global_position
		if _dash_slash and _dash_timer > 0.0 and absf(gap.x) <= LAUNCH_REACH.x and absf(gap.y) <= LAUNCH_REACH.y:
			if Moves.on("launch") and other.is_launch_ready():
				_launch(other)
				return
			if Moves.on("momentum_relay") and other.is_relay_parry():
				_start_relay(other)
				return
			if Moves.on("momentum_relay") and other.is_blocking():
				_relay_blocked(other)
				return
		# Each pair is checked once, by the lower id. Flying at each other, or already bumped
		# together (the bump stops them) after jumping off opposite walls.
		if Moves.on("chimney_clash") and player_id < other.player_id and _in_wall_flight() \
				and other._in_wall_flight() and absf(gap.x) <= CHIMNEY_REACH.x \
				and absf(gap.y) <= CHIMNEY_REACH.y:
			var closing = gap.x * velocity.x > 0.0 and gap.x * other.velocity.x < 0.0
			var bumped = _wall_jump_dir * gap.x > 0.0 and other._wall_jump_dir * gap.x < 0.0 \
				and absf(gap.x) <= body.size.x + WALL_PROBE
			if closing or bumped:
				_chimney_clash(other)
				return


func _in_wall_flight() -> bool:
	return not is_on_floor() and _hold_kind == Hold.NONE and _now() - _wall_jump_time <= CHIMNEY_WINDOW


# Both thrown back toward the walls they jumped from, higher.
func _chimney_clash(other):
	var point = (global_position + other.global_position) / 2.0
	var boost = -sqrt(2.0 * GRAVITY * CHIMNEY_BOOST_HEIGHT)
	for p in [self, other]:
		var back = signf(p.global_position.x - point.x)
		p._begin_hold(Hold.CHIMNEY, CHIMNEY_CLASH_TIME, Vector2(back * CHIMNEY_PUSH, boost))
		p._wall_jump_time = -100.0  # one clash per wall jump
		p._spent_wall_side = 0.0  # thrown back at the wall they came from: it's climbable again
		p._sword_flash = SWORD_FLASH_TIME
	_spawn_sparks(point, 14, body_color.lerp(other.body_color, 0.5).lightened(0.5))
	Sfx.play("parry_strong")
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(4.0)


# Blades locked: the dasher aims while both are held, then boosts (see _release_hold()).
func _start_relay(anchor):
	_relay_dir = Vector2(_dash_dir, 0.0)
	_begin_hold(Hold.RELAY_DASHER, RELAY_CLASH_TIME, Vector2.ZERO, anchor)
	# The anchor's hold outlasts the dasher's, so the dasher's release is what frees them.
	anchor._begin_hold(Hold.RELAY_ANCHOR, RELAY_CLASH_TIME + 0.1)
	anchor.parry_press_time = -100.0  # one press parries one dash-slash
	_sword_flash = SWORD_FLASH_TIME
	anchor._sword_flash = SWORD_FLASH_TIME
	_spawn_sparks((global_position + anchor.global_position) / 2.0, 12, Color(1.0, 0.85, 0.4))
	Sfx.play("parry_strong")
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(4.0)
	relayed.emit(self)


# The partner parried a dash-slash: blocked, with the press timed to the blades meeting.
func is_relay_parry() -> bool:
	return is_blocking() and _now() - parry_press_time <= RELAY_PARRY_TOLERANCE


# Blocked but not parried: the dash stops dead with a dull clang, and the dasher bounces off.
func _relay_blocked(anchor):
	_dash_timer = 0.0
	_dash_slash = false
	var back = -signf(anchor.global_position.x - global_position.x)
	if back == 0.0:
		back = -_dash_dir
	apply_knockback(Vector2(back * RELAY_FAIL_BOUNCE.x, RELAY_FAIL_BOUNCE.y))
	_spawn_sparks((global_position + anchor.global_position) / 2.0, 5, Color(0.6, 0.6, 0.6))
	Sfx.play("chip")


func _begin_hold(kind: Hold, time: float, release = Vector2.ZERO, partner = null):
	_hold_kind = kind
	_hold_timer = time
	_hold_release = release
	_hold_partner = partner
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	_dash_slash = false
	_windup_timer = 0.0
	_attack_timer = 0.0
	_launch_timer = 0.0
	_boost_timer = 0.0
	_wall_side = 0.0
	_wall_flight = 0.0


func _process_hold(delta):
	velocity = Vector2.ZERO
	_hold_timer -= delta
	if _hold_kind == Hold.RELAY_DASHER:
		_relay_dir = _aim(_relay_dir)
	if _hold_timer <= 0.0:
		_release_hold()


func _release_hold():
	var kind = _hold_kind
	_hold_kind = Hold.NONE
	match kind:
		Hold.CHIMNEY:
			velocity = _hold_release
			if velocity.x != 0.0:
				facing = signf(velocity.x)
				_wall_jump_dir = facing  # a flight back to the wall, like a wall jump's
				_wall_flight = WALL_FLIGHT_TIME
			_wall_jump_lock = WALL_JUMP_LOCK
			_uncut_timer = -_hold_release.y / GRAVITY
		Hold.RELAY_DASHER:
			_boost_velocity = _relay_dir * RELAY_SPEED
			_boost_timer = RELAY_BOOST_TIME
			velocity = _boost_velocity
			if _relay_dir.x != 0.0:
				facing = signf(_relay_dir.x)
			if Moves.on("relay_refresh_dash"):
				_dash_ready = true
				_dash_cooldown = 0.0
			var anchor = _hold_partner
			if anchor and is_instance_valid(anchor) and anchor._hold_kind == Hold.RELAY_ANCHOR:
				anchor._hold_kind = Hold.NONE
				anchor.apply_knockback(-_relay_dir * RELAY_RECOIL)
			Sfx.play("launch", -4.0)
	_hold_partner = null


# The direction held right now, sideways or upward, snapped to 5 ways (down doesn't count);
# `fallback` if none.
func _aim(fallback: Vector2) -> Vector2:
	var aim = Vector2(move_axis(), 0.0)
	if Input.is_action_pressed(_action("up")) or Input.is_action_pressed(_action("jump")):
		aim.y -= 1.0
	if aim.length() < 0.5:
		return fallback
	return Vector2.from_angle(snappedf(aim.angle(), PI / 4.0))


# Stops everything the player was doing in the air: walls, ledges, clashes, boosts. For hits,
# grabs, respawns and the like.
func interrupt_movement():
	if _windup_timer > 0.0:
		_windup_timer = 0.0
		_dash_slash = false
	_wall_side = 0.0
	_wall_flight = 0.0
	_pogo_rise = 0.0
	_downslash_time = -100.0
	_ledge = false
	_boost_timer = 0.0
	_hold_kind = Hold.NONE
	_hold_timer = 0.0
	_hold_partner = null


# What the player is doing, for readouts.
func movement_state() -> String:
	if _hold_kind != Hold.NONE:
		return "clash"
	if _ledge:
		return "climbing" if _ledge_climb >= 0.0 else "ledge"
	if _boost_timer > 0.0:
		return "relay boost"
	if _wall_side != 0.0:
		return "wall cling" if velocity.y == 0.0 else "wall slide"
	if _windup_timer > 0.0:
		return "dash-slash windup"
	if _dash_timer > 0.0:
		return "dash-slash" if _dash_slash else "dash"
	if is_on_floor():
		return "ground"
	if _fast_falling:
		return "fast fall"
	return "air"


# The blades clash: the dash's momentum turns upward.
func _launch(partner):
	var rise_speed = sqrt(2.0 * GRAVITY * LAUNCH_HEIGHT)
	velocity = Vector2(_dash_dir * DASH_SPEED * LAUNCH_CARRY, -rise_speed)
	_dash_timer = 0.0
	_dash_slash = false
	_launch_timer = rise_speed / GRAVITY  # until the top of the rise
	_coyote_timer = 0.0
	_jump_buffer = 0.0
	refresh_air_moves()
	_sword_flash = SWORD_FLASH_TIME
	if _stretch_tween:
		_stretch_tween.kill()
	body.scale = LAUNCH_STRETCH
	_stretch_tween = create_tween()
	_stretch_tween.tween_property(body, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	partner.on_launch_clash()
	var point = (global_position + partner.global_position) / 2.0
	_spawn_sparks(point, 16, body_color.lerp(partner.body_color, 0.5).lightened(0.5))
	Sfx.play("parry_strong")
	Sfx.play("launch", -3.0)
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(6.0)
	launched.emit(self)


# The upslash side of a launch.
func on_launch_clash():
	_sword_flash = SWORD_FLASH_TIME
	_upslash_press_time = -100.0  # one upslash launches once


func is_launching() -> bool:
	return _launch_timer > 0.0


# Air jumps, the dash and the upslash hop back, as if touching the ground.
func refresh_air_moves():
	_air_jumps = AIR_JUMPS
	_dash_ready = true
	_dash_cooldown = 0.0
	_upslash_hop_ready = true


# Just the dash back (walls and ledges: the air jump only comes back on landing or a pogo).
func refresh_dash():
	_dash_ready = true
	_dash_cooldown = 0.0


func _tick_timers(delta):
	if _dash_timer > 0.0 and _dash_timer <= delta:
		# The dash runs out: keep only running speed, which the usual acceleration takes from there.
		velocity.x = _dash_dir * DASH_EXIT_SPEED
		_dash_slash = false
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if is_on_floor():
		_dash_ready = true
		_upslash_hop_ready = true
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_sword_flash = maxf(_sword_flash - delta, 0.0)
	_recoil_timer = maxf(_recoil_timer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	_parry_flick = maxf(_parry_flick - delta, 0.0)
	_dodge_flash = maxf(_dodge_flash - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_launch_timer = maxf(_launch_timer - delta, 0.0)
	if _boost_timer > 0.0 and _boost_timer <= delta:
		velocity = _boost_velocity * RELAY_EXIT_FRACTION  # the boost runs out: keep some of it
	_boost_timer = maxf(_boost_timer - delta, 0.0)
	_uncut_timer = maxf(_uncut_timer - delta, 0.0)
	_pogo_rise = maxf(_pogo_rise - delta, 0.0)
	_wall_coyote = maxf(_wall_coyote - delta, 0.0)
	_wall_jump_lock = maxf(_wall_jump_lock - delta, 0.0)
	_wall_flight = maxf(_wall_flight - delta, 0.0)
	_ledge_regrab = maxf(_ledge_regrab - delta, 0.0)
	_knockback_timer = maxf(_knockback_timer - delta, 0.0)
	_stagger_timer = maxf(_stagger_timer - delta, 0.0)
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER, true)


# Emits landed() on touchdown, with how long the player was in the air. (Time, not height: on
# a moving pan the height fallen says little.)
func _track_landing():
	var grounded = is_on_floor()
	if grounded and not _was_on_floor:
		landed.emit(self, _air_time)
	if grounded:
		_air_time = 0.0
	else:
		_air_time += get_physics_process_delta_time()
	_was_on_floor = grounded


# --- Defensive queries used by the boss at the moment its hitbox connects ---

func is_blocking() -> bool:
	return not is_grabbed and not is_drinking() and not is_staggered() and not is_tumbling() \
		and not _is_swinging() and Input.is_action_pressed(_action("block"))


func is_perfect_parry() -> bool:
	return not is_grabbed and not is_drinking() and not is_staggered() and not is_tumbling() \
		and _now() - parry_press_time <= PARRY_TOLERANCE


func is_staggered() -> bool:
	return _stagger_timer > 0.0


func is_perfect_dodge() -> bool:
	return not is_grabbed and _now() - _dash_press_time <= DODGE_TOLERANCE


# Standing on the arena floor itself, not on a one-way platform. Standing on the partner counts
# as standing where they stand (see get_floor_body()).
func is_on_main_floor() -> bool:
	var floor_body = get_floor_body()
	return floor_body is CollisionObject2D and floor_body.get_collision_layer_value(WORLD_LAYER)


# What the player is standing on (e.g. which pan of the Scales), or null in the air. Standing on
# the partner counts as standing on whatever they stand on.
func get_floor_body():
	if not is_on_floor():
		return null
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_normal().y < -0.7:
			var collider = collision.get_collider()
			if collider != null and collider.is_in_group("players") and collider != self:
				return collider.get_floor_body()
			return collider
	return null


# --- Shockwave gathering: all-or-nothing per volley --------------------------

func start_gather(needed: int):
	gathered = 0
	_gather_needed = needed
	_gather_failed = false


func add_gather():
	if not _gather_failed:
		gathered += 1


func fail_gather():
	gathered = 0
	_gather_failed = true


func has_full_gather() -> bool:
	return _gather_needed > 0 and not _gather_failed and gathered >= _gather_needed


func end_gather():
	_gather_needed = 0
	gathered = 0
	_gather_failed = false


func on_perfect_parry(strong: bool):
	parry_press_time = -100.0  # one press parries one hit
	_last_block_press = -100.0  # a landed parry isn't mashing: the next press may parry at once
	_sword_flash = SWORD_FLASH_TIME
	_parry_flick = PARRY_FLICK_TIME
	Sfx.play("parry_strong" if strong else "parry")
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(7.0 if strong else 4.0)


# burst: a ring bursting off the player and a whoosh on top of the flash (Cubus's grab).
func on_grab_dodged(burst = false):
	_dodge_flash = DODGE_FLASH_TIME
	if burst:
		_spawn_ring(DODGE_COLOR, 22.0, 60.0, DODGE_FLASH_TIME)
		Sfx.play("slash", -2.0)


# ignore_invuln: for hits chained faster than the post-hit invulnerability (the triple stab).
func take_damage(amount: float, knockback = Vector2.ZERO, chip = false, ignore_invuln = false):
	if _is_dead or (_invuln_timer > 0.0 and not ignore_invuln):
		return
	if not invincible:
		hp = maxf(hp - amount, 0.0)
	_invuln_timer = CHIP_INVULN_TIME if chip else HIT_INVULN_TIME
	_dash_timer = 0.0
	interrupt_movement()
	_launch_timer = 0.0
	_cancel_drink()
	_hurt_flash = HURT_FLASH_TIME
	velocity = knockback
	if chip:
		Sfx.play("chip")
	else:
		Sfx.play("hurt")
	if knockback != Vector2.ZERO:
		_knockback_timer = KNOCKBACK_TIME
		if not chip:
			Sfx.play_delayed("knockback", 0.06, -4.0)  # the tumble, just behind the impact
	health_changed.emit(self, hp)
	if chip:
		blocked.emit(self)
	else:
		damaged.emit(self)
	if hp <= 0.0:
		_is_dead = true
		died.emit(self)


func set_grabbed(grabbed: bool):
	is_grabbed = grabbed
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	interrupt_movement()
	_launch_timer = 0.0
	if grabbed:
		_cancel_drink()  # being carried off interrupts the drink like a hit would


# Reeling from a hit: can't move, block, parry or act until it wears off.
func stagger(duration: float):
	_stagger_timer = maxf(_stagger_timer, duration)
	velocity.x = 0.0
	_dash_timer = 0.0
	interrupt_movement()
	_attack_timer = 0.0


func set_clashing(clashing: bool, overhead = true):
	is_clashing = clashing
	_clash_overhead = overhead
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	interrupt_movement()
	_attack_timer = 0.0


func apply_knockback(push: Vector2):
	velocity = push
	_knockback_timer = KNOCKBACK_TIME


# Fell out of the arena (the Scales' pit): back in at `spawn`, hurt, briefly invulnerable.
func fall_into_pit(spawn: Vector2, damage: float, invuln_time: float):
	global_position = spawn
	velocity = Vector2.ZERO
	_tumble_timer = 0.0
	body.rotation = 0.0
	_drop_timer = 0.0
	set_collision_mask_value(PLATFORM_LAYER, true)
	_air_time = 0.0
	take_damage(damage, Vector2.ZERO, false, true)
	_invuln_timer = maxf(_invuln_timer, invuln_time)


# Ties this player to `partner` with a rope of `length` px; null unties. Set it on both.
func set_tether(partner, length = 0.0):
	tether_partner = partner
	tether_length = length


# Past the rope's length, pull back toward the partner: this player's share of the excess
# (the rest is the partner's, on their own frame), and no more speed away from them.
func _apply_tether():
	if tether_partner == null or not is_instance_valid(tether_partner):
		return
	var to_partner = tether_partner.global_position - global_position
	var excess = to_partner.length() - tether_length
	if excess <= 0.0:
		return
	var dir = to_partner.normalized()
	var mine = _tether_give()
	var theirs = tether_partner._tether_give()
	var share = 0.5 if mine + theirs <= 0.0 else mine / (mine + theirs)
	if share <= 0.0:
		return
	move_and_collide(dir * minf(excess * share, TETHER_MAX_CORRECTION))
	var away = -velocity.dot(dir)
	if away > 0.0:
		velocity += dir * away


# How easily the rope drags this player: an airborne player swings freely, a grounded one digs
# in, and one blocking on the ground holds fast (an anchor for a partner who fell).
func _tether_give() -> float:
	if is_grabbed or is_clashing:
		return 0.0
	if not is_on_floor():
		return 1.0
	return 0.05 if is_blocking() else 0.3


# Thrown: flies at launch until it hits the floor, where impact_damage (if any) lands and it
# bounces off with bounce.x sideways speed, up to bounce.y pixels high. Landing from that bounce
# it slides, and gets back up (control returns) after get_up_time. Walls bounce it back;
# one-way platforms don't catch it, only the arena floor does.
func tumble(launch: Vector2, impact_damage = 0.0, bounce = Vector2.ZERO, get_up_time = 0.0):
	velocity = launch
	_tumble_timer = TUMBLE_MAX_TIME
	_tumble_damage = impact_damage
	_tumble_bounce = bounce
	_tumble_get_up = get_up_time
	_tumble_floor_hits = 0
	_block_ignored = true  # thrown out of the boss's hands: through his block until clear of it
	_dash_timer = 0.0
	interrupt_movement()
	_attack_timer = 0.0
	_knockback_timer = 0.0
	_launch_timer = 0.0
	_drop_timer = 0.0
	set_collision_mask_value(PLATFORM_LAYER, false)
	_cancel_drink()


func is_tumbling() -> bool:
	return _tumble_timer > 0.0


func _process_tumble(delta):
	_tumble_timer = maxf(_tumble_timer - delta, 0.0)
	if velocity.y < MAX_FALL_SPEED:  # a throw may be faster than a normal fall; don't slow it
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if _tumble_floor_hits >= 2:
		velocity.x = move_toward(velocity.x, 0.0, TUMBLE_FRICTION * delta)
		_tumble_get_up -= delta
	var before = velocity
	move_and_slide()
	body.rotation += before.x * delta * TUMBLE_SPIN

	if is_on_wall():
		velocity.x = -before.x * TUMBLE_WALL_BOUNCE
	if is_on_floor() and before.y > 0.0 and _tumble_floor_hits < 2:
		_tumble_floor_hits += 1
		if _tumble_floor_hits == 1:
			velocity = Vector2(_tumble_bounce.x, -sqrt(2.0 * GRAVITY * maxf(_tumble_bounce.y, 0.0)))
			if _tumble_damage > 0.0:
				var damage = _tumble_damage
				_tumble_damage = 0.0
				take_damage(damage, velocity, false, true)  # keeps the bounce going
				var cam = get_viewport().get_camera_2d()
				if cam and cam.has_method("shake"):
					cam.shake(TUMBLE_IMPACT_SHAKE)

	var got_up = _tumble_floor_hits >= 2 and _tumble_get_up <= 0.0
	if got_up or _tumble_timer <= 0.0 or _is_dead:
		_tumble_timer = 0.0
		body.rotation = 0.0
		set_collision_mask_value(PLATFORM_LAYER, true)


# --- The boss's body (Moves "boss_body") ---------------------------------------

# Keeps the player out of the boss's block (BaseBoss.body_block()). Runs after both have moved
# this frame (the boss comes first in the tree), so his movement wins: an overlapping player is
# pushed out sideways toward the side they were on, never through him; one landing on top
# slides off the side they came from. The push goes through the player's own collision, so walls
# stop it (a partner in the way is shoved along): with no room, the overlap stays until there
# is. The block is never a wall or a floor to the movement: nothing else here sees it.
func _keep_out_of_boss(delta):
	var boss = GameManager.boss
	var block: Rect2 = boss.body_block() if is_instance_valid(boss) else Rect2()
	if block.size == Vector2.ZERO or is_grabbed:
		_block_ignored = is_grabbed
		_block_sliding = false
		return
	var me = Rect2(global_position - body.size / 2.0, body.size)
	if not me.intersects(block):
		_block_ignored = false
		_block_sliding = false
		_block_above = me.end.y <= block.position.y
		# Beside or under him: that's your side. Over him, keep the side you came from.
		var side = signf(global_position.x - block.get_center().x)
		if not _block_above and side != 0.0:
			_block_side = side
		return
	if _block_ignored:
		return  # held or thrown: passing through until clear
	if _block_above:
		_block_sliding = true  # came down on top of him
		_block_above = false
	var out_x = block.position.x - body.size.x / 2.0 if _block_side < 0.0 else block.end.x + body.size.x / 2.0
	var push = out_x - global_position.x
	if _block_sliding:
		push = clampf(push, -BOSS_SLIDE_SPEED * delta, BOSS_SLIDE_SPEED * delta)
	var hit = move_and_collide(Vector2(push, 0.0))
	# A partner in the way is shoved along (through their own collision too), so nobody is left
	# inside him while there's room behind them. Not the one his attack is aimed at, though: he'd
	# drag them along (his approach homes on them), so they stay the wall.
	var other = hit.get_collider() if hit else null
	if other is Node and other.is_in_group("players") and not boss.is_attacking(other):
		other.move_and_collide(hit.get_remainder())
		move_and_collide(hit.get_remainder())
	if velocity.x * _block_side < 0.0:
		velocity.x = 0.0  # stopped at his side, like at a wall


# The boss's block lies between here and `x`, at this player's height.
func _boss_in_the_way(x: float) -> bool:
	var boss = GameManager.boss
	if not is_instance_valid(boss):
		return false
	var block: Rect2 = boss.body_block()
	if block.size == Vector2.ZERO:
		return false
	var span = Rect2(minf(x, global_position.x), global_position.y - body.size.y / 2.0,
		absf(x - global_position.x), body.size.y)
	return span.intersects(block)


# --- The tell: when to press, around the partner of a dash-slash ---------------

# Seconds until this dash-slash's blades meet `other` (LAUNCH_REACH), from where both are now:
# what's left of the windup, then the run at dash speed. -1 if it won't reach them: not winding
# up or dash-slashing, the partner not ahead or too high or low, out of the dash's range, or the
# boss in the way.
func _predict_contact(other) -> float:
	var dashing = _dash_slash and _dash_timer > 0.0
	if _windup_timer <= 0.0 and not dashing:
		return -1.0
	var gap = other.global_position - global_position
	if signf(gap.x) != _dash_dir or absf(gap.y) > LAUNCH_REACH.y:
		return -1.0
	var run = maxf(0.0, absf(gap.x) - LAUNCH_REACH.x)
	var reach = _dash_timer * DASH_SPEED if dashing else DASH_DISTANCE
	if run > reach or _boss_in_the_way(other.global_position.x):
		return -1.0
	return _windup_timer + run / DASH_SPEED


# Every frame: the ring follows the prediction, and fades once there's none (the dash-slash is
# over, clashed, or can't reach).
func _update_tell(delta):
	var partner = null
	var contact = -1.0
	for other in get_tree().get_nodes_in_group("players"):
		if other != self:
			contact = _predict_contact(other)
			if contact >= 0.0:
				partner = other
				break
	if partner:
		_tell_partner = partner
		_tell_left = contact - TELL_LEAD
		_tell_alpha = 1.0
		if not _tell_sounded and _tell_left <= TELL_SOUND_TIME:
			_tell_sounded = true
			Sfx.play("tell", -3.0)
	else:
		_tell_alpha = move_toward(_tell_alpha, 0.0, delta / TELL_FADE)
	_tell_ring.visible = _tell_alpha > 0.0 and is_instance_valid(_tell_partner)
	if _tell_ring.visible:
		_tell_ring.global_position = _tell_partner.global_position
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


# --- Call: a countdown both players can follow ---------------------------------

# The call button starts a 3, 2, 1, GO over this player's head (replacing a partner's running
# one); pressed again during your own, it cancels it. Works whatever the player is doing.
func _process_call(delta):
	if Moves.on("call") and Input.is_action_just_pressed(_action("call")):
		if _call_time >= 0.0:
			cancel_call()
		else:
			for other in get_tree().get_nodes_in_group("players"):
				if other != self:
					other.cancel_call()
			_call_time = 0.0
			_call_beat = -1
	if _call_time < 0.0:
		return
	var beat = floori(_call_time / CALL_BEAT + 0.001)
	if beat > _call_beat and beat <= CALL_COUNT:
		_call_beat = beat
		_on_call_beat(beat)
	if _call_time >= CALL_COUNT * CALL_BEAT + CALL_GO_HOLD:
		cancel_call()
	else:
		_call_time += delta


func cancel_call():
	_call_time = -1.0
	_call_beat = -1
	_call_label.visible = false


func is_calling() -> bool:
	return _call_time >= 0.0


# Beats 0, 1, 2 show 3, 2, 1 with a tick; beat CALL_COUNT is GO.
func _on_call_beat(beat: int):
	var go = beat == CALL_COUNT
	_call_label.text = "GO" if go else str(CALL_COUNT - beat)
	_call_label.visible = true
	_call_label.scale = Vector2.ONE * 1.5
	_call_label.create_tween().tween_property(_call_label, "scale", Vector2.ONE, CALL_BEAT * 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for p in get_tree().get_nodes_in_group("players"):
		p.pulse(Color.WHITE if go else body_color.lightened(0.3), go)
	Sfx.play("call_go" if go else "call_tick", -2.0)


# A ring swelling out of the player and fading: the call's beat, seen by both.
func pulse(color: Color, strong = false):
	_spawn_ring(color, 24.0, 70.0 if strong else 48.0, 0.3 if strong else 0.2)


func _setup_call_label():
	_call_label = Label.new()
	_call_label.size = Vector2(120, 60)
	_call_label.position = Vector2(-60, -CALL_HEIGHT - 30)
	_call_label.pivot_offset = _call_label.size / 2
	_call_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_call_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_call_label.add_theme_font_size_override("font_size", CALL_FONT_SIZE)
	_call_label.add_theme_constant_override("outline_size", 8)
	_call_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_call_label.modulate = body_color.lightened(0.2)
	_call_label.z_index = 10
	_call_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_call_label.visible = false
	add_child(_call_label)


# The blade's angle right now: 0 is level, pointing the way the player faces; negative is up.
func _sword_angle() -> float:
	if is_clashing or _hold_kind != Hold.NONE:
		return 0.0  # held flat against the other blade
	if _dash_slash and _dash_timer > 0.0:
		return 0.0  # thrust out level through the whole dash
	if _windup_timer > 0.0:
		return -0.35  # drawn back, tip raised a little
	if _attack_timer > 0.0:
		var start = SWING_START_ANGLE
		var end = SWING_END_ANGLE
		if _swing_kind == Swing.UPSLASH:
			start = UPSLASH_START_ANGLE
			end = UPSLASH_END_ANGLE
		elif _swing_kind == Swing.DOWNSLASH:
			start = DOWNSLASH_START_ANGLE
			end = DOWNSLASH_END_ANGLE
		var elapsed = _swing_elapsed()
		var windup = _swing_windup_time()
		if elapsed < windup:
			return lerpf(_swing_from_angle, start, elapsed / windup)  # drawn back to where the cut starts
		elapsed -= windup
		var active = _swing_active_time()
		if elapsed < active:
			return lerpf(start, end, elapsed / active)
		# Back to rest. A downslash comes back over the top, finishing the circle, rather than
		# swiping under again.
		var rest = SWORD_REST_ANGLE + (TAU if _swing_kind == Swing.DOWNSLASH else 0.0)
		return lerpf(end, rest, (elapsed - active) / _swing_return_time())
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
	if _is_swinging() or is_clashing or _hold_kind != Hold.NONE:
		_sword_idle_angle = wrapf(_sword_angle(), -PI, PI)  # it carries on from wherever that leaves it
		return
	var target = SWORD_REST_ANGLE
	if _parry_flick > 0.0:
		target = PARRY_FLICK_ANGLE
	elif is_blocking():
		target = GUARD_ANGLE
	_sword_idle_angle = lerpf(_sword_idle_angle, target, 1.0 - exp(-SWORD_EASE * delta))


func _update_visuals():
	_update_tell(get_physics_process_delta_time())
	# Idle bob while standing still on the ground; ease back to rest otherwise.
	var bob = 0.0
	if is_on_floor() and absf(velocity.x) < 1.0 and not is_grabbed:
		_bob_time += get_physics_process_delta_time()
		# Rises from rest and back, never dipping into the floor.
		bob = -IDLE_BOB_HEIGHT * (0.5 - 0.5 * cos(_bob_time * TAU * IDLE_BOB_HZ))
	else:
		_bob_time = 0.0
	body.position.y = lerpf(body.position.y, _body_rest.y + bob, 0.3)
	# Straining to hold the boss back, or locked with the partner's blade: tremble.
	var straining = is_clashing or _hold_kind != Hold.NONE
	body.position.x = _body_rest.x + (randf_range(-2.0, 2.0) if straining else 0.0)
	# Aiming a relay: the arrow shows the way the boost will go.
	_relay_arrow.visible = _hold_kind == Hold.RELAY_DASHER
	if _relay_arrow.visible:
		_relay_arrow.rotation = _relay_dir.angle()
		_relay_arrow.color = body_color.lightened(0.6)

	# Guard pose: sword held diagonally down in front of the chest while blocking; in a clash,
	# flat overhead (grand slash) or level against the boss's blade (triple stab); thrust forward
	# through a dash-slash; otherwise held at the side, diagonally up.
	_update_sword_idle(get_physics_process_delta_time())
	var sword_offset = Vector2(0.0, body.position.y - _body_rest.y)
	if is_clashing:
		sword_offset = Vector2(-38.0 * facing, -28.0) if _clash_overhead else Vector2(0.0, -4.0)
	elif _dash_slash and _dash_timer > 0.0:
		sword_offset = Vector2(DASH_SLASH_THRUST * facing, 0.0)
	elif _windup_timer > 0.0:
		sword_offset = Vector2(-DASH_SLASH_WINDUP_DRAW * facing, 0.0)
	elif is_blocking() and _attack_timer <= 0.0:
		sword_offset = Vector2(GUARD_OFFSET.x * facing, GUARD_OFFSET.y)
	sword_pivot.position = sword_pivot.position.lerp(sword_offset, 0.4)
	var dash_slashing = _dash_slash and _dash_timer > 0.0
	# A dash-slash draws the blade out long and white-hot (its hitbox scales along with it).
	sword_pivot.scale = Vector2(facing * (DASH_SLASH_REACH if dash_slashing else 1.0), 1.0)
	sword_pivot.rotation = _sword_angle() * facing
	if _sword_flash > 0.0:
		sword.color = Color.WHITE
	elif dash_slashing:
		sword.color = _sword_color.lerp(Color.WHITE, DASH_SLASH_GLOW)
	elif _windup_timer > 0.0:
		sword.color = _sword_color.lerp(Color.WHITE, _windup_progress())  # heating up: the cue to parry
	else:
		sword.color = _sword_color
	if dash_slashing:
		_trail_timer -= get_physics_process_delta_time()
		if _trail_timer <= 0.0:
			_trail_timer += DASH_SLASH_TRAIL_INTERVAL
			_spawn_afterimage()

	var color = body_color
	if _hurt_flash > 0.0 and fmod(HURT_FLASH_TIME - _hurt_flash, 0.2) < 0.1:
		color = Color.WHITE
	elif _dodge_flash > 0.0:
		color = DODGE_COLOR
	elif _dash_timer > 0.0:
		color = body_color.lightened(0.5)
	elif _windup_timer > 0.0:
		color = body_color.lightened(0.5 * _windup_progress())
	elif _launch_timer > 0.0:
		color = body_color.lerp(Color.WHITE, 0.3)
	elif straining:
		color = body_color.lerp(Color(1.0, 0.8, 0.3), 0.35 + 0.25 * sin(_now() * 30.0))
	elif _boost_timer > 0.0:
		color = body_color.lightened(0.5)
	elif is_staggered():
		color = body_color.lerp(Color(0.6, 0.6, 0.6), 0.6)
	elif is_blocking():
		color = body_color.darkened(0.3)
	body.color = color
	_update_hands()

	# Drinking cues: a bar under the feet and an orb over the head, both shrinking with the timer.
	var drink_left = _drink_timer / DRINK_TIME
	_drink_bar.visible = is_drinking()
	_drink_orb.visible = is_drinking()
	if is_drinking():
		var width = 44.0 * drink_left
		_drink_bar.size.x = width
		_drink_bar.position.x = -width / 2
		var d = maxf(DRINK_ORB_SIZE * drink_left, 2.0)
		_drink_orb.size = Vector2(d, d)
		_drink_orb.position = Vector2(-d / 2, -40.0 - d / 2)

	_gather_label.visible = _gather_needed > 0
	if _gather_label.visible:
		_gather_label.text = "%d/%d" % [gathered, _gather_needed]
		if _gather_failed:
			_gather_label.modulate = Color(0.5, 0.5, 0.5, 0.7)
		elif has_full_gather():
			# Counter ready: pulse between the player's color and white.
			var pulse = 0.5 + 0.5 * sin(_now() * 20.0)
			_gather_label.modulate = body_color.lerp(Color.WHITE, pulse)
		else:
			_gather_label.modulate = body_color.lerp(Color.WHITE, 0.5)


# 0 -> 1 through a dash-slash's windup.
func _windup_progress() -> float:
	return 1.0 - _windup_timer / DASH_SLASH_WINDUP


# A fading copy of the body and the long blade, left behind along a dash-slash.
func _spawn_afterimage():
	var ghost = ColorRect.new()
	ghost.top_level = true
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = body.size
	ghost.color = Color(body_color.lightened(0.3), 0.45)
	add_child(ghost)
	ghost.global_position = body.global_position
	var blade = ColorRect.new()
	blade.top_level = true
	blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blade.size = Vector2(sword.size.x * DASH_SLASH_REACH, sword.size.y)
	blade.color = Color(_sword_color.lerp(Color.WHITE, DASH_SLASH_GLOW), 0.5)
	add_child(blade)
	var tip_side = sword.global_position.x if facing > 0.0 else sword.global_position.x - blade.size.x
	blade.global_position = Vector2(tip_side, sword.global_position.y)
	for node in [ghost, blade]:
		var tween = node.create_tween()
		tween.tween_property(node, "modulate:a", 0.0, DASH_SLASH_TRAIL_FADE)
		tween.tween_callback(node.queue_free)


func _spawn_sparks(point: Vector2, count: int, color: Color):
	for i in count:
		var spark = ColorRect.new()
		spark.top_level = true
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.size = Vector2(4, 4)
		spark.color = color.lerp(Color.WHITE, randf() * 0.6)
		add_child(spark)
		spark.global_position = point
		var fly = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0)
		var tween = spark.create_tween().set_parallel()
		tween.tween_property(spark, "global_position", point + fly, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(spark.queue_free)


# A circle outline around the player that swells from `from_radius` to `to_radius` and fades.
func _spawn_ring(color: Color, from_radius: float, to_radius: float, duration: float):
	var ring = Node2D.new()
	ring.z_index = 4
	ring.set_meta("radius", from_radius)
	ring.draw.connect(func(): ring.draw_arc(Vector2.ZERO, ring.get_meta("radius"), 0.0, TAU, 40, color, 3.0, true))
	add_child(ring)
	var tween = ring.create_tween().set_parallel()
	tween.tween_method(func(r): ring.set_meta("radius", r); ring.queue_redraw(), from_radius, to_radius, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)


func _setup_drink_bar():
	_drink_bar = ColorRect.new()
	_drink_bar.size = Vector2(44, 5)
	_drink_bar.position = Vector2(-22, 24)
	_drink_bar.color = Color(0.4, 1.0, 0.55)
	_drink_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drink_bar.visible = false
	add_child(_drink_bar)

	var style = StyleBoxFlat.new()
	style.bg_color = _drink_bar.color
	style.set_corner_radius_all(int(DRINK_ORB_SIZE))  # clamps to a circle at any size
	_drink_orb = Panel.new()
	_drink_orb.add_theme_stylebox_override("panel", style)
	_drink_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drink_orb.visible = false
	add_child(_drink_orb)


func _setup_hands():
	for i in 2:
		var hand = ColorRect.new()
		hand.size = body.size * HAND_SIZE_RATIO
		hand.pivot_offset = hand.size / 2
		hand.top_level = true
		hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hand)
		_hands.append(hand)
	_update_hands()


# The hands grip the hilt and follow every swing and guard.
func _update_hands():
	var hilt = sword.position.x
	var length = sword.size.x
	var blade_y = sword.position.y + sword.size.y / 2
	for i in _hands.size():
		var hand = _hands[i]
		var grip = sword_pivot.to_global(Vector2(hilt + length * HAND_GRIPS[i], blade_y))
		hand.global_position = grip - hand.size / 2
		hand.rotation = sword_pivot.rotation
		hand.color = body.color.darkened(HAND_DARKEN)


func _setup_gather_label():
	_gather_label = Label.new()
	_gather_label.size = Vector2(60, 20)
	_gather_label.position = Vector2(-30, -82)  # above the boss's target marker
	_gather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gather_label.add_theme_font_size_override("font_size", 16)
	_gather_label.add_theme_constant_override("outline_size", 4)
	_gather_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_gather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gather_label.visible = false
	add_child(_gather_label)
