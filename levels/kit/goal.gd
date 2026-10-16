@tool
class_name KitGoal
extends Node2D
## The way out: once both players stand in it, the room is done and the next room loads: this
## goal's own `next_room` if it has one (a room with several ways out, like the showcase's
## selection room), else the room's. Place it at its top-left corner.

signal reached(goal)

const COLOR = Color(0.4, 1.0, 0.6)

@export var size = Vector2(96, 128):
	set(v):
		size = Vector2(maxf(v.x, 32.0), maxf(v.y, 32.0))
		queue_redraw()
## Written in it instead of GOAL, and shown when it's reached.
@export var label = "":
	set(v):
		label = v
		queue_redraw()
## Loaded instead of the room's `next_room`.
@export_file("*.tscn") var next_room = ""

var _done = false


func _physics_process(_delta):
	if Engine.is_editor_hint() or _done:
		return
	var players = get_tree().get_nodes_in_group("players")
	var zone = Rect2(global_position, size)
	if not players.is_empty() and players.all(func(p): return zone.has_point(p.global_position)):
		_done = true
		reached.emit(self)


func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(COLOR, 0.12))
	draw_rect(Rect2(Vector2.ZERO, size), Color(COLOR, 0.6), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(8, 20), label.to_upper() if label != "" else "GOAL", HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 14, Color(COLOR, 0.8))
