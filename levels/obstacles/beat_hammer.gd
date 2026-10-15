class_name BeatHammer
extends Clockwork
## A hammer that comes out of the ceiling and hits the floor exactly on its beats (`pattern`:
## counts 1-4 of the bar, shifted `offset` beats later). In the beat before, it draws up a little
## and glows; it falls in FALL_TIME, lies on the floor for HOLD_BEATS, then rises back over
## RISE_BEATS. It's a block as wide as its head reaching down from the ceiling, so once down it
## fills the corridor's height and can't be jumped over: you go under it between its beats.
## Touching it anywhere off its resting place puts you back at the checkpoint. Place it with its
## x at the hammer's middle and its y on the floor.

const HEAD_SIZE = Vector2(56, 40)
const FALL_TIME = 0.07  # s from the top of its draw-up to the floor: a slam, not a drop
const HOLD_BEATS = 0.5  # lies on the floor this long: half a beat after the hit is still deadly
const RISE_BEATS = 1.0  # back up to rest over a beat; it clears a player's head about a third of the way up
const REST_SHOW = 16.0  # px of it showing under the ceiling at rest
const DRAW_UP = 14.0  # px it draws up into the ceiling in the beat before its hit
const SHAKE = 3.0  # camera shake on the hit, for a hammer near the camera
const COLOR_HEAD = Color(0.42, 0.42, 0.47)
const COLOR_SHAFT = Color(0.3, 0.3, 0.34)
const COLOR_GLOW = Color(1.0, 0.55, 0.2)  # heating up in the beat before the hit
const COLOR_EDGE = Color(0.85, 0.87, 0.95)

var pattern = [1]
var offset = 0  # beats later than the pattern says (a wave of hammers: 0, 1, 2, 3)
var clearance = 120.0  # the corridor's height, floor to ceiling: the head fills it

var _height = 0.0  # the head's underside above the floor: 0 is down
var _glow = 0.0


func _ready():
	z_index = -1  # behind the ceiling, which hides the shaft and the draw-up
	Beat.beat.connect(_on_beat)
	_height = _rest_height()


# The head's underside above the floor at rest: tucked up under the ceiling.
func _rest_height() -> float:
	return clearance - REST_SHOW


func _on_beat(index: int):
	if Beat.plays_on(index, pattern, offset):
		play_near("hammer", -2.0)
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("shake") and cam.get_screen_center_position().distance_to(global_position) < 500.0:
			cam.shake(SHAKE)


func _physics_process(_delta):
	_update_height()
	queue_redraw()
	if _height >= _rest_height() - 0.5:
		return  # tucked away under the ceiling: nobody fits in there
	# The whole block from the ceiling down to the head's underside.
	var block = Rect2(global_position + Vector2(-HEAD_SIZE.x / 2.0, -clearance), Vector2(HEAD_SIZE.x, clearance - _height))
	for p in players():
		if block.intersects(player_box(p)):
			hit.emit(p)


func _update_height():
	var rest = _rest_height()
	if not Beat.running:
		_height = rest
		_glow = 0.0
		return
	var length = Beat.beat_length()
	var b = Beat.beats_at(Beat.time())
	var last = _impact_before(b)
	var next = _impact_after(b)
	var since = (b - last) * length
	var until = (next - b) * length
	var rising = rest * clampf((since - HOLD_BEATS * length) / (RISE_BEATS * length), 0.0, 1.0)
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
	for k in Beat.BEATS_PER_BAR + 1:
		if Beat.plays_on(n - k, pattern, offset):
			return n - k
	return -100.0


func _impact_after(b: float) -> float:
	var n = floori(b) + 1
	for k in Beat.BEATS_PER_BAR + 1:
		if Beat.plays_on(n + k, pattern, offset):
			return n + k
	return 100000.0


func _draw():
	var head_top = -_height - HEAD_SIZE.y
	var shaft_top = -clearance - DRAW_UP - 200.0  # hidden in the ceiling
	draw_rect(Rect2(-HEAD_SIZE.x / 2.0 + 4.0, shaft_top, HEAD_SIZE.x - 8.0, head_top - shaft_top), COLOR_SHAFT)
	var head = Rect2(-HEAD_SIZE.x / 2.0, head_top, HEAD_SIZE.x, HEAD_SIZE.y)
	draw_rect(head, COLOR_HEAD.lerp(COLOR_GLOW, _glow * 0.8))
	draw_rect(Rect2(head.position.x, head.end.y - 3.0, head.size.x, 3.0), COLOR_EDGE.lerp(COLOR_GLOW, _glow))
