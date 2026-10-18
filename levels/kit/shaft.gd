@tool
class_name KitShaft
extends Node2D
## Two facing walls to wall-jump up, as wide as the room's tempo says (the wall gym's shafts):
##  WIDE    a beat's flight from wall to wall: too far for a wall jump's own flight, hold toward
##          the far wall.
##  NARROW  half as wide: twice as fast, no steering needed.
##  COOP    two wide ones side by side: too wide alone. Jump off together, meet in the middle
##          and press jump (a chimney clash): each is the other's far wall.
## The gap is a player's body (Player.BODY_SIZE.x) plus the ground a wall jump flies
## (WALL_JUMP_PUSH) in that many beats at the room's BPM: change the BPM and every shaft follows.
## The wall rhythm flies on the room's clock.
## Its position is the left wall's top-left corner (where it would be with `left_drop` 0); the
## walls stand `height` tall, on a floor there (put a KitBlock under it). Either wall can start
## lower (`left_drop`, `right_drop`), have a way in under it (`entrance`) and a ledge on top
## (`caps`).

enum Kind { WIDE, NARROW, COOP }
enum Side { NONE, LEFT, RIGHT }
enum Caps { NONE, LEFT, RIGHT, BOTH }

const CAP_THICKNESS = 12.0
const WIDE_BEATS = 1.0
const NARROW_BEATS = 0.5
const COLOR_SOLID = Color(0.22, 0.22, 0.25)
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const COLOR_LEDGE = Color(0.32, 0.32, 0.36)
const COLOR_MEASURE = Color(0.55, 0.8, 1.0, 0.8)
const Player = preload("res://actors/player/player.gd")

@export var kind = Kind.WIDE:
	set(v):
		kind = v
		queue_redraw()
@export_range(128, 1280, 16, "or_greater") var height = 640:
	set(v):
		height = v
		queue_redraw()
## How much lower the left wall's top is than the shaft's top.
@export_range(0, 640, 16, "or_greater") var left_drop = 0:
	set(v):
		left_drop = v
		queue_redraw()
## How much lower the right wall's top is.
@export_range(0, 640, 16, "or_greater") var right_drop = 0:
	set(v):
		right_drop = v
		queue_redraw()
@export_range(16, 160, 8) var wall_thickness = 40:
	set(v):
		wall_thickness = v
		queue_redraw()
## A way in under one wall: walk in, but no jumping through it.
@export var entrance = Side.NONE:
	set(v):
		entrance = v
		queue_redraw()
@export_range(48, 320, 8) var entrance_height = 56:
	set(v):
		entrance_height = v
		queue_redraw()
## One-way ledges on the walls' tops, reaching outward: the last jump flies over the top, and
## this catches you.
@export var caps = Caps.NONE:
	set(v):
		caps = v
		queue_redraw()
@export_range(32, 640, 16, "or_greater") var cap_length = 160:
	set(v):
		cap_length = v
		queue_redraw()
## A bright surface line on the walls' tops.
@export var top_edges = true:
	set(v):
		top_edges = v
		queue_redraw()
# Wall to wall, inside, for a kind at a tempo.
static func gap(of_kind: Kind, bpm: float) -> float:
	var beats = NARROW_BEATS if of_kind == Kind.NARROW else WIDE_BEATS
	var one = Player.BODY_SIZE.x + Player.WALL_JUMP_PUSH * beats * 60.0 / bpm
	return 2.0 * one if of_kind == Kind.COOP else one


func width() -> float:
	return gap(kind, _bpm())


func _bpm() -> float:
	var n = get_parent()
	while n:
		if n.has_method("start_over"):  # the KitRoom
			return n.bpm
		n = n.get_parent()
	return 150.0


func _process(_delta):
	if Engine.is_editor_hint():
		queue_redraw()  # follows the room's BPM


func _ready():
	if Engine.is_editor_hint():
		return
	for r in _walls():
		_solid(r, false)
	for r in _caps():
		_solid(r, true)


func _walls() -> Array:
	var w = width()
	var t = float(wall_thickness)
	var left_cut = entrance_height if entrance == Side.LEFT else 0.0
	var right_cut = entrance_height if entrance == Side.RIGHT else 0.0
	return [Rect2(0, left_drop, t, height - left_drop - left_cut), Rect2(t + w, right_drop, t, height - right_drop - right_cut)]


func _caps() -> Array:
	var r = []
	if caps in [Caps.LEFT, Caps.BOTH]:
		r.append(Rect2(-cap_length, left_drop, cap_length, CAP_THICKNESS))
	if caps in [Caps.RIGHT, Caps.BOTH]:
		r.append(Rect2(2.0 * wall_thickness + width(), right_drop, cap_length, CAP_THICKNESS))
	return r


func _solid(r: Rect2, one_way: bool):
	var body = StaticBody2D.new()
	body.collision_layer = 1 << (Player.PLATFORM_LAYER - 1) if one_way else 1
	body.collision_mask = 0
	body.position = r.get_center()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = r.size
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


func _draw():
	for r in _walls():
		draw_rect(r, COLOR_SOLID)
		if top_edges:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), COLOR_EDGE)
	for r in _caps():
		draw_rect(r, COLOR_LEDGE)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), COLOR_EDGE)
	var w = width()
	var y = height - 150.0
	draw_line(Vector2(wall_thickness, y), Vector2(wall_thickness + w, y), COLOR_MEASURE, 1.5)
	var beats = {Kind.WIDE: "1 beat", Kind.NARROW: "1/2 beat", Kind.COOP: "2 x 1 beat"}[kind]
	draw_string(ThemeDB.fallback_font, Vector2(wall_thickness + 4.0, y - 6.0), "%d · %s at %d BPM" % [roundi(w), beats, roundi(_bpm())],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_MEASURE)
