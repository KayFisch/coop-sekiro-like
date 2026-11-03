extends Node2D
## The tutorial's dummy (levels/tutorial/tutorial.gd): the try-out boss made to look like a training
## dummy. Drawn into his body (a child of it, under the halves that light up as he winds up), so
## his own colors still show through and every tell of his stays his: a sack of straw with its
## seams, a crossbar for his arms, a sack head with a target stitched on, and a plank he stands on.

const STRAW = Color(0.78, 0.66, 0.4, 0.32)  # over his body: its own color shows through
const SEAM = Color(0.35, 0.27, 0.15, 0.7)
const WOOD = Color(0.42, 0.29, 0.16)
const HEAD = Color(0.74, 0.63, 0.42)
const TARGET = Color(0.3, 0.2, 0.1)
const SEAMS = 5  # straw bands across the sack
const HEAD_RADIUS = 17.0
const BAR_REACH = 14.0  # px the crossbar sticks out on each side
const PLANK = Vector2(96.0, 8.0)

var body: ColorRect  # his, drawn into


func _ready():
	body.item_rect_changed.connect(queue_redraw)
	queue_redraw()


func _draw():
	var size = body.size
	draw_rect(Rect2(Vector2.ZERO, size), STRAW)
	for i in range(1, SEAMS + 1):
		var y = size.y * i / (SEAMS + 1.0)
		draw_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), SEAM, 1.5, true)
	# The crossbar, at his shoulders.
	draw_rect(Rect2(-BAR_REACH, size.y * 0.12, size.x + 2.0 * BAR_REACH, 7.0), WOOD)
	# The sack head on top, with a target stitched on.
	var head = Vector2(size.x / 2.0, -HEAD_RADIUS + 2.0)
	draw_circle(head, HEAD_RADIUS, HEAD)
	draw_arc(head, HEAD_RADIUS, 0.0, TAU, 24, SEAM, 1.5, true)
	draw_arc(head, HEAD_RADIUS * 0.5, 0.0, TAU, 20, TARGET, 2.0, true)
	draw_line(head - Vector2(HEAD_RADIUS * 0.7, 0.0), head + Vector2(HEAD_RADIUS * 0.7, 0.0), TARGET, 1.5, true)
	draw_line(head - Vector2(0.0, HEAD_RADIUS * 0.7), head + Vector2(0.0, HEAD_RADIUS * 0.7), TARGET, 1.5, true)
	# The plank he stands on.
	draw_rect(Rect2(size.x / 2.0 - PLANK.x / 2.0, size.y - PLANK.y, PLANK.x, PLANK.y), WOOD)
