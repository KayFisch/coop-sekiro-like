class_name BifronsSwords
extends BaseBoss
## Columna Bifrons, part 1 of 3: his two swords. Whom each fights (its ward) and on which side
## of him that is; how they're posed and drawn (blades, the guard plates down his flanks, the
## halves of his body lit by what's coming); and his guard: a blade at its flank guards, and a
## parry of his other one opens a window on it (the partner's hit).
## Part 2, where he stands and how he gets there: bifrons_moves.gd. Part 3, his attacks, the
## sync rules and the reactive mode: columna_bifrons.gd (ColumnaBifrons, the boss itself).

const LEFT = StrikePattern.LEFT
const RIGHT = StrikePattern.RIGHT
const BOTH = StrikePattern.BOTH
const CUT = StrikePattern.CUT
const CHARGE = StrikePattern.CHARGE
const PUSH = StrikePattern.PUSH
const RUSH = StrikePattern.RUSH
const BLADES = [LEFT, RIGHT]  # his two swords, named for the hand that holds each
const SIDES = [LEFT, RIGHT]
const SYNC_WAVE = preload("res://actors/player/sync_wave.gd")
const BLADE_REACH = 215.0  # from his center: a player this close is in his blades' reach

# The swords, each on a pivot at its hand.
const SWORD_LENGTH = 170.0
const SWORD_WIDTH = 12.0
const SWORD_FOLLOW = 22.0  # how fast a blade eases into its pose (1/s); a drop itself is exact
const PLATE_WIDTH = 6.0  # the guard, drawn down the flank a blade is guarding
const PARRY_FLICK_TIME = 0.12  # his own parry: the guarding blade flicked at the attacker
# A blade counts as back at its flank, guarding, once it's this close to its guard pose.
const GUARD_NEAR = Vector2(10.0, 0.2)  # px, radians
# Sword poses, for a sword on his right (on his left they're mirrored): x, y = where the hand
# is, from his center; z = the blade's angle in radians (0 points outward, level; negative is up).
const POSE_GUARD = Vector3(42.0, 46.0, -1.571)  # upright, covering its flank
const POSE_PARRY = Vector3(52.0, 38.0, -1.2)  # flicked outward, meeting a player's blade
const POSE_RAISED = Vector3(34.0, -52.0, -1.82)  # over his head, about to strike
const POSE_COILED = Vector3(30.0, -58.0, -2.07)  # drawn all the way back: the drop starts here
const POSE_DOWN = Vector3(36.0, 43.0, 0.19)  # landed: out from his flank at head height, tip on the floor
const POSE_RECOIL = Vector3(42.0, 15.0, -0.9)  # thrown back up by a parry
const POSE_OPEN = Vector3(50.0, 30.0, -1.02)  # guard broken: knocked outward, off the flank
const POSE_LIMP = Vector3(44.0, 53.0, 0.13)  # staggered or dead: dropped to the floor
const POSE_SWEEP_BACK = Vector3(46.0, 27.0, -0.75)  # the sweep's windup: held out to the side, drawn back
const POSE_SWEEP = Vector3(40.0, 40.0, 0.0)  # cutting level, at head height
const POSE_PROP = Vector3(44.0, -82.0, 1.18)  # planted in the floor out to the side, his weight on it
const POSE_LANCE_LOW = Vector3(40.0, 44.0, -0.3)  # the charge's windup: lowered, pointing at the player...
const POSE_LANCE_BACK = Vector3(-18.0, 44.0, -0.04)  # ...and drawn far back, level, the hand behind his middle
const POSE_LANCE = Vector3(62.0, 44.0, 0.0)  # thrust out
const POSE_STAB = Vector3(13.0, -95.0, 1.54)  # the leap: held high over his middle, pointing straight down
# PPE, both swords on one side: the one whose hand is on the other flank reaches across, in
# front of him and of the other sword. It stands outside the other one, leaning out (this is
# added to its guard poses). It strikes as the other one does, only from lower: where that one
# comes down from over his head, this one is laid back over his shoulder and comes on a
# flatter arc.
const ACROSS_SHIFT = Vector3(16.0, -16.0, 0.28)
const ACROSS_POSES = [POSE_GUARD, POSE_PARRY, POSE_OPEN]
const POSE_SLASH_RAISED = Vector3(54.0, -14.0, -2.2)
const POSE_SLASH_COILED = Vector3(50.0, -20.0, -2.55)
const POSE_SLASH_DOWN = Vector3(46.0, 38.0, 0.1)
const EDGE_WIDTH = 4.0  # a blade's cutting edge, in the color of the player it fights

const COLOR_SWORD = Color(0.8, 0.82, 0.86)  # silver
const COLOR_SWORD_LIMP = Color(0.45, 0.45, 0.5)
const COLOR_PLATE = Color(0.62, 0.64, 0.7)
const COLOR_OPEN = Color(1.0, 0.95, 0.6)  # "hit here, now": a broken guard's flank, flashing
const COLOR_PARRY = Color(1.0, 0.7, 0.3)  # sparks off his own parry
const COLOR_PLAYER_PARRY = Color(1.0, 0.85, 0.4)  # sparks off a player's
const COLOR_PROVOKED = Color(0.75, 0.33, 0.16)  # his body, the closer he is to striking back
const COLOR_SYNC_BEAT = Color(0.7, 0.45, 1.0)  # the beat-ring's violet shard (the fight's cue is SyncWave's)
const WARD_TINT = 0.85  # how far a sword's crossguard and edge take its player's color: whose it is
const HAND_SIZE = 16.0
const HAND_DARKEN = 0.25
const CROSSGUARD = Vector2(6.0, 32.0)

var _wards = {LEFT: null, RIGHT: null}  # sword -> its own player (see _assign_wards())
var _turned = {LEFT: false, RIGHT: false}  # sword -> it has turned on the other sword's player
var _away_for = {LEFT: 0.0, RIGHT: 0.0}  # sword -> how long its own player has been out of range
var _pivots = {}  # sword -> Node2D
var _blades = {}  # sword -> ColorRect
var _edges = {}  # sword -> ColorRect: its cutting edge
var _crossguards = {}  # sword -> ColorRect
var _plates = {}  # sword -> ColorRect: its guard
var _halves = {}  # side -> ColorRect over that half of his body
var _poses = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where each blade is drawn right now
var _targets = {LEFT: POSE_GUARD, RIGHT: POSE_GUARD}  # where it's headed (pose_sword())
var _snaps = {LEFT: false, RIGHT: false}
# How far over toward the side *away* from its player a blade is headed: 1 on its player's
# side, -1 all the way over on the other (the sweep).
var _overs = {LEFT: 1.0, RIGHT: 1.0}
var _homes = {LEFT: false, RIGHT: false}  # posed at its own hand's flank, wherever its player is
# Where a blade is drawn: 1 at its own hand's flank, -1 across on the other. In between it's
# drawn foreshortened, passing in front of him.
var _crosses = {LEFT: 1.0, RIGHT: 1.0}
var _front = 0  # the sword drawn in front of the other: the one that last reached across
var _stagger_poses = {}  # sword -> [pose, over] for a stagger, instead of POSE_LIMP (set_stagger_pose())
var _side_tints = {LEFT: Color(1, 1, 1, 0), RIGHT: Color(1, 1, 1, 0)}  # sword -> tint_side()
var _at_guard = {LEFT: true, RIGHT: true}  # that blade is back at its flank (see is_guarding())
var _flick_until = {LEFT: 0.0, RIGHT: 0.0}  # anim_time until which that blade is parrying

# A broken guard, per sword: open from..until (anim_time). It may be broken a moment before it
# opens (break_guard()'s delay).
var _open_from = {LEFT: 0.0, RIGHT: 0.0}
var _open_until = {LEFT: 0.0, RIGHT: 0.0}
var _open_shown = {LEFT: true, RIGHT: true}  # the opening has made its sound and sparks
var _opened_by = {LEFT: null, RIGHT: null}  # the player whose parry broke it
var _open_used = {LEFT: false, RIGHT: false}  # a sync hit came through it
var _open_judged = {LEFT: true, RIGHT: true}  # its closing has been seen (_judge_windows())
# Sync as life (core/sync_rules.gd, Moves "bifrons_rules" on "sync"), or null: the old rules,
# health and the sync meter in GameManager.
var rules: SyncRules = null


# How close he is to striking back, 0 to 1: his body warms with it (the reactive mode, see
# columna_bifrons.gd).
func _body_heat() -> float:
	return 0.0


# --- His swords' players, and sides ---

# Each sword gets the player on its side as the fight begins, and keeps them.
func _assign_wards():
	if is_instance_valid(_wards[LEFT]) or is_instance_valid(_wards[RIGHT]):
		return
	var players = get_players()
	players.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	if players.size() == 1:
		_wards[side_of(players[0])] = players[0]
	elif players.size() > 1:
		_wards[LEFT] = players[0]
		_wards[RIGHT] = players[1]
	for p in players:
		if not p.repainted.is_connected(_color_swords):
			p.repainted.connect(_color_swords)
	_color_swords()


# That sword's own player, or null.
func own_ward(blade: int):
	var ward = _wards[blade]
	return ward if is_instance_valid(ward) else null


# The player that sword fights right now, or null: its own, unless it has turned on the other
# sword's (see "LEFT ALONE").
func ward_of(blade: int):
	return own_ward(-blade if _turned[blade] else blade)


func side_of(player) -> int:
	return LEFT if player.global_position.x < global_position.x else RIGHT


# The side that sword is on: its player's.
func blade_side(blade: int) -> int:
	var ward = ward_of(blade)
	return side_of(ward) if ward != null else blade


# Both swords on one side of him: both players there, or both swords on one player.
func is_ppe() -> bool:
	return ward_of(LEFT) != null and ward_of(RIGHT) != null and blade_side(LEFT) == blade_side(RIGHT)


# PPE: true for the sword that's on the flank its hand isn't (see ACROSS_SHIFT).
func reaches_across(blade: int) -> bool:
	return is_ppe() and blade_side(blade) != blade


# The players his swords fight right now: both, or the one who's there.
func _fought() -> Array:
	var players = []
	for blade in BLADES:
		var ward = ward_of(blade)
		if ward != null and not ward in players:
			players.append(ward)
	return players


func distance_to(player) -> float:
	return absf(player.global_position.x - global_position.x)


# A sword's crossguard and cutting edge have the color of the player it fights.
func _color_swords():
	for blade in BLADES:
		var ward = ward_of(blade)
		var color = COLOR_PLATE if ward == null else COLOR_PLATE.lerp(ward.player_color, WARD_TINT)
		_crossguards[blade].color = color
		_edges[blade].color = color


# --- The guard ---

# True while that sword is back at its flank, ready: it parries its player's sword hits.
func is_guarding(blade: int) -> bool:
	return hp > 0.0 and state != State.STAGGER and _at_guard[blade] and not is_broken(blade) \
		and (rules == null or rules.boss_guards())  # no guard in chaos


# True while that sword's window is open (a parry of the other sword opened it): the other
# player's hits are sync hits. Its guard is broken meanwhile, unless Moves "bifrons_guard_break"
# is off: then the window only times the beat, and a hit in it lands (a sync hit) only if that
# sword can't parry it just then.
func is_open(blade: int) -> bool:
	return anim_time >= _open_from[blade] and anim_time < _open_until[blade]


# True while that sword's guard is down because the window is open (see is_open()).
func is_broken(blade: int) -> bool:
	return guard_breaks() and is_open(blade)


func guard_breaks() -> bool:
	return Moves.on("bifrons_guard_break")


# The sword whose guard is open for `player`'s sync hit (another player's parry broke it), or 0.
func window_for(player) -> int:
	for blade in BLADES:
		if is_open(blade) and _opened_by[blade] != player:
			return blade
	return 0


# True from the parry that breaks that sword's guard until it's back: open, or about to be.
func is_breaking(blade: int) -> bool:
	return guard_breaks() and anim_time < _open_until[blade]


# A strike of his other sword, parried by `by`: after `delay` this one's guard is gone for
# `duration`. The parry's energy runs over to the partner meanwhile (SyncWave), arriving as the
# window opens.
func break_guard(blade: int, duration: float, delay = 0.0, by = null):
	_open_from[blade] = anim_time + delay
	_open_until[blade] = _open_from[blade] + duration
	_open_shown[blade] = false
	_opened_by[blade] = by
	_open_used[blade] = false
	_open_judged[blade] = false
	if by != null:
		for p in get_players():
			if p != by:
				SYNC_WAVE.send(by, p, delay, Tuning.value("sync_beat_time"), ARENA_FLOOR_Y, get_parent())
	if delay <= 0.0:
		_show_open(blade)


func _show_open(blade: int):
	_open_shown[blade] = true
	if guard_breaks():
		Sfx.play("guard_break", -2.0)
		spawn_sparks(_flank(blade_side(blade), global_position.y), 12, COLOR_PLATE)
	# The beat for the partner's hit: their sword lights up while a hit is on it (as the parry's
	# SyncWave arrives).
	for p in get_players():
		if p != _opened_by[blade]:
			p.cue_sync(Tuning.value("sync_beat_time"), SYNC_WAVE.COLOR)


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
	for blade in BLADES:
		# Its guard: a plate down the flank it's guarding.
		var plate = _rect(Vector2(PLATE_WIDTH, body.size.y), COLOR_PLATE)
		body.add_child(plate)
		_plates[blade] = plate
		# The sword: blade, crossguard and hand on a pivot at the hand, flipped on his left.
		var pivot = Node2D.new()
		add_child(pivot)
		_pivots[blade] = pivot
		var steel = _rect(Vector2(SWORD_LENGTH, SWORD_WIDTH), COLOR_SWORD)
		steel.position = Vector2(0.0, -SWORD_WIDTH / 2.0)
		pivot.add_child(steel)
		_blades[blade] = steel
		# Its cutting edge (the side it comes down with), which keeps its player's color whatever
		# color the blade turns.
		var edge = _rect(Vector2(SWORD_LENGTH, EDGE_WIDTH), COLOR_PLATE)
		edge.position = Vector2(0.0, SWORD_WIDTH - EDGE_WIDTH)
		steel.add_child(edge)
		_edges[blade] = edge
		var crossguard = _rect(CROSSGUARD, COLOR_PLATE)
		crossguard.position = Vector2(HAND_SIZE / 2.0, -CROSSGUARD.y / 2.0)
		pivot.add_child(crossguard)
		_crossguards[blade] = crossguard
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
	for blade in BLADES:
		pose_sword(blade, POSE_GUARD)
		tint_sword(blade, COLOR_SWORD)
		tint_side(blade, COLOR_SWORD, 0.0)


# Where a sword should be: one of the POSE_s (or between two), on its player's side, or `over`
# toward the other (1: its player's side, -1: all the way over). It eases there, unless `snap`:
# then it's there this frame (a drop or a sweep, which have to land on time).
func pose_sword(blade: int, pose: Vector3, snap = false, over = 1.0):
	_targets[blade] = pose
	_snaps[blade] = snap
	_overs[blade] = over
	_homes[blade] = false


# The same, but at its own hand's flank wherever its player is (the leap: a sword down each side).
func pose_sword_home(blade: int, pose: Vector3, snap = false):
	pose_sword(blade, pose, snap)
	_homes[blade] = true


func tint_sword(blade: int, color: Color):
	_blades[blade].color = color


# Lights the half of his body that sword is on: where a strike is coming from.
func tint_side(blade: int, color: Color, alpha: float):
	_side_tints[blade] = Color(color, alpha)


# Where that sword lies while he's staggered, instead of dropped on its player's side. Set just
# before the stagger; forgotten after it.
func set_stagger_pose(blade: int, pose: Vector3, over = 1.0):
	_stagger_poses[blade] = [pose, over]


func _update_pose():
	var down = hp <= 0.0 or state == State.STAGGER
	var follow = 1.0 - exp(-SWORD_FOLLOW * get_physics_process_delta_time())
	if not down:
		_stagger_poses = {}
	# His body warms as his patience runs out (the reactive mode, see _body_heat()).
	if state in [State.IDLE, State.RECOVER]:
		body.color = COLOR_IDLE.lerp(COLOR_PROVOKED, _body_heat())
	var tints = {LEFT: Color(1, 1, 1, 0), RIGHT: Color(1, 1, 1, 0)}  # side -> the strongest tint there
	var flashing = {LEFT: false, RIGHT: false}  # side -> a guard is open there
	for blade in BLADES:
		var side = blade_side(blade)
		var across = reaches_across(blade)
		var open = is_open(blade) and not down
		if open and not _open_shown[blade]:
			_show_open(blade)  # a window opened with a delay opens only now
		var broken = open and guard_breaks()
		if across and _front != blade:
			_front = blade  # it reaches across in front of the other sword
			move_child(_pivots[blade], -1)
		var pose: Vector3 = _targets[blade]
		var over: float = _overs[blade]
		var snap: bool = _snaps[blade]
		var home: bool = _homes[blade]
		# Guarding means back at its flank: an attack wants it there, and it has arrived.
		var wants_guard = pose == POSE_GUARD and over == 1.0 and not home and not down and not broken
		if not wants_guard:
			_at_guard[blade] = false
		elif not _at_guard[blade]:
			var off = _poses[blade] - (POSE_GUARD + (ACROSS_SHIFT if across else Vector3.ZERO))
			_at_guard[blade] = Vector2(off.x, off.y).length() <= GUARD_NEAR.x and absf(off.z) <= GUARD_NEAR.y \
				and absf(_crosses[blade] - blade * side) <= 0.1
		if down:
			var limp = _stagger_poses.get(blade, [POSE_LIMP, 1.0])
			pose = limp[0]
			over = limp[1]
			home = false
			snap = hp <= 0.0  # dead: this is the last frame he's posed
		elif broken and pose == POSE_GUARD:
			pose = POSE_OPEN  # its guard is broken: knocked aside
		elif anim_time < _flick_until[blade] and not snap:
			pose = POSE_PARRY  # his parry shows even if the blade is already off to strike back
		var flicking = pose == POSE_PARRY
		if across and pose in ACROSS_POSES:
			pose += ACROSS_SHIFT
		var cross = 1.0 if home else over * blade * side
		_poses[blade] = pose if snap else _poses[blade].lerp(pose, follow)
		_crosses[blade] = cross if snap else lerpf(_crosses[blade], cross, follow)
		# Across: the blade passes in front of him, drawn foreshortened.
		var drawn = _crosses[blade]
		if absf(drawn) < 0.02:
			drawn = 0.02
		var pivot: Node2D = _pivots[blade]
		pivot.position = Vector2(_poses[blade].x * blade * drawn, _poses[blade].y)
		pivot.rotation = _poses[blade].z * blade * drawn
		pivot.scale.x = blade * drawn
		if down:
			_blades[blade].color = COLOR_SWORD_LIMP
		elif flicking:
			_blades[blade].color = Color.WHITE
		elif _targets[blade] == POSE_GUARD:
			_blades[blade].color = COLOR_SWORD
		# Its guard, down the flank it's on (outside the other's, if both are there).
		var plate: ColorRect = _plates[blade]
		var lane = PLATE_WIDTH if across else 0.0
		plate.visible = is_guarding(blade)
		plate.position.x = -PLATE_WIDTH - lane if side == LEFT else body.size.x + lane
		if open:
			flashing[side] = true
		if _side_tints[blade].a > tints[side].a:
			tints[side] = _side_tints[blade]
	for side in SIDES:
		if down:
			_halves[side].color = Color(1, 1, 1, 0)  # the body's own stagger flash shows
		elif flashing[side]:
			_halves[side].color = COLOR_OPEN if fmod(anim_time, 0.1) < 0.05 else Color.WHITE
		else:
			_halves[side].color = tints[side]


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
