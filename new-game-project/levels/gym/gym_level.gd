class_name GymLevel
extends Node2D
## Base for the movement test rooms (the gyms): builds the room from code in _build() (solid
## blocks, one-way ledges, labels, height marks and gap measures over a 32 px grid, checkpoints,
## targets), spawns the players, a following camera and the readout HUD, and puts anyone who
## falls out of the room back at the last checkpoint. No damage anywhere: these rooms are for
## feeling out the movement, not for failing.
## Coordinates are world px, y down; GROUND_Y is the floor's surface. Heights in labels are
## measured from the surface a player stands on to the thing (feet to ledge).

const PLAYER_SCENE = preload("res://actors/player/player.tscn")
const Player = preload("res://actors/player/player.gd")
const GymCameraScript = preload("res://levels/gym/gym_camera.gd")
const GymHudScript = preload("res://levels/gym/gym_hud.gd")

const GROUND_Y = 600.0
const PLAYER_HALF = 20.0  # half the player's body
const GRID = 32.0
const LEDGE_THICKNESS = 12.0
const CHECKPOINT_SIZE = Vector2(80, 320)  # the zone that sets it, standing on its floor
const RESPAWN_SPREAD = 60.0  # px between the players when put back
const SPIKE_HEIGHT = 18.0
const SPIKE_WIDTH = 16.0
const COLOR_SPIKES = Color(0.78, 0.32, 0.3)

const COLOR_BACKGROUND = Color(0.06, 0.06, 0.08)
const COLOR_GRID = Color(1, 1, 1, 0.035)
const COLOR_GRID_MAJOR = Color(1, 1, 1, 0.07)  # every 5 cells (160 px)
const COLOR_SOLID = Color(0.22, 0.22, 0.25)
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const COLOR_LEDGE = Color(0.32, 0.32, 0.36)
const COLOR_LABEL = Color(1, 1, 1, 0.8)
const COLOR_HINT = Color(1, 1, 1, 0.5)
const COLOR_MEASURE = Color(0.55, 0.8, 1.0, 0.6)
const COLOR_CHECKPOINT = Color(0.4, 1.0, 0.6)

var bounds = Rect2(0, -500, 3000, 1220)  # the room; set in _build() before placing anything
var players: Array = []
var respawn_point = Vector2(120, GROUND_Y - PLAYER_HALF)

var _checkpoints: Array = []  # {zone: Rect2, spawn: Vector2, flag: ColorRect}
var _measures: Array = []  # {from, to, text}: dimension lines, drawn by _overlay
var _marks: Array = []  # {x1, x2, y, text}: dashed height marks
var _spikes: Array = []  # Rect2: touching one puts you back at the checkpoint
var _overlay: Node2D


# --- For rooms to override ---

func room_name() -> String:
	return "GYM"


func player_count() -> int:
	return 1


# Build the room here with the helpers below.
func _build():
	pass


# Called after a player is put back at the checkpoint.
func _on_respawned(_player):
	pass


# --- Setup ---

func _ready():
	var background = ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = COLOR_BACKGROUND
	add_child(background)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_build()
	background.position = bounds.position
	background.size = bounds.size

	for id in range(1, player_count() + 1):
		var p = PLAYER_SCENE.instantiate()
		p.player_id = id
		if id == 2:
			p.player_color = Color(1, 0.55, 0.15)
			p.sword_color = Color(1, 0.8, 0.55)
		p.position = respawn_point + Vector2((id - 1) * RESPAWN_SPREAD, 0.0)
		add_child(p)
		players.append(p)

	var camera = GymCameraScript.new()
	camera.targets = players
	camera.bounds = bounds
	add_child(camera)
	camera.make_current()
	camera.snap()

	var hud = GymHudScript.new()
	hud.room_name = room_name()
	hud.players = players
	add_child(hud)
	_overlay.queue_redraw()


func _physics_process(_delta):
	for p in players:
		if p.global_position.y > bounds.end.y + PLAYER_HALF * 2.0:
			respawn(p)
		var box = Rect2(p.global_position - Vector2.ONE * PLAYER_HALF, Vector2.ONE * PLAYER_HALF * 2.0)
		for hazard in _spikes:
			if hazard.intersects(box) and not p.just_pogoed():
				Sfx.play("chip")
				respawn(p)
				break
		for cp in _checkpoints:
			if cp.zone.has_point(p.global_position) and respawn_point != cp.spawn:
				_activate_checkpoint(cp)


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		for p in players:
			respawn(p)


func respawn(p):
	p.global_position = respawn_point + Vector2((p.player_id - 1) * RESPAWN_SPREAD, 0.0)
	p.velocity = Vector2.ZERO
	p.interrupt_movement()
	p.refresh_air_moves()
	_on_respawned(p)


func _activate_checkpoint(cp):
	respawn_point = cp.spawn
	for other in _checkpoints:
		other.flag.color = Color(COLOR_CHECKPOINT, 0.35)
	cp.flag.color = COLOR_CHECKPOINT
	Sfx.play("chip", -8.0)


# --- Building helpers ---

# A solid block: top-left corner and size. Its top gets a bright edge.
func solid(x: float, y: float, w: float, h: float, color = COLOR_SOLID) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = Vector2(x + w / 2.0, y + h / 2.0)
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(w, h)
	body.add_child(shape)
	body.add_child(_rect(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h), color))
	body.add_child(_rect(Vector2(-w / 2.0, -h / 2.0), Vector2(w, 2.0), COLOR_EDGE))
	add_child(body)
	return body


# Floor from x1 to x2, down to the bottom of the room.
func ground(x1: float, x2: float, top = GROUND_Y) -> StaticBody2D:
	return solid(x1, top, x2 - x1, bounds.end.y - top)


# A block standing on the ground, `height` px tall: a pillar or step.
func pillar(x: float, w: float, height: float, floor_y = GROUND_Y) -> StaticBody2D:
	return solid(x, floor_y - height, w, height)


# A one-way ledge (jump up through it, S / stick down to drop) with its top at y.
func ledge(x: float, y: float, w: float) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.collision_layer = 8  # physics layer 4: the one-way platforms (see player.gd)
	body.collision_mask = 0
	body.position = Vector2(x + w / 2.0, y + LEDGE_THICKNESS / 2.0)
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(w, LEDGE_THICKNESS)
	shape.one_way_collision = true
	body.add_child(shape)
	body.add_child(_rect(Vector2(-w / 2.0, -LEDGE_THICKNESS / 2.0), Vector2(w, LEDGE_THICKNESS), COLOR_LEDGE))
	body.add_child(_rect(Vector2(-w / 2.0, -LEDGE_THICKNESS / 2.0), Vector2(w, 2.0), COLOR_EDGE))
	add_child(body)
	return body


func label(pos: Vector2, text: String, font_size = 14, color = COLOR_LABEL) -> Label:
	var l = Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.modulate = color
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# A station's heading and what it's for, above the ground at x.
func station(x: float, title: String, hint: String, y = GROUND_Y - 300.0):
	label(Vector2(x, y), title, 22)
	label(Vector2(x, y + 30.0), hint, 13, COLOR_HINT)


# A dimension line from `from` to `to` with its length (or `text`) written on it.
func measure(from: Vector2, to: Vector2, text = ""):
	_measures.append({"from": from, "to": to, "text": text if text != "" else "%d" % roundi(from.distance_to(to))})


# A dashed horizontal line at height y from x1 to x2, labeled at its right end.
func height_mark(x1: float, x2: float, y: float, text: String):
	_marks.append({"x1": x1, "x2": x2, "y": y, "text": text})


# Standing anywhere in the zone above (x, floor_y) makes this the respawn point.
func checkpoint(x: float, floor_y = GROUND_Y):
	var pole = _rect(Vector2(x - 2.0, floor_y - 60.0), Vector2(4, 60), Color(1, 1, 1, 0.4))
	add_child(pole)
	var flag = _rect(Vector2(x + 2.0, floor_y - 60.0), Vector2(22, 14), Color(COLOR_CHECKPOINT, 0.35))
	add_child(flag)
	var zone = Rect2(x - CHECKPOINT_SIZE.x / 2.0, floor_y - CHECKPOINT_SIZE.y, CHECKPOINT_SIZE.x, CHECKPOINT_SIZE.y)
	_checkpoints.append({"zone": zone, "spawn": Vector2(x, floor_y - PLAYER_HALF), "flag": flag})


# A strip of spikes from x1 to x2, points up with their base at `base_y` (or hanging down from
# it if `down`). Touching them puts you back at the checkpoint; a downslash bounces off them.
func spikes(x1: float, x2: float, base_y: float, down = false):
	var h = SPIKE_HEIGHT
	var zone = Rect2(x1, base_y if down else base_y - h, x2 - x1, h)
	_spikes.append(zone.grow(-3.0))
	var pogo = CharacterBody2D.new()  # what the sword hitboxes see (they pick up bodies like the boss)
	pogo.add_to_group("pogo")
	pogo.collision_layer = 4
	pogo.collision_mask = 0
	pogo.position = zone.get_center()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = zone.size
	pogo.add_child(shape)
	add_child(pogo)
	var teeth = Polygon2D.new()
	teeth.color = COLOR_SPIKES
	var points = PackedVector2Array()
	var tip = -h if not down else h
	var x = x1
	points.append(Vector2(x1, base_y))
	while x < x2:
		var w = minf(SPIKE_WIDTH, x2 - x)
		points.append(Vector2(x + w / 2.0, base_y + tip))
		points.append(Vector2(x + w, base_y))
		x += w
	teeth.polygon = points
	add_child(teeth)


# A sword target centered at pos (see target.gd).
func target(pos: Vector2, mode = GymTarget.Mode.DUMMY, caption = "") -> GymTarget:
	var t = GymTarget.new()
	t.mode = mode
	t.caption = caption
	t.position = pos
	add_child(t)
	return t


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# The grid, the dimension lines and the height marks, under everything else.
func _draw_overlay():
	var x = floorf(bounds.position.x / GRID) * GRID
	var i = 0
	while x <= bounds.end.x:
		_overlay.draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), COLOR_GRID_MAJOR if i % 5 == 0 else COLOR_GRID)
		x += GRID
		i += 1
	# Horizontal lines count up from the ground, so the major ones mark heights of 160, 320, ...
	var y = GROUND_Y
	i = 0
	while y >= bounds.position.y:
		_overlay.draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), COLOR_GRID_MAJOR if i % 5 == 0 else COLOR_GRID)
		y -= GRID
		i += 1
	var font = ThemeDB.fallback_font
	for m in _measures:
		var dir = (m.to - m.from).normalized()
		var tick = Vector2(-dir.y, dir.x) * 6.0
		_overlay.draw_line(m.from, m.to, COLOR_MEASURE, 1.5)
		_overlay.draw_line(m.from - tick, m.from + tick, COLOR_MEASURE, 1.5)
		_overlay.draw_line(m.to - tick, m.to + tick, COLOR_MEASURE, 1.5)
		var mid = (m.from + m.to) / 2.0
		_overlay.draw_string(font, mid + Vector2(-20, -6), m.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_MEASURE)
	for m in _marks:
		var dash = m.x1
		while dash < m.x2:
			_overlay.draw_line(Vector2(dash, m.y), Vector2(minf(dash + 8.0, m.x2), m.y), COLOR_MEASURE, 1.0)
			dash += 14.0
		_overlay.draw_string(font, Vector2(m.x2 + 6.0, m.y + 4.0), m.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_MEASURE)
