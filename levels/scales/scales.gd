class_name Scales
extends Node2D
## The Scales, Sphaera Pendula's arena: two pans hanging from the ends of a beam, one on each
## side of a pit with no floor. The pans' heights follow the weight on them: a player standing
## on a pan weighs PLAYER_WEIGHT (a player in the air weighs nothing, so jumping takes your
## weight off your pan), and attacks can add more (extra_weight, e.g. the sphere resting on a
## pan) or push a pan down past its range (sink). The heavier pan sinks and the lighter one
## rises, on a spring, so the motion lags a little and can be read.
## A player who falls into the pit takes PIT_DAMAGE and is put back on the higher pan.

const LEFT = -1
const RIGHT = 1

# --- Tuning ---
const CENTER_X = 576.0
const PAN_REST_TOP = 470.0  # a pan's surface when the scales are level
const PAN_THICKNESS = 20.0
const PIT_LEFT = 476.0  # the pans' inner edges
const PIT_RIGHT = 676.0
const PAN_STEP = 45.0  # px a pan moves per unit of weight difference between the pans
const PAN_MAX = 120.0  # furthest the weight alone moves a pan from level
const PAN_STIFFNESS = 90.0  # the spring pulling a pan toward the height its weight asks for...
const PAN_DAMPING = 13.0  # ...and its damping: a slight overshoot, then settled in ~0.5 s
const PLAYER_WEIGHT = 1.0
const PIT_KILL_Y = 780.0  # a player whose center drops below this has fallen into the pit
const PIT_DAMAGE = 15.0
const PIT_RESPAWN_INVULN = 1.0
const RESPAWN_X = {LEFT: 250.0, RIGHT: 902.0}
const SHUDDER_AMPLITUDE = 3.0  # px the pan's visuals rattle while shuddering (a warning)
const BEAM_Y = 36.0  # where the pans' chains hang from
const PAN_CHAIN_INSET = 20.0  # the chains hang this far in from each pan's ends
const COLOR_CHAIN = Color(0.42, 0.4, 0.38)

var sensitivity = 1.0  # multiplies PAN_STEP (Sphaera Pendula's second phase raises it)
var extra_weight = {LEFT: 0.0, RIGHT: 0.0}  # set by attacks
var sink = {LEFT: 0.0, RIGHT: 0.0}  # px pushed down past the weight's height, set by attacks

var _weights = {LEFT: 0.0, RIGHT: 0.0}
var _offset = {LEFT: 0.0, RIGHT: 0.0}  # px below level (negative: above)
var _speed = {LEFT: 0.0, RIGHT: 0.0}
var _shudder = {LEFT: 0.0, RIGHT: 0.0}  # seconds of shuddering left
var _chains: Node2D

@onready var _pans = {LEFT: $PanLeft, RIGHT: $PanRight}


func _ready():
	# The pans' chains, drawn behind everything but the background.
	_chains = Node2D.new()
	_chains.draw.connect(_draw_chains)
	add_child(_chains)
	move_child(_chains, $Background.get_index() + 1)
	for side in [LEFT, RIGHT]:
		set_highlight(side, Color.WHITE, 0.0)


func _physics_process(delta):
	var weights = {LEFT: extra_weight[LEFT], RIGHT: extra_weight[RIGHT]}
	for p in get_tree().get_nodes_in_group("players"):
		var side = side_of_body(p.get_floor_body())
		if side != 0:
			weights[side] += PLAYER_WEIGHT
	_weights = weights
	var tilt = clampf((weights[LEFT] - weights[RIGHT]) * PAN_STEP * sensitivity, -PAN_MAX, PAN_MAX)
	var targets = {LEFT: tilt + sink[LEFT], RIGHT: -tilt + sink[RIGHT]}
	for side in [LEFT, RIGHT]:
		_speed[side] += (PAN_STIFFNESS * (targets[side] - _offset[side]) - PAN_DAMPING * _speed[side]) * delta
		_offset[side] += _speed[side] * delta
		_pans[side].position.y = PAN_REST_TOP + PAN_THICKNESS / 2.0 + _offset[side]
		_shudder[side] = maxf(_shudder[side] - delta, 0.0)
		var rattle = randf_range(-SHUDDER_AMPLITUDE, SHUDDER_AMPLITUDE) if _shudder[side] > 0.0 else 0.0
		_pans[side].get_node("Visual").position = Vector2(rattle, rattle * 0.5)
	_check_pit()
	_chains.queue_redraw()


# --- Queries ---

func side_of_x(x: float) -> int:
	return LEFT if x < CENTER_X else RIGHT


# Which pan a body is (the collider a player stands on), or 0.
func side_of_body(b) -> int:
	if b == null:
		return 0
	if b == _pans[LEFT]:
		return LEFT
	if b == _pans[RIGHT]:
		return RIGHT
	return 0


func pan(side: int) -> Node2D:
	return _pans[side]


# The pan's surface height (y), right now.
func pan_top(side: int) -> float:
	return PAN_REST_TOP + _offset[side]


func mean_top() -> float:
	return (pan_top(LEFT) + pan_top(RIGHT)) / 2.0


# The side whose pan is higher right now.
func higher_side() -> int:
	return LEFT if pan_top(LEFT) <= pan_top(RIGHT) else RIGHT


func weight(side: int) -> float:
	return _weights[side]


# LEFT or RIGHT, whichever carries more weight; 0 while they're balanced.
func heavier_side() -> int:
	var diff = _weights[LEFT] - _weights[RIGHT]
	if absf(diff) < 0.01:
		return 0
	return LEFT if diff > 0.0 else RIGHT


func is_standing_on(player, side: int) -> bool:
	return side_of_body(player.get_floor_body()) == side


# The x range a pan covers.
func pan_span(side: int) -> Vector2:
	if side == LEFT:
		return Vector2(BaseBoss.ARENA_LEFT, PIT_LEFT)
	return Vector2(PIT_RIGHT, BaseBoss.ARENA_RIGHT)


# --- Effects attacks use ---

# Knocks a pan upward (speed in px/s), as if struck from below; the spring brings it back.
func kick(side: int, speed: float):
	_speed[side] -= speed


func shudder(side: int, duration: float):
	_shudder[side] = maxf(_shudder[side], duration)


# A colored strip along the pan's surface (alpha 0 hides it).
func set_highlight(side: int, color: Color, alpha: float):
	_pans[side].get_node("Visual/Glow").color = Color(color, clampf(alpha, 0.0, 1.0))


# Players who fall in come back on the higher pan, hurt.
func _check_pit():
	for p in get_tree().get_nodes_in_group("players"):
		if p.global_position.y > PIT_KILL_Y and not p.is_grabbed:
			var side = higher_side()
			p.fall_into_pit(Vector2(RESPAWN_X[side], pan_top(side) - 40.0), PIT_DAMAGE, PIT_RESPAWN_INVULN)


func _draw_chains():
	for side in [LEFT, RIGHT]:
		var span = pan_span(side)
		for x in [span.x + PAN_CHAIN_INSET, span.y - PAN_CHAIN_INSET]:
			_chains.draw_line(Vector2(x, BEAM_Y), Vector2(x, pan_top(side)), COLOR_CHAIN, 3.0)
