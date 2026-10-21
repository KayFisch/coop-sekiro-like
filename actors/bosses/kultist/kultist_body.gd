class_name KultistBody
extends BaseBoss
## The Kultist, part 1 of 2: how he looks, his staff, his guard and his flight. Part 2, the boss
## himself (his attacks and their order, where he stands, the sync rules, his blows landing):
## kultist.gd. The design: docs/boss_kultist.md.
##
## ONE BODY, AN IMAGE IN EACH HALF. He's built like Bifrons, an upright block. On the mirrored
## screen (ui/mirror_view.gd) each half shows an image of him in its own colors, mirrored at the
## axis as the players are: light in the dark half above (P1's), dark in the pale half below
## (P2's). He is one body: where he stands and how high he flies is the same in both halves.
## A STAFF IN EACH HALF. Each half has its own staff, in the color of that half's player, and it
## faces that player wherever they are: it strikes at them and guards against them. So the two
## can do different things at once (in one half strike, in the other cast). Each half shows only
## its own staff.
## HIS GUARD. A staff resting at his side, back from whatever it did for staff_return_time,
## parries its player's sword hits (or blocks them, see staff_parry_chance), as Bifrons's swords
## do; a strip down that flank shows it. A staff that's raised, striking, lying where it landed,
## thrown back by a parry or casting can't. Flying, staggered or in chaos he has no guard at all.
## THE FLIGHT, which any attack can use (fly_to(), land()): he leaves the floor, demonic wings
## open (only a look), and a beam of energy runs straight down from his feet to the floor. His
## reflection's beam meets it there, so on screen it joins his two images through the axis.

const LAYERS = [1, 2]  # the halves, by the player_id whose they are: 1 P1's (light), 2 P2's (shadow)
const LEFT = -1
const RIGHT = 1

# --- His look, in each half ---
# His robe is a shade off that half's player's color (light in the light half, dark in the shadow
# half); his hood, sash and wings lean toward the other half's color, his eyes are that color.
const MID_GREY = Color(0.45, 0.44, 0.46)
const ROBE_SHADE = 0.22  # the robe: this much from his player's color toward MID_GREY
const HOOD_SHADE = 0.3  # the hood and sash: the robe, this much toward the other half's color
const WING_SHADE = 0.4  # the wings: the same, further
const HOOD_HEIGHT = 34.0  # px down from the top of his body
const EYES = Rect2(17.0, 16.0, 30.0, 5.0)  # the slit of his eyes, in his body's own coordinates
const SASH = Rect2(0.0, 84.0, 64.0, 6.0)
# Whatever BaseBoss shows on his body (a stagger's flash, the red of a strike, dead) colors his robe
# this much.
const MOOD = 0.5

# --- The staff, on a pivot at his hand ---
# Along it (0: pointing outward, level): the butt behind the hand, the head at the front end.
const STAFF_LENGTH = 200.0
const STAFF_BUTT = 64.0  # px of it behind his hand
const STAFF_WIDTH = 7.0
const HEAD_SIZE = 18.0  # the head: a diamond at the front end...
const GLOW_SIZE = 46.0  # ...lit around when he casts (light_head())
const HAND_SIZE = 14.0
const STAFF_FOLLOW = 20.0  # how fast a staff eases into its pose (1/s); a drop itself is exact
const SIDE_SWAP_TIME = 0.15  # a staff whose player passes him swings round to them in this long (s)
const PARRY_FLICK_TIME = 0.12  # his own parry: the staff flicked at the attacker
const PLATE_WIDTH = 5.0  # his guard: a strip down the flank whose staff guards
# Staff poses, for a staff on his right (on his left they're mirrored): x, y = where the hand is,
# from his center; z = the staff's angle in radians (0 points outward, level; negative is up).
const POSE_REST = Vector3(40.0, 12.0, -1.45)  # upright at his side, its butt on the floor: guarding
const POSE_PARRY = Vector3(48.0, 0.0, -1.0)  # flicked out at a player's blade
const POSE_RAISED = Vector3(26.0, -52.0, -2.3)  # over his head, about to strike
const POSE_COILED = Vector3(22.0, -58.0, -2.65)  # drawn all the way back: the drop starts here
const POSE_DOWN = Vector3(44.0, 18.0, 0.32)  # landed: out at its player, the head at the floor
const POSE_RECOIL = Vector3(40.0, -8.0, -1.9)  # thrown back up by a parry
const POSE_CAST = Vector3(34.0, -42.0, -1.0)  # held up and out at its player: casting
const POSE_CHANNEL = Vector3(18.0, -70.0, -1.57)  # held straight up over him: channeling
const POSE_LIMP = Vector3(40.0, 40.0, 0.25)  # staggered or dead: dropped

# --- The wings: only a look. Bat-like, from his shoulders, open while he's off the floor ---
const WING = [Vector2(0, 0), Vector2(30, -34), Vector2(88, -46), Vector2(112, -20), Vector2(96, 2),
	Vector2(80, -8), Vector2(66, 14), Vector2(50, 0), Vector2(36, 20), Vector2(14, 12)]
const WING_AT = Vector2(14.0, -50.0)  # the right shoulder, from his center
const WING_OPEN_TIME = 0.3  # s to open or fold
const WING_FLAP_HZ = 1.4
const WING_FLAP = 0.2  # radians each way

# --- The beam, from his feet straight down to the floor ---
const BEAM_WIDTH = 5.0
const BEAM_GLOW = 4.0  # its glow: this many times as wide
const FALL_SPEED = 900.0  # px/s: a flight cut short (a stagger), he drops back to the floor

const COLOR_PARRY = Color(1.0, 0.7, 0.3)  # sparks off his own parry (as Bifrons's)
const COLOR_PLAYER_PARRY = Color(1.0, 0.85, 0.4)  # sparks off a player's
const COLOR_BLOCK = Color(0.62, 0.64, 0.7)  # sparks off his block

@export_group("Guard")
## A player's sword hit on a resting staff: the chance he parries it (their blade is knocked back,
## both lose posture), else he blocks it (he loses posture). Bifrons's is F2 "boss_parry_chance".
@export_range(0.0, 1.0, 0.05) var staff_parry_chance = 0.5
## A staff that has done anything (struck, cast, flown) guards only once it has been back at his
## side this long (s).
@export var staff_return_time = 0.25

@export_group("Flight")
## How high he flies: his feet this far over the floor (px). Up to about 200 his image stays
## inside its half of the mirrored screen.
@export var flight_height = 170.0
## Rising from the floor to that height (s)...
@export var rise_time = 0.8
## ...and coming back down (s).
@export var descend_time = 0.6
## Hovering, he bobs this far up and down (px).
@export var hover_bob = 6.0

# Sync as life (core/sync_rules.gd): the fight's rules, set once he's ready (kultist.gd).
var rules: SyncRules = null

var _backs = {}  # layer -> Node2D behind his body: that half's wings and beam
var _fronts = {}  # layer -> Node2D before it: that half's staff and guard strip
var _skins = {}  # layer -> ColorRect over his body: his robe in that half
var _hoods = {}  # layer -> [hood, sash]
var _eyes = {}  # layer -> ColorRect
var _bits = {}  # layer -> the visibility layer that half's look is on just now
var _pivots = {}  # layer -> Node2D at the staff's hand
var _shafts = {}  # layer -> ColorRect
var _heads = {}  # layer -> Polygon2D
var _glows = {}  # layer -> Polygon2D: the head's glow
var _plates = {}  # layer -> ColorRect: his guard on that staff's side
var _wings = {}  # layer -> [right wing, left wing]
var _beams = {}  # layer -> [glow, core]
var _poses = {1: POSE_REST, 2: POSE_REST}  # where each staff is drawn right now
var _targets = {1: POSE_REST, 2: POSE_REST}  # where it's headed (pose_staff())
var _snaps = {1: false, 2: false}
var _sides = {1: float(LEFT), 2: float(RIGHT)}  # the side each staff is drawn on (through 0 as it swings round)
var _tints = {1: null, 2: null}  # a color a staff has for now (tint_staff()); null: its player's
var _lit = {1: Color(1, 1, 1, 0), 2: Color(1, 1, 1, 0)}  # its head's glow (light_head())
var _rest_since = {1: 0.0, 2: 0.0}  # anim_time each staff was last sent back to his side
var _flick_until = {1: 0.0, 2: 0.0}  # anim_time until which that staff shows his parry
var _flight = null  # {from, to, t, time}: a flight under way
var _aloft = false  # off the floor, flying or hovering
var _hover_y = 0.0  # hovering: round this height...
var _hover_t = 0.0  # ...for this long
var _wings_open = 0.0  # 0 folded, 1 open


# --- The halves and their players ---

# The player whose half that is, or null.
func player_of(layer: int):
	for p in get_players():
		if p.player_id == layer:
			return p
	return null


func layer_of(player) -> int:
	return player.player_id


func other_layer(layer: int) -> int:
	return LAYERS[1] if layer == LAYERS[0] else LAYERS[0]


# The visibility layer that half's things are drawn on (MirrorView's bits): its player's. With the
# screen not split both halves' looks are drawn, one over the other.
func layer_bit(layer: int) -> int:
	var p = player_of(layer)
	if p != null:
		return p.visibility_layer
	return MirrorView.LIGHT if layer == LAYERS[0] else MirrorView.SHADOW


# That half's player's color (light or shadow on the mirrored screen).
func half_color(layer: int) -> Color:
	var p = player_of(layer)
	if p != null:
		return p.player_color
	return MirrorView.LIGHT_BODY if layer == LAYERS[0] else MirrorView.SHADOW_BODY


func side_of(player) -> int:
	return LEFT if player.global_position.x < global_position.x else RIGHT


func distance_to(player) -> float:
	return absf(player.global_position.x - global_position.x)


# --- Building him ---

func _setup_pose():
	# He stands on the floor: the stagger's rocking and a hit's swell turn on his feet.
	body.pivot_offset = Vector2(body.size.x / 2.0, body.size.y)
	for layer in LAYERS:
		_bits[layer] = -1
		# His robe in that half, over the body BaseBoss colors; with a hood, eyes and a sash.
		var skin = _rect(body.size, Color.WHITE)
		body.add_child(skin)
		_skins[layer] = skin
		var hood = _rect(Vector2(body.size.x, HOOD_HEIGHT), Color.WHITE)
		skin.add_child(hood)
		var sash = _rect(SASH.size, Color.WHITE)
		sash.position = SASH.position
		skin.add_child(sash)
		_hoods[layer] = [hood, sash]
		var eyes = _rect(EYES.size, Color.WHITE)
		eyes.position = EYES.position
		skin.add_child(eyes)
		_eyes[layer] = eyes
		# Behind him: the wings and the beam.
		var back = Node2D.new()
		add_child(back)
		move_child(back, 0)
		_backs[layer] = back
		var beam_glow = _rect(Vector2(BEAM_WIDTH * BEAM_GLOW, 0.0), Color.WHITE)
		var beam_core = _rect(Vector2(BEAM_WIDTH, 0.0), Color.WHITE)
		back.add_child(beam_glow)
		back.add_child(beam_core)
		_beams[layer] = [beam_glow, beam_core]
		var wings = []
		for side in [RIGHT, LEFT]:
			var wing = Polygon2D.new()
			wing.polygon = PackedVector2Array(WING)
			wing.position = Vector2(WING_AT.x * side, WING_AT.y)
			back.add_child(wing)
			wings.append(wing)
		_wings[layer] = wings
		# Before him: the guard strip and the staff, on a pivot at his hand.
		var front = Node2D.new()
		add_child(front)
		_fronts[layer] = front
		var plate = _rect(Vector2(PLATE_WIDTH, body.size.y), Color.WHITE)
		front.add_child(plate)
		_plates[layer] = plate
		var pivot = Node2D.new()
		front.add_child(pivot)
		_pivots[layer] = pivot
		var glow = _diamond(GLOW_SIZE)
		glow.position = Vector2(STAFF_LENGTH - STAFF_BUTT, 0.0)
		pivot.add_child(glow)
		_glows[layer] = glow
		var shaft = _rect(Vector2(STAFF_LENGTH, STAFF_WIDTH), Color.WHITE)
		shaft.position = Vector2(-STAFF_BUTT, -STAFF_WIDTH / 2.0)
		pivot.add_child(shaft)
		_shafts[layer] = shaft
		var head = _diamond(HEAD_SIZE)
		head.position = glow.position
		pivot.add_child(head)
		_heads[layer] = head
		var hand = _rect(Vector2(HAND_SIZE, HAND_SIZE), Color.WHITE)
		hand.position = Vector2(-HAND_SIZE / 2.0, -HAND_SIZE / 2.0)
		pivot.add_child(hand)
		_hoods[layer].append(hand)  # his hand: the hood's color


func _rect(rect_size: Vector2, color: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _diamond(size: float) -> Polygon2D:
	var half = size / 2.0
	var diamond = Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(-half, 0), Vector2(0, -half), Vector2(half, 0), Vector2(0, half)])
	return diamond


# Both staves back at his side, unlit, in their players' colors; a flight cut short is over (he
# drops). After every attack and stagger, and on death.
func reset_pose():
	for layer in LAYERS:
		pose_staff(layer, POSE_REST)
		tint_staff(layer, null)
		light_head(layer, Color.WHITE, 0.0)
	_flight = null
	_aloft = false


# --- The staff (his attacks pose it) ---

# Where that half's staff should be: one of the POSE_s (or between two). It eases there, unless
# `snap`: then it's there this frame (a drop, which has to land on time). Back at REST it guards
# once staff_return_time has passed.
func pose_staff(layer: int, pose: Vector3, snap = false):
	if pose == POSE_REST and _targets[layer] != POSE_REST:
		_rest_since[layer] = anim_time
	_targets[layer] = pose
	_snaps[layer] = snap


# That staff's color for now (a telegraph's); null: its player's.
func tint_staff(layer: int, color):
	_tints[layer] = color


# The glow round that staff's head (casting, channeling): `alpha` 0 for none.
func light_head(layer: int, color: Color, alpha: float):
	_lit[layer] = Color(color, clampf(alpha, 0.0, 1.0))


# His parry: that staff flicked out at the player's blade for a moment.
func flick_staff(layer: int):
	_flick_until[layer] = anim_time + PARRY_FLICK_TIME


# Where that staff's head is (world coordinates): where his spells come from.
func staff_head(layer: int) -> Vector2:
	return _pivots[layer].to_global(Vector2(STAFF_LENGTH - STAFF_BUTT, 0.0))


# --- His guard ---

# True while his staff in that player's half guards against them: resting at his side, back for
# staff_return_time; he on the floor, not staggered, not in chaos.
func is_guarding(player) -> bool:
	if player == null or hp <= 0.0 or state == State.STAGGER or _aloft:
		return false
	if rules != null and not rules.boss_guards():
		return false  # in chaos he has no guard
	var layer = layer_of(player)
	return _targets[layer] == POSE_REST and anim_time - _rest_since[layer] >= staff_return_time


# --- The flight ---

# He flies to `point` (his center) in `time`, easing in and out: off the floor and up, or about
# while up. Taking off opens his wings; once there he hovers.
func fly_to(point: Vector2, time: float):
	_flight = {"from": global_position, "to": point, "t": 0.0, "time": maxf(time, 0.01)}
	if point.y < home_position.y - 1.0 and not _aloft:
		_aloft = true
		Sfx.play("launch", -6.0)


# He comes down where he is, in `time`. On the floor his wings fold, and his guard can come back.
func land(time: float):
	fly_to(Vector2(global_position.x, home_position.y), time)


# Off the floor: flying or hovering (or coming down).
func is_aloft() -> bool:
	return _aloft


# A flight under way, not yet where it's going.
func is_flying() -> bool:
	return _flight != null


func _physics_process(delta):
	if hp > 0.0:
		_fly(delta)
	super(delta)


func _fly(delta: float):
	if _flight == null:
		if _aloft:
			# Hovering: a slow bob round where he arrived.
			_hover_t += delta
			global_position.y = _hover_y - sin(_hover_t * 3.0) * hover_bob
		elif global_position.y < home_position.y and state != State.STAGGER:
			# Off the floor and not flying (a flight cut short): he drops.
			global_position.y = minf(global_position.y + FALL_SPEED * delta, home_position.y)
		return
	_flight.t += delta
	var k = smoothstep(0.0, 1.0, clampf(_flight.t / _flight.time, 0.0, 1.0))
	global_position = _flight.from.lerp(_flight.to, k)
	if _flight.t < _flight.time:
		return
	var to: Vector2 = _flight.to
	_flight = null
	if to.y < home_position.y - 1.0:
		_hover_y = to.y
		_hover_t = 0.0
	elif _aloft:
		_touch_down()


func _touch_down():
	_aloft = false
	Sfx.play("thunk", -2.0)
	shake(4.0)
	spawn_sparks(global_position + Vector2(0.0, body.size.y / 2.0), 10, MID_GREY)


func spawn_sparks(point: Vector2, count: int, color: Color):
	Fx.sparks(self, point, count, color)


# --- Every frame: both halves posed and colored ---

func _update_pose():
	var delta = get_physics_process_delta_time()
	var down = hp <= 0.0 or state == State.STAGGER
	var follow = 1.0 - exp(-STAFF_FOLLOW * delta)
	var mood = 0.0 if body.color == COLOR_IDLE else MOOD
	var feet = global_position.y + body.size.y / 2.0
	var off_floor = maxf(ARENA_FLOOR_Y - feet, 0.0)
	_wings_open = move_toward(_wings_open, 1.0 if _aloft and not down else 0.0, delta / WING_OPEN_TIME)
	for layer in LAYERS:
		var p = player_of(layer)
		_set_bit(layer, layer_bit(layer))
		var own = half_color(layer)
		var other = half_color(other_layer(layer))
		var robe = own.lerp(MID_GREY, ROBE_SHADE)
		var trim = robe.lerp(other, HOOD_SHADE)
		_skins[layer].color = robe.lerp(body.color, mood)
		for part in _hoods[layer]:
			part.color = trim
		_eyes[layer].color = other
		# The staff, swung round to its player's side, and posed.
		var side = side_of(p) if p != null else (LEFT if layer == LAYERS[0] else RIGHT)
		_sides[layer] = move_toward(_sides[layer], side, delta * 2.0 / SIDE_SWAP_TIME)
		var pose: Vector3 = _targets[layer]
		var snap: bool = _snaps[layer]
		var flicking = anim_time < _flick_until[layer] and not down
		if down:
			pose = POSE_LIMP
			snap = hp <= 0.0  # dead: this is the last frame he's posed
		elif flicking and not snap:
			pose = POSE_PARRY  # his parry shows even if the staff is already off to strike
		_poses[layer] = pose if snap else _poses[layer].lerp(pose, follow)
		var drawn = _sides[layer]
		if absf(drawn) < 0.02:
			drawn = 0.02 if side > 0 else -0.02  # passing in front of him: drawn foreshortened
		var pivot: Node2D = _pivots[layer]
		pivot.position = Vector2(_poses[layer].x * drawn, _poses[layer].y)
		pivot.rotation = _poses[layer].z * drawn
		pivot.scale.x = drawn
		var steel: Color = own if _tints[layer] == null else _tints[layer]
		if down:
			steel = own.lerp(MID_GREY, 0.5)
		elif flicking:
			steel = Color.WHITE
		_shafts[layer].color = steel
		_heads[layer].color = steel
		var lit: Color = _lit[layer]
		_glows[layer].color = Color(lit, lit.a * (0.75 + 0.25 * sin(anim_time * 30.0))) if not down else Color(lit, 0.0)
		# His guard: a strip down the flank whose staff guards.
		var plate: ColorRect = _plates[layer]
		plate.visible = is_guarding(p)
		plate.color = own
		plate.position = Vector2(-body.size.x / 2.0 - PLATE_WIDTH - 2.0 if side < 0 else body.size.x / 2.0 + 2.0, -body.size.y / 2.0)
		# Wings and beam, while he's off the floor.
		var flap = sin(anim_time * TAU * WING_FLAP_HZ) * WING_FLAP
		var wing_color = Color(robe.lerp(other, WING_SHADE), 0.9)
		for i in 2:
			var wing: Polygon2D = _wings[layer][i]
			var way = 1.0 if i == 0 else -1.0
			wing.visible = _wings_open > 0.0
			wing.scale = Vector2(way, 1.0) * _wings_open
			wing.rotation = -flap * way
			wing.color = wing_color
		var pulse = 0.8 + 0.2 * sin(anim_time * 9.0)
		for i in 2:
			var beam: ColorRect = _beams[layer][i]
			var width = BEAM_WIDTH * (BEAM_GLOW if i == 0 else 1.0)
			beam.visible = off_floor > 1.0 and not down
			beam.position = Vector2(-width / 2.0, body.size.y / 2.0)
			beam.size = Vector2(width, off_floor)
			beam.color = Color(own, (0.22 if i == 0 else 0.9) * pulse)


# That half's look onto its visibility layer, when it changes (its player's: see layer_bit()).
func _set_bit(layer: int, bit: int):
	if _bits[layer] == bit:
		return
	_bits[layer] = bit
	_skins[layer].visibility_layer = bit
	_backs[layer].visibility_layer = bit
	_fronts[layer].visibility_layer = bit
