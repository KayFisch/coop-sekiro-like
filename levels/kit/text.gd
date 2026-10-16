@tool
class_name KitText
extends Node2D
## A note written on the room's wall: a hint, a title, a "jump here". Shows in the editor and in
## the game, behind the players. Place it at its first line's top-left corner (or the middle,
## with `align` CENTER, the right end with RIGHT).

const OUTLINE = 4

@export_multiline var text = "Text":
	set(v):
		text = v
		queue_redraw()
@export_range(8, 64, 1) var font_size = 14:
	set(v):
		font_size = v
		queue_redraw()
@export var color = Color(1, 1, 1, 0.6):
	set(v):
		color = v
		queue_redraw()
## Lines longer than this wrap (0: only where you break them).
@export_range(0, 1152, 1, "or_greater", "suffix:px") var width = 0:
	set(v):
		width = v
		queue_redraw()
@export_enum("Left", "Center", "Right") var align = 0:
	set(v):
		align = v
		queue_redraw()


func _draw():
	var font = ThemeDB.fallback_font
	var w = width if width > 0 else -1
	var x = 0.0
	if align != 0:
		# draw_multiline_string aligns inside the width: give it one, around the position.
		w = width if width > 0 else ceili(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		x = -w / 2.0 if align == 1 else -w
	var pos = Vector2(x, font.get_ascent(font_size))
	var h_align = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][align]
	draw_multiline_string_outline(font, pos, text, h_align, w, font_size, -1, OUTLINE, Color(0, 0, 0, color.a))
	draw_multiline_string(font, pos, text, h_align, w, font_size, -1, color)
