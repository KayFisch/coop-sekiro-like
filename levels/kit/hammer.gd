@tool
class_name KitHammer
extends Clockwork
## A hammer coming out of the ceiling that hits the floor exactly on its beats. In the beat
## before, it draws up a little and glows; it falls in FALL_TIME, lies on the floor for
## `hold_beats`, then rises back over `rise_beats`. It's a block as wide as its head reaching
## down from the ceiling, so once down it fills the corridor and can't be jumped over: you go
## under it between its beats. Touching it anywhere off its resting place kills.
## Place it with its position on the floor, in the hammer's middle; `clearance` is how far up
## the ceiling is (put a KitBlock there).

const HEAD_HEIGHT = 40.0  # the heavy end at the bottom
const FALL_TIME = 0.07  # s from the top of its draw-up to the floor: a slam, not a drop
const REST_SHOW = 16.0  # px of it showing under the ceiling at rest
const DRAW_UP = 14.0  # px it draws up into the ceiling in the beat before its hit
const SHAKE = 3.0  # camera shake on the hit, for a hammer near the camera
const COLOR_HEAD = Color(0.42, 0.42, 0.47)
const COLOR_SHAFT = Color(0.3, 0.3, 0.34)
const COLOR_GLOW = Color(1.0, 0.55, 0.2)  # heating up in the beat before the hit
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const COLOR_REACH = Color(1.0, 0.4, 0.3, 0.25)  # the editor: where it comes down

## Counts it hits on, over `bars` bars: [1] once a bar, [1, 3] twice, [1, 2, 3, 4] every beat.
@export var pattern: Array[int] = [1]:
	set(v):
		pattern = v
		queue_redraw()
## How many bars the pattern spans (2: counts 1-8).
@export_range(1, 4) var bars = 1
## Beats later than the pattern says (a wave of hammers: 0, 1, 2, 3).
@export var offset = 0
@export_range(24, 320, 8) var width = 56.0:
	set(v):
		width = v
		queue_redraw()
## Floor to ceiling where it hangs.
@export_range(64, 400, 8) var clearance = 120.0:
	set(v):
		clearance = v
		queue_redraw()
## Lies on the floor this long after the hit (still deadly).
@export_range(0.1, 2.0, 0.05) var hold_beats = 0.5
## Back up to rest over this long; it clears a player's head about a third of the way.
@export_range(0.25, 3.0, 0.05) var rise_beats = 1.0

var _height = 0.0  # the head's underside above the floor: 0 is down
var _glow = 0.0


func _ready():
	_height = _rest_height()
	if not in_editor():
		Beat.beat.connect(_on_beat)


func _rest_height() -> float:
	return clearance - REST_SHOW


func _on_beat(index: int):
	if plays(index, pattern, offset, bars):
		play_near("hammer", -2.0)
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("shake") and cam.get_screen_center_position().distance_to(global_position) < 500.0:
			cam.shake(SHAKE)


func _physics_process(_delta):
	_update_height()
	queue_redraw()
	if in_editor() or _height >= _rest_height() - 0.5:
		return  # tucked away under the ceiling: nobody fits in there
	# The whole block from the ceiling down to the head's underside.
	var block = Rect2(global_position + Vector2(-width / 2.0, -clearance), Vector2(width, clearance - _height))
	for p in players():
		if block.intersects(player_box(p)):
			hit.emit(p)


func _update_height():
	var rest = _rest_height()
	if not clock_running() or pattern.is_empty():
		_height = rest
		_glow = 0.0
		return
	var length = beat_length()
	var b = beats_now()
	var since = (b - _impact_before(b)) * length
	var until = (_impact_after(b) - b) * length
	var rising = rest * clampf((since - hold_beats * length) / (rise_beats * length), 0.0, 1.0)
	var top = rest + DRAW_UP
	_glow = 0.0
	if until <= FALL_TIME:
		var k = 1.0 - until / FALL_TIME
		_height = top * (1.0 - k * k)  # accelerating into the floor
		_glow = 1.0
	elif until <= length:
		# The beat before: draw up and heat up.
		var w = smoothstep(0.0, 1.0, 1.0 - (until - FALL_TIME) / (length - FALL_TIME))
		_height = lerpf(rising, top, w)
		_glow = w
	else:
		_height = rising


# The last hit at or before beat count b, and the next one after it.
func _impact_before(b: float) -> float:
	var n = floori(b)
	for k in 4 * bars + 1:
		if plays(n - k, pattern, offset, bars):
			return n - k
	return -100.0


func _impact_after(b: float) -> float:
	var n = floori(b) + 1
	for k in 4 * bars + 1:
		if plays(n + k, pattern, offset, bars):
			return n + k
	return 100000.0


func _draw():
	if in_editor():
		_update_height()
		draw_rect(Rect2(-width / 2.0, -clearance, width, clearance), COLOR_REACH)
	# Only what hangs below the ceiling shows; the rest is up inside it.
	var ceiling = -clearance
	var head_top = -_height - HEAD_HEIGHT
	if head_top > ceiling:
		draw_rect(Rect2(-width / 2.0 + 4.0, ceiling, width - 8.0, head_top - ceiling), COLOR_SHAFT)
	var head = Rect2(-width / 2.0, maxf(head_top, ceiling), width, -_height - maxf(head_top, ceiling))
	draw_rect(head, COLOR_HEAD.lerp(COLOR_GLOW, _glow * 0.8))
	draw_rect(Rect2(head.position.x, head.end.y - 3.0, head.size.x, 3.0), COLOR_EDGE.lerp(COLOR_GLOW, _glow))
	draw_ruler(Vector2(-width / 2.0, 8.0), pattern, offset, bars)
