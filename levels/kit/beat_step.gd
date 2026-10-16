@tool
class_name KitBeatStep
extends Clockwork
## A one-way platform (jump up through it, down to drop) that is there only on some beats: on
## during the counts of its `pattern`, e.g. two sets taking turns, [1, 2] and [3, 4]. Off it's an
## outline you fall through; in its last beat before it goes it blinks.
## An owner (P1 or P2) makes it carry only that player, on that player's own physics layer, in
## that player's color: player colors only ever say *who*.
## Place it at its top-left corner. (A platform a switch turns on is a KitDoor.)

const THICKNESS = 12.0
const BLINK_HZ = 10.0  # blinks this often in its last beat
const OUTLINE_WIDTH = 1.5
const COLORS = [Color(0.62, 0.62, 0.68), Color(0.25, 0.5, 1.0), Color(1.0, 0.55, 0.15)]  # both, P1, P2
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const OFF_ALPHA = 0.55  # the outline when it's off

static var _sounded_beat = -1  # one appearing sound per beat, however many steps appear

## Counts it's there on, over `bars` bars.
@export var pattern: Array[int] = [1, 2]
@export_range(1, 4) var bars = 1
@export var offset = 0
## 0: carries both players; 1 or 2: only that one.
@export_enum("Both", "P1", "P2") var owner_id = 0:
	set(v):
		owner_id = v
		queue_redraw()
@export_range(16, 640, 8, "or_greater") var width = 80.0:
	set(v):
		width = v
		queue_redraw()

var _body: StaticBody2D
var _on = false


func _ready():
	if in_editor():
		return
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


func _on_at(b: float) -> bool:
	if not clock_running():
		return true
	return plays(floori(b + 0.0001), pattern, offset, bars)


func _physics_process(_delta):
	var b = beats_now()
	var on = _on_at(b)
	if not in_editor():
		var n = floori(b + 0.0001)
		if on and not _on and Beat.running and _sounded_beat != n:
			_sounded_beat = n
			play_near("step_on", -12.0)
		_body.collision_layer = 1 << (KitRoom.platform_layer(owner_id) - 1) if on else 0
	_on = on
	queue_redraw()


func _draw():
	var rect = Rect2(0, 0, width, THICKNESS)
	var c = COLORS[owner_id]
	var last_beat = clock_running() and not _on_at(beats_now() + 1.0)
	if not _on or (last_beat and fmod(beats_now() * beat_length() * BLINK_HZ, 1.0) > 0.5):
		draw_rect(rect, Color(c, OFF_ALPHA), false, OUTLINE_WIDTH)
	else:
		draw_rect(rect, c.darkened(0.25))
		draw_rect(Rect2(0, 0, width, 2.0), COLOR_EDGE if owner_id == 0 else c.lightened(0.5))
	draw_ruler(Vector2(0, THICKNESS + 6.0), pattern, offset, bars)
