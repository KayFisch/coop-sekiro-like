@tool
class_name KitBlock
extends Node2D
## A block of wall, floor or ceiling; or, with `one_way`, a platform you jump up through and drop
## through (down). A one-way platform can belong to one player: it carries only them, on their
## own physics layer, in their color. Place it at its top-left corner.
## How it looks is only how it looks: `look` (plain, brick, dark, wood) and `edges`, the bright
## lines that mark a surface (on top by default: a floor; a wall inside a building may want none).
## A one-way platform for both of you can be wood too; one of a player's keeps their color.
## With `background` it's scenery: nothing stands on it or bumps into it, it's drawn dimmed and
## behind everything else in the room.

enum Look { PLAIN, BRICK, DARK, WOOD }

const COLORS_LOOK = [Color(0.22, 0.22, 0.25), Color(0.27, 0.21, 0.2), Color(0.13, 0.13, 0.15), Color(0.36, 0.24, 0.14)]
const COLOR_MORTAR = Color(0.17, 0.14, 0.14)
const COLOR_GRAIN = Color(0.27, 0.17, 0.1)  # wood: the seams between planks
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const COLOR_EDGE_WOOD = Color(0.72, 0.55, 0.36)
const COLOR_DIM = Color(0.06, 0.06, 0.08, 0.55)  # over a background block: the room's background, half through
const PLANK = 48.0  # px, a wood plank's length
const BACKGROUND_Z = -1  # a background block's draw layer: under every other piece, over the room's backdrop
const COLORS_ONE_WAY = [Color(0.32, 0.32, 0.36), Color(0.2, 0.4, 0.85), Color(0.85, 0.47, 0.13)]  # both, P1, P2
const EDGE = 2.0  # px, an edge line's thickness
const BRICK = Vector2(32, 16)

@export_custom(PROPERTY_HINT_RANGE, "8,640,8,or_greater,suffix:px") var size = Vector2(128, 32):  # whole px
	set(v):
		size = Vector2(maxf(roundf(v.x), 4.0), maxf(roundf(v.y), 4.0))
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
## A solid block's look.
@export var look = Look.PLAIN:
	set(v):
		look = v
		queue_redraw()
## Which sides get a bright surface line.
@export_flags("Top", "Bottom", "Left", "Right") var edges = 1:
	set(v):
		edges = v
		queue_redraw()
## Scenery: no collision, dimmed, drawn behind the rest of the room.
@export var background = false:
	set(v):
		background = v
		z_index = BACKGROUND_Z if v else 0
		queue_redraw()


func _ready():
	if Engine.is_editor_hint() or background:
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
	var wood = look == Look.WOOD and (not one_way or owner_id == 0)
	draw_rect(Rect2(Vector2.ZERO, size), COLORS_LOOK[look] if wood or not one_way else COLORS_ONE_WAY[owner_id])
	if look == Look.BRICK and not one_way:
		_draw_bricks()
	if wood:
		_draw_planks()
	var edge = COLOR_EDGE if not one_way or owner_id == 0 else COLORS_ONE_WAY[owner_id].lightened(0.5)
	if look == Look.DARK and not one_way:
		edge = edge.darkened(0.5)
	if wood:
		edge = COLOR_EDGE_WOOD
	if edges & 1:
		draw_rect(Rect2(0, 0, size.x, EDGE), edge)
	if edges & 2:
		draw_rect(Rect2(0, size.y - EDGE, size.x, EDGE), edge)
	if edges & 4:
		draw_rect(Rect2(0, 0, EDGE, size.y), edge)
	if edges & 8:
		draw_rect(Rect2(size.x - EDGE, 0, EDGE, size.y), edge)
	if background:
		draw_rect(Rect2(Vector2.ZERO, size), COLOR_DIM)


# Planks along it: a seam between rows of BRICK.y, and across each row every PLANK, every other
# row shifted by a third; a thin platform is one row.
func _draw_planks():
	var row = 0
	var y = 0.0
	while y < size.y:
		if y > 0.0:
			draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_GRAIN, 2.0)
		var x = PLANK / 3.0 if row % 2 == 1 else PLANK
		while x < size.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + BRICK.y, size.y)), COLOR_GRAIN, 2.0)
			x += PLANK
		y += BRICK.y
		row += 1


# Rows of bricks, every other row shifted by half a brick, cut off at the block's sides.
func _draw_bricks():
	var row = 0
	var y = BRICK.y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_MORTAR, 2.0)
		y += BRICK.y
	y = 0.0
	while y < size.y:
		var x = BRICK.x / 2.0 if row % 2 == 1 else BRICK.x
		while x < size.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + BRICK.y, size.y)), COLOR_MORTAR, 2.0)
			x += BRICK.x
		y += BRICK.y
		row += 1
