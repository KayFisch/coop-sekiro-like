@tool
class_name KitBlock
extends Node2D
## A block of wall, floor or ceiling; or, with `one_way`, a platform you jump up through and drop
## through (down). A one-way platform can belong to one player: it carries only them, on their
## own physics layer, in their color. Place it at its top-left corner.

const COLOR_SOLID = Color(0.22, 0.22, 0.25)
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const COLORS_ONE_WAY = [Color(0.32, 0.32, 0.36), Color(0.2, 0.4, 0.85), Color(0.85, 0.47, 0.13)]  # both, P1, P2

@export var size = Vector2(128, 32):
	set(v):
		size = Vector2(maxf(v.x, 4.0), maxf(v.y, 4.0))
		queue_redraw()
## Jump up through it, drop through it (down). Keep it thin (12).
@export var one_way = false:
	set(v):
		one_way = v
		queue_redraw()
## One-way only: who it carries.
@export_enum("Both", "P1", "P2") var owner_id = 0:
	set(v):
		owner_id = v
		queue_redraw()


func _ready():
	if Engine.is_editor_hint():
		return
	var body = StaticBody2D.new()
	body.collision_layer = 1 << (KitRoom.platform_layer(owner_id) - 1) if one_way else 1  # one-way layers, or the world's
	body.collision_mask = 0
	body.position = size / 2.0
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), COLORS_ONE_WAY[owner_id] if one_way else COLOR_SOLID)
	var edge = COLOR_EDGE if not one_way or owner_id == 0 else COLORS_ONE_WAY[owner_id].lightened(0.5)
	draw_rect(Rect2(0, 0, size.x, 2.0), edge)
