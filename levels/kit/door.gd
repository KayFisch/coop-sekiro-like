@tool
class_name KitDoor
extends Node2D
## What a KitSwitch is wired to (the switch's `targets`). Switched on, a SOLID door opens and a
## PLATFORM (one-way, maybe one player's own) appears; `inverted` turns that round (a door that
## shuts, a platform that goes). With several switches wired to it, `needs` says whether any one
## of them does it, or only all of them together: two plates far apart, one for each of you.
## A solid door shutting on a player crushes them. Place it at its top-left corner.

signal hit(player)

enum Kind { SOLID, PLATFORM }

const COLOR_DOOR = Color(0.36, 0.33, 0.45)
const COLOR_BARS = Color(0.5, 0.46, 0.62)
const COLORS_PLATFORM = [Color(0.62, 0.62, 0.68), Color(0.25, 0.5, 1.0), Color(1.0, 0.55, 0.15)]  # both, P1, P2
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const OPEN_ALPHA = 0.5  # the outline of an open door, or of a platform that isn't there
const Player = preload("res://actors/player/player.gd")

@export_custom(PROPERTY_HINT_RANGE, "8,640,8,or_greater,suffix:px") var size = Vector2(32, 128):  # whole px
	set(v):
		size = Vector2(maxf(roundf(v.x), 4.0), maxf(roundf(v.y), 4.0))
		queue_redraw()
@export var kind = Kind.SOLID:
	set(v):
		kind = v
		queue_redraw()
## A platform's owner: who it carries.
@export_enum("Both", "P1", "P2") var owner_id = 0:
	set(v):
		owner_id = v
		queue_redraw()
@export_enum("Any switch", "All switches") var needs = 0
## Open (or there) until switched, instead.
@export var inverted = false:
	set(v):
		inverted = v
		queue_redraw()

var _switches: Array = []
var _active = false  # switched: open, or there
var _body: StaticBody2D


func _ready():
	_active = inverted
	if Engine.is_editor_hint():
		return
	_body = StaticBody2D.new()
	_body.collision_mask = 0
	_body.position = size / 2.0
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	shape.one_way_collision = kind == Kind.PLATFORM
	_body.add_child(shape)
	add_child(_body)
	_apply()


# Called by a switch wired to this, as the room starts.
func add_switch(s):
	_switches.append(s)


func _physics_process(_delta):
	if Engine.is_editor_hint() or _switches.is_empty():
		return
	var ons = _switches.filter(func(s): return s.on).size()
	var switched = ons == _switches.size() if needs == 1 else ons > 0
	if (switched != inverted) != _active:
		_active = switched != inverted
		_apply()


# Solid (closed door, or a platform there) or not.
func _blocking() -> bool:
	return not _active if kind == Kind.SOLID else _active


func _apply():
	var layer = 1 if kind == Kind.SOLID else KitRoom.platform_layer(owner_id)
	_body.collision_layer = 1 << (layer - 1) if _blocking() else 0
	if kind == Kind.SOLID and _blocking():
		var me = Rect2(global_position, size).grow(-2.0)
		for p in get_tree().get_nodes_in_group("players"):
			if me.intersects(Rect2(p.global_position - Player.BODY_SIZE / 2.0, Player.BODY_SIZE)):
				hit.emit(p)  # shut on them
	queue_redraw()


# The room starts over.
func reset_piece():
	if not Engine.is_editor_hint() and _active != inverted:
		_active = inverted
		_apply()


func _draw():
	var rect = Rect2(Vector2.ZERO, size)
	var blocking = _blocking() if not Engine.is_editor_hint() else (inverted if kind == Kind.PLATFORM else not inverted)
	if kind == Kind.PLATFORM:
		var c = COLORS_PLATFORM[owner_id]
		if blocking:
			draw_rect(rect, c.darkened(0.25))
			draw_rect(Rect2(0, 0, size.x, 2.0), COLOR_EDGE if owner_id == 0 else c.lightened(0.5))
		else:
			draw_rect(rect, Color(c, OPEN_ALPHA), false, 1.5)
		return
	if not blocking:
		draw_rect(rect, Color(COLOR_BARS, OPEN_ALPHA), false, 1.5)
		return
	draw_rect(rect, COLOR_DOOR)
	var x = 6.0
	while x < size.x - 2.0:
		draw_line(Vector2(x, 0), Vector2(x, size.y), COLOR_BARS, 2.0)
		x += 10.0
	var y = 6.0
	while y < size.y - 2.0:
		draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_BARS, 2.0)
		y += 32.0
