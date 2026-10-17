@tool
extends EditorPlugin
## Handles in the 2D view to resize the selected level kit piece by dragging, snapped to SNAP:
## a piece with a `size` (KitBlock, KitDoor, KitGoal, KitRoom) gets one on each corner and side,
## and the left and top ones move it too, so the opposite side stays where it is; a piece with a
## `width` gets one on each end (WIDTH_PIECES). Hold Alt to drag without snapping. Ctrl+Z undoes
## a drag. The pieces are found by their properties and scripts, not their class names, so this
## compiles without the kit.

const SNAP = 8.0  # px, the same steps as the size sliders
const MIN_SIZE = 8.0  # px, the smallest a side can get
const HANDLE = 8.0  # px on screen, a handle's side
const GRAB = 10.0  # px on screen around a handle that still grabs it
const COLOR_HANDLE = Color(1, 1, 1)
const COLOR_HOVER = Color(1.0, 0.82, 0.3)
const COLOR_OUTLINE = Color(0.1, 0.1, 0.12)
const COLOR_LABEL = Color(1, 1, 1, 0.9)

# Pieces with a `width`: script -> [where x 0 is ("left": their left end, "center": their
# middle), the y their handles sit at (local px)].
const WIDTH_PIECES = {
	"res://levels/kit/elevator.gd": ["left", 10.0],  # the platform's middle (THICKNESS 20)
	"res://levels/kit/beat_step.gd": ["left", 6.0],  # THICKNESS 12
	"res://levels/kit/hammer.gd": ["center", -8.0],  # just above the floor it stands on
}

var _node: Node2D
var _drag = Vector2.ZERO  # the handle being dragged: x, y each -1 (left/top), 0, 1 (right/bottom); ZERO: none
var _hover = Vector2.ZERO
var _from_size  # the piece's size (or width) and position when the drag started, for undo
var _from_position = Vector2.ZERO


func _handles(object) -> bool:
	return _mode(object) != ""


func _edit(object):
	_end_drag(false)
	_node = object if object is Node2D and _handles(object) else null
	update_overlays()


func _make_visible(visible: bool):
	if not visible:
		_end_drag(false)
		_node = null
	update_overlays()


# "size", "left", "center" (see WIDTH_PIECES), or "" for a node this doesn't resize.
func _mode(object) -> String:
	if not object is Node2D or object.get_script() == null:
		return ""
	var path = object.get_script().resource_path
	if WIDTH_PIECES.has(path):
		return WIDTH_PIECES[path][0]
	if path.begins_with("res://levels/kit/") and object.get("size") is Vector2:
		return "size"
	return ""


# The piece's own px to the 2D view's (screen) px.
func _to_screen() -> Transform2D:
	return _node.get_viewport_transform() * _node.get_global_transform()


# The handles: [which (see _drag), where in the piece's own px].
func _handle_points() -> Array:
	var mode = _mode(_node)
	if mode == "size":
		var s: Vector2 = _node.size
		var out = []
		for y in [-1, 0, 1]:
			for x in [-1, 0, 1]:
				if x != 0 or y != 0:
					out.append([Vector2(x, y), Vector2((x + 1) / 2.0 * s.x, (y + 1) / 2.0 * s.y)])
		return out
	var w = float(_node.width)
	var y = WIDTH_PIECES[_node.get_script().resource_path][1]
	var left = 0.0 if mode == "left" else -w / 2.0
	return [[Vector2(-1, 0), Vector2(left, y)], [Vector2(1, 0), Vector2(left + w, y)]]


func _handle_at(screen: Vector2) -> Vector2:
	var xf = _to_screen()
	for h in _handle_points():
		var p = xf * h[1]
		if absf(screen.x - p.x) <= GRAB and absf(screen.y - p.y) <= GRAB:
			return h[0]
	return Vector2.ZERO


func _forward_canvas_draw_over_viewport(overlay: Control):
	if not is_instance_valid(_node) or not _node.is_inside_tree():
		return
	var xf = _to_screen()
	for h in _handle_points():
		var p = xf * h[1]
		var r = Rect2(p - Vector2.ONE * HANDLE / 2.0, Vector2.ONE * HANDLE)
		overlay.draw_rect(r.grow(1.0), COLOR_OUTLINE)
		overlay.draw_rect(r, COLOR_HOVER if h[0] == _drag or (_drag == Vector2.ZERO and h[0] == _hover) else COLOR_HANDLE)
	if _drag != Vector2.ZERO:  # the size, next to the handle being dragged
		var text = "%d x %d" % [_node.size.x, _node.size.y] if _mode(_node) == "size" else "%d" % _node.width
		for h in _handle_points():
			if h[0] == _drag:
				var font = overlay.get_theme_default_font()
				overlay.draw_string_outline(font, xf * h[1] + Vector2(12, -10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, COLOR_OUTLINE)
				overlay.draw_string(font, xf * h[1] + Vector2(12, -10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_LABEL)


func _forward_canvas_gui_input(event) -> bool:
	if not is_instance_valid(_node) or not _node.is_inside_tree():
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var h = _handle_at(event.position)
			if h == Vector2.ZERO:
				return false
			_drag = h
			_from_size = _node.size if _mode(_node) == "size" else _node.width
			_from_position = _node.position
			update_overlays()
			return true
		if _drag != Vector2.ZERO:
			_end_drag(true)
			return true
		return false
	if event is InputEventMouseMotion:
		if _drag == Vector2.ZERO:
			var h = _handle_at(event.position)
			if h != _hover:
				_hover = h
				update_overlays()
			return false
		_drag_to(_to_screen().affine_inverse() * event.position, not event.alt_pressed)
		update_overlays()
		return true
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and _drag != Vector2.ZERO:
		_end_drag(false)  # back to where it was
		return true
	return false


# The dragged handle to `at` (the piece's own px): its sides move there, snapped in the world.
func _drag_to(at: Vector2, snap: bool):
	var mode = _mode(_node)
	var origin = _node.global_position
	var g = at + origin  # world px (the kit pieces aren't rotated or scaled)
	if snap:
		g = g.snapped(Vector2.ONE * SNAP)
	if mode == "center":
		_node.width = maxf(absf(g.x - origin.x) * 2.0, MIN_SIZE)
		return
	if mode == "left":
		var right = origin.x + float(_node.width)
		if _drag.x > 0:
			_node.width = maxf(g.x - origin.x, MIN_SIZE)
		else:
			var left = minf(g.x, right - MIN_SIZE)
			_node.global_position.x = left
			_node.width = right - left
		return
	var rect = Rect2(origin, _node.size)
	var s = rect.size
	var pos = rect.position
	if _drag.x > 0:
		s.x = maxf(g.x - pos.x, MIN_SIZE)
	elif _drag.x < 0:
		pos.x = minf(g.x, rect.end.x - MIN_SIZE)
		s.x = rect.end.x - pos.x
	if _drag.y > 0:
		s.y = maxf(g.y - pos.y, MIN_SIZE)
	elif _drag.y < 0:
		pos.y = minf(g.y, rect.end.y - MIN_SIZE)
		s.y = rect.end.y - pos.y
	_node.global_position = pos
	_node.size = s


# Done dragging: keep it as one undo step, or put it back.
func _end_drag(keep: bool):
	if _drag == Vector2.ZERO:
		return
	_drag = Vector2.ZERO
	if not is_instance_valid(_node):
		return
	var prop = "size" if _mode(_node) == "size" else "width"
	var to_size = _node.get(prop)
	var to_position = _node.position
	_node.set(prop, _from_size)
	_node.position = _from_position
	if keep and (to_size != _from_size or to_position != _from_position):
		var ur = get_undo_redo()
		ur.create_action("Resize %s" % _node.name)
		ur.add_do_property(_node, prop, to_size)
		ur.add_do_property(_node, "position", to_position)
		ur.add_undo_property(_node, prop, _from_size)
		ur.add_undo_property(_node, "position", _from_position)
		ur.commit_action()
	update_overlays()
