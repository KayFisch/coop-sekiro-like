class_name HitterWeapon
extends BaseBoss
## The Heavy Hitter, part 1 of 2: his weapon in two layers, his two heads, his guard, and the windows
## his parried strikes open (docs/boss_heavy_hitter.md). Part 2, the boss himself (the fields, his
## chains and his breath, the rules, where he stands): heavy_hitter.gd.
##
## THE WEAPON IN TWO LAYERS: one weapon, held level, a halberd: the blade (an axe head with a spear
## point) at one end, the pommel (an iron butt) at the other. Each player has a layer of it, by
## player_id: P1's is the light half of the mirrored screen, P2's the shadow half
## (ui/mirror_view.gd). In each layer the blade points left or right (its way), and the two may differ
## (parallel: the same way; diagonal: one each way; phase 1 is always parallel). Each layer's weapon
## has a pose of its own: they move together for a strike of both heads (pose_weapon()), and apart
## when each head goes for its own player (pose_layer(): one strikes with the blade, the other jabs).
## Each half shows only its own layer's weapon; one-sided, both are drawn, a little apart.
## ITS COLORS say whom each end is aimed at, the same in both halves: the axe head in the color of the
## player at the blade (both at the blade: half in each one's, to be parried together), the butt in
## the color of the player at the pommel; nobody there, steel. A strike's telegraph (green, yellow,
## red) is on the axe's cutting edge and the spear point, and on the butt's face for a jab.
## HIS HEADS sit on top of him, one each side. In each layer the head on the blade's side has the
## blade there: a band across it in that layer's player's color. A head whose side he's hit on, his
## pommel side, turns red for a moment (anger_head(); phase 1: only the picture).
## HIS GUARD (the rules, 4): only between his chains, the weapon held level: then it guards both
## sides, in both layers. Otherwise (his windups, strikes, staggers) he's open: hits land.
## THE PARTNER'S HIT: a parry of his strike that counts opens the window for the partner's sync hit
## (open_window()), timed as in Bifrons's fight (F2, the sync page's tab "sync hit"), the parry's
## energy running over to them (SyncWave). A hit of theirs in it that lands is a sync hit.

const LEFT = -1
const RIGHT = 1
const SIDES = [LEFT, RIGHT]
const LAYERS = [1, 2]  # the layers, by the player_id whose they are: P1 light, P2 shadow

# --- The weapon: a halberd, along its shaft; the blade's end the way it points, the butt the other ---
# Its parts, for a weapon pointing right, from the pivot (where the poses put it, between his hands
# and the head): the shaft, the spear point at its end, the axe head below it (its cutting edge down
# and forward: it leads the chop), a spike on its back, and the iron butt at the other end.
const SHAFT = Rect2(-64.0, -3.0, 198.0, 6.0)
const SPEAR = [Vector2(134, -5), Vector2(160, 0), Vector2(134, 5)]
const AXE_BACK = [Vector2(92, 3), Vector2(112, 3), Vector2(112, 43), Vector2(108, 42), Vector2(96, 32), Vector2(92, 18)]
const AXE_FRONT = [Vector2(112, 3), Vector2(132, 3), Vector2(138, 16), Vector2(136, 34), Vector2(124, 44), Vector2(112, 43)]
const AXE_OUTLINE = [Vector2(92, 3), Vector2(132, 3), Vector2(138, 16), Vector2(136, 34), Vector2(124, 44), Vector2(108, 42), Vector2(96, 32), Vector2(92, 18), Vector2(92, 3)]
const AXE_EDGE = [Vector2(138, 16), Vector2(136, 34), Vector2(124, 44), Vector2(108, 42), Vector2(96, 32)]
const AXE_LOW = Vector2(118.0, 43.0)  # the axe's lowest point: where it meets the floor
const SPIKE = [Vector2(104, -3), Vector2(116, -3), Vector2(110, -18)]
const COLLAR = Rect2(86.0, -5.0, 6.0, 10.0)
const BUTT_TOP = [Vector2(-81, -4), Vector2(-77, -9), Vector2(-67, -9), Vector2(-63, -4), Vector2(-63, 0), Vector2(-81, 0)]
const BUTT_BOTTOM = [Vector2(-81, 0), Vector2(-63, 0), Vector2(-63, 4), Vector2(-67, 9), Vector2(-77, 9), Vector2(-81, 4)]
const BUTT_OUTLINE = [Vector2(-81, -4), Vector2(-77, -9), Vector2(-67, -9), Vector2(-63, -4), Vector2(-63, 4), Vector2(-67, 9), Vector2(-77, 9), Vector2(-81, 4), Vector2(-81, -4)]
const BUTT_FACE = [Vector2(-77, -9), Vector2(-81, -4), Vector2(-81, 4), Vector2(-77, 9)]  # it leads the jab
const EDGE_WIDTH = 3.0  # the axe's edge and the butt's face: the telegraph's color
const OUTLINE_WIDTH = 1.5  # the axe and the butt outlined in steel: their shape shows on any ground
const HAND_SIZE = 14.0
const HANDS_AT = [-10.0, -34.0]  # where his hands hold the shaft, px from the pivot
const HAND_DARKEN = 0.25
const COLOR_SHAFT = Color(0.36, 0.3, 0.26)
const WEAPON_FOLLOW = 20.0  # how fast it eases into its pose (1/s); a drop itself is exact
const ONE_SIDED_APART = 8.0  # px between the two layers' weapons when both are drawn, so both show
const AIM_TINT = 0.9  # how far an end takes the color of the player it's aimed at
# Poses, for a weapon whose blade points right: x, y = the pivot from his center; z = the angle
# (0: level, pointing the blade's way; negative is up). The other way, they're mirrored.
const POSE_LEVEL = Vector3(12.0, -5.0, 0.0)  # held level, 55 px over the floor: his guard
const POSE_PARRY = Vector3(18.0, -16.0, -0.35)  # his guard flicked at a hit
const POSE_RAISED = Vector3(4.0, -62.0, -1.95)  # a blade strike's windup: up over him...
const POSE_COILED = Vector3(-4.0, -66.0, -2.45)  # ...drawn all the way back: the drop starts here
const POSE_HAMMER = Vector3(-10.0, -72.0, -2.75)  # the great hammer, drawn further back still
const POSE_DOWN = Vector3(36.0, -9.0, 0.15)  # landed: the axe on the floor, out in front
const POSE_RECOIL = Vector3(20.0, -40.0, -1.0)  # thrown back up by a parry
const POSE_JAB_BACK = Vector3(40.0, -5.0, 0.0)  # a jab's windup: pulled back toward the blade's side...
const POSE_JAB = Vector3(-40.0, -5.0, 0.0)  # ...and thrust out, the pommel first
const POSE_UP = Vector3(0.0, -70.0, -1.571)  # straight up over him (turning round)
const POSE_LIMP = Vector3(30.0, 20.0, 0.21)  # staggered or dead: down on the floor
const GUARD_NEAR = Vector2(8.0, 0.15)  # px, radians: back at his guard this close to POSE_LEVEL
const PARRY_FLICK_TIME = 0.12  # his guard parrying a hit
# A strike's reach, from his center along the floor: who's in front of the blade, or the pommel.
const BLADE_REACH = 200.0
const POMMEL_REACH = 140.0

# --- His heads ---
const HEAD_SIZE = Vector2(30.0, 24.0)
const HEAD_X = 21.0  # px from his middle to a head's
const HEAD_LIGHTEN = 0.15
const COLOR_ANGRY = Color(0.85, 0.15, 0.1)
const ANGRY_TIME = 0.4
const MARK_SIZE = Vector2(16.0, 5.0)  # the band across the blade's head, in a layer
const MARK_Y = 8.0  # px down from the head's top

# --- Turning round (his breath; the stomp leap's air) ---
const TURN_TIME = 0.45
const TURN_SQUASH = Vector2(0.55, 1.04)  # his body, turning: narrowest halfway
const TURN_LIFT = 0.4  # the share of the turn the weapon goes up over him, before it comes down

const COLOR_SWORD = Color(0.8, 0.82, 0.86)  # silver
const COLOR_SWORD_LIMP = Color(0.45, 0.45, 0.5)
const COLOR_PLATE = Color(0.62, 0.64, 0.7)
const COLOR_PARRY = Color(1.0, 0.7, 0.3)  # sparks off his own parry
const COLOR_PLAYER_PARRY = Color(1.0, 0.85, 0.4)  # sparks off a player's
const WINDOW_REACH = 200.0  # a window left unused costs sync if its player was this near him

# Sync as life (core/sync_rules.gd): the fight's rules, set once he's ready (heavy_hitter.gd).
var rules: SyncRules = null
# In a stomp leap's air (attacks/swings.gd): his body blocks nobody meanwhile (ghost()).
var airborne = false

var _ways = {1: RIGHT, 2: RIGHT}  # layer -> the way its blade points
var _poses = {1: POSE_LEVEL, 2: POSE_LEVEL}  # layer -> where its weapon is drawn just now
var _targets = {1: POSE_LEVEL, 2: POSE_LEVEL}  # layer -> where it's headed (pose_layer())...
var _snaps = {1: false, 2: false}  # ...there this frame: a drop has to land on time
var _tells = {1: [COLOR_SWORD, COLOR_SWORD], 2: [COLOR_SWORD, COLOR_SWORD]}  # layer -> its telegraph's colors just now, at the blade and the butt (tint_layer())
var _at_guard = true  # the weapon is back at its guard (see is_guarding())
var _weapons = {}  # layer -> Node2D: its weapon, on its pivot
var _parts = {}  # layer -> {name: CanvasItem}: its parts (_setup_pose())
var _heads = {}  # side -> ColorRect
var _marks = {}  # layer -> ColorRect: across the blade's head, in that layer
var _angry_until = {LEFT: 0.0, RIGHT: 0.0}  # side -> anim_time its head is red until
var _turned_at = -100.0  # anim_time he last turned round (turn_round())
var _turn_posed = true  # ...and that turn poses the weapon itself (not the stomp leap's: its attack does)
var _flick_until = 0.0  # anim_time until which his guard is parrying
var _ghost_until = 0.0  # anim_time until which his body blocks nobody
# player -> the window for their sync hit, which their partner's parry opened: {from, until (anim_time),
# by (the parrier), used (a hit came in it), shown (its cue), judged (its closing seen)}.
var _windows = {}


# --- Layers and sides ---

# The way the blade points in that player's layer.
func way_of(player) -> int:
	return _ways.get(player.player_id, RIGHT)


func side_of(player) -> int:
	return LEFT if player.global_position.x < global_position.x else RIGHT


# In front of the blade, in their own layer: on the side it points to there.
func at_blade(player) -> bool:
	return side_of(player) == way_of(player)


# ...and in its reach, as it comes down.
func in_front_of_blade(player) -> bool:
	return at_blade(player) and distance_to(player) <= BLADE_REACH


# On the pommel's side, in reach of a jab.
func in_front_of_pommel(player) -> bool:
	return not at_blade(player) and distance_to(player) <= POMMEL_REACH


# The other layer: the other half of the mirrored screen.
func other_layer(layer: int) -> int:
	return LAYERS[1] if layer == LAYERS[0] else LAYERS[0]


# The player whose layer that is, or null.
func player_of(layer: int):
	for p in get_players():
		if p.player_id == layer:
			return p
	return null


# Where a blade strike comes down in that layer: its point on the floor (x).
func impact_x(layer: int) -> float:
	return global_position.x + _ways[layer] * (POSE_DOWN.x + AXE_LOW.rotated(POSE_DOWN.z).x)


# The visibility layer things of that layer are drawn on: its half of the mirrored screen, or, with
# the halves not split, both.
func layer_bit(layer: int) -> int:
	if not _split():
		return MirrorView.WORLD
	return MirrorView.LIGHT if layer == 1 else MirrorView.SHADOW


func _split() -> bool:
	var view = get_tree().get_first_node_in_group("mirror_view")
	return view != null and view.split()


# --- Turning round ---

# He turns round: in both layers the blade points the other way, and the alignment (parallel or
# diagonal) stays. The weapon swings up over him and down on the other side (TURN_TIME), unless
# `in_air`: the stomp leap's attack poses it then.
func turn_round(in_air = false):
	for layer in LAYERS:
		_flip(layer)
	_turned_at = anim_time
	_turn_posed = not in_air
	if not in_air:
		pop_body(TURN_SQUASH, TURN_TIME)
		Sfx.play("swing", -8.0)


func is_turning() -> bool:
	return anim_time < _turned_at + TURN_TIME


# That layer's blade the other way, drawn just where it was: its pose taken over into the new way,
# so it eases on from there, up over him.
func _flip(layer: int):
	_ways[layer] = -_ways[layer]
	var pose: Vector3 = _poses[layer]
	_poses[layer] = Vector3(-pose.x, pose.y, -(pose.z + PI))


# --- The guard ---

# True while his weapon guards (HIS GUARD): between his chains, held level, not turning, not in chaos.
func is_guarding() -> bool:
	return hp > 0.0 and state in [State.IDLE, State.RECOVER] and _at_guard and not is_turning() \
		and (rules == null or rules.boss_guards())


# His guard parries a player's hit: their blade is knocked back.
func guard_parry(player):
	player.on_swing_parried()
	_flick_until = anim_time + PARRY_FLICK_TIME
	Sfx.play("parry", -4.0)
	shake(3.0)
	spawn_sparks(flank(side_of(player), player.global_position.y), 10, COLOR_PARRY)


# ...or blocks it: their blade isn't knocked back.
func guard_block(player):
	Sfx.play("chip", -4.0)
	shake(2.0)
	spawn_sparks(flank(side_of(player), player.global_position.y), 6, COLOR_PLATE)


# A hit on his pommel side (in the hitter's layer): the head on that side turns red a moment.
func anger_head(side: int):
	_angry_until[side] = anim_time + ANGRY_TIME


# A point on that side's flank, at height y (world coordinates).
func flank(side: int, y: float) -> Vector2:
	return Vector2(global_position.x + side * body.size.x / 2.0, y)


# --- The partner's hit ---

# A parry of `by`'s opens `player`'s window: after the sync rules' delay, for its time, the parry's
# energy running over to them meanwhile.
func open_window(player, by):
	if player == null:
		return
	var delay = Tuning.value("sync_window_delay")
	var from = anim_time + delay
	_windows[player] = {"from": from, "until": from + Tuning.value("sync_beat_time") + Tuning.value("sync_window_late"),
		"by": by, "used": false, "shown": false, "judged": false}
	SyncWave.send(by, player, delay, Tuning.value("sync_beat_time"), ARENA_FLOOR_Y, get_parent())
	update_windows()


# True while that player's window is open.
func window_for(player) -> bool:
	var window = _windows.get(player)
	return window != null and anim_time >= window.from and anim_time < window.until


# The window of `player`'s that's open just now, or null.
func open_window_of(player):
	return _windows[player] if window_for(player) else null


# Each window opening (its cue on its player's blade, as the energy arrives) and closing: unused,
# with its player near enough to have used it, it costs the players sync.
func update_windows():
	for p in _windows:
		var window = _windows[p]
		if not is_instance_valid(p):
			window.judged = true
			continue
		if not window.shown and anim_time >= window.from:
			window.shown = true
			p.cue_sync(Tuning.value("sync_beat_time"), SyncWave.COLOR)
		if not window.judged and anim_time >= window.until:
			window.judged = true
			if not window.used and rules != null and distance_to(p) <= WINDOW_REACH:
				rules.missed_window()
				Dev.window_missed()


# --- His body ---

# His body blocks players (Moves "boss_body"), but not while he's a ghost (ghost()).
func body_block() -> Rect2:
	if not Moves.on("boss_body") or hp <= 0.0 or anim_time < _ghost_until:
		return Rect2()
	return Rect2(global_position - body.size / 2.0, body.size)


# His body blocks nobody for that long (from now): in the air, coming down on someone.
func ghost(duration: float):
	_ghost_until = anim_time + duration


# --- The weapon, the heads, the halves ---

func _setup_pose():
	# He stands on the floor: the stagger's rocking and a hit's swell turn on his foot.
	body.pivot_offset = Vector2(body.size.x / 2.0, body.size.y)
	for side in SIDES:
		var head = _rect(HEAD_SIZE, COLOR_IDLE.lightened(HEAD_LIGHTEN))
		head.position = Vector2(body.size.x / 2.0 + side * HEAD_X - HEAD_SIZE.x / 2.0, -HEAD_SIZE.y)
		body.add_child(head)
		_heads[side] = head
	for layer in LAYERS:
		var weapon = Node2D.new()
		add_child(weapon)
		_weapons[layer] = weapon
		var parts = {}
		var shaft = _rect(SHAFT.size, COLOR_SHAFT)
		shaft.position = SHAFT.position
		weapon.add_child(shaft)
		var collar = _rect(COLLAR.size, COLOR_SWORD)
		collar.position = COLLAR.position
		weapon.add_child(collar)
		parts.spear = _polygon(weapon, SPEAR, COLOR_SWORD)
		parts.spike = _polygon(weapon, SPIKE, COLOR_SWORD)
		parts.axe_back = _polygon(weapon, AXE_BACK, COLOR_SWORD)
		parts.axe_front = _polygon(weapon, AXE_FRONT, COLOR_SWORD)
		_line(weapon, AXE_OUTLINE, COLOR_SWORD, OUTLINE_WIDTH)
		parts.edge = _line(weapon, AXE_EDGE, COLOR_SWORD, EDGE_WIDTH)
		parts.butt_top = _polygon(weapon, BUTT_TOP, COLOR_SWORD)
		parts.butt_bottom = _polygon(weapon, BUTT_BOTTOM, COLOR_SWORD)
		_line(weapon, BUTT_OUTLINE, COLOR_SWORD, OUTLINE_WIDTH)
		parts.face = _line(weapon, BUTT_FACE, COLOR_SWORD, EDGE_WIDTH)
		parts.hands = []
		for at in HANDS_AT:
			var hand = _rect(Vector2(HAND_SIZE, HAND_SIZE), COLOR_IDLE.darkened(HAND_DARKEN))
			hand.position = Vector2(at - HAND_SIZE / 2.0, -HAND_SIZE / 2.0)
			weapon.add_child(hand)
			parts.hands.append(hand)
		_parts[layer] = parts
		var mark = _rect(MARK_SIZE, Color.WHITE)
		body.add_child(mark)
		_marks[layer] = mark
	move_child(_weapons[1], -1)  # P1's drawn over P2's: one-sided, P2's shows below it


func _rect(rect_size: Vector2, color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _polygon(parent: Node, points: Array, color: Color) -> Polygon2D:
	var polygon = Polygon2D.new()
	polygon.polygon = PackedVector2Array(points)
	polygon.color = color
	parent.add_child(polygon)
	return polygon


func _line(parent: Node, points: Array, color: Color, width: float) -> Line2D:
	var line = Line2D.new()
	line.points = PackedVector2Array(points)
	line.default_color = color
	line.width = width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(line)
	return line


func reset_pose():
	pose_weapon(POSE_LEVEL)
	tint_steel(COLOR_SWORD)


# Where the weapon should be, in both layers (a strike of both heads): one of the POSE_s, or between
# two. It eases there, unless `snap`: then it's there this frame (a drop, which has to land on time).
func pose_weapon(pose: Vector3, snap = false):
	for layer in LAYERS:
		pose_layer(layer, pose, snap)


# ...in one layer only (each head going for its own player).
func pose_layer(layer: int, pose: Vector3, snap = false):
	_targets[layer] = pose
	_snaps[layer] = snap


# The telegraph's color (silver: none), in both layers...
func tint_steel(color: Color):
	for layer in LAYERS:
		tint_layer(layer, color)


# ...in one; on its butt's face instead (`butt`: a jab), the other end silver.
func tint_layer(layer: int, color: Color, butt = false):
	_tells[layer] = [COLOR_SWORD, color] if butt else [color, COLOR_SWORD]


func _update_pose():
	var down = hp <= 0.0 or state == State.STAGGER
	var follow = 1.0 - exp(-WEAPON_FOLLOW * get_physics_process_delta_time())
	var turning = is_turning()
	# Guarding means back at the level hold: wanted there, and arrived.
	var wants_guard = LAYERS.all(func(layer): return _targets[layer] == POSE_LEVEL) and not down and not turning
	if not wants_guard:
		_at_guard = false
	elif not _at_guard:
		_at_guard = LAYERS.all(func(layer): return _near_level(_poses[layer]))
	var split = _split()
	var aims = _aim_colors()
	for layer in LAYERS:
		var target: Vector3 = _targets[layer]
		var snap: bool = _snaps[layer]
		var tell: Array = _tells[layer]
		if down:
			target = POSE_LIMP
			snap = hp <= 0.0  # dead: this is the last frame he's posed
			tell = [COLOR_SWORD_LIMP, COLOR_SWORD_LIMP]
		elif turning and _turn_posed and state in [State.IDLE, State.RECOVER]:
			target = POSE_UP if anim_time < _turned_at + TURN_TIME * TURN_LIFT else POSE_LEVEL
			snap = false
		elif anim_time < _flick_until:
			target = POSE_PARRY
			tell = [Color.WHITE, Color.WHITE]
		_poses[layer] = target if snap else _poses[layer].lerp(target, follow)
		_place_weapon(layer, split)
		_paint(layer, tell, aims)
	_update_heads(split)


func _near_level(pose: Vector3) -> bool:
	var off = pose - POSE_LEVEL
	return Vector2(off.x, off.y).length() <= GUARD_NEAR.x and absf(off.z) <= GUARD_NEAR.y


# That layer's weapon where its pose and way say; one-sided, a little off the other's.
func _place_weapon(layer: int, split: bool):
	var pose: Vector3 = _poses[layer]
	var way = _ways[layer]
	var apart = 0.0 if split else ONE_SIDED_APART * (layer - 1.5)
	var weapon: Node2D = _weapons[layer]
	weapon.position = Vector2(pose.x * way, pose.y + apart)
	weapon.rotation = pose.z * way
	weapon.scale.x = way
	_set_layer(weapon, layer_bit(layer) if split else MirrorView.WORLD)


# ITS COLORS: whom each end is aimed at, the same in both halves: [the axe's back, its front, the
# butt's top, its bottom]. Two at one end: one color on each half of it.
func _aim_colors() -> Array:
	var ends = [[], []]  # the players at the blade, at the pommel
	for layer in LAYERS:
		var p = player_of(layer)
		if p != null:
			ends[0 if at_blade(p) else 1].append(p)
	var colors = []
	for players in ends:
		var first = COLOR_SWORD if players.is_empty() else COLOR_SWORD.lerp(players[0].player_color, AIM_TINT)
		var second = first if players.size() < 2 else COLOR_SWORD.lerp(players[1].player_color, AIM_TINT)
		colors.append_array([first, second])
	return colors


# That layer's colors: the ends by whom they're aimed at; its telegraph on the axe's edge, the spear
# point and the butt's face.
func _paint(layer: int, tell: Array, aims: Array):
	var parts: Dictionary = _parts[layer]
	parts.axe_back.color = aims[0]
	parts.axe_front.color = aims[1]
	parts.butt_top.color = aims[2]
	parts.butt_bottom.color = aims[3]
	parts.edge.default_color = tell[0]
	parts.spear.color = tell[0]
	parts.face.default_color = tell[1]
	for hand in parts.hands:
		hand.color = body.color.darkened(HAND_DARKEN)


# The heads: red a moment when angered; and in each layer, the band across the blade's one.
func _update_heads(split: bool):
	for side in SIDES:
		_heads[side].color = COLOR_ANGRY if anim_time < _angry_until[side] else COLOR_IDLE.lightened(HEAD_LIGHTEN)
	for layer in LAYERS:
		var mark: ColorRect = _marks[layer]
		var p = player_of(layer)
		mark.visible = p != null and hp > 0.0
		if not mark.visible:
			continue
		var head: ColorRect = _heads[_ways[layer]]
		var apart = 0.0 if split else (MARK_SIZE.y + 1.0) * (layer - 1.5)  # one-sided: one over the other
		mark.position = head.position + Vector2((HEAD_SIZE.x - MARK_SIZE.x) / 2.0, MARK_Y + apart)
		mark.color = p.player_color
		_set_layer(mark, layer_bit(layer) if split else MirrorView.WORLD)


# A node and all below it onto a visibility layer (MirrorView's bits): drawn in that half only.
func _set_layer(node: CanvasItem, bit: int):
	if node.visibility_layer == bit:
		return
	node.visibility_layer = bit
	for child in node.get_children():
		_set_layer(child, bit)


func spawn_sparks(point: Vector2, count: int, color: Color):
	Fx.sparks(self, point, count, color)


func _die():
	_windows = {}
	airborne = false
	global_position.y = home_position.y  # not left hanging in a stomp leap
	super()
