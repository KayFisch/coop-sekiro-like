extends Camera2D
## Follows the players around a gym: centered on them all, zooming out (down to MIN_ZOOM) to
## keep two players who drift apart both on screen, never showing past the room's bounds.
## shake() works like core/camera_shake.gd, so hits and launches still shake the view.

const FOLLOW = 8.0  # how quickly it catches up (per second)
const MARGIN = Vector2(300, 200)  # room kept around the players
const MIN_ZOOM = 0.55
const SHAKE_RETURN_TIME = 0.2

var targets: Array = []
var bounds = Rect2()

var _shake_tween: Tween


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func _process(delta):
	var goal = _goal()
	var t = 1.0 - exp(-FOLLOW * delta)
	global_position = global_position.lerp(goal[0], t)
	zoom = zoom.lerp(Vector2.ONE * goal[1], t)


# Jump straight to where it should be (on spawn).
func snap():
	var goal = _goal()
	global_position = goal[0]
	zoom = Vector2.ONE * goal[1]


# [center, zoom]
func _goal() -> Array:
	var live = targets.filter(func(p): return is_instance_valid(p))
	if live.is_empty():
		return [global_position, zoom.x]
	var box = Rect2(live[0].global_position, Vector2.ZERO)
	for p in live:
		box = box.expand(p.global_position)
	var view = get_viewport_rect().size
	var needed = box.size + MARGIN * 2.0
	var fit = minf(view.x / needed.x, view.y / needed.y)
	return [box.get_center(), clampf(fit, MIN_ZOOM, 1.0)]


func shake(strength = 5.0):
	if _shake_tween:
		_shake_tween.kill()
	offset = Vector2.from_angle(randf() * TAU) * strength
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, SHAKE_RETURN_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
