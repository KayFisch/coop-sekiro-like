class_name ColumnaBifrons
extends BaseBoss
## Columna Bifrons, the two-faced column: a test boss for fights fought from both sides at once
## (player - boss - player). He stands in the middle of the arena and never moves, a sword on
## each side, and strikes left, right or both in set patterns (attacks/strike_pattern.gd). The
## state machine lives in BaseBoss; what's his own is here: the patterns and how often they come,
## his two swords, and his guard.
##
## THE GUARD: he's guarded on both sides, so sword hits bounce off him. A strike that's perfect
## parried breaks the guard on the *other* side for a moment, and the partner's hit there, timed
## to the same strike, is a sync hit. Both swords parried at once stagger him: open on both sides.
## docs/boss_columna_bifrons.md has the design and what it's meant to find out.

const LEFT = StrikePattern.LEFT
const RIGHT = StrikePattern.RIGHT
const BOTH = StrikePattern.BOTH
const SIDES = [LEFT, RIGHT]

# --- Tuning ---
const MAX_HP = 1600.0

# The strike patterns: how often each comes, relative to the others (0 disables it), and its
# strikes in order, as [wait, side]. `wait` is the time until the strike lands, counted from the
# pattern's start or from the strike before, in StrikePattern.TIME_UNITs: a rough 1-10 scale,
# where 4 is a quick follow-up and 9 a long windup (under 3 is too quick to read). `side` is
# LEFT, RIGHT or BOTH. Each pattern is written once and also comes mirrored (MIRROR_PATTERNS).
const PATTERNS = {
	"SINGLE": {"weight": 1.0, "strikes": [[5, LEFT]]},
	"TRIPLE": {"weight": 3.0, "strikes": [[5, RIGHT], [4, RIGHT], [4, LEFT]]},
	"QUAD": {"weight": 2.0, "strikes": [[7, LEFT], [4, LEFT], [4, RIGHT], [4, BOTH]]},
	"LONG": {"weight": 1.0, "strikes": [
		[9, RIGHT], [4, RIGHT], [4, LEFT], [4, RIGHT], [4, RIGHT], [4, LEFT], [4, BOTH]]},
	# Building blocks, off for now: the smallest swap of roles, and a lone strike on both sides.
	"SWAP": {"weight": 0.0, "strikes": [[5, LEFT], [4, RIGHT]]},
	"BOTH": {"weight": 0.0, "strikes": [[6, BOTH]]},
}
# Patterns that may come twice in a row; the rest never repeat back to back.
const REPEATABLE_PATTERNS = ["SINGLE", "TRIPLE"]
# Runs each pattern as written or mirrored, whichever keeps the strikes even between the two
# sides (at random while they're even). Off: always as written.
const MIRROR_PATTERNS = true
# For testing: set to a pattern's name (e.g. "TRIPLE") to use only that pattern.
const TEST_ONLY_PATTERN = ""
# For testing alone: LEFT or RIGHT makes every strike on that side count as parried, with nobody
# needed there (and nobody there hurt), so one player can practice the hits from the other side.
# 0 is off.
const TEST_PARRY_SIDE = 0

const SYNC_HIT_FACTOR = 2.5  # a sync hit's damage, times the sword hit's own
# A sword hit that bounces off his guard keeps that player's hits bouncing for this long, even
# where the guard is broken: mashing attack never gets through, a timed hit does. Longer than a
# swing's cooldown (0.3 s), shorter than the gap between two strikes.
const HIT_SPAM_LOCK = 0.45
const BOUNCE_PUSH = 260.0  # px/s: the player whose hit bounced, pushed back

# The swords, one per side, each on a pivot at its hand.
const SWORD_LENGTH = 230.0
const SWORD_WIDTH = 14.0
const SWORD_FOLLOW = 22.0  # how fast a blade eases into its pose (1/s); the drop itself is exact
const PLATE_WIDTH = 6.0  # the guard, drawn down each flank
# Sword poses, for the right-hand sword (the left one mirrors them): x, y = where the hand is,
# from his center; z = the blade's angle in radians (0 points outward, level; negative is up).
const POSE_GUARD = Vector3(50.0, 62.0, -1.571)  # upright, covering its flank
const POSE_RAISED = Vector3(44.0, -70.0, -1.82)  # over his head, about to strike
const POSE_COILED = Vector3(40.0, -78.0, -2.07)  # drawn all the way back: the drop starts here
const POSE_DOWN = Vector3(46.0, 56.0, 0.19)  # landed: out from his flank at head height, tip on the floor
const POSE_RECOIL = Vector3(54.0, 20.0, -0.9)  # thrown back up by a parry
const POSE_OPEN = Vector3(62.0, 40.0, -1.02)  # guard broken: knocked outward, off the flank
const POSE_LIMP = Vector3(56.0, 70.0, 0.13)  # staggered or dead: dropped to the floor

const COLOR_SWORD = Color(0.8, 0.82, 0.86)  # silver
const COLOR_SWORD_LIMP = Color(0.45, 0.45, 0.5)
const COLOR_PLATE = Color(0.62, 0.64, 0.7)
const COLOR_OPEN = Color(1.0, 0.95, 0.6)  # "hit here, now": a broken guard's flank, flashing
const COLOR_BOUNCE = Color(0.6, 0.6, 0.6)
const HAND_SIZE = 18.0
const HAND_DARKEN = 0.25
const CROSSGUARD = Vector2(6.0, 40.0)

var _pivots = {}  # side -> Node2D
var _blades = {}  # side -> ColorRect
var _plates = {}  # side -> ColorRect
var _halves = {}  # side -> ColorRect over that half of his body
var _poses = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where each blade is drawn right now
var _targets = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where it's headed (pose_sword())
var _snaps = {LEFT: false, RIGHT: false}
var _side_tints = {LEFT: Color(1, 1, 1, 0), RIGHT: Color(1, 1, 1, 0)}  # tint_side()

var _open_until = {LEFT: 0.0, RIGHT: 0.0}  # anim_time at which that side's guard is back
var _held = {LEFT: [], RIGHT: []}  # sword hits waiting for a strike to land: {player, amount}
var _hit_locks = {}  # player -> anim_time until which their hits bounce (HIT_SPAM_LOCK)
var _strikes_at = {LEFT: 0, RIGHT: 0}  # strikes aimed at each side so far (pick_mirror())


func get_max_hp() -> float:
	return MAX_HP


func get_display_name() -> String:
	return "COLUMNA BIFRONS"


func get_attack_pool() -> Array:
	var pool = []
	for pattern_name in PATTERNS:
		var pattern = StrikePattern.new(pattern_name, PATTERNS[pattern_name].strikes)
		pattern.strike_parried.connect(func(_player): sync_event.emit("bifrons_parried"))
		pattern.both_parried.connect(sync_event.emit.bind("bifrons_both_parried"))
		pool.append(pattern)
	return pool


func get_attack_weights() -> Dictionary:
	if TEST_ONLY_PATTERN != "":
		return {TEST_ONLY_PATTERN: 1.0}
	var weights = {}
	for pattern_name in PATTERNS:
		weights[pattern_name] = PATTERNS[pattern_name].weight
	return weights


func get_repeatable_attacks() -> Array:
	return REPEATABLE_PATTERNS


# His whole body blocks: taller than a jump, so getting to the other side takes the partner.
func body_block() -> Rect2:
	if not Moves.on("boss_body") or hp <= 0.0:
		return Rect2()
	return Rect2(global_position - body.size / 2.0, body.size)


# --- The patterns' sides ---

func side_of(player) -> int:
	return LEFT if player.global_position.x < global_position.x else RIGHT


# Whether a pattern about to start should run mirrored (see MIRROR_PATTERNS), counting its
# strikes toward the sides' tally.
func pick_mirror(strikes: Array) -> bool:
	var lean = 0  # > 0: as written, it strikes right more often than left
	for strike in strikes:
		lean += strike[1]
	var ahead = (_strikes_at[RIGHT] - _strikes_at[LEFT]) * lean  # > 0: as written, it adds to the lead
	var mirror = MIRROR_PATTERNS and (ahead > 0 or (ahead == 0 and randf() < 0.5))
	for strike in strikes:
		if strike[1] != BOTH:
			_strikes_at[-strike[1] if mirror else strike[1]] += 1
	return mirror


# --- The guard ---

func is_open(side: int) -> bool:
	return anim_time < _open_until[side]


# A parried strike on the other side: this side's guard is gone for `duration`, and the sword
# hits held for the strike land.
func break_guard(side: int, duration: float):
	_open_until[side] = anim_time + duration
	Sfx.play("guard_break", -2.0)
	spawn_sparks(_flank(side, global_position.y), 12, COLOR_PLATE)
	land_held(side)


# The sword hits held on `side` land, as sync hits.
func land_held(side: int):
	var held = _held[side]
	_held[side] = []
	for hit in held:
		if hp > 0.0 and is_instance_valid(hit.player):
			_land_sync_hit(hit.player, hit.amount)


# The strike wasn't parried: the guard holds, and the sword hits held on `side` are refused.
func keep_guard(side: int):
	var held = _held[side]
	_held[side] = []
	for hit in held:
		if is_instance_valid(hit.player):
			_refuse(hit.player, hit.amount)


# source: the player whose sword hit landed. Those only get through where his guard is broken
# (or while he's staggered); everything else is plain damage.
func take_damage(amount: float, source = null):
	if source == null or hp <= 0.0 or state == State.STAGGER:
		super(amount, source)
		return
	var side = side_of(source)
	var locked = anim_time < _hit_locks.get(source, 0.0)
	var pattern = current_attack as StrikePattern
	if is_open(side) and not locked:
		_land_sync_hit(source, amount)
	elif not locked and pattern and pattern.holds_hit(side):
		_held[side].append({"player": source, "amount": amount})
	else:
		_refuse(source, amount)


func _land_sync_hit(player, amount: float):
	sync_event.emit("bifrons_sync_hit")
	Sfx.play("sync_hit")
	shake(6.0)
	spawn_sparks(_flank(side_of(player), player.global_position.y), 16, COLOR_OPEN)
	super.take_damage(amount * SYNC_HIT_FACTOR, player)


# A sword hit on his guard: it bounces off (with Moves "bifrons_guard" off, it's a plain hit).
func _refuse(player, amount: float):
	if not Moves.on("bifrons_guard"):
		super.take_damage(amount, player)
		return
	var side = side_of(player)
	_hit_locks[player] = anim_time + HIT_SPAM_LOCK
	player.apply_knockback(Vector2(side * BOUNCE_PUSH, 0.0))
	Sfx.play("chip")
	spawn_sparks(_flank(side, player.global_position.y), 5, COLOR_BOUNCE)


func _die():
	_held = {LEFT: [], RIGHT: []}
	_open_until = {LEFT: 0.0, RIGHT: 0.0}
	super()


# A point on that side's flank, at height y (world coordinates).
func _flank(side: int, y: float) -> Vector2:
	return Vector2(global_position.x + side * body.size.x / 2.0, y)


# --- Swords, plates and halves ---

func _setup_pose():
	# He stands on the floor: the stagger's rocking and a hit's swell turn on his foot.
	body.pivot_offset = Vector2(body.size.x / 2.0, body.size.y)
	for side in SIDES:
		# That half of his body, lit by what's happening on its side.
		var half = _rect(Vector2(body.size.x / 2.0, body.size.y), Color(1, 1, 1, 0))
		half.position = Vector2(0.0 if side == LEFT else body.size.x / 2.0, 0.0)
		body.add_child(half)
		_halves[side] = half
		# The guard: a plate down that flank, there while hits on that side bounce off.
		var plate = _rect(Vector2(PLATE_WIDTH, body.size.y), COLOR_PLATE)
		plate.position = Vector2(-PLATE_WIDTH if side == LEFT else body.size.x, 0.0)
		body.add_child(plate)
		_plates[side] = plate
		# The sword: blade, crossguard and hand on a pivot at the hand, flipped for the left one.
		var pivot = Node2D.new()
		pivot.scale.x = side
		add_child(pivot)
		_pivots[side] = pivot
		var blade = _rect(Vector2(SWORD_LENGTH, SWORD_WIDTH), COLOR_SWORD)
		blade.position = Vector2(0.0, -SWORD_WIDTH / 2.0)
		pivot.add_child(blade)
		_blades[side] = blade
		var crossguard = _rect(CROSSGUARD, COLOR_PLATE)
		crossguard.position = Vector2(HAND_SIZE / 2.0, -CROSSGUARD.y / 2.0)
		pivot.add_child(crossguard)
		var hand = _rect(Vector2(HAND_SIZE, HAND_SIZE), COLOR_IDLE.darkened(HAND_DARKEN))
		hand.position = Vector2(-HAND_SIZE / 2.0, -HAND_SIZE / 2.0)
		pivot.add_child(hand)


func _rect(rect_size: Vector2, color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func reset_pose():
	for side in SIDES:
		pose_sword(side, POSE_GUARD)
		tint_sword(side, COLOR_SWORD)
		tint_side(side, COLOR_SWORD, 0.0)


# Where a blade should be (one of the POSE_s, or between two). It eases there, unless `snap`:
# then it's there this frame (the drop, which has to land on time).
func pose_sword(side: int, pose: Vector3, snap = false):
	_targets[side] = pose
	_snaps[side] = snap


func tint_sword(side: int, color: Color):
	_blades[side].color = color


# Lights that half of his body: the side a strike is coming from.
func tint_side(side: int, color: Color, alpha: float):
	_side_tints[side] = Color(color, alpha)


func _update_pose():
	var down = hp <= 0.0 or state == State.STAGGER
	var follow = 1.0 - exp(-SWORD_FOLLOW * get_physics_process_delta_time())
	for side in SIDES:
		var open = is_open(side) and not down
		var pose: Vector3 = _targets[side]
		var snap: bool = _snaps[side]
		if down:
			pose = POSE_LIMP
			snap = hp <= 0.0  # dead: this is the last frame he's posed
		elif open and pose == POSE_GUARD:
			pose = POSE_OPEN  # knocked aside (a blade with a strike coming up is posed by the pattern)
			_blades[side].color = COLOR_SWORD
		_poses[side] = pose if snap else _poses[side].lerp(pose, follow)
		var pivot: Node2D = _pivots[side]
		pivot.position = Vector2(_poses[side].x * side, _poses[side].y)
		pivot.rotation = _poses[side].z * side
		if down:
			_blades[side].color = COLOR_SWORD_LIMP
		_plates[side].visible = not down and not open
		if down:
			_halves[side].color = Color(1, 1, 1, 0)  # the body's own stagger flash shows
		elif open:
			_halves[side].color = COLOR_OPEN if fmod(anim_time, 0.1) < 0.05 else Color.WHITE
		else:
			_halves[side].color = _side_tints[side]


func spawn_sparks(point: Vector2, count: int, color: Color):
	for i in count:
		var spark = _rect(Vector2(4, 4), color.lerp(Color.WHITE, randf() * 0.6))
		spark.top_level = true
		add_child(spark)
		spark.global_position = point
		var fly = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 110.0)
		var tween = spark.create_tween().set_parallel()
		tween.tween_property(spark, "global_position", point + fly, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(spark.queue_free)
