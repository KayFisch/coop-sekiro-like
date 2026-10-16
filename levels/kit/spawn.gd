@tool
class_name KitSpawn
extends Node2D
## Where a player starts the room, and starts over when either of you dies. Put its position on
## the floor, where the player's feet go. One for P1, one for P2.

const Player = preload("res://actors/player/player.gd")
const COLORS = [Color(0.25, 0.5, 1.0), Color(1.0, 0.55, 0.15)]

@export_enum("P1", "P2") var player = 0:
	set(v):
		player = v
		queue_redraw()


func player_id() -> int:
	return player + 1


func _draw():
	if not Engine.is_editor_hint():
		return
	var size = Player.BODY_SIZE
	draw_rect(Rect2(Vector2(-size.x / 2.0, -size.y), size), Color(COLORS[player], 0.6))
	draw_rect(Rect2(Vector2(-size.x / 2.0, -size.y), size), COLORS[player], false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-9, -size.y - 6), "P%d" % player_id(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLORS[player])
