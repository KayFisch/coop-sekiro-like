@tool
class_name KitRoom
extends Node2D
## A room for two, like Celeste's: a passage you get through together, or you both start over.
## Build it in the Godot editor from the kit's pieces (levels/kit/, see docs/level_kit.md) as
## children of this node: KitSpawn (one per player), KitBlock, KitSpikes, KitSwitch + KitDoor,
## KitHammer, KitPendulum, KitBeatStep, KitCannon, KitElevator, KitShaft, KitText, KitGoal. F6 plays
## the open room.
## When either player dies (an obstacle, spikes, falling out the bottom), both go back to their
## spawns and the room's switches and doors start over; the clock (Beat) runs on. R does the
## same. Both in the goal: done, and `next_room` loads.

const PLAYER_SCENE = preload("res://actors/player/player.tscn")
const Player = preload("res://actors/player/player.gd")
const GymCameraScript = preload("res://levels/gym/gym_camera.gd")

const VIEW = Vector2(1152, 648)  # one screen
const GRID = 32.0
const FALL_MARGIN = 40.0  # px below the room's bottom that counts as fallen out
const NEXT_ROOM_DELAY = 1.5  # s from reaching the goal to the next room
const FLASH_TIME = 0.25  # the screen flashes when you start over
const BACKDROP_Z = -100  # the background and grid's draw layer: under background blocks (KitBlock.BACKGROUND_Z)
const COLOR_BACKGROUND = Color(0.06, 0.06, 0.08)
const COLOR_GRID = Color(1, 1, 1, 0.035)
const COLOR_GRID_MAJOR = Color(1, 1, 1, 0.07)  # every 5 cells (160 px)
const COLOR_BOUNDS = Color(1, 1, 1, 0.5)
const COLOR_P2 = Color(1, 0.55, 0.15)
const COLOR_P2_SWORD = Color(1, 0.8, 0.55)
const COLOR_TEXT = Color(1, 1, 1, 0.85)
const COLOR_DONE = Color(0.4, 1.0, 0.6)

## Shown at the top.
@export var title = "ROOM"
## The room's tempo: hammers, pendulums, steps and the shafts' widths follow it.
@export_range(60, 240, 1) var bpm = 150.0:
	set(v):
		bpm = v
		queue_redraw()
## The room's size from its top-left corner (this node's position). One screen is 1152 x 648;
## bigger rooms scroll.
@export_custom(PROPERTY_HINT_RANGE, "32,2304,8,or_greater,suffix:px") var size = VIEW:  # whole px
	set(v):
		size = Vector2(maxf(roundf(v.x), GRID), maxf(roundf(v.y), GRID))
		queue_redraw()
		if _backdrop:
			_backdrop.queue_redraw()
## Loaded once both players reach the goal (unless the goal has a `next_room` of its own).
@export_file("*.tscn") var next_room = ""
## The music (Beat.TRACKS), in time with the clock; it plays on into a next room with the same.
@export_enum("none", "arcade_psytrance") var music: String = "none"

var players: Array = []
var deaths = 0

var _cleared = false
var _last_kill_frame = -1
var _deaths_label: Label
var _flash: ColorRect
var _backdrop: Node2D  # draws the background and grid, under everything


# The physics layer of one-way platforms carrying both (0), only P1 (1) or only P2 (2). The
# room puts each player's own layer into their collision mask, so the player needn't know them.
static func platform_layer(owner_id: int) -> int:
	return [Player.PLATFORM_LAYER, GymLevel.OWN_PLATFORM_LAYERS[1], GymLevel.OWN_PLATFORM_LAYERS[2]][owner_id]


func _ready():
	_backdrop = Node2D.new()
	_backdrop.z_index = BACKDROP_Z
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop, false, INTERNAL_MODE_FRONT)  # internal: never saved into the scene
	if Engine.is_editor_hint():
		return
	Beat.start(bpm, self, "" if music == "none" else music)
	var pieces = _descendants(self)
	for n in pieces:
		if n.has_signal("hit"):
			n.hit.connect(kill)
		if n.has_signal("reached"):
			n.reached.connect(_on_goal)
	_spawn_players(pieces)
	var camera = GymCameraScript.new()
	camera.targets = players
	camera.bounds = Rect2(global_position, size)
	add_child(camera)
	camera.make_current()
	camera.snap()
	_build_hud()


func _descendants(node: Node) -> Array:
	var found = []
	for c in node.get_children():
		found.append(c)
		found.append_array(_descendants(c))
	return found


func _spawn_players(pieces: Array):
	for id in [1, 2]:
		var p = PLAYER_SCENE.instantiate()
		p.player_id = id
		if id == 2:
			p.player_color = COLOR_P2
			p.sword_color = COLOR_P2_SWORD
		p.global_position = _spawn_point(id, pieces)
		add_child(p)
		p.set_collision_mask_value(GymLevel.OWN_PLATFORM_LAYERS[id], true)
		players.append(p)


# Where player `id` starts: their KitSpawn's feet, raised to the body's middle.
func _spawn_point(id: int, pieces = null) -> Vector2:
	for n in (pieces if pieces != null else _descendants(self)):
		if n.has_method("player_id") and n.player_id() == id:  # a KitSpawn
			return n.global_position + Vector2(0, -Player.BODY_SIZE.y / 2.0)
	return global_position + Vector2(64.0 + 60.0 * id, size.y - 120.0)  # no spawn: somewhere


func _physics_process(_delta):
	if Engine.is_editor_hint():
		return
	for p in players:
		# Dropping through (down) lets go of the one-way platforms: of one's own ones too.
		p.set_collision_mask_value(GymLevel.OWN_PLATFORM_LAYERS[p.player_id], p.get_collision_mask_value(Player.PLATFORM_LAYER))
		if p.global_position.y > global_position.y + size.y + FALL_MARGIN:
			kill(p)


func _unhandled_input(event):
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		start_over()


# One of you died: you both start over.
func kill(_player):
	if _cleared or Engine.get_physics_frames() == _last_kill_frame:
		return  # one start-over per frame, however many things hit
	_last_kill_frame = Engine.get_physics_frames()
	deaths += 1
	Sfx.play("hurt", -4.0)
	start_over()


# Both back to their spawns; the switches, doors and held pendulums start over. The clock runs on.
func start_over():
	for p in players:
		p.set_clashing(false)
		p.global_position = _spawn_point(p.player_id)
		p.velocity = Vector2.ZERO
		p.interrupt_movement()
		p.refresh_dash()
	get_tree().call_group("kit_reset", "reset_piece")
	if _deaths_label:
		_deaths_label.text = "deaths %d" % deaths
	if _flash:
		_flash.modulate.a = 0.35
		create_tween().tween_property(_flash, "modulate:a", 0.0, FLASH_TIME)


func _on_goal(goal):
	_cleared = true
	Sfx.play("big_bell", 0.0)
	var t = Beat.time()
	var next = goal.next_room if goal.next_room != "" else next_room
	var text = goal.label.to_upper() if goal.label != "" else "%s  ·  done\n%d:%04.1f  ·  %d deaths" % [title, floori(t / 60.0), fmod(t, 60.0), deaths]
	var done = _hud_label(Vector2.ZERO, text, 30)
	done.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	done.modulate = COLOR_DONE
	if next != "":
		get_tree().create_timer(NEXT_ROOM_DELAY).timeout.connect(func(): get_tree().change_scene_to_file(next))
	else:
		done.text += "\n\nEsc: back to the menu"


# --- HUD ---

var _hud: CanvasLayer


func _build_hud():
	_hud = CanvasLayer.new()
	add_child(_hud)
	_hud_label(Vector2(16, 10), title, 20)
	_hud_label(Vector2(16, 38), "R: start over · F1: movement switches · M: click · Esc: menu", 12).modulate = Color(1, 1, 1, 0.55)
	_deaths_label = _hud_label(Vector2(16, 58), "deaths 0", 14)
	var display = BeatDisplay.new()
	display.position = Vector2(VIEW.x - 230.0, 14.0)
	_hud.add_child(display)
	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_flash)


func _hud_label(pos: Vector2, text: String, font_size: int) -> Label:
	var l = Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.modulate = COLOR_TEXT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


# The background and the grid, on the backdrop: under every piece, background blocks too.
func _draw_backdrop():
	var room = Rect2(Vector2.ZERO, size)
	_backdrop.draw_rect(room, COLOR_BACKGROUND)
	var i = 0
	var x = 0.0
	while x <= size.x:
		_backdrop.draw_line(Vector2(x, 0), Vector2(x, size.y), COLOR_GRID_MAJOR if i % 5 == 0 else COLOR_GRID)
		x += GRID
		i += 1
	# Horizontal lines count up from the floor (the room's bottom), so the major ones mark heights of 160, 320, ...
	i = 0
	var y = size.y
	while y >= 0.0:
		_backdrop.draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_GRID_MAJOR if i % 5 == 0 else COLOR_GRID)
		y -= GRID
		i += 1


# In the editor, the room's bounds and its title.
func _draw():
	var room = Rect2(Vector2.ZERO, size)
	if Engine.is_editor_hint():
		draw_rect(room, COLOR_BOUNDS, false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(4, -8), "%s · %d BPM · %d x %d" % [title, roundi(bpm), roundi(size.x), roundi(size.y)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_BOUNDS)
