class_name ColumnaBifrons
extends BaseBoss
## Columna Bifrons, the two-faced column: a test boss for fights fought from both sides at once
## (player - boss - player). He stands in the middle of the arena and never moves, a sword on
## each side. The state machine lives in BaseBoss, the attacks in attacks/; what's his own is
## here: which attacks come and how often, his two swords, his guard, and how he answers being
## attacked.
##
## THE RULES, the same that hold for the players' swords (see "THE SWORD" in player.gd):
## 1. A blade guards or swings. While his blade on a side is back at its flank it parries every
##    sword hit on that side. While it's up for a strike, dropping, lying where it landed,
##    thrown back by a parry, or away (the sweep), it can't: hits land, as many as fit.
## 2. A parried swing recoils: a player's blade is knocked back by his guard, his own is thrown
##    back by a player's perfect parry, and either takes longer to come back.
## 3. A strike that's perfect parried breaks his guard on the *other* side for a moment, and
##    hits there are sync hits: more damage, and sync.
## 4. Both blades parried at once stagger him: no guard on either side.
##
## TWO MODES (Moves "bifrons_mode"), one set of attacks. "patterns": he runs one attack after
## another, and the players' part is to answer them. "reactive": he leaves a little more room
## between them, and a hit he parries calls up his next attack at once, aimed at whoever
## attacked him.
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
const SWEEP_WEIGHT = 1.5  # the sweep (attacks/sweep.gd) comes among the patterns, this often
# Patterns that may come twice in a row; the rest never repeat back to back.
const REPEATABLE_PATTERNS = ["SINGLE", "TRIPLE"]
# Runs each pattern as written or mirrored, whichever keeps the strikes even between the two
# sides (at random while they're even). Off: always as written.
const MIRROR_PATTERNS = true
# For testing: set to an attack's name (e.g. "TRIPLE", "SWEEP") to use only that one.
const TEST_ONLY_PATTERN = ""

# He starts an attack only while a player is within BLADE_REACH: he can't walk up to them yet.
const REACH_RECHECK = 0.2  # nobody there: he looks again this much later

# THE REACTIVE MODE. Between two attacks he waits REACTIVE_WAIT (after the usual recovery)
# before starting the next of his own: a little room for the players to start instead. Every
# hit he parries, at any time, counts toward his patience: one of PATIENCE's numbers, picked
# afresh with every attack. Once that many are parried and he's free, he strikes back at the
# player whose hit he parried last: with one of the same attacks, turned so its first strike is
# theirs, and that strike comes quickly (ANSWER_WAIT). Then the series runs to its end, as ever.
const REACTIVE_WAIT_MIN = 0.5
const REACTIVE_WAIT_MAX = 1.2
const PATIENCE = [1, 1, 2]
const ANSWER_WAIT = 4  # StrikePattern.TIME_UNITs until an answer's first strike lands, at most

# A blade landing on a player (any of his attacks).
const BLADE_REACH = 215.0  # from his center: players this close on that side are under the blade
const BLADE_DAMAGE = 12.0
const BLADE_KNOCKBACK = 300.0
const BLOCKED_DAMAGE = 4.0
const BLOCKED_KNOCKBACK = 150.0
const SYNC_HIT_FACTOR = 2.5  # a sync hit's damage, times the sword hit's own
# TESTING ALONE (Moves "bifrons_stand_in"): a stand-in on that side parries the blades landing
# there, this often; nobody on that side is hurt. Below 1 it misses some, so the player on the
# other side has to watch whether the parry came before hitting.
const STAND_IN_PARRY_CHANCE = 0.75

# The swords, one per side, each on a pivot at its hand.
const SWORD_LENGTH = 170.0
const SWORD_WIDTH = 12.0
const SWORD_FOLLOW = 22.0  # how fast a blade eases into its pose (1/s); a drop itself is exact
const PLATE_WIDTH = 6.0  # the guard, drawn down each flank
const PARRY_FLICK_TIME = 0.12  # his own parry: the guarding blade flicked at the attacker
# A blade counts as back at its flank, guarding, once it's this close to POSE_GUARD.
const GUARD_NEAR = Vector2(10.0, 0.2)  # px, radians
# Sword poses, for the right-hand sword (the left one mirrors them): x, y = where the hand is,
# from his center; z = the blade's angle in radians (0 points outward, level; negative is up).
const POSE_GUARD = Vector3(42.0, 46.0, -1.571)  # upright, covering its flank
const POSE_PARRY = Vector3(52.0, 38.0, -1.2)  # flicked outward, meeting a player's blade
const POSE_RAISED = Vector3(34.0, -52.0, -1.82)  # over his head, about to strike
const POSE_COILED = Vector3(30.0, -58.0, -2.07)  # drawn all the way back: the drop starts here
const POSE_DOWN = Vector3(36.0, 43.0, 0.19)  # landed: out from his flank at head height, tip on the floor
const POSE_RECOIL = Vector3(42.0, 15.0, -0.9)  # thrown back up by a parry
const POSE_OPEN = Vector3(50.0, 30.0, -1.02)  # guard broken: knocked outward, off the flank
const POSE_LIMP = Vector3(44.0, 53.0, 0.13)  # staggered or dead: dropped to the floor
const POSE_SWEEP_BACK = Vector3(46.0, 27.0, -0.75)  # the sweep's windup: held out to the side, drawn back
const POSE_SWEEP = Vector3(40.0, 40.0, 0.0)  # sweeping: level, at head height
const POSE_PROP = Vector3(44.0, -82.0, 1.18)  # planted in the floor out to the side, his weight on it

const COLOR_SWORD = Color(0.8, 0.82, 0.86)  # silver
const COLOR_SWORD_LIMP = Color(0.45, 0.45, 0.5)
const COLOR_PLATE = Color(0.62, 0.64, 0.7)
const COLOR_OPEN = Color(1.0, 0.95, 0.6)  # "hit here, now": a broken guard's flank, flashing
const COLOR_PARRY = Color(1.0, 0.7, 0.3)  # sparks off his own parry
const COLOR_PLAYER_PARRY = Color(1.0, 0.85, 0.4)  # sparks off a player's
const COLOR_PROVOKED = Color(0.75, 0.33, 0.16)  # his body, the closer he is to striking back
const HAND_SIZE = 16.0
const HAND_DARKEN = 0.25
const CROSSGUARD = Vector2(6.0, 32.0)
const PLAYER_HEAD = Vector2(30.0, 45.0)  # where a player stands, from his flank and his center

var _pivots = {}  # side -> Node2D
var _blades = {}  # side -> ColorRect
var _plates = {}  # side -> ColorRect
var _halves = {}  # side -> ColorRect over that half of his body
var _poses = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where each blade is drawn right now
var _targets = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where it's headed (pose_sword())
var _snaps = {LEFT: false, RIGHT: false}
# How far over to the *other* side a blade is: 1 on its own side, -1 all the way across (the
# sweep). In between it's drawn foreshortened, passing in front of him.
var _crosses = {LEFT: 1.0, RIGHT: 1.0}
var _cross_targets = {LEFT: 1.0, RIGHT: 1.0}
var _stagger_poses = {}  # side -> [pose, cross] for a stagger, instead of POSE_LIMP (set_stagger_pose())
var _side_tints = {LEFT: Color(1, 1, 1, 0), RIGHT: Color(1, 1, 1, 0)}  # tint_side()
var _at_guard = {LEFT: true, RIGHT: true}  # that blade is back at its flank (see is_guarding())
var _flick_until = {LEFT: 0.0, RIGHT: 0.0}  # anim_time until which that blade is parrying

# A broken guard, per side: open from..until (anim_time). It may be broken a moment before it
# opens (break_guard()'s delay).
var _open_from = {LEFT: 0.0, RIGHT: 0.0}
var _open_until = {LEFT: 0.0, RIGHT: 0.0}
var _open_shown = {LEFT: true, RIGHT: true}  # the opening has made its sound and sparks
var _strikes_at = {LEFT: 0, RIGHT: 0}  # strikes aimed at each side so far (orient())

# The reactive mode (see REACTIVE_WAIT).
var _provocations = 0  # hits parried since his last attack began
var _patience = 2  # how many of those he lets go before striking back
var _provoker_side = RIGHT  # the side the last one came from
var _answering = false  # starting his answer (see orient() and first_wait())


func get_max_hp() -> float:
	return MAX_HP


func get_display_name() -> String:
	return "COLUMNA BIFRONS"


func get_attack_pool() -> Array:
	var pool = []
	for pattern_name in PATTERNS:
		pool.append(StrikePattern.new(pattern_name, PATTERNS[pattern_name].strikes))
	pool.append(Sweep.new())
	for attack in pool:
		attack.strike_parried.connect(func(_player): sync_event.emit("bifrons_parried"))
		attack.both_parried.connect(sync_event.emit.bind("bifrons_both_parried"))
	return pool


# The patterns' weights, and the sweep's.
func get_attack_weights() -> Dictionary:
	if TEST_ONLY_PATTERN != "":
		return {TEST_ONLY_PATTERN: 1.0}
	var weights = {}
	for pattern_name in PATTERNS:
		weights[pattern_name] = PATTERNS[pattern_name].weight
	weights[Sweep.NAME] = SWEEP_WEIGHT
	return weights


func get_repeatable_attacks() -> Array:
	return REPEATABLE_PATTERNS


func get_idle_pause() -> float:
	if _is_reactive():
		return randf_range(REACTIVE_WAIT_MIN, REACTIVE_WAIT_MAX)
	return super()


# His whole body blocks: taller than a jump, so getting to the other side takes the partner.
func body_block() -> Rect2:
	if not Moves.on("boss_body") or hp <= 0.0:
		return Rect2()
	return Rect2(global_position - body.size / 2.0, body.size)


func _is_reactive() -> bool:
	return Moves.value("bifrons_mode") == "reactive"


func _physics_process(delta):
	# Nobody in reach of his blades: he waits.
	if state == State.IDLE and timer <= delta and not _anyone_in_reach():
		timer = REACH_RECHECK
	super(delta)
	if hp > 0.0 and state == State.IDLE and _is_reactive() and _provocations >= _patience:
		_strike_back()


func _anyone_in_reach() -> bool:
	if stand_in_side() != 0:
		return true
	return get_players().any(func(p): return absf(p.global_position.x - global_position.x) <= BLADE_REACH)


# --- Sides ---

func side_of(player) -> int:
	return LEFT if player.global_position.x < global_position.x else RIGHT


# The side Moves "bifrons_stand_in" puts a stand-in on (see STAND_IN_PARRY_CHANCE), or 0.
func stand_in_side() -> int:
	match Moves.value("bifrons_stand_in"):
		"left":
			return LEFT
		"right":
			return RIGHT
	return 0


# Called by an attack as it starts, with its strikes as written ([wait, side] each): which way
# round it runs, 1 as written or -1 mirrored. His answer to a player's attack is turned so its
# first strike goes to that player; any other attack, to whichever way keeps the strikes even
# between the sides (see MIRROR_PATTERNS).
func orient(strikes: Array) -> int:
	var way = 1
	var first = strikes[0][1]
	if _answering and first != BOTH:
		way = first * _provoker_side
	elif MIRROR_PATTERNS:
		var lean = 0  # > 0: as written, it strikes right more often than left
		for strike in strikes:
			lean += strike[1]
		var ahead = (_strikes_at[RIGHT] - _strikes_at[LEFT]) * lean  # > 0: as written, it adds to the lead
		if ahead > 0 or (ahead == 0 and randf() < 0.5):
			way = -1
	for strike in strikes:
		if strike[1] != BOTH:
			_strikes_at[strike[1] * way] += 1
	_provocations = 0
	_patience = PATIENCE.pick_random()
	return way


# Called by a pattern as it starts, with its first strike's wait as written: the wait it gets
# this run. His answer to a player's attack comes quickly, whatever the pattern.
func first_wait(written: float) -> float:
	return minf(written, ANSWER_WAIT) if _answering else written


# --- A blade landing on a player (used by his attacks) ---

# Who the blade landing on `side` meets: the players under it, those of them who perfect
# parried it, and whether it counts as parried (by one of them, or by the stand-in).
func judge(side: int, players: Array) -> Dictionary:
	var under = players.filter(func(p):
		return is_instance_valid(p) and side_of(p) == side \
			and absf(p.global_position.x - global_position.x) <= BLADE_REACH)
	var parriers = under.filter(func(p): return p.is_perfect_parry())
	var stand_in = stand_in_side() == side and randf() < STAND_IN_PARRY_CHANCE
	return {"side": side, "under": under, "parriers": parriers, "stand_in": stand_in,
		"parried": stand_in or not parriers.is_empty()}


# The judged blade lands: the parriers parry it (`strong`: the heavier kind of parry), everyone
# else under it is hit, or chipped behind a block.
func land(judged: Dictionary, strong = false):
	for p in judged.under:
		if p in judged.parriers:
			p.on_perfect_parry(strong)
			spawn_sparks(p.global_position + Vector2(0.0, -24.0), 10, COLOR_PLAYER_PARRY)
		elif stand_in_side() == judged.side:
			pass  # testing alone: nobody on the stand-in's side is hurt
		elif p.is_blocking():
			p.take_damage(BLOCKED_DAMAGE, knockback_for(p, BLOCKED_KNOCKBACK), true)
		else:
			p.take_damage(BLADE_DAMAGE, knockback_for(p, BLADE_KNOCKBACK))
			shake(5.0)
	if judged.stand_in:
		# A clang and sparks where a player would stand.
		Sfx.play("parry", -3.0)
		var at = _flank(judged.side, global_position.y + PLAYER_HEAD.y) + Vector2(judged.side * PLAYER_HEAD.x, 0.0)
		spawn_sparks(at, 10, COLOR_PLAYER_PARRY)
	elif not judged.parried:
		Sfx.play("thunk", -6.0)  # the blade hitting the floor


# --- The guard ---

# True while his blade on that side is back at its flank, ready: it parries sword hits there.
func is_guarding(side: int) -> bool:
	return hp > 0.0 and state != State.STAGGER and _at_guard[side] and not is_open(side)


# True while that side's guard is broken and open: sword hits there are sync hits.
func is_open(side: int) -> bool:
	return anim_time >= _open_from[side] and anim_time < _open_until[side]


# True from the parry that breaks that side's guard until it's back: open, or about to be.
func is_breaking(side: int) -> bool:
	return anim_time < _open_until[side]


# A parried strike on the other side: after `delay` this side's guard is gone for `duration`.
func break_guard(side: int, duration: float, delay = 0.0):
	_open_from[side] = anim_time + delay
	_open_until[side] = _open_from[side] + duration
	_open_shown[side] = false
	if delay <= 0.0:
		_show_open(side)


func _show_open(side: int):
	_open_shown[side] = true
	Sfx.play("guard_break", -2.0)
	spawn_sparks(_flank(side, global_position.y), 12, COLOR_PLATE)


# source: the player whose sword hit landed. A guarding blade parries it; anything else is hit.
func take_damage(amount: float, source = null):
	if source == null or hp <= 0.0 or state == State.STAGGER:
		super(amount, source)
		return
	var side = side_of(source)
	if is_open(side):
		# Through the guard a parry on the other side broke: a sync hit.
		sync_event.emit("bifrons_sync_hit")
		Sfx.play("sync_hit")
		shake(6.0)
		spawn_sparks(_flank(side, source.global_position.y), 16, COLOR_OPEN)
		super(amount * SYNC_HIT_FACTOR, source)
	elif is_guarding(side):
		_parry(source)
	else:
		# That blade is busy: nothing to parry with.
		Sfx.play("sync_hit", -6.0)
		shake(3.0)
		spawn_sparks(_flank(side, source.global_position.y), 8, COLOR_EXECUTE)
		super(amount, source)


# He parries a player's sword hit with the blade on that side: the hit is lost and the player's
# blade is knocked back. In the reactive mode it also wears on his patience.
func _parry(player):
	var side = side_of(player)
	player.on_swing_parried()
	_flick_until[side] = anim_time + PARRY_FLICK_TIME
	Sfx.play("parry", -4.0)
	shake(3.0)
	spawn_sparks(_flank(side, player.global_position.y), 10, COLOR_PARRY)
	if _is_reactive():
		_provocations += 1
		_provoker_side = side


# The reactive mode: his patience is gone and he's free. He strikes back at the player whose hit
# he parried last (see REACTIVE_WAIT).
func _strike_back():
	_choose_target()
	if target_player == null:
		return
	_answering = true
	_begin_telegraph(pick_attack())
	_answering = false


func _die():
	_open_until = {LEFT: 0.0, RIGHT: 0.0}
	_open_shown = {LEFT: true, RIGHT: true}
	_stagger_poses = {}
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
		# The guard: a plate down that flank, there while that side's blade is guarding.
		var plate = _rect(Vector2(PLATE_WIDTH, body.size.y), COLOR_PLATE)
		plate.position = Vector2(-PLATE_WIDTH if side == LEFT else body.size.x, 0.0)
		body.add_child(plate)
		_plates[side] = plate
		# The sword: blade, crossguard and hand on a pivot at the hand, flipped for the left one.
		var pivot = Node2D.new()
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


# Where a blade should be: one of the POSE_s (or between two), and how far across to the other
# side (`cross`: 1 on its own side, -1 all the way over). It eases there, unless `snap`: then
# it's there this frame (a drop or a sweep, which have to land on time).
func pose_sword(side: int, pose: Vector3, snap = false, cross = 1.0):
	_targets[side] = pose
	_snaps[side] = snap
	_cross_targets[side] = cross


func tint_sword(side: int, color: Color):
	_blades[side].color = color


# Lights that half of his body: the side a strike is coming from.
func tint_side(side: int, color: Color, alpha: float):
	_side_tints[side] = Color(color, alpha)


# Where that blade lies while he's staggered, instead of dropped on its own side. Set just
# before the stagger; forgotten after it.
func set_stagger_pose(side: int, pose: Vector3, cross = 1.0):
	_stagger_poses[side] = [pose, cross]


func _update_pose():
	var down = hp <= 0.0 or state == State.STAGGER
	var follow = 1.0 - exp(-SWORD_FOLLOW * get_physics_process_delta_time())
	if not down:
		_stagger_poses = {}
	# His body warms as his patience runs out.
	if state in [State.IDLE, State.RECOVER]:
		var heat = clampf(float(_provocations) / _patience, 0.0, 1.0) if _is_reactive() else 0.0
		body.color = COLOR_IDLE.lerp(COLOR_PROVOKED, heat)
	for side in SIDES:
		var open = is_open(side) and not down
		if open and not _open_shown[side]:
			_show_open(side)  # a guard broken with a delay opens only now
		var pose: Vector3 = _targets[side]
		var cross: float = _cross_targets[side]
		var snap: bool = _snaps[side]
		# Guarding means back at its flank: an attack wants it there, and it has arrived.
		var wants_guard = pose == POSE_GUARD and cross == 1.0 and not down and not open
		if not wants_guard:
			_at_guard[side] = false
		elif not _at_guard[side]:
			var off = _poses[side] - POSE_GUARD
			_at_guard[side] = Vector2(off.x, off.y).length() <= GUARD_NEAR.x and absf(off.z) <= GUARD_NEAR.y \
				and absf(_crosses[side] - 1.0) <= 0.1
		if down:
			var limp = _stagger_poses.get(side, [POSE_LIMP, 1.0])
			pose = limp[0]
			cross = limp[1]
			snap = hp <= 0.0  # dead: this is the last frame he's posed
		elif open and pose == POSE_GUARD:
			pose = POSE_OPEN  # its guard is broken: knocked aside
		elif anim_time < _flick_until[side] and not snap:
			pose = POSE_PARRY  # his parry shows even if the blade is already off to strike back
		_poses[side] = pose if snap else _poses[side].lerp(pose, follow)
		_crosses[side] = cross if snap else lerpf(_crosses[side], cross, follow)
		# Across (the sweep): the blade passes in front of him, drawn foreshortened.
		var over = _crosses[side]
		if absf(over) < 0.02:
			over = 0.02
		var pivot: Node2D = _pivots[side]
		pivot.position = Vector2(_poses[side].x * side * over, _poses[side].y)
		pivot.rotation = _poses[side].z * side * over
		pivot.scale.x = side * over
		if down:
			_blades[side].color = COLOR_SWORD_LIMP
		elif pose == POSE_PARRY:
			_blades[side].color = Color.WHITE
		elif _targets[side] == POSE_GUARD:
			_blades[side].color = COLOR_SWORD
		_plates[side].visible = is_guarding(side)
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
