@tool
class_name KitShaft
extends Node2D
## Two facing walls to wall-jump up, as wide as the room's tempo says (the wall gym's shafts):
##  WIDE    a beat's flight from wall to wall: too far for a wall jump's own flight, hold toward
##          the far wall.
##  NARROW  half as wide: twice as fast, no steering needed.
##  COOP    two wide ones side by side: too wide alone. Jump off together, meet in the middle
##          and press jump (a chimney clash): each is the other's far wall.
## The gap is a player's body (Player.BODY_SIZE.x) plus the ground a wall jump flies
## (WALL_JUMP_PUSH) in that many beats at the room's BPM: change the BPM and every shaft follows.
## A room with a shaft switches on what wall jumps need (F1: wall, wall jump, chimney clash for
## COOP, wall rhythm if `rhythm`) while it runs, and ticks a Metronome at its BPM.
## Its position is the left wall's top-left corner; the walls stand `height` tall, on a floor
## there (put a KitBlock under it).

enum Kind { WIDE, NARROW, COOP }

const WALL = 40.0  # a wall's thickness
const ENTRANCE = 56.0  # the gap under the left wall: walk in, but no jumping through it
const CAP = 160.0  # a one-way ledge on top of each wall, reaching out: the last jump flies over the top, and this catches you
const WIDE_BEATS = 1.0
const NARROW_BEATS = 0.5
const COLOR_SOLID = Color(0.22, 0.22, 0.25)
const COLOR_EDGE = Color(0.85, 0.87, 0.95)
const COLOR_LEDGE = Color(0.32, 0.32, 0.36)
const COLOR_MEASURE = Color(0.55, 0.8, 1.0, 0.8)
const Player = preload("res://actors/player/player.gd")

@export var kind = Kind.WIDE:
	set(v):
		kind = v
		queue_redraw()
@export_range(128, 3200, 16) var height = 640.0:
	set(v):
		height = v
		queue_redraw()
## A way in under the left wall.
@export var entrance = true:
	set(v):
		entrance = v
		queue_redraw()
## One-way ledges on the walls' tops, reaching outward.
@export var caps = true:
	set(v):
		caps = v
		queue_redraw()
## Wall jumps judged against hitting the wall (F1 "wall rhythm").
@export var rhythm = true


# Wall to wall, inside, for a kind at a tempo.
static func gap(of_kind: Kind, bpm: float) -> float:
	var beats = NARROW_BEATS if of_kind == Kind.NARROW else WIDE_BEATS
	var one = Player.BODY_SIZE.x + Player.WALL_JUMP_PUSH * beats * 60.0 / bpm
	return 2.0 * one if of_kind == Kind.COOP else one


func width() -> float:
	return gap(kind, _bpm())


# The F1 switches it needs: key -> value.
func needed_moves() -> Dictionary:
	var needed = {"wall": "slide", "wall_jump": true}
	if kind == Kind.COOP:
		needed["chimney_clash"] = true
	if rhythm:
		needed["wall_rhythm"] = true
	return needed


func _bpm() -> float:
	var n = get_parent()
	while n:
		if n.has_method("start_over"):  # the KitRoom
			return n.bpm
		n = n.get_parent()
	return 150.0


func _process(_delta):
	if Engine.is_editor_hint():
		queue_redraw()  # follows the room's BPM


func _ready():
	if Engine.is_editor_hint():
		return
	for r in _walls():
		_solid(r, false)
	if caps:
		for r in _caps():
			_solid(r, true)


func _walls() -> Array:
	var w = width()
	return [Rect2(0, 0, WALL, height - (ENTRANCE if entrance else 0.0)), Rect2(WALL + w, 0, WALL, height)]


func _caps() -> Array:
	return [Rect2(-CAP, 0, CAP, 12.0), Rect2(WALL + width() + WALL, 0, CAP, 12.0)]


func _solid(r: Rect2, one_way: bool):
	var body = StaticBody2D.new()
	body.collision_layer = 1 << (Player.PLATFORM_LAYER - 1) if one_way else 1
	body.collision_mask = 0
	body.position = r.get_center()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = r.size
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


func _draw():
	for r in _walls():
		draw_rect(r, COLOR_SOLID)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), COLOR_EDGE)
	if caps:
		for r in _caps():
			draw_rect(r, COLOR_LEDGE)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), COLOR_EDGE)
	var w = width()
	var y = height - 150.0
	draw_line(Vector2(WALL, y), Vector2(WALL + w, y), COLOR_MEASURE, 1.5)
	var beats = {Kind.WIDE: "1 beat", Kind.NARROW: "1/2 beat", Kind.COOP: "2 x 1 beat"}[kind]
	draw_string(ThemeDB.fallback_font, Vector2(WALL + 4.0, y - 6.0), "%d · %s at %d BPM" % [roundi(w), beats, roundi(_bpm())],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_MEASURE)
