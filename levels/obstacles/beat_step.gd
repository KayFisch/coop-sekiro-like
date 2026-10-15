class_name BeatStep
extends Clockwork
## A one-way platform (like GymLevel.ledge(): jump up through it, down to drop) that is there
## only on some beats. Off it's a faint outline you fall through, on it's filled; in its last
## beat before it goes it blinks.
##  CLOCK: on during the counts in `pattern` (1-4, shifted `offset` beats), e.g. two sets taking
##         turns, [1, 2] and [3, 4].
##  CALL:  off until a beat bell calls it (call_until()), then on until the time it says.
## An owner (1 or 2) makes it carry only that player, on that player's own physics layer
## (GymLevel.OWN_PLATFORM_LAYERS), in that player's color: player colors only ever say *who*.
## Place it at its top-left corner.

enum Mode { CLOCK, CALL }

const THICKNESS = 12.0
const BLINK_HZ = 10.0  # blinks this often in its last beat
const OUTLINE_WIDTH = 1.5
const COLOR_BOTH = Color(0.62, 0.62, 0.68)
const COLOR_P1 = Color(0.25, 0.5, 1.0)  # the players' colors (player.tscn, GymLevel)
const COLOR_P2 = Color(1.0, 0.55, 0.15)
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const OFF_ALPHA = 0.35  # the outline when it's off

static var _sounded_beat = -1  # one appearing sound per beat, however many steps appear

var mode = Mode.CLOCK
var pattern = [1, 2]
var offset = 0
var owner_id = 0  # 0: carries both players; 1 or 2: only that one
var width = 80.0

var _body: StaticBody2D
var _on = false
var _called_until = -100.0  # CALL: on until this Beat time


func _ready():
	_body = StaticBody2D.new()
	_body.collision_layer = 0
	_body.collision_mask = 0
	_body.position = Vector2(width / 2.0, THICKNESS / 2.0)
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(width, THICKNESS)
	shape.one_way_collision = true
	_body.add_child(shape)
	add_child(_body)


func color() -> Color:
	return [COLOR_BOTH, COLOR_P1, COLOR_P2][owner_id]


# Called by a bell: on from now until Beat time `until` (an earlier call never shortens it).
func call_until(until: float):
	_called_until = maxf(_called_until, until)


# Whether it's there at Beat time t.
func _on_at(t: float) -> bool:
	if not Beat.running:
		return mode == Mode.CLOCK
	if mode == Mode.CALL:
		return t < _called_until
	return Beat.plays_on(floori(Beat.beats_at(t) + 0.0001), pattern, offset)


func _physics_process(_delta):
	var on = _on_at(Beat.time())
	var n = Beat.current_beat()
	if on and not _on and Beat.running and _sounded_beat != n:
		_sounded_beat = n
		play_near("step_on", -12.0)
	_on = on
	var layer = GymLevel.OWN_PLATFORM_LAYERS.get(owner_id, Player.PLATFORM_LAYER)
	_body.collision_layer = 1 << (layer - 1) if on else 0
	queue_redraw()


func _draw():
	var rect = Rect2(0, 0, width, THICKNESS)
	var c = color()
	if not _on:
		draw_rect(rect, Color(c, OFF_ALPHA), false, OUTLINE_WIDTH)
		return
	var last_beat = Beat.running and not _on_at(Beat.time() + Beat.beat_length())
	if last_beat and fmod(Beat.time() * BLINK_HZ, 1.0) > 0.5:
		draw_rect(rect, Color(c, OFF_ALPHA), false, OUTLINE_WIDTH)
		return
	draw_rect(rect, c.darkened(0.25))
	draw_rect(Rect2(0, 0, width, 2.0), COLOR_EDGE if owner_id == 0 else c.lightened(0.5))
