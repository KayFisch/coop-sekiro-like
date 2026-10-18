class_name PlayerBody
extends CharacterBody2D
## A player, part 1 of 5: the body. Each player's buttons, running, jumping, the dash, falling,
## knockback, being carried (a launch's rise, a relay's throw) or bounced, and the boss's block in
## the way. The parts above add to it through the hooks at the end (_face(), _cling(),
## _speed_scale()...) and by extending _ready(), _tick_timers(), interrupt_movement() and the
## like, each override calling super.
## Part 2, the sword: player_sword.gd. Part 3, walls and ledges: player_walls.gd. Part 4, moves
## with the partner: player_partner.gd. Part 5, the player itself (what a boss does to it, the
## pair's strike, the look, the frame): player.gd, the script the scene and everyone else use.
## Which abilities are on is decided by the Moves autoload (core/moves.gd, F1 in game): every
## ability checks its switch there.

signal landed(player, air_time)  # touched down after air_time seconds off the ground

# --- Movement tuning ---
# Running: a slight ease in and out, never a slide (px/s and px/s²).
const SPEED = 360.0  # top running speed
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
const DASH_STRETCH = Vector2(1.3, 0.7)  # the dash's squash, springing back...
const DASH_STRETCH_TIME = 0.1  # ...over this long
const KNOCKBACK_TIME = 0.25  # input can't steer while this runs
const KNOCKBACK_FRICTION = 1500.0
# FAST FALL: holding down in the air, once falling, pulls you down harder and faster.
const FAST_FALL_GRAVITY = 2.2  # times the usual falling gravity
const FAST_FALL_MAX_SPEED = 1900.0
const DROP_THROUGH_TIME = 0.3  # down on a one-way platform: it lets you through this long
const WORLD_LAYER = 1  # floor and walls
const PLAYER_LAYER = 2  # players; they collide with each other while Moves "players_collide" is on
const PLATFORM_LAYER = 4  # one-way platforms live on physics layer 4
# BOSS BODY (Moves "boss_body"): a boss may block players with a zone (BaseBoss.body_block()).
# Nobody walks, dashes or jumps through it, and nobody stands on it; see _keep_out_of_boss().
const BOSS_SLIDE_SPEED = 900.0  # px/s: landing on top, you slide off the side you came from
# DASH-PARRY (Moves "parry_pass"): a perfect parry that lands while you're dashing at the boss
# carries you through him: the dash starts over from there, and his block is no obstacle until
# it's done. A dash started up to PASS_WINDOW after the parry goes through him too. Out the far
# side, you've changed sides; a dash too short for that is pushed back out the nearer side.
const PASS_WINDOW = 0.2
# The body: half as wide as it's tall, so two players side by side make a square, and their
# swords and hitboxes sit closer together. The scene's rect and collision shape take this size
# in _ready().
const BODY_SIZE = Vector2(20, 40)

@export var player_id: int = 1  # set to 1 or 2 in the inspector
@export var player_color = Color(0.25, 0.5, 1)  # body; P1 blue, P2 orange

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
var _air_jumps = AIR_JUMPS
var _coyote_timer = 0.0  # > 0 while a ground jump is still allowed
var _jump_buffer = 0.0  # > 0 while a jump press is waiting to fire
var _jump_press_time = -100.0  # the last jump press
var _dash_ready = true  # refreshed on the ground
var _dash_dir = 1.0
var _dash_timer = 0.0
var _dash_cooldown = 0.0
var dash_press_time = -100.0
var _drop_timer = 0.0
var _knockback_timer = 0.0
var _stagger_timer = 0.0  # > 0 while reeling from a hit: no movement, no input
var _stretch_tween: Tween
var _was_on_floor = false
var _air_time = 0.0  # seconds since leaving the ground
var _fast_falling = false
var _uncut_timer = 0.0  # > 0 while releasing jump mustn't cut the rise (a bounce, a wall jump)
var _heavy_rise = 0.0  # > 0 while rising from a bounce: gravity times _rise_gravity (see bounce())
var _rise_gravity = 1.0
# Carried, until _end_carry(): up by a launch (player_partner.gd), or by a relay's throw.
var _launch_timer = 0.0  # > 0 while rising from a launch: the sideways carry isn't eased off
var _boost_timer = 0.0  # a relay's throw, and the hang at its top
var _boost_velocity = Vector2.ZERO
var _throw_left = 0.0  # px a relay's throw still has to go before the hang
var _block_side = 1.0  # which side of the boss's block you're on (see _keep_out_of_boss())
var _block_above = false  # clear of the block, above it, last frame
var _block_sliding = false  # landed on top: sliding off
var _pass_timer = 0.0  # > 0 just after a perfect parry: a dash started now goes through the boss
var _passing = false  # this dash goes through the boss's block (see PASS_WINDOW)

@onready var body: ColorRect = $ColorRect


# --- Setup ---------------------------------------------------------------------

func _ready():
	body.size = BODY_SIZE
	body.position = -BODY_SIZE / 2.0
	$CollisionShape2D.shape.size = BODY_SIZE  # shared by both players: the same size anyway
	body.color = player_color
	body_color = player_color
	# Facing the boss if there is one (it's registered first: it comes before the players).
	if player_id == 2:
		facing = -1.0
	if is_instance_valid(GameManager.boss) and GameManager.boss.global_position.x != global_position.x:
		facing = signf(GameManager.boss.global_position.x - global_position.x)
	_block_side = -facing
	body.pivot_offset = body.size / 2  # stretch around the center
	_update_player_collision()
	Moves.changed.connect(_update_player_collision)


func _update_player_collision():
	set_collision_mask_value(PLAYER_LAYER, Moves.on("players_collide") and not own_half)


# --- Buttons, time, the partner -------------------------------------------------

# The input action behind this player's `button` ("jump" -> "p1_jump"), for anything that reads
# or presses a player's buttons. Each player has a set of their own; "Swap P1 / P2 controls"
# (Moves) trades them, e.g. to play solo on a pad.
func action(button: String) -> String:
	var id = player_id
	if Moves.on("swap_controls"):
		id = 3 - player_id
	return "p%d_%s" % [id, button]


# This player's `button`: pressed this frame, held down, let go this frame.
func _pressed(button: String) -> bool:
	return Input.is_action_just_pressed(action(button))


func _held(button: String) -> bool:
	return Input.is_action_pressed(action(button))


func _let_go(button: String) -> bool:
	return Input.is_action_just_released(action(button))


# Left/right input, -1..1.
func move_axis() -> float:
	if running_on:
		return 0.0
	return Input.get_axis(action("left"), action("right"))


# The real clock, in s: the timing windows are measured on it, and so is anything compared with
# the player's own moments (dash_press_time, parry_press_time...).
func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# s since `t`, a moment read off now().
func _since(t: float) -> float:
	return now() - t


# The other player; null if there's none.
func partner():
	for other in GameManager.players:
		if other != self and is_instance_valid(other):
			return other
	return null


# --- Running and falling ----------------------------------------------------------

func _process_movement(delta):
	var direction = move_axis()
	_fast_falling = false
	if is_on_floor():
		_air_jumps = AIR_JUMPS
		_coyote_timer = COYOTE_TIME
	_before_move(direction)
	_face(direction)

	if _boost_timer > 0.0:
		# A relay's throw: straight, gravity off, covering exactly its distance however the frames
		# fall; then it hangs.
		var step = minf(_boost_velocity.length(), _throw_left / delta)
		velocity = _boost_velocity.normalized() * step
		_throw_left -= step * delta
		return
	if _dash_timer > 0.0:
		velocity = Vector2(_dash_dir * _dash_speed(), 0.0)
		return
	if not is_on_floor() and _knockback_timer <= 0.0 and _cling(direction, delta):
		return

	if _knockback_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
	elif _keeps_course(direction):
		pass  # a launch's sideways carry (until steered), or flying off a wall: keep it
	else:
		var target = direction * SPEED * _speed_scale()
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
		and _held("down")
	_apply_gravity(delta, _fast_falling)
	if _let_go("jump") and velocity.y < 0.0 and _launch_timer <= 0.0 \
			and _uncut_timer <= 0.0:
		velocity.y *= JUMP_CUT


# Normal gravity on the way up, heavier on the way down, up to the fall speed cap; heavier and
# faster still when fast falling.
func _apply_gravity(delta, fast = false):
	var gravity = GRAVITY * (FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else 1.0)
	if _heavy_rise > 0.0 and velocity.y < 0.0:
		gravity *= _rise_gravity
	if fast:
		velocity.y = minf(velocity.y + gravity * FAST_FALL_GRAVITY * delta, FAST_FALL_MAX_SPEED)
	else:
		velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)


# The upward speed that rises `height` px before gravity (times `heavier`) stops it.
static func rise_speed(height: float, heavier = 1.0) -> float:
	return sqrt(2.0 * GRAVITY * heavier * height)


# Springs the player up `height` px however fast they were falling (a pogo's bounce), gravity
# times `heavier` on the way up for a quicker one. Letting go of jump doesn't cut it short.
func bounce(height: float, heavier = 1.0):
	var rise = rise_speed(height, heavier)
	velocity.y = -rise
	_rise_gravity = heavier
	_heavy_rise = rise / (GRAVITY * heavier)
	_uncut_timer = _heavy_rise
	_end_carry()


# --- Buttons: what each press does ---------------------------------------------

func _process_actions():
	if _pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
		_jump_press_time = now()
	if _jump_buffer > 0.0:
		_try_jump()

	# The dash goes the way you face (_process_movement() has already turned you this frame);
	# while a boss holds your facing, the way you hold.
	if _pressed("dash"):
		var held = move_axis()
		var boss = GameManager.boss
		var free = held != 0.0 and is_instance_valid(boss) and boss.holds_facing()
		_start_dash(signf(held) if free else facing)

	_process_other_buttons()

	if _pressed("down") and is_on_floor():
		set_collision_mask_value(PLATFORM_LAYER, false)
		_drop_timer = DROP_THROUGH_TIME


# --- Jumping and dashing ---------------------------------------------------------

# Jumps if it can: from the ground (or just off a ledge), off a wall, else with an air jump. A
# fresh press with none of those stays buffered, and fires on landing (or on reaching a wall)
# if that comes soon enough.
func _try_jump():
	if _coyote_timer > 0.0:
		velocity.y = -rise_speed(JUMP_HEIGHT)
	elif _try_wall_jump():
		return
	elif Moves.on("double_jump") and _air_jumps > 0 and _pressed("jump") and _may_air_jump():
		_air_jumps -= 1
		velocity.y = -rise_speed(DOUBLE_JUMP_HEIGHT)
	else:
		return
	_jump_buffer = 0.0
	_coyote_timer = 0.0
	_end_carry()
	_uncut_timer = 0.0
	if _dash_timer > 0.0:
		# Jumping cancels a dash, carrying only a normal amount of its speed.
		_end_dash()
		velocity.x = clampf(velocity.x, -DASH_EXIT_SPEED, DASH_EXIT_SPEED)


# Dashes the way `direction` if it can. True if it did (the parts above add theirs then).
func _start_dash(direction: float) -> bool:
	if not Moves.on("dash") or _dash_cooldown > 0.0 or not _dash_ready:
		return false
	_end_carry()
	_dash_ready = false
	_dash_dir = direction
	_dash_timer = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	dash_press_time = now()
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	_passing = _pass_timer > 0.0 and _boss_ahead()  # right after a parry: through him
	_pass_timer = 0.0
	_squash(DASH_STRETCH, DASH_STRETCH_TIME)  # snap wide and short, then spring back
	return true


# The speed of the dash running now.
func _dash_speed() -> float:
	return DASH_SPEED


# The dash stops where it is.
func _end_dash():
	_dash_timer = 0.0


# Whatever was carrying the player lets go: a launch's rise, a relay's throw.
func _end_carry():
	_launch_timer = 0.0
	_boost_timer = 0.0


func is_launching() -> bool:
	return _launch_timer > 0.0


func is_dashing() -> bool:
	return _dash_timer > 0.0


# The dash is there to use: given back since the last one, and cooled down.
func can_dash() -> bool:
	return _dash_ready and _dash_cooldown <= 0.0


func can_air_jump() -> bool:
	return _air_jumps > 0


# Air jumps, the dash and the upslash hop back, as if touching the ground.
func refresh_air_moves():
	refresh_air_jump()
	refresh_dash()


# The air jumps back (a pogo, if its switch says so).
func refresh_air_jump():
	_air_jumps = AIR_JUMPS


# Just the dash back (walls and ledges: the air jump only comes back on landing or a pogo).
func refresh_dash():
	_dash_ready = true
	_dash_cooldown = 0.0


# --- Every frame; knocked about ----------------------------------------------------

func _tick_timers(delta):
	if _dash_timer > 0.0 and _dash_timer <= delta:
		# The dash runs out: keep only running speed, which the usual acceleration takes from there.
		velocity.x = _dash_dir * DASH_EXIT_SPEED
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if is_on_floor():
		_dash_ready = true
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_pass_timer = maxf(_pass_timer - delta, 0.0)
	_launch_timer = maxf(_launch_timer - delta, 0.0)
	if _boost_timer > 0.0 and _boost_timer <= delta:
		velocity = Vector2.ZERO  # the throw's hang is over: falling from a standstill
	_boost_timer = maxf(_boost_timer - delta, 0.0)
	_uncut_timer = maxf(_uncut_timer - delta, 0.0)
	_heavy_rise = maxf(_heavy_rise - delta, 0.0)
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


# Stops everything the player was doing in the air: dashes, walls, ledges, clashes, whatever was
# carrying them. For hits, staggers, locked blades, respawns and the like.
func interrupt_movement():
	_end_dash()
	_end_carry()
	_heavy_rise = 0.0


# What the player is doing, for readouts.
func movement_state() -> String:
	if _dash_timer > 0.0:
		return "dash"
	if is_on_floor():
		return "ground"
	if _fast_falling:
		return "fast fall"
	return "air"


func is_staggered() -> bool:
	return _stagger_timer > 0.0


func apply_knockback(push: Vector2):
	velocity = push
	_knockback_timer = KNOCKBACK_TIME


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


# The body squashed or stretched to `shape`, springing back over `time` (a dash, a launch).
func _squash(shape: Vector2, time: float):
	if _stretch_tween:
		_stretch_tween.kill()
	_stretch_tween = Fx.squash(body, shape, time)


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


# --- Hooks: what the parts above add to the body -----------------------------------

# Before moving each frame, with the stick's `direction` (the walls note what they touch).
func _before_move(_direction: float):
	pass


# Which way the player faces this frame: the way they hold. A boss that changes sides keeps their
# eyes on him, whichever way they walk.
func _face(direction: float):
	if direction != 0.0:
		facing = signf(direction)
	var boss = GameManager.boss
	if is_instance_valid(boss) and boss.holds_facing() and boss.global_position.x != global_position.x:
		facing = signf(boss.global_position.x - global_position.x)


# True to move the body some other way this frame, in the air (hanging from a ledge, on a wall).
func _cling(_direction: float, _delta: float) -> bool:
	return false


# True while the sideways speed is kept, not steered: a launch's carry, until the stick moves.
func _keeps_course(direction: float) -> bool:
	return _launch_timer > 0.0 and direction == 0.0


# Times the running speed (blocking slows it, a wall jump's flight times it to the beat).
func _speed_scale() -> float:
	return 1.0


# A jump press that a wall takes. True if it jumped.
func _try_wall_jump() -> bool:
	return false


# Whether a jump press in the air may be an air jump (it may be a clash's press instead).
func _may_air_jump() -> bool:
	return true


# The buttons the parts above handle (block, attack), between the dash and dropping through.
func _process_other_buttons():
	pass
