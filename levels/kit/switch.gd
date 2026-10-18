@tool
class_name KitSwitch
extends Node2D
## A switch wired to doors (`targets`: KitDoors; the editor draws the wires).
##  STRIKE: hit with the blade, like a boss. PLATE: a plate on the floor, pressed by standing on it.
##  BALL: a target, hit by a KitCannon's ball (and by nothing else).
## `who`: anyone, or only P1 or only P2 (a P1 plate ignores P2, a P2 lamp ignores P1's blade, a
## P2 target counts only a ball P2 parried last).
## `mode`:
##  TOGGLE  each strike / each step onto it flips it.
##  ONCE    on for good once triggered.
##  TIMED   on for `timed_bars` bars (a plate: after you step off), struck again: from then.
##  HOLD    a plate: on while someone stands on it. (A struck one acts as TIMED.)
## `on_the_one`: a strike counts only on the 1 (within ON_ONE_WINDOW); off it, a dull clack and
## the switch is out of tune until after the next 1, so mashing gets nothing. TIMED then runs
## from that 1. Floats how far off the strike was, in ms.
## Put a plate's position on the floor, a struck one's or a target's at its middle.

signal changed(on)

enum Trigger { STRIKE, PLATE, BALL }
enum Mode { TOGGLE, ONCE, TIMED, HOLD }

const ON_ONE_WINDOW = 0.1  # s either side of the 1
const LAMP_SIZE = 26.0
const PLATE_SIZE = Vector2(64, 8)
const TARGET_RADIUS = 26.0  # a ball touching this counts
const COLOR_OFF = Color(0.5, 0.5, 0.56)
const COLOR_ON = Color(1.0, 0.82, 0.3)
const COLOR_DETUNED = Color(0.3, 0.28, 0.3)
const COLORS_WHO = [Color(1, 1, 1, 0.5), Color(0.25, 0.5, 1.0), Color(1.0, 0.55, 0.15)]
const COLOR_WIRE = Color(1.0, 0.82, 0.3, 0.45)
const Player = preload("res://actors/player/player.gd")

@export var trigger = Trigger.STRIKE:
	set(v):
		trigger = v
		queue_redraw()
@export_enum("Anyone", "P1", "P2") var who = 0:
	set(v):
		who = v
		queue_redraw()
@export var mode = Mode.TOGGLE
@export_range(1, 8) var timed_bars = 1
@export var on_the_one = false
## The KitDoors it opens (or platforms it makes appear).
@export var targets: Array[NodePath] = []:
	set(v):
		targets = v
		queue_redraw()

var on = false

var _until = -100.0  # TIMED: on until this Beat time
var _detuned_until = -100.0
var _pressed = false  # a plate: someone on it last frame
var _flash = 0.0


# What the blade hits (it looks for a body in the "boss" group, see _process_attack() in player_sword.gd).
class StrikeBox extends CharacterBody2D:
	var switch

	func take_damage(_amount: float, source = null):
		switch._struck(source)


func _ready():
	add_to_group("kit_reset")
	if Engine.is_editor_hint():
		set_process(true)
		return
	for path in targets:
		var door = get_node_or_null(path)
		if door and door.has_method("add_switch"):
			door.add_switch(self)
	if trigger == Trigger.BALL:
		add_to_group("kit_ball_targets")
	if trigger == Trigger.STRIKE:
		var box = StrikeBox.new()
		box.switch = self
		box.add_to_group("boss")
		box.collision_layer = 4  # where player sword hitboxes look (the boss's layer)
		box.collision_mask = 0
		var shape = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2.ONE * LAMP_SIZE
		box.add_child(shape)
		add_child(box)


func _process(delta):
	if Engine.is_editor_hint():
		return  # it redraws itself when changed in the editor (its setters)
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _physics_process(_delta):
	if Engine.is_editor_hint():
		return
	if trigger == Trigger.PLATE:
		_update_plate()
	elif mode in [Mode.TIMED, Mode.HOLD] and on and Beat.time() >= _until:
		_set_on(false)


func _update_plate():
	var plate = Rect2(global_position + Vector2(-PLATE_SIZE.x / 2.0, -PLATE_SIZE.y - 2.0), PLATE_SIZE + Vector2(0, 4))
	var pressed = false
	for p in get_tree().get_nodes_in_group("players"):
		var box = Rect2(p.global_position - Player.BODY_SIZE / 2.0, Player.BODY_SIZE)
		if (who == 0 or p.player_id == who) and p.is_on_floor() and box.intersects(plate):
			pressed = true
	var stepped_on = pressed and not _pressed
	_pressed = pressed
	match mode:
		Mode.HOLD:
			_set_on(pressed)
		Mode.TIMED:
			if pressed:
				_until = Beat.time() + Beat.bar_length() * timed_bars
			_set_on(pressed or Beat.time() < _until)
		Mode.ONCE:
			if stepped_on:
				_set_on(true)
		Mode.TOGGLE:
			if stepped_on:
				_set_on(not on)


# A KitCannon's ball asks.
func ball_touches(point: Vector2, radius: float) -> bool:
	return global_position.distance_to(point) <= TARGET_RADIUS + radius


func ball_hit(ball):
	_struck(ball)


func _struck(source):
	if source == null or not Beat.running:
		return
	if who != 0 and source.player_id != who:
		Sfx.play("bell_dull", -4.0)
		return
	var t = Beat.time()
	var start = t
	if on_the_one:
		var off = Beat.offset_to_downbeat(t)
		_float_text("%+d ms" % roundi(off * 1000.0))
		if t < _detuned_until or absf(off) > ON_ONE_WINDOW:
			Sfx.play("bell_dull", -2.0)
			if t >= _detuned_until:
				var next_one = (floori(Beat.beats_at(t) / Beat.BEATS_PER_BAR) + 1) * Beat.BEATS_PER_BAR
				_detuned_until = Beat.beat_time(next_one) + ON_ONE_WINDOW
			return
		start = t - off + ON_ONE_WINDOW  # from the 1, and its window: a late but good strike on the next keeps it
		Sfx.play("bell", -3.0)
	else:
		Sfx.play("parry", -4.0)
	_flash = 0.15
	match mode:
		Mode.TOGGLE:
			_set_on(not on)
		Mode.ONCE:
			_set_on(true)
		_:
			_until = start + Beat.bar_length() * timed_bars
			_set_on(true)


func _set_on(v: bool):
	if v == on:
		return
	on = v
	changed.emit(on)
	if trigger == Trigger.PLATE:
		Sfx.play("step_on", -8.0)


# The room starts over.
func reset_piece():
	_until = -100.0
	_detuned_until = -100.0
	_pressed = false
	if on:
		on = false
		changed.emit(false)


func _float_text(text: String):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.top_level = true
	add_child(l)
	l.global_position = global_position + Vector2(-30, -LAMP_SIZE - 20.0)
	var tween = l.create_tween().set_parallel()
	tween.tween_property(l, "global_position:y", l.global_position.y - 30.0, 0.8)
	tween.tween_property(l, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(l.queue_free)


func _draw():
	var detuned = not Engine.is_editor_hint() and Beat.time() < _detuned_until
	var color = COLOR_DETUNED if detuned else (COLOR_ON if on else COLOR_OFF)
	color = color.lerp(Color.WHITE, _flash / 0.15 * 0.6)
	if trigger == Trigger.PLATE:
		draw_rect(Rect2(-PLATE_SIZE.x / 2.0, -PLATE_SIZE.y + (3.0 if _pressed else 0.0), PLATE_SIZE.x, PLATE_SIZE.y), color)
		draw_rect(Rect2(-PLATE_SIZE.x / 2.0 - 4.0, -2.0, PLATE_SIZE.x + 8.0, 2.0), COLORS_WHO[who])
	elif trigger == Trigger.BALL:
		draw_circle(Vector2.ZERO, TARGET_RADIUS, color)
		draw_circle(Vector2.ZERO, TARGET_RADIUS * 0.62, COLOR_DETUNED)
		draw_circle(Vector2.ZERO, TARGET_RADIUS * 0.3, color)
		draw_arc(Vector2.ZERO, TARGET_RADIUS, 0.0, TAU, 32, COLORS_WHO[who], 2.0)
		if on_the_one:
			draw_string(ThemeDB.fallback_font, Vector2(-4, 5), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.7))
	else:
		var s = LAMP_SIZE / sqrt(2.0)
		var diamond = PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
		draw_colored_polygon(diamond, color)
		diamond.append(diamond[0])
		draw_polyline(diamond, COLORS_WHO[who], 2.0)
		if on_the_one:
			draw_string(ThemeDB.fallback_font, Vector2(-4, 5), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.7))
	# The time left on a timed one, as a shrinking bar.
	if not Engine.is_editor_hint() and on and mode in [Mode.TIMED, Mode.HOLD] and _until > Beat.time():
		var left = clampf((_until - Beat.time()) / (Beat.bar_length() * timed_bars), 0.0, 1.0)
		draw_rect(Rect2(-LAMP_SIZE / 2.0, LAMP_SIZE / 2.0 + 6.0, LAMP_SIZE * left, 3.0), COLOR_ON)
	if Engine.is_editor_hint():
		for path in targets:
			var door = get_node_or_null(path)
			if door:
				_draw_wire(door.global_position + (door.size / 2.0 if "size" in door else Vector2.ZERO))


func _draw_wire(to_global: Vector2):
	var to = to_global - global_position
	var length = to.length()
	var d = 0.0
	while d < length:
		draw_line(to * (d / length), to * (minf(d + 8.0, length) / length), COLOR_WIRE, 2.0)
		d += 14.0
	draw_circle(to, 4.0, COLOR_WIRE)
