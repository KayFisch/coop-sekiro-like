class_name WeighedPans
extends Node2D
## Two linked pans, like the Scales in Sphaera Pendula's arena but free-standing and tunable:
## each player standing on a pan weighs 1 (in the air, 0), the heavier pan sinks `step` px per
## unit of difference (up to `max_travel`) and the other rises as much, on a spring.
## Configure with setup() before adding it to the tree.

const THICKNESS = 20.0
const STIFFNESS = 90.0  # as in scales.gd
const DAMPING = 13.0
const COLOR = Color(0.3, 0.27, 0.24)
const COLOR_EDGE = Color(0.92, 0.82, 0.62)
const COLOR_CHAIN = Color(0.42, 0.4, 0.38)

var rest_top = 600.0
var step = 90.0
var max_travel = 180.0
var chain_top = 0.0  # where the pans' chains hang from

var _pans: Array = []  # [left, right] AnimatableBody2D
var _spans: Array = []  # [Vector2(x1, x2), ...]
var _offset = [0.0, 0.0]  # px below rest (negative: above)
var _speed = [0.0, 0.0]


func setup(left: Vector2, right: Vector2, top: float, step_px: float, max_px: float, chains_from: float):
	_spans = [left, right]
	rest_top = top
	step = step_px
	max_travel = max_px
	chain_top = chains_from


func _ready():
	for span in _spans:
		var w = span.y - span.x
		var pan = AnimatableBody2D.new()
		pan.position = Vector2((span.x + span.y) / 2.0, rest_top + THICKNESS / 2.0)
		var shape = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(w, THICKNESS)
		pan.add_child(shape)
		for part in [[Vector2(w, THICKNESS), COLOR], [Vector2(w, 2.0), COLOR_EDGE]]:
			var r = ColorRect.new()
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.size = part[0]
			r.position = Vector2(-w / 2.0, -THICKNESS / 2.0)
			r.color = part[1]
			pan.add_child(r)
		add_child(pan)
		_pans.append(pan)


func _physics_process(delta):
	var weights = [0.0, 0.0]
	for p in get_tree().get_nodes_in_group("players"):
		var floor_body = p.get_floor_body()
		for i in 2:
			if floor_body == _pans[i]:
				weights[i] += 1.0
	var tilt = clampf((weights[0] - weights[1]) * step, -max_travel, max_travel)
	var targets = [tilt, -tilt]
	for i in 2:
		_speed[i] += (STIFFNESS * (targets[i] - _offset[i]) - DAMPING * _speed[i]) * delta
		_offset[i] += _speed[i] * delta
		_pans[i].position.y = rest_top + THICKNESS / 2.0 + _offset[i]
	queue_redraw()


func pan_top(i: int) -> float:
	return rest_top + _offset[i]


func _draw():
	for i in 2:
		for x in [_spans[i].x + 16.0, _spans[i].y - 16.0]:
			draw_line(Vector2(x, chain_top), Vector2(x, pan_top(i)), COLOR_CHAIN, 3.0)
