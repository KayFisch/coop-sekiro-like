class_name SphaeraPendula
extends BaseBoss
## Sphaera Pendula: an iron sphere on a chain, hung from the fulcrum of the Scales. It never
## walks: it swings, drops and reels. Everything specific to it lives here: its health and its
## second phase, its chain, and which attacks it uses and how often. The state machine lives in
## BaseBoss; each attack's logic and tuning lives in attacks/. The attacks lean on the arena
## (`scales`, see levels/scales/scales.gd), which this boss expects to fight in.

# --- Tuning ---
const MAX_HP = 1200.0
const PHASE_TWO_AT = 0.5  # fraction of MAX_HP at which the second phase starts
const PHASE_TWO_PAN_SENSITIVITY = 1.4  # the pans react this much more to weight in phase 2

# How often each attack is picked, relative to the others: 2 is twice as likely as 1, and
# 0 (or leaving an attack out) disables it.
const ATTACK_WEIGHTS = {
	"PENDULUM_SWING": 1.5,
	"HOOK": 1.0,
	"UNDERTOW": 1.0,
	"COUNTERWEIGHT": 0.8,
	"SHACKLE": 0.8,
	"ZENITH": 0.6,
}
# From PHASE_TWO_AT on.
const PHASE_TWO_WEIGHTS = {
	"PENDULUM_SWING": 1.5,
	"HOOK": 1.0,
	"UNDERTOW": 0.8,
	"COUNTERWEIGHT": 0.8,
	"SHACKLE": 0.8,
	"ZENITH": 0.6,
	"COUPLED_PENDULUMS": 1.2,
}
# Attacks that may come twice in a row; the rest never repeat back to back.
const REPEATABLE_ATTACKS = ["PENDULUM_SWING"]
# This attack is always the fight's TEACHING_ATTACK_AT-th, so the Launch is learned early.
const TEACHING_ATTACK = "ZENITH"
const TEACHING_ATTACK_AT = 3
# For testing: set to an attack's name (e.g. "SHACKLE") to use only that attack.
const TEST_ONLY_ATTACK = ""
# For testing: 1 or 2 makes it target only that player (attacks aimed at both still hit the
# other, who can't lose health). 0 targets both players as normal.
const TEST_ONLY_TARGET = 0

const RADIUS = 44.0  # matches the scene's body and collision shape
const ANCHOR = Vector2(576, 50)  # where the chain hangs from (the Scales' fulcrum)
const HOVER_POINT = Vector2(576, 200)  # the center charge
const IDLE_SWAY = 14.0  # px either way, idly swinging on its chain between attacks
const IDLE_SWAY_HZ = 0.25
const SKIM_CLEARANCE = 2.0  # skimming a pan, its bottom stays this far above the surface
# Dazed (staggered), it hangs low over the pit, swaying: in reach from both pans' edges.
const STAGGER_HANG = 26.0  # its center, above the pans' mean surface height
const STAGGER_SWAY = 40.0
const STAGGER_SWAY_HZ = 0.5
const STAGGER_ROLL = 0.35  # radians it rolls back and forth, dazed
const CHAIN_LINK = 12.0  # px between drawn links
const COLOR_CHAIN = Color(0.5, 0.5, 0.56)
const COLOR_EYE = Color(1.0, 0.92, 0.7)
const COLOR_EYE_PHASE_TWO = Color(1.0, 0.2, 0.15)
const EYE_LOOK = 10.0  # px the eye slides toward its target

var phase_two = false
var chain_attached = true  # the chain runs from ANCHOR to the sphere (Counterweight lets go)
var chain_color = COLOR_CHAIN
var scales: Scales

var _extra_chains: Array = []  # {from, to, color}: drawn this frame only, see draw_chain()
var _attacks_picked = 0
var _eye_rest = Vector2.ZERO

@onready var _chain_node: Node2D = $Chain
@onready var _eye: ColorRect = $ColorRect/Eye


func _ready():
	scales = get_tree().get_first_node_in_group("scales")
	if scales == null:
		push_error("Sphaera Pendula needs the Scales arena (a node in the \"scales\" group).")
	_chain_node.draw.connect(_draw_chains)
	super()


func _physics_process(delta):
	_extra_chains.clear()
	super(delta)
	_chain_node.queue_redraw()


func get_max_hp() -> float:
	return MAX_HP


func get_display_name() -> String:
	return "SPHAERA PENDULA"


func get_attack_pool() -> Array:
	var swing = PendulumSwing.new()
	swing.swing_parried.connect(func(_player): sync_event.emit("swing_parried"))
	swing.relay_completed.connect(sync_event.emit.bind("swing_relay_completed"))
	var hook = Hook.new()
	hook.hook_dodged.connect(sync_event.emit.bind("hook_dodged"))
	hook.hook_rescued.connect(sync_event.emit.bind("hook_rescued"))
	var undertow = Undertow.new()
	undertow.exposed.connect(sync_event.emit.bind("undertow_exposed"))
	var counterweight = Counterweight.new()
	counterweight.catapulted.connect(sync_event.emit.bind("counterweight_catapult"))
	var shackle = Shackle.new()
	shackle.sweeps_cleared.connect(sync_event.emit.bind("shackle_sweeps_cleared"))
	shackle.slingshot.connect(sync_event.emit.bind("shackle_slingshot"))
	var zenith = Zenith.new()
	zenith.interrupted.connect(sync_event.emit.bind("zenith_interrupted"))
	var coupled = CoupledPendulums.new()
	coupled.pendulum_parried.connect(func(_player): sync_event.emit("coupled_parried"))
	coupled.collided.connect(sync_event.emit.bind("coupled_collision"))
	return [swing, hook, undertow, counterweight, shackle, zenith, coupled]


func get_attack_weights() -> Dictionary:
	if TEST_ONLY_ATTACK != "":
		return {TEST_ONLY_ATTACK: 1.0}
	return PHASE_TWO_WEIGHTS if phase_two else ATTACK_WEIGHTS


func get_forced_target_id() -> int:
	return TEST_ONLY_TARGET


func get_repeatable_attacks() -> Array:
	return REPEATABLE_ATTACKS


func pick_attack() -> Attack:
	_attacks_picked += 1
	if TEST_ONLY_ATTACK == "" and _attacks_picked == TEACHING_ATTACK_AT:
		var teaching = find_attack(TEACHING_ATTACK)
		if teaching:
			_last_attack = teaching
			return teaching
	return super()


# --- Health and the second phase ---

func take_damage(amount: float, source = null):
	super(amount, source)
	if not phase_two and hp > 0.0 and hp <= MAX_HP * PHASE_TWO_AT:
		_enter_phase_two()


# Cracked open: the eye burns red, the pans get touchier, and Coupled Pendulums joins in.
func _enter_phase_two():
	phase_two = true
	if scales:
		scales.sensitivity = PHASE_TWO_PAN_SENSITIVITY
	_eye.color = COLOR_EYE_PHASE_TWO
	var crack = ColorRect.new()
	crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crack.color = COLOR_EYE_PHASE_TWO.darkened(0.3)
	crack.size = Vector2(4, 34)
	crack.position = Vector2(body.size.x * 0.62, 6)
	crack.rotation = 0.35
	body.add_child(crack)
	shake(14.0)
	Sfx.play("grand_impact")
	spawn_ring_burst(global_position, COLOR_EYE_PHASE_TWO, 280.0, 0.5)


# --- Pose: the chain and the eye ---

func _setup_pose():
	_eye_rest = _eye.position
	_eye.color = COLOR_EYE


func reset_pose():
	chain_attached = true
	chain_color = COLOR_CHAIN
	body.visible = true


func tint_weapon(color: Color):
	chain_color = COLOR_CHAIN.lerp(color, 0.5)


# The eye slides toward whoever it's after.
func _update_pose():
	var look = 0.0
	if target_player and is_instance_valid(target_player) and hp > 0.0:
		look = clampf((target_player.global_position.x - global_position.x) / 200.0, -1.0, 1.0)
	_eye.position = _eye_rest + Vector2(look * EYE_LOOK, 0.0)


func hover_point() -> Vector2:
	return HOVER_POINT


func _idle_motion(_delta: float):
	var sway = Vector2(IDLE_SWAY * sin(anim_time * TAU * IDLE_SWAY_HZ), 0.0)
	global_position = global_position.lerp(home_position + sway, 0.05)


# Dazed: hanging low over the pit, swaying between the pans' edges and rolling.
func _stagger_motion(_delta: float):
	var sway = Vector2(STAGGER_SWAY * sin(anim_time * TAU * STAGGER_SWAY_HZ), 0.0)
	global_position = global_position.lerp(stagger_spot() + sway, 0.12)
	body.rotation = STAGGER_ROLL * sin(anim_time * TAU * STAGGER_SWAY_HZ)


# Draws a chain from `from` to `to` for this frame only (call it every frame it should show).
func draw_chain(from: Vector2, to: Vector2, color = COLOR_CHAIN):
	_extra_chains.append({"from": from, "to": to, "color": color})


func _draw_chains():
	if chain_attached and hp > 0.0:
		_draw_chain(ANCHOR, global_position, chain_color)
	elif chain_attached:
		_draw_chain(ANCHOR, global_position, COLOR_CHAIN.darkened(0.4))
	for c in _extra_chains:
		_draw_chain(c.from, c.to, c.color)


# A line with alternating flat and upright links along it.
func _draw_chain(from: Vector2, to: Vector2, color: Color):
	_chain_node.draw_line(from, to, color.darkened(0.35), 2.0)
	var length = from.distance_to(to)
	if length < 1.0:
		return
	var dir = (to - from) / length
	var d = 0.0
	var i = 0
	while d < length:
		var link = Vector2(7, 4) if i % 2 == 0 else Vector2(4, 7)
		_chain_node.draw_rect(Rect2(from + dir * d - link / 2.0, link), color)
		d += CHAIN_LINK
		i += 1


# --- Helpers used by attacks ---

# Where it hangs while staggered: low over the middle of the pit.
func stagger_spot() -> Vector2:
	return Vector2(ANCHOR.x, scales.mean_top() - STAGGER_HANG)


# The center height at which it skims a pan whose surface is at `top`: its bottom just clear.
func skim_height(top: float) -> float:
	return top - RADIUS - SKIM_CLEARANCE


# The skimming height at x: over each pan, just clear of it (`tops` = {LEFT: y, RIGHT: y}, the
# pans' surfaces; the live ones if omitted), blending across the pit between them and dipping
# `dip` px down into the pit at its middle.
func skim_at(x: float, dip = 0.0, tops = null) -> float:
	if tops == null:
		tops = {Scales.LEFT: scales.pan_top(Scales.LEFT), Scales.RIGHT: scales.pan_top(Scales.RIGHT)}
	var across = smoothstep(Scales.PIT_LEFT, Scales.PIT_RIGHT, x)
	var y = skim_height(lerpf(tops[Scales.LEFT], tops[Scales.RIGHT], across))
	var half_pit = (Scales.PIT_RIGHT - Scales.PIT_LEFT) / 2.0
	var from_center = absf(x - Scales.CENTER_X) / half_pit
	return y + dip * maxf(0.0, 1.0 - from_center * from_center)


# Is a disc (center, radius) touching the player's body?
func touches(player, center: Vector2, radius: float) -> bool:
	var half = player.body.size / 2.0
	var p = player.global_position
	var closest = Vector2(clampf(center.x, p.x - half.x, p.x + half.x), clampf(center.y, p.y - half.y, p.y + half.y))
	return closest.distance_squared_to(center) <= radius * radius


# An unparried hit: chip damage (and half the knockback) through a block, the full hit otherwise.
func hit_player(player, damage: float, blocked_damage: float, knockback: Vector2, ignore_invuln = false):
	if player.is_blocking():
		player.take_damage(blocked_damage, knockback * 0.5, true, ignore_invuln)
	else:
		player.take_damage(damage, knockback, false, ignore_invuln)
		shake(6.0)


# A disc drawn like the sphere's body (its shader), e.g. a hook tip or a split-off half.
func make_disc(diameter: float, color: Color) -> ColorRect:
	var disc = ColorRect.new()
	disc.top_level = true
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.material = body.material
	disc.size = Vector2.ONE * diameter
	disc.pivot_offset = disc.size / 2.0
	disc.color = color
	add_child(disc)
	return disc


func spawn_sparks(point: Vector2, count: int, color: Color):
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


# A ring that expands and fades (no gameplay effect).
func spawn_ring_burst(center: Vector2, color: Color, max_radius: float, duration: float):
	var ring = Node2D.new()
	ring.top_level = true
	ring.set_meta("radius", 10.0)
	ring.draw.connect(func():
		ring.draw_arc(Vector2.ZERO, ring.get_meta("radius"), 0.0, TAU, 96, color, 10.0, true))
	add_child(ring)
	ring.global_position = center
	var tween = ring.create_tween().set_parallel()
	tween.tween_method(func(r): ring.set_meta("radius", r); ring.queue_redraw(), 10.0, max_radius, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)
