class_name GymTarget
extends CharacterBody2D  # like the bosses: a body the sword hitboxes (Area2D) pick up
## A sword target for the gyms. Player blades hit it like a boss (it's in the "boss" group, on
## the boss's physics layer), and it says what hit it: SLASH, UPSLASH or DASH-SLASH, the damage,
## and whether the player was rising from a launch.
##  DUMMY: floats each hit up as text.
##  BELL: rings and stays lit once struck (a height you reached).
##  SWITCH: stays on once struck and emits activated (e.g. opens a way up).
##  LANTERN: a small hanging thing to pogo off (a downslash bounces you); it glows when struck.

signal struck(player, amount, kind)
signal activated

enum Mode { DUMMY, BELL, SWITCH, LANTERN }

const SIZE = {Mode.DUMMY: Vector2(34, 56), Mode.BELL: Vector2(26, 26), Mode.SWITCH: Vector2(22, 36), Mode.LANTERN: Vector2(24, 24)}
const COLOR = {Mode.DUMMY: Color(0.6, 0.5, 0.38), Mode.BELL: Color(0.55, 0.55, 0.6), Mode.SWITCH: Color(0.45, 0.35, 0.6), Mode.LANTERN: Color(0.95, 0.6, 0.25)}
const COLOR_ON = Color(1.0, 0.82, 0.3)
const FLOAT_TIME = 0.8

var mode = Mode.DUMMY
var caption = ""
var is_on = false

var _body: ColorRect


func _ready():
	add_to_group("boss")
	collision_layer = 4  # where player sword hitboxes look (the boss's layer)
	collision_mask = 0
	var size = SIZE[mode]
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	add_child(shape)
	_body = ColorRect.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = size
	_body.position = -size / 2.0
	_body.pivot_offset = size / 2.0
	_body.color = COLOR[mode]
	if mode == Mode.BELL:
		_body.rotation = PI / 4.0
	add_child(_body)
	if caption != "":
		var l = Label.new()
		l.text = caption
		l.add_theme_font_size_override("font_size", 12)
		l.modulate = Color(1, 1, 1, 0.6)
		l.position = Vector2(size.x / 2.0 + 8.0, -8.0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)


# Called by a player's blade (see _process_attack() in player.gd).
func take_damage(amount: float, source = null):
	var kind = "HIT"
	if source:
		if source._dash_slash:
			kind = "DASH-SLASH"
		elif source._swing_kind == source.Swing.UPSLASH:
			kind = "UPSLASH"
		elif source._swing_kind == source.Swing.DOWNSLASH:
			kind = "DOWNSLASH"
		else:
			kind = "SLASH"
		if source.is_launching():
			kind += " (launched)"
		elif source.movement_state() == "relay boost":
			kind += " (relayed)"
	struck.emit(source, amount, kind)
	_body.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(_body, "scale", Vector2.ONE, 0.15)
	match mode:
		Mode.DUMMY:
			_float_text("%s %d" % [kind, roundi(amount)])
			Sfx.play("chip", -4.0)
		Mode.BELL:
			if not is_on:
				is_on = true
				_body.color = COLOR_ON
				_float_text("reached: " + kind)
			Sfx.play("parry", -4.0)
		Mode.LANTERN:
			_body.color = COLOR_ON
			create_tween().tween_property(_body, "color", COLOR[mode], 0.4)
		Mode.SWITCH:
			if not is_on:
				is_on = true
				_body.color = COLOR_ON
				_float_text("ON")
				Sfx.play("parry_strong")
				activated.emit()


func _float_text(text: String):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.top_level = true
	add_child(l)
	l.global_position = global_position + Vector2(-40, -SIZE[mode].y / 2.0 - 24.0)
	var tween = l.create_tween().set_parallel()
	tween.tween_property(l, "global_position:y", l.global_position.y - 40.0, FLOAT_TIME)
	tween.tween_property(l, "modulate:a", 0.0, FLOAT_TIME)
	tween.chain().tween_callback(l.queue_free)
