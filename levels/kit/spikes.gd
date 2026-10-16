@tool
class_name KitSpikes
extends Node2D
## A strip of spikes: touching them kills. Their position is one end of the base; they run
## `length` along it (right, or down for the ones facing sideways) and point `facing`. Put them
## on a KitBlock. A downslash bounces off them if F1 "Pogo off targets, spikes" is on.

signal hit(player)

enum Facing { UP, DOWN, LEFT, RIGHT }

const HEIGHT = 18.0
const TOOTH = 16.0
const FORGIVE = 3.0  # px each side the teeth's hitbox is smaller than they look
const COLOR = Color(0.78, 0.32, 0.3)
const Player = preload("res://actors/player/player.gd")

@export_range(16, 2048, 16) var length = 96.0:
	set(v):
		length = v
		queue_redraw()
@export var facing = Facing.UP:
	set(v):
		facing = v
		queue_redraw()


func zone() -> Rect2:
	match facing:
		Facing.DOWN:
			return Rect2(0, 0, length, HEIGHT)
		Facing.LEFT:
			return Rect2(-HEIGHT, 0, HEIGHT, length)
		Facing.RIGHT:
			return Rect2(0, 0, HEIGHT, length)
	return Rect2(0, -HEIGHT, length, HEIGHT)


func _ready():
	if Engine.is_editor_hint():
		return
	# What a downslash's pogo box finds (see _check_pogo() in player.gd).
	var pogo = CharacterBody2D.new()
	pogo.add_to_group("pogo")
	pogo.collision_layer = 4
	pogo.collision_mask = 0
	pogo.position = zone().get_center()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = zone().size
	pogo.add_child(shape)
	add_child(pogo)


func _physics_process(_delta):
	if Engine.is_editor_hint():
		return
	var hazard = Rect2(global_position + zone().position, zone().size).grow(-FORGIVE)
	for p in get_tree().get_nodes_in_group("players"):
		if hazard.intersects(Rect2(p.global_position - Player.BODY_SIZE / 2.0, Player.BODY_SIZE)) and not p.just_pogoed():
			hit.emit(p)


func _draw():
	var points = PackedVector2Array()
	var along = Vector2.DOWN if facing in [Facing.LEFT, Facing.RIGHT] else Vector2.RIGHT
	var out = {Facing.UP: Vector2.UP, Facing.DOWN: Vector2.DOWN, Facing.LEFT: Vector2.LEFT, Facing.RIGHT: Vector2.RIGHT}[facing]
	points.append(Vector2.ZERO)
	var d = 0.0
	while d < length:
		var w = minf(TOOTH, length - d)
		points.append(along * (d + w / 2.0) + out * HEIGHT)
		points.append(along * (d + w))
		d += w
	draw_colored_polygon(points, COLOR)
