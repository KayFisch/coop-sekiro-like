class_name CubusMaximus
extends BaseBoss
## Cubus Maximus: the sword-wielding cube. Everything here is specific to him: his health,
## his sword and hands, and which attacks he uses and how often. The state machine lives in
## BaseBoss; each attack's logic and its tuning values (damage, timings, ...) live in attacks/.

# --- Tuning ---
const MAX_HP = 1000.0

# How often each attack is picked, relative to the others: 2 is twice as likely as 1, and
# 0 (or leaving an attack out) disables it.
const ATTACK_WEIGHTS = {
	"JUMP_ATTACK": 1.0,
	"GRAB": 1.0,
	"GROUND_SLAM": 1.0,
	"GRAND_SLASH": 1.0,
	"SHOCKWAVE_SLASHES": 1.0,
	"TRIPLE_STAB": 1.0,
}
# Attacks that may come twice in a row; the rest never repeat back to back.
const REPEATABLE_ATTACKS = ["JUMP_ATTACK"]
# For testing: set to an attack's name (e.g. "TRIPLE_STAB") to use only that attack.
const TEST_ONLY_ATTACK = ""
# For testing: 1 or 2 makes him target only that player (attacks aimed at both still hit the
# other, who can't lose health). 0 targets both players as normal.
const TEST_ONLY_TARGET = 0

const SWORD_REACH = 110.0  # blade tip distance from the pivot at scale 1 (see the scene)

# His body (Moves "boss_body"): players can't get past him alone. He blocks them from his
# bottom up to BOSS_BLOCK_HEIGHT, above a running jump (136) and far below a launch (340), as
# wide as his body; the zone moves with him, so players walk under him while he's in the air.
# Drawn faintly, so it isn't an invisible wall.
const BOSS_BLOCK_HEIGHT = 170.0
const BLOCK_ZONE_COLOR = Color(1.0, 1.0, 1.0, 0.035)
const BLOCK_EDGE_COLOR = Color(1.0, 1.0, 1.0, 0.14)  # its top edge

# Sword angles in radians, for a boss facing right (mirrored when facing left).
const SWORD_REST_ANGLE = 0.3  # low guard; steeper would clip through the floor
const SWORD_RAISED_ANGLE = -1.9
const SWORD_FOLLOW_ANGLE = 0.7
const COLOR_SWORD = Color(0.8, 0.82, 0.86)  # silver

# Hands: two small blocks, a fifth of the body's size, gripping the sword's hilt unless an
# attack takes them over (hands_free).
const HAND_SIZE_RATIO = 0.2
const HAND_GRIPS = [0.075, 0.275]  # where each hand holds the sword, as a fraction of its length
const HAND_DARKEN = 0.25  # hands are the body's color, a bit darker

var sword_scale = Vector2.ONE
var hands: Array = []  # [ColorRect, ColorRect]
var hands_free = false  # true while an attack places the hands itself (see place_hand())

var _block_zone: ColorRect

@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: ColorRect = $SwordPivot/Sword
@onready var sword_hitbox: Area2D = $SwordPivot/SwordHitbox
@onready var grab_area: Area2D = $GrabArea


func get_max_hp() -> float:
	return MAX_HP


func get_display_name() -> String:
	return "CUBUS MAXIMUS"


func get_attack_pool() -> Array:
	var jump = JumpAttack.new()
	jump.relay_completed.connect(sync_event.emit.bind("relay_completed"))
	var grab = Grab.new()
	grab.grab_dodged.connect(sync_event.emit.bind("grab_dodged"))
	var slam = GroundSlam.new()
	var grand = GrandSlash.new()
	grand.grand_slash_parried.connect(sync_event.emit.bind("grand_slash_parried"))
	var volley = ShockwaveSlashes.new()
	volley.shockwave_parried.connect(func(_player): sync_event.emit("shockwave_parried"))
	volley.counterattack_landed.connect(func(both_players):
		sync_event.emit("double_counter" if both_players else "single_counter"))
	var triple = TripleStab.new()
	triple.stab_parried.connect(func(_player): sync_event.emit("stab_parried"))
	triple.clash_started.connect(sync_event.emit.bind("triple_clash"))
	triple.clash_countered.connect(sync_event.emit.bind("clash_countered"))
	return [jump, grab, slam, grand, volley, triple]


func get_attack_weights() -> Dictionary:
	if TEST_ONLY_ATTACK != "":
		return {TEST_ONLY_ATTACK: 1.0}
	return ATTACK_WEIGHTS


func get_forced_target_id() -> int:
	return TEST_ONLY_TARGET


func get_repeatable_attacks() -> Array:
	return REPEATABLE_ATTACKS


func body_block() -> Rect2:
	if not Moves.on("boss_body") or hp <= 0.0:
		return Rect2()
	var bottom = global_position.y + body.size.y / 2.0
	return Rect2(global_position.x - body.size.x / 2.0, bottom - BOSS_BLOCK_HEIGHT, body.size.x, BOSS_BLOCK_HEIGHT)


func _update_block_zone():
	_block_zone.visible = Moves.on("boss_body") and hp > 0.0


# --- Sword and hands ---

func _setup_pose():
	# The block's faint column, behind everything else of his.
	_block_zone = ColorRect.new()
	_block_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block_zone.size = Vector2(body.size.x, BOSS_BLOCK_HEIGHT)
	_block_zone.position = Vector2(-body.size.x / 2.0, body.size.y / 2.0 - BOSS_BLOCK_HEIGHT)
	_block_zone.color = BLOCK_ZONE_COLOR
	var edge = ColorRect.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.size = Vector2(body.size.x, 2.0)
	edge.color = BLOCK_EDGE_COLOR
	_block_zone.add_child(edge)
	add_child(_block_zone)
	move_child(_block_zone, 0)  # drawn first: under his glow and body (a z_index below 0 would hide it under the arena)
	_update_block_zone()
	Moves.changed.connect(_update_block_zone)
	for i in 2:
		var hand = ColorRect.new()
		hand.size = body.size * HAND_SIZE_RATIO
		hand.pivot_offset = hand.size / 2
		hand.top_level = true
		hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hand)
		hands.append(hand)


func reset_pose():
	reset_sword()


func tint_weapon(color: Color):
	sword.color = color


func _update_pose():
	_update_hands()


func _die():
	hands_free = false
	super()
	_update_block_zone()


func reset_sword():
	sword_scale = Vector2.ONE
	sword.color = COLOR_SWORD
	set_sword_offset(Vector2.ZERO)
	set_sword_angle(SWORD_REST_ANGLE)


func set_sword_angle(angle: float):
	sword_pivot.scale = Vector2(sword_scale.x * facing, sword_scale.y)
	sword_pivot.rotation = angle * facing


# Moves the sword's pivot away from his center, for a boss facing right (mirrored when facing
# left), e.g. drawing it back before a thrust.
func set_sword_offset(offset: Vector2):
	sword_pivot.position = Vector2(offset.x * facing, offset.y)


# Puts a hand's center at a world position (for attacks that set hands_free).
func place_hand(index: int, center: Vector2, angle = 0.0):
	var hand = hands[index]
	hand.global_position = center - hand.size / 2
	hand.rotation = angle


# Hands follow the sword's hilt through every swing, unless an attack has taken them over.
func _update_hands():
	for hand in hands:
		hand.color = body.color.darkened(HAND_DARKEN)
	if hands_free:
		return
	var hilt = sword.position.x
	var length = sword.size.x
	var blade_y = sword.position.y + sword.size.y / 2
	for i in hands.size():
		var grip = sword_pivot.to_global(Vector2(hilt + length * HAND_GRIPS[i], blade_y))
		place_hand(i, grip, sword_pivot.rotation)
