extends CharacterBody2D

signal damaged(player)
signal blocked(player)
signal died(player)
signal launched(player)  # sent up by a partner's upslash (see _check_clashes())
signal relayed(player)  # boosted off a partner's block (momentum relay, see _check_clashes())
signal landed(player, air_time)  # touched down after air_time seconds off the ground
signal pogo_clashed(player)  # bounced off a partner's upslash (see _pogo_clash())
signal repainted  # new colors (paint()): a boss's swords that carry them follow

enum Swing { SLASH, UPSLASH, DOWNSLASH }
# Held in place for a moment by a clash with the partner (see _begin_hold()).
enum Hold { NONE, RELAY_DASHER, RELAY_ANCHOR }

# Which abilities are on is decided by the Moves autoload (core/moves.gd, F1 in game): every
# ability below checks its switch there.
#
# CONTENTS, in this order (each section starts with "# --- <name>"):
#   tuning constants, grouped by feature (movement, the parry and dodge windows, THE SWORD,
#     the dash-slash, the tell, launch, walls, pogo, relay, boss body, dash-parry, call, the
#     pair's strike)
#   Lifecycle and the frame ........... _ready(), _physics_process(), input helpers
#   Running ........................... _process_movement()
#   Walls / Ledges .................... slide, cling, wall jump, wall rhythm; grab, hang, climb
#   Buttons ........................... _process_actions(): what each press does
#   Jumping and dashing
#   Sword ............................. slash, upslash, dash-slash, pogo
#   Clashes with the partner .......... launch, momentum relay, chimney clash, rhythm relay
#   Defensive queries used by the boss  is_blocking(), is_perfect_parry() ...
#   What a boss does to a player ...... parried, hit, staggered, held in a clash
#   The boss's body / The tell / Call
#   The look .......................... the sword's angle, colors, flashes, effects, hands
#   The pair's strike ................. the sync mode's draw-back and sabre (core/sync_bond.gd)

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
const KNOCKBACK_TIME = 0.25  # input can't steer while this runs
const KNOCKBACK_FRICTION = 1500.0
const HIT_INVULN_TIME = 0.6
const CHIP_INVULN_TIME = 0.2
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
# toward the wall you left, or holding nothing, doesn't steer, so between two walls you can keep
# one direction held (or none) and just time the jumps. The flight is short: it carries you
# across a narrow gap (half a beat) on its own; a wider one needs the stick held toward it
# (SPEED is the push, so holding keeps the flight's timing). Once it ends you steer freely.
# Walls and ledges refresh the dash (Moves "wall_refresh"), never the air jump.
# Partners aren't walls.
const WALL_PROBE = 4.0  # px: how close a wall has to be to stick to or jump off
const WALL_ATTACH_SPEED = 150.0  # flying into a wall this fast sticks without pressing into it
const WALL_SLIDE_SPEED = 140.0
const WALL_CLING_TIME = 1.2
const WALL_COYOTE_TIME = 0.1  # a wall jump this soon after letting go of the wall still works
const WALL_SPENT_RANGE = 24.0  # px: a wall on the spent side this close to where you jumped is the same wall
const WALL_JUMP_HEIGHT = 145.0  # its top ~0.4 s up, so a beat's flight lands near it; never cut short by letting go of jump
const WALL_JUMP_PUSH = 360.0  # px/s away from the wall
const WALL_JUMP_LOCK = 0.15
# Riding up a wall past its top hops you over onto it (no dead zone where the wall's too short to
# jump off but you're too low to land on it).
const WALL_TOP_HOP_SPEED = 300.0  # px/s over the edge...
const WALL_TOP_HOP_RISE = 200.0  # ...rising at least this fast (~11 px up)...
const WALL_TOP_HOP_TIME = 0.12  # ...unsteerable this long: ~35 px onto the top
const WALL_FLIGHT_TIME = 0.3  # how long a wall jump flies on its own (~110 px: a narrow shaft's half beat and some, not a wide one's beat)
const WALL_TURN_GRACE = 0.12  # s (Moves "wall_turn_grace"): this close to the next wall or the partner, holding back keeps flying there (~reaction time: steering early for the jump after)
# WALL RHYTHM (Moves "wall_rhythm"): a wall jump is timed to the moment you hit the wall. Pressed
# within WALL_RHYTHM_TOLERANCE of it (an early press waits for the wall, see JUMP_BUFFER_TIME),
# it's a full one; earlier or later, weak (WALL_WEAK_HEIGHT), so mashing or hanging on sinks you.
# So the rhythm is the walls': a shaft as wide as a beat's flight is climbed on every beat, one
# half as wide twice as fast. The first wall jump of a climb starts the rhythm: it's always a
# full one, and a level's Metronome starts ticking on it (landing stops it), unless the
# partner is already climbing to it. A full jump that's off the beat (pressed late, or the wall
# reached late or early) flies to the next wall a little faster or slower (_resync()), so it
# arrives on the beat and nothing adds up and drifts off it. A ring around you closes on the next moment to jump
# (reaching the wall, meeting the partner for a chimney clash) and flashes white for its window.
const WALL_BEAT = 0.5  # a beat where the level has no Metronome (a chimney clash's throw): 120 per minute
const WALL_RESYNC_MAX = 0.1  # s a flight is pulled at most toward arriving on the Metronome's half-beats (see _steer_tempo())
const WALL_TEMPO_RANGE = 0.2  # the flight to the next wall goes at most 20% faster or slower to land on the beat
const WALL_TEMPO_REACH = 1000.0  # px: a wall further than this isn't flown to on the beat
const WALL_TEMPO_LONGEST = 1.0  # s a flight is steered on the beat at most (it's at a wall long before)
const WALL_RHYTHM_TOLERANCE = 0.065  # s before or after hitting the wall that still counts
const WALL_WEAK_HEIGHT = 0.0  # a mistimed wall jump goes this fraction as high: none, just the push off the wall
const WALL_RING_RADIUS = 26.0  # the ring closes to this, just around the body...
const WALL_RING_SHRINK = 220.0  # ...shrinking this many px/s toward it
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
# other, clash in mid-air: each is the other's wall. Both wall-jump off each other, back toward
# the walls they came from, exactly like a wall jump (same push, same height, no hold), so a
# chimney twice as wide as one climbed alone is climbed in the same rhythm, the partner standing
# in for the far wall. They meet when they touch (players collide; if not, when they'd touch).
# Meeting isn't enough: both press jump, each within CHIMNEY_PRESS_TOLERANCE of the meeting (a
# press there never air-jumps); without both presses they fly on and fall. With Moves
# "wall_rhythm" on, each one's press is judged against the meeting like a wall jump's against
# hitting the wall: within WALL_RHYTHM_TOLERANCE a full jump, else a weak one.
const CHIMNEY_WINDOW = 0.7  # s since each one's wall jump: past the meeting and its press window
const CHIMNEY_PRESS_TOLERANCE = 0.08  # s before or after meeting that a jump press still clashes (weak past WALL_RHYTHM_TOLERANCE)
const CHIMNEY_REACH = Vector2(60.0, 60.0)  # once met, staying this close still lets a late press clash
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
# RHYTHM RELAY (Moves "relay_rhythm"): the relay as a bar of the clock (Beat), the partners
# taking turns: 1 the dasher lets go, 2 the anchor's parry (the blades lock), 3 the anchor's
# strike, which throws the dasher the way the anchor's stick points (4 ways: up, down, left,
# right; none: straight on; the arrow on the dasher shows it), 4 the top of the throw, where the
# level asks the dasher for something (a dash, a pogo point). The dasher doesn't aim.
# The dash-slash charges as long as attack is held (blade drawn back, flaring on every beat), and
# its release has to land on a beat, within a parry's window (RHYTHM_RELEASE_TOLERANCE): that beat
# is 1, whichever of the bar it is. Off the beat the blade fumbles and the dash is spent. After
# the release the blade heats up through the beat, and the run takes hardly any time, so the
# blades meet on beat 2 wherever the partner stands within reach; the parry press has to be close
# to it too. A strike off beat 3, or none, drops the dasher. Every beat sounds: 1 a tick, 2 the
# parry, 3 the strike, 4 a high tick. The throw stops a little before beat 4 and the dasher hangs
# still around it (gravity off), so a move on 4 has as much room early as late; any move ends
# the hang. Charging in the air hangs you still, as the windup does.
# (While the switch is on, every dash-slash is this one, at a boss too; it starts the clock where
# no level has.)
const RHYTHM_TOLERANCE = 0.08  # the strike counts this far off beat 3, early or late
const RHYTHM_RELEASE_TOLERANCE = PARRY_TOLERANCE  # the release counts this far off a beat, early or late
# The hang at the top: from this long before beat 4 to this long after it. Longer before than
# after, as falling the first few px after it barely counts as missing the top.
const RHYTHM_HANG_BEFORE = 0.06
const RHYTHM_HANG_AFTER = 0.02
const RHYTHM_THROW_HEIGHT = 190.0  # px the throw covers, reached RHYTHM_HANG_BEFORE before beat 4
const RHYTHM_DASH_TIME = 0.04  # the dash-slash's run, DASH_DISTANCE in this long (a plain dash: DASH_TIME)
const RHYTHM_PARRY_TOLERANCE = 0.1  # the block press at most this long before the blades meet
const RHYTHM_CHARGE_FLARE = 0.15  # s: charging, the blade flares white on every beat and fades over this
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
const HURT_FLASH_TIME = 0.5  # three 0.1s white flashes with 0.1s gaps...
const FLASH_DARK_ABOVE = 0.8  # ...black ones on a body this light (luminance), or they'd vanish
const IDLE_BOB_HEIGHT = 3.0
const IDLE_BOB_HZ = 0.6
const DASH_STRETCH = Vector2(1.3, 0.7)
const DASH_STRETCH_TIME = 0.1
# BOSS BODY (Moves "boss_body"): a boss may block players with a zone (BaseBoss.body_block()).
# Nobody walks, dashes or jumps through it, and nobody stands on it; see _keep_out_of_boss().
const BOSS_SLIDE_SPEED = 900.0  # px/s: landing on top, you slide off the side you came from
# DASH-PARRY (Moves "parry_pass"): a perfect parry that lands while you're dashing at the boss
# carries you through him: the dash starts over from there, and his block is no obstacle until
# it's done. A dash started up to PASS_WINDOW after the parry goes through him too. Out the far
# side, you've changed sides; a dash too short for that is pushed back out the nearer side.
const PASS_WINDOW = 0.2
# DASH-SLASH THROUGH (Moves "dash_slash_pass"): a dash-slash at the boss goes through him the same
# way: in the players' sync mode only (so the two can always get together to bind), always, or
# never. A dash-slash too short to get past him is pushed back out the nearer side.
# CALL (Moves "call"): a 3, 2, 1, GO countdown over the caller's head, one beat per CALL_BEAT, so
# GO lands CALL_COUNT beats after the press. Both players pulse on every beat. Informational only.
const CALL_BEAT = 0.4
const CALL_COUNT = 3
const CALL_GO_HOLD = 0.35  # GO stays up this long
const CALL_FONT_SIZE = 44
const CALL_HEIGHT = 112.0  # the number's center, above the caller's
# The body: half as wide as it's tall, so two players side by side make a square, and their
# swords and hitboxes sit closer together. The scene's rect and collision shape take this size
# in _ready().
const BODY_SIZE = Vector2(20, 40)
# Hands: same proportions as the boss's (square, a fifth of the body's height, gripping the hilt).
const HAND_SIZE_RATIO = 0.2
const HAND_GRIPS = [0.075, 0.275]  # where each hand holds the sword, as a fraction of its length
const HAND_DARKEN = 0.25
# The sword's look, a little less of a needle than the scene's plain rect (its hitbox is the
# scene's, unchanged): a broader blade, a crossguard just past the hands, and a point.
const SWORD_WIDTH = 8.0  # px thick (the scene's rect: 6)
const SWORD_POINT = 7.0  # px at its end tapering to the point
const CROSSGUARD_AT = 0.36  # where the crossguard sits, as a fraction of the sword's length
const CROSSGUARD_SIZE = Vector2(4, 16)
# THE PAIR'S STRIKE (sync mode, core/sync_bond.gd): while the two are bound (`bond` set), attack
# is held to draw the sword back (fully in Tuning "sync_charge_time") and let go to strike; the
# bond times the two strikes and deals the hit, the swing itself deals none. A block press lets
# the drawn sword go, unstruck. Bound, the sword is a sabre: longer, curved, half light, half dark.
const DRAW_ANGLE = -2.5  # drawn back all the way: over the shoulder
const SABRE_LENGTH = 1.3  # the sabre: this much longer than the sword...
const SABRE_WIDTH = 11.0  # ...this broad at the hilt (px)...
const SABRE_CURVE = 12.0  # ...its point curving back by this much (px)
const SABRE_LIGHT = Color(0.95, 0.94, 0.9)
const SABRE_DARK = Color(0.07, 0.07, 0.09)

@export var player_id: int = 1  # set to 1 or 2 in the inspector
@export var player_color = Color(0.25, 0.5, 1)  # body; P1 blue, P2 orange
@export var sword_color = Color(0.62, 0.8, 1)  # a lighter shade of the body color

var is_clashing = false  # blades locked with a boss's or an obstacle's, held in place
var invincible = false  # testing: hits still land (flash, knockback) but cost nothing (see SyncRules)
var facing = 1.0
var body_color: Color
# The beat-runner (levels/runner/): the world goes by, the player runs on the spot. No walking
# (the stick does nothing), and they face the way things come from.
var running_on = false
# The mirrored screen (ui/mirror_view.gd) shows each player in a half of their own: there the
# partner is nobody to bump into.
var own_half = false:
	set(v):
		own_half = v
		_update_player_collision()
var parry_press_time = -100.0  # when the last block press that can still parry happened
var swing_serial = 0  # bumped by every new swing and dash-slash (see active_sword_point())

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
var _hurt_flash = 0.0
var _bob_time = 0.0
var _body_rest = Vector2.ZERO
var _stretch_tween: Tween
var _is_dead = false
var _sword_color: Color
var _cue_timer = 0.0  # cue_sync()
var _cue_color = Color.WHITE
var _hands: Array = []  # [ColorRect, ColorRect]
var _sword_tip: Polygon2D  # the blade's point (see SWORD_POINT)
var _crossguard: ColorRect
var bond = null  # core/sync_bond.gd while the two are bound in sync mode (THE PAIR'S STRIKE)
var _drawing = false  # attack held, the sword drawing back
var _draw_time = 0.0
var _sabre: Node2D  # the sword's look while bound (set_sabre())
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
var _wall_chain = false  # wall-jumped since last on the floor (see WALL RHYTHM)
var wall_beat_time = -100.0  # the last wall jump, for WALL RHYTHM (a clash resets _wall_jump_time)
var _wall_contact_time = -100.0  # when you last hit a wall (see WALL RHYTHM), stuck to it or not
var _wall_contact_side = 0.0  # that wall's side
var _wall_touch_side = 0.0  # the wall you're touching (and moving into) this frame, 0 if none
var wall_jump_moment = -100.0  # when the last wall jump should have been pressed: hitting the wall, or the beat
var wall_jump_off = 0.0  # s the last wall jump's press was off its moment (< 0 early)
var wall_jump_strong = true  # the last wall jump was on time (a full one)
var _jump_press_time = -100.0  # the last jump press
var _chimney_meet_time = -100.0  # when this wall flight met the partner's (see CHIMNEY CLASH)
var _beat_ring: Node2D  # the ring closing on the next moment to jump (see _update_beat_ring())
var wall_rhythm_sound = true  # this player's wall jumps sound and show the ring (see WALL RHYTHM); a bot's may not
var _wall_jump_dir = 0.0  # which way the last wall jump flew
var _wall_jump_lock = 0.0
var _wall_flight = 0.0  # > 0 while flying from a wall jump (see WALL_FLIGHT_TIME)
var _turn_graced = false  # last frame, holding back was ignored just before the next wall (_turn_held())
var _near_wall_dist = INF  # px: the closest the wall flown to has come since the last wall jump (Moves "wall_reach")
var _near_wall_time = -100.0  # ...and when
var _wall_held_away = 0.0  # a key held away from the wall since arriving on it (doesn't let go)
var _tempo = 1.0  # times the usual sideways speed, flying to the next wall on the beat (see _resync())
var _tempo_until = -100.0  # flying on the beat (see _resync()) until then at the latest; < 0 if not
var chimney_clash_time = -100.0  # the last chimney clash
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
var _relay_rhythm = false  # this relay is a rhythm relay (Moves "relay_rhythm" when it began)
var _rhythm_dash = false  # this dash-slash is a rhythm relay's: charged, released on a beat, then a quick run
var _charging = false  # a rhythm dash-slash held, not released yet (while _windup_timer > 0)
var _windup_length = DASH_SLASH_WINDUP  # s this windup lasts (a rhythm one: from the release to the run)
var relay_beat = -1  # the Beat count of beat 1 of the current rhythm relay (its release)
var _relay_arrow: ColorRect
var _boost_timer = 0.0  # a rhythm relay's includes the hang at the top
var _boost_velocity = Vector2.ZERO
var _throw_left = 0.0  # px a rhythm relay's throw still has to go before the hang
var rhythm_top_time = -100.0  # beat 4 of the last rhythm relay thrown (when it belongs)
var _tell_ring: Node2D  # drawn around the partner (see _update_tell())
var _tell_partner = null
var _tell_left = 0.0  # seconds to the ring's close
var _tell_alpha = 0.0
var _tell_sounded = false
var _block_side = 1.0  # which side of the boss's block you're on (see _keep_out_of_boss())
var _block_above = false  # clear of the block, above it, last frame
var _block_sliding = false  # landed on top: sliding off
var _pass_timer = 0.0  # > 0 just after a perfect parry: a dash started now goes through the boss
var _passing = false  # this dash goes through the boss's block (see PASS_WINDOW)
var _call_time = -1.0  # time into the countdown; < 0 while there's none
var _call_beat = -1
var _call_label: Label

@onready var body: ColorRect = $ColorRect
@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: ColorRect = $SwordPivot/Sword
@onready var sword_hitbox: Area2D = $SwordPivot/SwordHitbox
@onready var _sword_shape: CollisionShape2D = $SwordPivot/SwordHitbox/CollisionShape2D


# --- Lifecycle and the frame ---------------------------------------------------

func _ready():
	body.size = BODY_SIZE
	body.position = -BODY_SIZE / 2.0
	$CollisionShape2D.shape.size = BODY_SIZE  # shared by both players: the same size anyway
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
	_setup_sword()
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
	_beat_ring = Node2D.new()
	_beat_ring.z_index = 5
	_beat_ring.visible = false
	_beat_ring.draw.connect(_draw_beat_ring)
	add_child(_beat_ring)
	_setup_call_label()
	_update_player_collision()
	Moves.changed.connect(_update_player_collision)
	GameManager.register_player(self)


func _update_player_collision():
	set_collision_mask_value(PLAYER_LAYER, Moves.on("players_collide") and not own_half)


# New colors for the body and the sword (the mirrored screen makes the players light and shadow).
func paint(new_body: Color, new_sword: Color):
	player_color = new_body
	sword_color = new_sword
	body_color = new_body
	_sword_color = new_sword
	repainted.emit()


func _physics_process(delta):
	_tick_timers(delta)
	_process_call(delta)
	if is_clashing:
		velocity = Vector2.ZERO  # braced, holding the other blade back
	elif _hold_kind != Hold.NONE:
		_process_hold(delta)
	elif _ledge:
		_process_ledge(delta)
	elif is_staggered():
		velocity.x = 0.0
		_apply_gravity(delta)
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
	_track_landing()
	_process_attack()
	_update_visuals()


# Normal gravity on the way up, heavier on the way down, up to the fall speed cap; heavier and
# faster still when fast falling.
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


# Left/right input, -1..1.
func move_axis() -> float:
	if running_on:
		return 0.0
	return Input.get_axis(_action("left"), _action("right"))


# --- Running -------------------------------------------------------------------

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
		if _wall_chain:
			# The climb is over: the metronome stops, unless the partner is still climbing.
			var metronome = _metronome()
			if metronome and not _climbing_partner():
				metronome.stop()
		_wall_chain = false
		_wall_touch_side = 0.0
		_near_wall_dist = INF
		_end_tempo()
	else:
		_track_wall_contact(direction)
		_steer_tempo(direction)
	# Flying off a wall, holding back toward it or nothing keeps the flight (see WALLS).
	# Just before the next wall, holding back too (Moves "wall_turn_grace", see WALL_TURN_GRACE).
	_turn_graced = _turn_held(direction)
	var coasting = (_wall_flight > 0.0 and (direction == 0.0 or signf(direction) == -_wall_jump_dir)) \
		or _turn_graced
	if coasting:
		facing = _wall_jump_dir  # holding toward the wall you left doesn't turn you around

	if _boost_timer > 0.0:
		velocity = _boost_velocity  # a relay boost: straight, gravity off
		if _relay_rhythm:
			# The throw covers exactly its distance, however the frames fall; then it hangs.
			var step = minf(_boost_velocity.length(), _throw_left / delta)
			velocity = _boost_velocity.normalized() * step
			_throw_left -= step * delta
		return
	if _dash_timer > 0.0:
		velocity = Vector2(_dash_dir * _dash_speed(), 0.0)
		return
	if not is_on_floor() and _knockback_timer <= 0.0:
		if _try_ledge_grab(direction) or _update_wall(direction, delta):
			return

	if _knockback_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
	elif (_launch_timer > 0.0 and direction == 0.0) or _wall_jump_lock > 0.0 or coasting:
		pass  # a launch's sideways carry (until steered), or flying off a wall: keep it
	else:
		var target = direction * SPEED * _tempo * (BLOCK_SPEED_FACTOR if is_blocking() else 1.0)
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
			var hop = mode != "off" and not pressing_away and velocity.y < 0.0
			if hop:
				_hop_over_wall_top()
			_leave_wall()
			if hop:
				_wall_coyote = 0.0  # going over: a late press doesn't pull you back off it
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
	if _wall_flight > 0.0 or _turn_graced:  # (hitting the wall stops you: the grace still carries you into it)
		sides.append(_wall_jump_dir)
	return sides


# Notes the moment you hit a wall (one you're moving into, not the one you jumped off), whether
# you stick to it or not: the moment a wall jump off it is timed to (see WALL RHYTHM).
func _track_wall_contact(direction: float):
	var sides = _sides_moving_into(direction)
	if _wall_side != 0.0:
		sides.push_front(_wall_side)
	var touching = 0.0
	for side in sides:
		if not _wall_spent(side) and _touching_wall(side):
			touching = side
			break
	if touching != 0.0 and touching != _wall_touch_side:
		_wall_contact_time = _now()
		_wall_contact_side = touching
		_end_tempo()  # arrived
	_wall_touch_side = touching
	# How close the wall flown to came (Moves "wall_reach"): turned back just short of it, a jump
	# still pushes off it, timed to that closest moment.
	if _wall_chain and _wall_reach() > 0.0 and not _wall_spent(_wall_jump_dir):
		var gap = _wall_distance(_wall_jump_dir, WALL_PROBE + _wall_reach())
		if gap < _near_wall_dist:
			_near_wall_dist = gap
			_near_wall_time = _now()


# The Metronome's tick or off-beat nearest `t`; `t` itself if none is ticking.
func _nearest_tick(t: float) -> float:
	var metronome = _metronome()
	if not (metronome and metronome.running):
		return t
	var step = metronome.beat_length() / 2.0
	return metronome.origin + roundf((t - metronome.origin) / step) * step


# px short of a wall (or the partner) a jump still pushes off, if you turned back early.
func _wall_reach() -> float:
	return float(Moves.value("wall_reach")) if Moves.on("wall_reach") else 0.0


# A wall right beside you on `side`. Only the world counts: a partner isn't a wall.
func _touching_wall(side: float) -> bool:
	return _wall_distance(side, WALL_PROBE) < INF


# px to the world on `side`, looking at most `reach` far; INF if nothing's there.
func _wall_distance(side: float, reach: float) -> float:
	var params = PhysicsTestMotionParameters2D.new()
	params.from = global_transform
	params.motion = Vector2(side * reach, 0.0)
	var partners: Array[RID] = []
	for other in get_tree().get_nodes_in_group("players"):
		if other != self:
			partners.append(other.get_rid())
	params.exclude_bodies = partners
	var result = PhysicsTestMotionResult2D.new()
	if not PhysicsServer2D.body_test_motion(get_rid(), params, result):
		return INF
	return result.get_travel().length()


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


# Rode up the wall past its top: hop over onto it, rather than hang beside its edge with no
# wall left to jump off and no way onto it.
func _hop_over_wall_top():
	velocity.x = _wall_side * WALL_TOP_HOP_SPEED
	velocity.y = minf(velocity.y, -WALL_TOP_HOP_RISE)
	_wall_jump_lock = maxf(_wall_jump_lock, WALL_TOP_HOP_TIME)


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
	# Bounced off a wall you didn't stick to: a press late within the window still jumps off it.
	if _wall_chain and _now() - _wall_contact_time <= WALL_RHYTHM_TOLERANCE \
			and not _wall_spent(_wall_contact_side):
		return _wall_contact_side
	# Turned back just short of the wall you flew to (Moves "wall_reach"); still flying into it,
	# an early press waits for the wall.
	if _wall_chain and _near_wall_dist < INF and not _wall_spent(_wall_jump_dir) \
			and velocity.x * _wall_jump_dir < WALL_ATTACH_SPEED \
			and _wall_distance(_wall_jump_dir, WALL_PROBE + _wall_reach()) < INF:
		return _wall_jump_dir
	return 0.0


func _wall_jump(side: float):
	var now = _now()
	# Timed to hitting this wall; the first of a climb starts the rhythm instead.
	var timed = _wall_chain
	if _wall_chain:
		wall_jump_moment = now
		if _wall_contact_side == side and _wall_contact_time > maxf(_wall_jump_time, chimney_clash_time):
			wall_jump_moment = _wall_contact_time
		elif side == _wall_jump_dir and _near_wall_dist < INF:
			# Never touched it: timed to the tick you'd have hit it on (the flight is steered onto
			# them), else its closest moment.
			wall_jump_moment = _nearest_tick(_near_wall_time)
		wall_jump_off = _jump_press_time - wall_jump_moment
	else:
		wall_jump_off = 0.0
		wall_jump_moment = now
		var metronome = _metronome()
		if metronome and not _climbing_partner():
			metronome.restart(now)
	_wall_chain = true
	wall_beat_time = now
	_chimney_meet_time = -100.0
	wall_jump_strong = not Moves.on("wall_rhythm") or not timed \
		or absf(wall_jump_off) <= WALL_RHYTHM_TOLERANCE
	if Moves.on("wall_rhythm") and wall_rhythm_sound:
		Sfx.play("relay_peak" if wall_jump_strong else "chip", -4.0)
	var rise = sqrt(2.0 * GRAVITY * WALL_JUMP_HEIGHT * (1.0 if wall_jump_strong else WALL_WEAK_HEIGHT))
	velocity = Vector2(-side * WALL_JUMP_PUSH, -rise)
	_uncut_timer = rise / GRAVITY  # a tap goes as high as a hold: the timing decides, not the hold
	facing = -side
	_wall_side = 0.0
	_wall_coyote = 0.0
	_spent_wall_side = side
	_spent_wall_x = global_position.x
	_wall_jump_lock = WALL_JUMP_LOCK
	_wall_jump_time = _now()
	_wall_jump_dir = -side
	_near_wall_dist = INF
	_wall_flight = WALL_FLIGHT_TIME
	_wall_held_away = 0.0
	_jump_buffer = 0.0
	_launch_timer = 0.0
	_boost_timer = 0.0
	_dash_timer = 0.0
	if Moves.on("wall_rhythm") and wall_jump_strong:
		_resync()


# A full wall jump (or chimney clash) just launched: its flight to the next moment to jump
# (hitting a wall, meeting the partner) goes on the beat (_steer_tempo()), so neither late
# presses nor a slow flight (steering) add up and drift off it.
func _resync():
	_tempo_until = _now() + WALL_TEMPO_LONGEST
	_steer_tempo(move_axis())


# Flying to the next moment to jump on the beat (see _resync()): when it would get there at the
# usual speed, rounded to the Metronome's nearest half-beat (by at most WALL_RESYNC_MAX), is when
# it's to get there; this sets the speed that does, within WALL_TEMPO_RANGE of the usual. Flying
# on its own, the flight's; steered toward it, how fast holding the stick goes (any tilt toward
# it flies at least half speed's worth of it). Held away or not at all, it doesn't steer for you.
func _steer_tempo(direction: float):
	if _tempo_until < 0.0:
		return
	var now = _now()
	var metronome = _metronome()
	var distance = _tempo_distance()
	if now > _tempo_until or distance == INF or not (metronome and metronome.running):
		_end_tempo()
		return
	var usual = distance / WALL_JUMP_PUSH
	if usual <= get_physics_process_delta_time():
		return  # there (or nearly): keep the speed it has
	var arrive = now + usual + _seen_late()
	var step = metronome.beat_length() / 2.0
	var on_beat = metronome.origin + roundf((arrive - metronome.origin) / step) * step
	var left = usual + clampf(on_beat - arrive, -WALL_RESYNC_MAX, WALL_RESYNC_MAX)
	var k = clampf(usual / maxf(left, 0.001), 1.0 - WALL_TEMPO_RANGE, 1.0 + WALL_TEMPO_RANGE)
	var on_its_own = _wall_jump_lock > 0.0 \
		or (_wall_flight > 0.0 and (direction == 0.0 or signf(direction) == -_wall_jump_dir)) \
		or _turn_held(direction)
	if on_its_own and velocity.x * _wall_jump_dir > 0.0:
		velocity.x = _wall_jump_dir * WALL_JUMP_PUSH * k
	_tempo = 1.0
	if direction * _wall_jump_dir > 0.0:
		_tempo = k * WALL_JUMP_PUSH / (maxf(absf(direction), 0.5) * SPEED)


# Moves "wall_turn_grace": holding back toward the wall you left (or nothing), WALL_TURN_GRACE or less before
# reaching the next wall (or meeting the partner), keeps the flight going there: steering early
# for the jump after doesn't turn you around short of it.
func _turn_held(direction: float) -> bool:
	if not Moves.on("wall_turn_grace") or not _wall_chain or _wall_jump_dir == 0.0:
		return false
	# (Letting go counts too: an analog stick turning back passes through the middle.)
	if signf(direction) == _wall_jump_dir or velocity.x * _wall_jump_dir <= 0.0:
		return false
	var distance = _tempo_distance()
	return distance != INF and distance / WALL_JUMP_PUSH <= WALL_TURN_GRACE


func _tempo_distance() -> float:
	var gap = _wall_distance(_wall_jump_dir, WALL_TEMPO_REACH)
	if gap == INF:
		return INF
	for other in get_tree().get_nodes_in_group("players"):
		var ahead = (other.global_position.x - global_position.x) * _wall_jump_dir
		if other != self and not other.is_on_floor() and ahead > 0.0 and ahead < gap:
			return maxf(ahead - body.size.x - WALL_PROBE, 0.0) / 2.0  # met once in reach (see _check_clashes)
	return gap


# s after reaching a wall that it's seen: up to a frame.
func _seen_late() -> float:
	return get_physics_process_delta_time() / 2.0


# Back to the usual speed (see _resync()).
func _end_tempo():
	_tempo = 1.0
	_tempo_until = -100.0


# The level's Metronome, if it has one (see WALL RHYTHM).
func _metronome():
	return get_tree().get_first_node_in_group("metronome")


# s of a beat: the metronome's, else WALL_BEAT.
func _beat_length() -> float:
	var metronome = _metronome()
	return metronome.beat_length() if metronome else WALL_BEAT


# s until the next moment to jump (see WALL RHYTHM), and s since the last one; -1 if none.
func _jump_cues() -> Vector2:
	var now = _now()
	var left = INF
	var since = INF
	if _hold_kind != Hold.NONE or is_on_floor():
		return Vector2(-1.0, -1.0)
	if _wall_chain:
		since = now - _wall_contact_time
		if _wall_side == 0.0 and absf(velocity.x) > 1.0:  # flying (or steering) at a wall
			var side = signf(velocity.x)
			left = _wall_distance(side, absf(velocity.x) * _beat_length()) / absf(velocity.x)
		since = minf(since, now - _chimney_meet_time)
		var partner = _chimney_partner()
		if partner and _chimney_meet_time < 0.0:
			var gap = partner.global_position.x - global_position.x
			var closing = velocity.x * signf(gap) - partner.velocity.x * signf(gap)
			if closing > 1.0:
				left = minf(left, maxf(absf(gap) - body.size.x, 0.0) / closing)
	return Vector2(left if left < INF else -1.0, since if since < INF else -1.0)


# The partner, if they're climbing (wall-jumped since they were last on the floor).
func _climbing_partner():
	for other in get_tree().get_nodes_in_group("players"):
		if other != self and other._wall_chain and not other.is_on_floor():
			return other
	return null


# The partner, if both of you are flying from a wall jump (a chimney clash in the making).
func _chimney_partner():
	if not Moves.on("chimney_clash") or not _in_wall_flight():
		return null
	for other in get_tree().get_nodes_in_group("players"):
		if other != self and other._in_wall_flight():
			return other
	return null


func _update_beat_ring():
	_beat_ring.visible = Moves.on("wall_rhythm") and wall_rhythm_sound
	if _beat_ring.visible:
		_beat_ring.queue_redraw()


# Closes on the next moment to jump, and flashes white for its window.
func _draw_beat_ring():
	var cues = _jump_cues()
	var closed = cues.y >= 0.0 and cues.y <= WALL_RHYTHM_TOLERANCE
	if not closed and cues.x < 0.0:
		return
	var radius = WALL_RING_RADIUS if closed else WALL_RING_RADIUS + cues.x * WALL_RING_SHRINK
	var color = Color.WHITE if closed else body_color.lightened(0.4)
	var alpha = 1.0 if closed else clampf(1.0 - cues.x / _beat_length(), 0.15, 0.8)
	_beat_ring.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, alpha), 4.0 if closed else 2.0, true)


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
	var stand = Vector2(face_x + side * (half + 4.0), down.position.y - body.size.y / 2.0 - 1.0)
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


# --- Buttons: what each press does ---------------------------------------------

func _process_actions():
	if Input.is_action_just_pressed(_action("jump")):
		_jump_buffer = JUMP_BUFFER_TIME
		_jump_press_time = _now()
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

	if bond != null:
		_process_draw()
	elif Input.is_action_just_pressed(_action("attack")):
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


# --- Jumping and dashing ---------------------------------------------------------

# Jumps if it can: from the ground (or just off a ledge), off a wall, else with an air jump. A
# fresh press with none of those stays buffered, and fires on landing (or on reaching a wall)
# if that comes soon enough.
func _try_jump():
	if _coyote_timer > 0.0:
		velocity.y = -sqrt(2.0 * GRAVITY * JUMP_HEIGHT)
	elif Moves.on("wall_jump") and _wall_jump_side() != 0.0:
		_wall_jump(_wall_jump_side())
		return
	elif Moves.on("double_jump") and _air_jumps > 0 and Input.is_action_just_pressed(_action("jump")) \
			and not _chimney_partner():  # flying at the partner, it's the clash's press
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
	_rhythm_dash = false
	_launch_timer = 0.0
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	_passing = _pass_timer > 0.0 and _boss_ahead()  # right after a parry: through him
	_pass_timer = 0.0
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
	_rhythm_dash = Moves.on("momentum_relay") and Moves.on("relay_rhythm")
	_windup_length = DASH_SLASH_WINDUP
	_windup_timer = DASH_SLASH_WINDUP  # a rhythm one: held at this until the release
	_charging = _rhythm_dash
	if _rhythm_dash and not Beat.running:
		Beat.start(Beat.DEFAULT_BPM, get_tree().current_scene)  # a bar needs a clock
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
	if _charging:
		if not Input.is_action_pressed(_action("attack")):
			_release_charge()
		return
	_windup_timer -= delta
	if _windup_timer > 0.0:
		return
	_windup_timer = 0.0
	_dash_timer = RHYTHM_DASH_TIME if _rhythm_dash else DASH_TIME
	velocity = Vector2(_dash_dir * _dash_speed(), 0.0)
	if _dash_slash_passes() and _boss_ahead():
		_passing = true  # through him (DASH-SLASH THROUGH)
	swing_serial += 1
	_trail_timer = 0.0
	if _stretch_tween:
		_stretch_tween.kill()
	body.scale = DASH_STRETCH
	_stretch_tween = create_tween()
	_stretch_tween.tween_property(body, "scale", Vector2.ONE, DASH_STRETCH_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _rhythm_dash:
		Sfx.play("slash", -10.0)  # quiet: beat 2 is the parry's
	else:
		Sfx.play("stab", 1.0)
		Sfx.play("slash", -2.0)


# A rhythm dash-slash let go: on a beat, that beat is 1, and the run starts half a run before
# the next, so the blades meet on beat 2. Off the beat, the blade fumbles and the dash is spent.
func _release_charge():
	_charging = false
	var t = Beat.time()
	if absf(Beat.offset_to_beat(t)) > RHYTHM_RELEASE_TOLERANCE:
		_windup_timer = 0.0
		_dash_slash = false
		_swing_from_angle = _sword_angle()
		_recoil_timer = PARRIED_RECOIL
		_spawn_sparks(sword_pivot.global_position, 5, Color(0.6, 0.6, 0.6))
		Sfx.play("chip")
		return
	relay_beat = roundi(Beat.beats_at(t))
	_windup_length = Beat.beat_time(relay_beat + 1) - RHYTHM_DASH_TIME / 2.0 - t
	_windup_timer = _windup_length
	Sfx.play("relay_beat")  # beat 1


func is_winding_up() -> bool:
	return _windup_timer > 0.0


# The speed of the dash running now: a rhythm relay's dash-slash covers the same ground faster.
func _dash_speed() -> float:
	return DASH_DISTANCE / RHYTHM_DASH_TIME if _rhythm_dash else DASH_SPEED


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
			hit.take_damage(_swing_damage(), self)


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
		if hit.has_method("accepts_pogo") and not hit.accepts_pogo(self):
			continue  # e.g. a lantern that only takes a pogo on the beat
		if hit.is_in_group("boss") and not _attack_landed:
			_attack_landed = true
			hit.take_damage(_swing_damage(), self)
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
		and _now() - _upslash_press_time <= tolerance and not is_staggered()


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
			var tolerance = RHYTHM_PARRY_TOLERANCE if _rhythm_dash else RELAY_PARRY_TOLERANCE
			if Moves.on("momentum_relay") and other.is_relay_parry(tolerance):
				_start_relay(other)
				return
			if Moves.on("momentum_relay") and other.is_blocking():
				_relay_blocked(other)
				return
		# Each pair is checked once, by the lower id. Flying at each other, or already bumped
		# together (the bump stops them) after jumping off opposite walls. Met while turned back
		# short of each other (Moves "wall_reach"), they fly apart: the press window still holds.
		var met_now = _chimney_meet_time >= 0.0 and _now() - _chimney_meet_time <= CHIMNEY_PRESS_TOLERANCE
		if Moves.on("chimney_clash") and player_id < other.player_id and _in_wall_flight() \
				and other._in_wall_flight() and (absf(gap.x) <= CHIMNEY_REACH.x or met_now) \
				and absf(gap.y) <= CHIMNEY_REACH.y:
			var touching = absf(gap.x) <= body.size.x + WALL_PROBE
			var closing = gap.x * velocity.x > 0.0 and gap.x * other.velocity.x < 0.0
			var bumped = _wall_jump_dir * gap.x > 0.0 and other._wall_jump_dir * gap.x < 0.0
			# Turned back just short of each other (Moves "wall_reach"): met where they turned.
			var near = bumped and not closing and absf(gap.x) <= body.size.x + WALL_PROBE + 2.0 * _wall_reach()  # each that short
			if (touching and (closing or bumped)) or near or _chimney_meet_time >= 0.0:  # once met, in reach is enough
				var now = _now()
				if _chimney_meet_time < 0.0:
					# Never touched: timed to the tick they'd have met on (see _wall_jump()).
					var meet = now if touching else _nearest_tick(now)
					_chimney_meet_time = meet
					other._chimney_meet_time = meet
				# Both pressed jump around the meeting (see CHIMNEY CLASH); too late, they fly on.
				if _pressed_near(_chimney_meet_time) and other._pressed_near(_chimney_meet_time):
					_chimney_clash(other)
					return


func _pressed_near(t: float) -> bool:
	return absf(_jump_press_time - t) <= CHIMNEY_PRESS_TOLERANCE


func _in_wall_flight() -> bool:
	return not is_on_floor() and _hold_kind == Hold.NONE and _now() - _wall_jump_time <= CHIMNEY_WINDOW


# Both wall-jump off each other, back toward the walls they came from (see CHIMNEY CLASH).
func _chimney_clash(other):
	var point = (global_position + other.global_position) / 2.0
	var meet = _chimney_meet_time
	for p in [self, other]:
		var back = signf(p.global_position.x - point.x)
		# Timed to the meeting, as a wall jump is to hitting the wall (see WALL RHYTHM).
		p.wall_jump_moment = meet
		p.wall_jump_off = p._jump_press_time - meet
		p.wall_jump_strong = not Moves.on("wall_rhythm") or absf(p.wall_jump_off) <= WALL_RHYTHM_TOLERANCE
		p.chimney_clash_time = _now()
		if Moves.on("wall_rhythm") and p.wall_rhythm_sound:
			Sfx.play("relay_peak" if p.wall_jump_strong else "chip", -4.0)
		var rise = sqrt(2.0 * GRAVITY * WALL_JUMP_HEIGHT * (1.0 if p.wall_jump_strong else WALL_WEAK_HEIGHT))
		p.velocity = Vector2(back * WALL_JUMP_PUSH, -rise)
		p._uncut_timer = rise / GRAVITY
		p.facing = back
		p._wall_jump_lock = WALL_JUMP_LOCK
		p._wall_jump_dir = back
		p._near_wall_dist = INF
		p._wall_flight = WALL_FLIGHT_TIME
		p._wall_jump_time = -100.0  # one clash per wall jump
		p._jump_buffer = 0.0  # the clash's press is spent: it doesn't wall-jump on arrival
		p._spent_wall_side = 0.0  # back at the wall they came from: it's climbable again
		p._sword_flash = SWORD_FLASH_TIME
		if Moves.on("wall_rhythm") and p.wall_jump_strong:
			p._resync()
	_spawn_sparks(point, 14, body_color.lerp(other.body_color, 0.5).lightened(0.5))
	Sfx.play("parry_strong")
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(4.0)


# Blades locked: the dasher aims while both are held, then boosts (see _release_hold()).
func _start_relay(anchor):
	_relay_dir = Vector2(_dash_dir, 0.0)
	_relay_rhythm = _rhythm_dash
	# A rhythm relay waits for the anchor's strike, up to the late end of beat 3.
	var clash_time = RELAY_CLASH_TIME
	if _relay_rhythm:
		clash_time = Beat.beat_time(relay_beat + 2) + RHYTHM_TOLERANCE - Beat.time()
	_begin_hold(Hold.RELAY_DASHER, clash_time, Vector2.ZERO, anchor)
	# The anchor's hold outlasts the dasher's, so the dasher's release is what frees them.
	anchor._begin_hold(Hold.RELAY_ANCHOR, clash_time + 0.1, Vector2.ZERO, self)
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
func is_relay_parry(tolerance = RELAY_PARRY_TOLERANCE) -> bool:
	return is_blocking() and _now() - parry_press_time <= tolerance


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
	_charging = false
	_attack_timer = 0.0
	_launch_timer = 0.0
	_boost_timer = 0.0
	_wall_side = 0.0
	_wall_flight = 0.0


func _process_hold(delta):
	velocity = Vector2.ZERO
	_hold_timer -= delta
	if _hold_kind == Hold.RELAY_DASHER and not _relay_rhythm:
		_relay_dir = _aim(_relay_dir)
	if _hold_kind == Hold.RELAY_ANCHOR and _process_rhythm_strike():
		return
	if _hold_timer <= 0.0:
		if _hold_kind == Hold.RELAY_DASHER and _relay_rhythm:
			_relay_dropped()  # no strike on the beat
		else:
			_release_hold()


# The anchor's side of a rhythm relay: the stick aims the dasher, and the attack press strikes.
# On beat 3 it throws them; off it, it drops them. True once struck.
func _process_rhythm_strike() -> bool:
	var dasher = _hold_partner
	if not (dasher and is_instance_valid(dasher) and dasher._hold_kind == Hold.RELAY_DASHER \
			and dasher._relay_rhythm):
		return false
	dasher._relay_dir = _aim_4(Vector2(dasher._dash_dir, 0.0))
	if not Input.is_action_just_pressed(_action("attack")):
		return false
	if absf(Beat.time() - Beat.beat_time(dasher.relay_beat + 2)) <= RHYTHM_TOLERANCE:
		dasher._release_hold()  # the throw; it frees this hold too, and pushes this player back
		_start_swing(Swing.SLASH)
		Sfx.play("relay_strike")  # beat 3
	else:
		dasher._relay_dropped()
	return true


# A rhythm relay without a strike on the beat: the blades come apart, and the dasher drops.
func _relay_dropped():
	var anchor = _hold_partner
	_hold_kind = Hold.NONE
	_hold_partner = null
	if anchor and is_instance_valid(anchor) and anchor._hold_kind == Hold.RELAY_ANCHOR:
		anchor._hold_kind = Hold.NONE
		anchor._hold_partner = null
	_spawn_sparks(global_position, 5, Color(0.6, 0.6, 0.6))
	Sfx.play("chip")


func _release_hold():
	var kind = _hold_kind
	_hold_kind = Hold.NONE
	match kind:
		Hold.RELAY_DASHER:
			_boost_velocity = _relay_dir * RELAY_SPEED
			_boost_timer = RELAY_BOOST_TIME
			if _relay_rhythm:
				# The throw, reaching the top RHYTHM_HANG_BEFORE before beat 4, then the hang.
				var to_top = Beat.beat_time(relay_beat + 3) - Beat.time()
				_boost_timer = to_top + RHYTHM_HANG_AFTER
				_throw_left = RHYTHM_THROW_HEIGHT
				_boost_velocity = _relay_dir * RHYTHM_THROW_HEIGHT / maxf(to_top - RHYTHM_HANG_BEFORE, 0.05)
				rhythm_top_time = _now() + to_top
			velocity = _boost_velocity
			if _relay_dir.x != 0.0:
				facing = signf(_relay_dir.x)
			if Moves.on("relay_refresh_dash") or _relay_rhythm:  # beat 4 may ask for a dash
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


# The direction held right now, snapped to 4 ways (up, down, left, right); `fallback` if none.
func _aim_4(fallback: Vector2) -> Vector2:
	var aim = Vector2(move_axis(), Input.get_axis(_action("up"), _action("down")))
	if aim.length() < 0.5:
		return fallback
	if absf(aim.x) >= absf(aim.y):
		return Vector2(signf(aim.x), 0.0)
	return Vector2(0.0, signf(aim.y))


# Stops everything the player was doing in the air: walls, ledges, clashes, boosts. For hits,
# grabs, respawns and the like.
func interrupt_movement():
	if _windup_timer > 0.0:
		_windup_timer = 0.0
		_dash_slash = false
	_charging = false
	_wall_side = 0.0
	_wall_flight = 0.0
	_pogo_rise = 0.0
	_downslash_time = -100.0
	_ledge = false
	_boost_timer = 0.0
	_hold_kind = Hold.NONE
	_hold_timer = 0.0
	_hold_partner = null
	_end_tempo()


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
		return "dash-slash charge" if _charging else "dash-slash windup"
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
	_pass_timer = maxf(_pass_timer - delta, 0.0)
	_parry_flick = maxf(_parry_flick - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_launch_timer = maxf(_launch_timer - delta, 0.0)
	if _boost_timer > 0.0 and _relay_rhythm:
		# A rhythm relay's throw (see _process_movement()), then the hang, ticking on 4.
		var left = _boost_timer - delta
		if _boost_timer > RHYTHM_HANG_AFTER and left <= RHYTHM_HANG_AFTER:
			Sfx.play("relay_peak")
		if left <= 0.0:
			velocity = Vector2.ZERO  # the hang is over: falling from a standstill
	elif _boost_timer > 0.0 and _boost_timer <= delta:
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
	return not is_staggered() and not _is_swinging() and Input.is_action_pressed(_action("block")) \
		and (GameManager.rules == null or GameManager.rules.can_block())  # no blocking in chaos


func is_perfect_parry() -> bool:
	return not is_staggered() and _now() - parry_press_time <= PARRY_TOLERANCE


func is_staggered() -> bool:
	return _stagger_timer > 0.0


# Killed by a fight's rules (take_damage()): out until the fight starts over.
func is_dead() -> bool:
	return _is_dead


# What the player is standing on (e.g. which of the duo gym's pans), or null in the air. Standing
# on the partner counts as standing on whatever they stand on.
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


# --- What a boss does to a player: parried, hit, staggered, held in a clash ---

func on_perfect_parry(strong: bool):
	Dev.defended(self, "parry", _now() - parry_press_time)
	if GameManager.rules:
		GameManager.rules.player_parried(self)
	parry_press_time = -100.0  # one press parries one hit
	_last_block_press = -100.0  # a landed parry isn't mashing: the next press may parry at once
	_sword_flash = SWORD_FLASH_TIME
	_parry_flick = PARRY_FLICK_TIME
	Sfx.play("parry_strong" if strong else "parry")
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(7.0 if strong else 4.0)
	if Moves.on("parry_pass"):
		_pass_timer = PASS_WINDOW
		if _dash_timer > 0.0 and not _dash_slash and _boss_ahead():
			# A dash-parry: the dash starts over from here, and goes through him.
			_dash_timer = DASH_TIME
			_passing = true
			_pass_timer = 0.0


# The sword lit in `color` for `duration`: the moment to strike (a sync hit's beat).
func cue_sync(duration: float, color: Color):
	_cue_timer = duration
	_cue_color = color


# A blow lands (`chip`: on a block): thrown back by `knockback`, briefly untouchable. What it
# costs is the fight's: on sync as life (core/sync_rules.gd) a hit costs the pair's sync and a
# block this one's posture, and in chaos a hit is the end. Elsewhere it costs nothing.
func take_damage(knockback = Vector2.ZERO, chip = false):
	if _is_dead or _invuln_timer > 0.0:
		return
	Dev.defended(self, "block" if chip else "hit", _now() - _last_block_press)
	var lethal = false
	if GameManager.rules:
		var rules = GameManager.rules
		lethal = rules.player_blocked(self) if chip else rules.player_hit(self)
	_invuln_timer = CHIP_INVULN_TIME if chip else HIT_INVULN_TIME
	_dash_timer = 0.0
	interrupt_movement()
	_launch_timer = 0.0
	_hurt_flash = HURT_FLASH_TIME
	velocity = knockback
	if chip:
		Sfx.play("chip")
	else:
		Sfx.play("hurt")
	if knockback != Vector2.ZERO:
		_knockback_timer = KNOCKBACK_TIME
		if not chip:
			Sfx.play_delayed("knockback", 0.06, -4.0)  # thrown back, just behind the impact
	if chip:
		blocked.emit(self)
	else:
		damaged.emit(self)
	if lethal:
		_is_dead = true
		died.emit(self)


# Reeling from a hit: can't move, block, parry or act until it wears off.
func stagger(duration: float):
	_stagger_timer = maxf(_stagger_timer, duration)
	velocity.x = 0.0
	_dash_timer = 0.0
	interrupt_movement()
	_attack_timer = 0.0


# Blades locked with another (an obstacle's, a boss's): held in place, sword level against it.
func set_clashing(clashing: bool):
	is_clashing = clashing
	velocity = Vector2.ZERO
	_dash_timer = 0.0
	interrupt_movement()
	_attack_timer = 0.0


func apply_knockback(push: Vector2):
	velocity = push
	_knockback_timer = KNOCKBACK_TIME


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
	if block.size == Vector2.ZERO:
		_block_sliding = false
		return
	var me = Rect2(global_position - body.size / 2.0, body.size)
	if _passing:
		if _dash_timer > 0.0:
			return  # a dash-parry: through him
		# The dash is over. Still inside him: out the side you got closer to.
		_passing = false
		if me.intersects(block):
			_block_side = 1.0 if global_position.x >= block.get_center().x else -1.0
			_block_sliding = true
			_block_above = false
	if not me.intersects(block):
		_block_sliding = false
		_block_above = me.end.y <= block.position.y
		# Beside or under him: that's your side. Over him, keep the side you came from.
		var side = signf(global_position.x - block.get_center().x)
		if not _block_above and side != 0.0:
			_block_side = side
		return
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


# DASH-SLASH THROUGH: whether a dash-slash goes through the boss just now.
func _dash_slash_passes() -> bool:
	match Moves.value("dash_slash_pass"):
		"always":
			return true
		"sync":
			return GameManager.rules != null and GameManager.rules.sync_mode
	return false


# The boss's block is in this dash's way.
func _boss_ahead() -> bool:
	return _boss_in_the_way(global_position.x + _dash_dir * (DASH_DISTANCE + body.size.x))


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
		if not _tell_sounded and _tell_left <= TELL_SOUND_TIME and not _rhythm_dash:  # that has its beats
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


# --- The look: the sword's angle, colors, flashes, effects, hands -----------------

# The blade's angle right now: 0 is level, pointing the way the player faces; negative is up.
func _sword_angle() -> float:
	if is_clashing or _hold_kind != Hold.NONE:
		return 0.0  # held flat against the other blade
	if _drawing:
		return lerpf(SWORD_REST_ANGLE, DRAW_ANGLE, ease(draw_share(), 0.6))  # drawing back
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
	if _is_swinging() or _drawing or is_clashing or _hold_kind != Hold.NONE:
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
	_update_beat_ring()
	# Idle bob while standing still on the ground; ease back to rest otherwise.
	var bob = 0.0
	if is_on_floor() and absf(velocity.x) < 1.0:
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
	# level against the other blade; thrust forward through a dash-slash; otherwise held at the
	# side, diagonally up.
	_update_sword_idle(get_physics_process_delta_time())
	var sword_offset = Vector2(0.0, body.position.y - _body_rest.y)
	if is_clashing:
		sword_offset = Vector2(0.0, -4.0)
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
	_cue_timer = maxf(_cue_timer - get_physics_process_delta_time(), 0.0)
	if _sword_flash > 0.0:
		sword.color = Color.WHITE
	elif _cue_timer > 0.0:
		sword.color = _cue_color
	elif dash_slashing:
		sword.color = _sword_color.lerp(Color.WHITE, DASH_SLASH_GLOW)
	elif _windup_timer > 0.0:
		sword.color = _sword_color.lerp(Color.WHITE, _windup_progress())  # heating up: the cue to parry
	else:
		sword.color = _sword_color
	_sword_tip.color = sword.color
	if dash_slashing:
		_trail_timer -= get_physics_process_delta_time()
		if _trail_timer <= 0.0:
			_trail_timer += DASH_SLASH_TRAIL_INTERVAL
			_spawn_afterimage()

	var color = body_color
	if _hurt_flash > 0.0 and fmod(HURT_FLASH_TIME - _hurt_flash, 0.2) < 0.1:
		color = Color.WHITE if body_color.get_luminance() < FLASH_DARK_ABOVE else Color.BLACK
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


# 0 -> 1 through a dash-slash's windup; charging, a flare on every beat of the clock.
func _windup_progress() -> float:
	if _charging:
		return maxf(0.0, 1.0 - Beat.phase() * Beat.beat_length() / RHYTHM_CHARGE_FLARE)
	return 1.0 - _windup_timer / _windup_length


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


# The blade a little broader, with a point at its end and a crossguard just past the hands (see
# SWORD_WIDTH). Both are the sword pivot's, so they swing and stretch with the blade.
func _setup_sword():
	var middle = sword.position.y + sword.size.y / 2.0
	var length = sword.size.x
	sword.size = Vector2(length - SWORD_POINT, SWORD_WIDTH)
	sword.position.y = middle - SWORD_WIDTH / 2.0
	var end = sword.position.x + sword.size.x
	_sword_tip = Polygon2D.new()
	_sword_tip.polygon = PackedVector2Array([Vector2(end, middle - SWORD_WIDTH / 2.0),
		Vector2(end + SWORD_POINT, middle), Vector2(end, middle + SWORD_WIDTH / 2.0)])
	sword_pivot.add_child(_sword_tip)
	_crossguard = ColorRect.new()
	_crossguard.size = CROSSGUARD_SIZE
	_crossguard.position = Vector2(sword.position.x + length * CROSSGUARD_AT, middle) - CROSSGUARD_SIZE / 2.0
	_crossguard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sword_pivot.add_child(_crossguard)


# A point on the blade, from where it starts at the hilt (0) to its point (1), in global
# coordinates (the sync wave runs along it).
func blade_point(along: float) -> Vector2:
	var length = sword.size.x + SWORD_POINT
	var middle = sword.position.y + sword.size.y / 2.0
	if sabre_on():
		return sword_pivot.to_global(Vector2(sword.position.x + length * SABRE_LENGTH * along, middle - SABRE_CURVE * along * along))
	return sword_pivot.to_global(Vector2(sword.position.x + length * along, middle))


# --- The pair's strike (see THE PAIR'S STRIKE) ---

# Bound: attack held draws the sword back, let go it strikes and the bond hears of it. A block
# press or a stagger lets it go unstruck.
func _process_draw():
	if _drawing:
		if Input.is_action_just_pressed(_action("block")) or is_staggered():
			_drawing = false
			return
		if Input.is_action_pressed(_action("attack")):
			_draw_time += get_physics_process_delta_time()
			return
		var drawn = _sword_angle()
		var share = draw_share()
		_drawing = false
		_start_swing(Swing.SLASH)
		_swing_from_angle = drawn
		_attack_landed = true  # the bond deals the pair's hit, not this swing
		Sfx.play("slash", -2.0)
		bond.released(self, share)
	elif Input.is_action_just_pressed(_action("attack")) and not _is_swinging() and not is_staggered():
		_drawing = true
		_draw_time = 0.0
		parry_press_time = -100.0


func is_drawing() -> bool:
	return _drawing


# How far the sword is drawn back: 0 to 1 (fully, after Tuning "sync_charge_time").
func draw_share() -> float:
	return clampf(_draw_time / Tuning.value("sync_charge_time"), 0.0, 1.0) if _drawing else 0.0


func sabre_on() -> bool:
	return _sabre != null and _sabre.visible


# Bound in sync mode the sword is a sabre (longer, curved, half light and half dark); unbound, the
# sword again. The hitbox stays the same.
func set_sabre(on: bool):
	if on and _sabre == null:
		_sabre = Node2D.new()
		var hilt = sword.position.x
		var middle = sword.position.y + sword.size.y / 2.0
		var length = (sword.size.x + SWORD_POINT) * SABRE_LENGTH
		var top = PackedVector2Array()
		var bottom = PackedVector2Array()
		var spine = PackedVector2Array()
		var steps = 14
		for i in steps + 1:
			var t = float(i) / steps
			var x = hilt + length * t
			var y = middle - SABRE_CURVE * t * t
			var half = SABRE_WIDTH / 2.0 * (1.0 - 0.3 * t) * (1.0 if t < 0.85 else (1.0 - t) / 0.15)
			top.append(Vector2(x, y - half))
			bottom.append(Vector2(x, y + half))
			spine.append(Vector2(x, y))
		var light = Polygon2D.new()
		var points = top.duplicate()
		var back = spine.duplicate()
		back.reverse()
		points.append_array(back)
		light.polygon = points
		light.color = SABRE_LIGHT
		var dark = Polygon2D.new()
		points = spine.duplicate()
		back = bottom.duplicate()
		back.reverse()
		points.append_array(back)
		dark.polygon = points
		dark.color = SABRE_DARK
		_sabre.add_child(light)
		_sabre.add_child(dark)
		sword_pivot.add_child(_sabre)
	if _sabre != null:
		_sabre.visible = on
	sword.visible = not on
	_sword_tip.visible = not on
	if not on:
		_drawing = false


func _setup_hands():
	for i in 2:
		var hand = ColorRect.new()
		hand.size = Vector2.ONE * body.size.y * HAND_SIZE_RATIO
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
	_crossguard.color = body.color.darkened(HAND_DARKEN)
