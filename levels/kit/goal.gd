@tool
class_name KitGoal
extends Node2D
## The way out: once both players stand in it, the room is done (and its `next_room` loads).
## Place it at its top-left corner.

signal reached

const COLOR = Color(0.4, 1.0, 0.6)

@export var size = Vector2(96, 128):
	set(v):
		size = Vector2(maxf(v.x, 32.0), maxf(v.y, 32.0))
		queue_redraw()

var _done = false


func _physics_process(_delta):
	if Engine.is_editor_hint() or _done:
		return
	var players = get_tree().get_nodes_in_group("players")
	var zone = Rect2(global_position, size)
	if not players.is_empty() and players.all(func(p): return zone.has_point(p.global_position)):
		_done = true
		reached.emit()


func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(COLOR, 0.12))
	draw_rect(Rect2(Vector2.ZERO, size), Color(COLOR, 0.6), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(8, 20), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(COLOR, 0.8))
