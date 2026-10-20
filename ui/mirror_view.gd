class_name MirrorView
extends CanvasLayer
## The mirrored screen (Moves "mirror_view", F1): the screen split along the floor. Above it the
## fight with P1, in light; below it the fight's reflection, upside down, with P2 in shadow (after
## the mirror scene in Gris). Only the picture changes: both players still stand on the one floor
## by the same rules, and the boss is one boss: he can't move his light and his shadow apart, the
## players can. Only his weapons may differ between the halves (Bifrons's blades, Moves
## "mirror_blades": each half shows the blades aimed at its player, see bifrons_swords.gd; the Heavy
## Hitter's weapon, a layer of it for each player, see hitter_weapon.gd). Each half leaves out the
## other player, so the two never cover each other; and they pass through each other
## (Player.own_half), there's nobody to bump into.
##
## Each half is a SubViewport on the level's world (the same World2D, a canvas transform of its
## own); the bottom one is shown flipped. Which half draws what is set by visibility layers: P1 and
## everything of theirs on LIGHT, P2's on SHADOW, the level's backdrop on SCENERY, which neither
## half draws (each has a background of its own). Switched off, everything is as it was.

# Visibility layers (bits of CanvasItem.visibility_layer and Viewport.canvas_cull_mask).
const WORLD = 1  # everything else: the boss, walls, sparks between blades
const LIGHT = 2  # P1, with their hands, sparks and afterimages
const SHADOW = 4  # P2, the same
const SCENERY = 8  # the level's backdrop

# How it looks.
const ZOOM = 0.85  # the room drawn this much smaller: his leap (200 px up) stays inside a half
const LIGHT_BODY = Color(0.92, 0.9, 0.85)  # P1: light...
const LIGHT_SWORD = Color(0.72, 0.7, 0.66)
const SHADOW_BODY = Color(0.07, 0.07, 0.09)  # ...P2: shadow
const SHADOW_SWORD = Color(0.3, 0.3, 0.34)
const LIGHT_TOP = Color(0.02, 0.02, 0.035)  # the light half: dark, as the room is now...
const LIGHT_FLOOR = Color(0.12, 0.12, 0.14)  # ...lighter toward the floor
const SHADOW_FLOOR = Color(0.93, 0.91, 0.86)  # the shadow half: pale paper, as the floor in Gris...
const SHADOW_BOTTOM = Color(0.78, 0.76, 0.71)  # ...greying away from the line
const LINE_COLOR = Color(0.55, 0.54, 0.5)  # the mirror line, where the floor is
const LINE_WIDTH = 2.0
# In the shadow half everything gets a dark outline, so silver blades and yellow telegraphs still
# read on the pale ground.
const OUTLINE_COLOR = Color(0.1, 0.1, 0.12)
const OUTLINE_WIDTH = 1.5  # px on screen
# The sync mode, bound (core/sync_bond.gd, Moves "sync_merge_view"): the two halves become one. The
# shadow joins the light half (with a pale outline there, to read on the dark), and the shadow half
# dims out of focus.
const MERGE_TIME = 0.5  # s
const MERGE_OUTLINE = Color(0.85, 0.83, 0.78)
const MERGE_DIM = Color(0.3, 0.3, 0.33)  # the shadow half, merged: its colors times this

const OUTLINE_SHADER = """
shader_type canvas_item;

uniform vec4 outline_color : source_color;
uniform float width = 1.5;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 reach = TEXTURE_PIXEL_SIZE * width;
	float a = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			a = max(a, texture(TEXTURE, UV + vec2(float(x), float(y)) * reach).a);
		}
	}
	COLOR = vec4(mix(outline_color.rgb, c.rgb, c.a), max(c.a, a * outline_color.a));
}
"""

@export var scenery: NodePath  # the level's backdrop, left out of both halves
@export var always_on = false  # whatever the switch says (the beat-runner is built for it)

var _halves = []  # top, bottom: {"viewport": SubViewport, "picture": TextureRect, "ground": TextureRect}
var _line: ColorRect
var _outline: ShaderMaterial
var _outline_light: ShaderMaterial  # the light half's, merged
var _merge = 0.0  # 0: two halves, 1: one (see MERGE_TIME)
var _colors = {}  # player -> [body, sword] from before the mirror
var _marks = {}  # player -> the Callable marking what they add later


func _ready():
	add_to_group("mirror_view")  # a boss that draws each half its own way finds it here
	layer = 1  # over the world, under the HUD (2) and the F1 panel (100)
	process_mode = Node.PROCESS_MODE_ALWAYS  # switched in the F1 panel, with the game paused
	Moves.changed.connect(_refresh)
	_refresh()


func _refresh():
	var on = always_on or Moves.on("mirror_view")
	if on != _halves.is_empty():
		return
	if on:
		_build()
	else:
		_tear_down()
	var backdrop = get_node_or_null(scenery)
	if backdrop:
		backdrop.visibility_layer = SCENERY if on else WORLD
	for p in get_tree().get_nodes_in_group("players"):
		_split(p, on)


# A player into their half (light or shadow), or back.
func _split(p, on: bool):
	var bit = WORLD
	if on:
		bit = LIGHT if p.player_id == 1 else SHADOW
		_colors[p] = [p.player_color, p.sword_color]
		if p.player_id == 1:
			p.paint(LIGHT_BODY, LIGHT_SWORD)
		else:
			p.paint(SHADOW_BODY, SHADOW_SWORD)
		_marks[p] = _mark.bind(bit)
		p.child_entered_tree.connect(_marks[p])
	else:
		if _colors.has(p):
			p.paint(_colors[p][0], _colors[p][1])
		if _marks.has(p) and p.child_entered_tree.is_connected(_marks[p]):
			p.child_entered_tree.disconnect(_marks[p])
	_mark(p, bit)
	p.own_half = on
	if not on:
		_colors.erase(p)
		_marks.erase(p)


# A node and all below it onto a visibility layer. Children that draw on their own (top_level:
# the player's hands, sparks, afterimages) don't follow their parent's layer, so each is set.
func _mark(node: Node, bit: int):
	if node is CanvasItem:
		node.visibility_layer = bit
	for child in node.get_children():
		_mark(child, bit)


func _build():
	_outline = ShaderMaterial.new()
	_outline.shader = Shader.new()
	_outline.shader.code = OUTLINE_SHADER
	_outline.set_shader_parameter("outline_color", OUTLINE_COLOR)
	_outline_light = ShaderMaterial.new()
	_outline_light.shader = _outline.shader
	_outline_light.set_shader_parameter("outline_color", MERGE_OUTLINE)
	for i in 2:
		var shadow = i == 1
		var ground = TextureRect.new()
		ground.texture = _gradient(SHADOW_FLOOR, SHADOW_BOTTOM) if shadow else _gradient(LIGHT_TOP, LIGHT_FLOOR)
		var viewport = SubViewport.new()
		viewport.world_2d = get_viewport().world_2d
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.gui_disable_input = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_cull_mask = WORLD | (SHADOW if shadow else LIGHT)
		var picture = TextureRect.new()
		picture.texture = viewport.get_texture()
		picture.flip_v = shadow
		if shadow:
			picture.material = _outline
		for rect in [ground, picture]:
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ground)
		add_child(viewport)
		add_child(picture)
		_halves.append({"viewport": viewport, "picture": picture, "ground": ground})
	_line = ColorRect.new()
	_line.color = LINE_COLOR
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)
	_layout()


func _tear_down():
	for half in _halves:
		for node in half.values():
			node.queue_free()
	_halves.clear()
	_line.queue_free()


# A vertical gradient, top color to bottom color.
func _gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var texture = GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray([top, bottom])
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 128
	return texture


func _process(_delta):
	if not _halves.is_empty():
		_layout()


# True while the halves are two (on, and not merged): each may draw a boss its own way (Columna
# Bifrons's blades, Moves "mirror_blades"; the Heavy Hitter's weapon).
func split() -> bool:
	return not _halves.is_empty() and _merge <= 0.0


# Both halves look at the same band of the room: from the floor up, as wide as the screen, around
# where the camera looks (and shaking with it). The bottom one is shown upside down, so the floor
# is the line between them.
func _layout():
	var screen = get_viewport().get_visible_rect().size  # in canvas units (1152 x 648)
	var pixels = Vector2(get_tree().root.size)
	var scale = pixels.y / screen.y  # canvas units to the window's pixels: a half is drawn sharp
	var half = Vector2(screen.x, screen.y / 2.0)
	var size = Vector2i((half * scale).round())
	var camera = get_viewport().get_camera_2d()
	var center_x = camera.global_position.x if camera else screen.x / 2.0
	var shake = camera.offset if camera else Vector2.ZERO
	var focus = Vector2(center_x, BaseBoss.ARENA_FLOOR_Y) + shake
	var k = ZOOM * scale
	var view = Transform2D(0.0, Vector2(k, k), 0.0, Vector2(size.x / 2.0, size.y) - focus * k)
	for i in _halves.size():
		var h = _halves[i]
		if h.viewport.size != size:
			h.viewport.size = size
		h.viewport.canvas_transform = view
		for rect in [h.ground, h.picture]:
			rect.position = Vector2(0.0, half.y * i)
			rect.size = half
	_outline.set_shader_parameter("width", OUTLINE_WIDTH * scale)
	_outline_light.set_shader_parameter("width", OUTLINE_WIDTH * scale)
	_merge_halves()
	_line.position = Vector2(0.0, half.y - LINE_WIDTH / 2.0)
	_line.size = Vector2(screen.x, LINE_WIDTH)


# Bound in the sync mode (with Moves "sync_merge_view"): the shadow comes up into the light half,
# and the shadow half dims away.
func _merge_halves():
	var rules = GameManager.rules
	var bound = Moves.on("sync_merge_view") and rules != null and rules.bond != null and rules.bond.bound
	_merge = move_toward(_merge, 1.0 if bound else 0.0, get_process_delta_time() / MERGE_TIME)
	var top = _halves[0]
	top.viewport.canvas_cull_mask = WORLD | LIGHT | (SHADOW if _merge > 0.0 else 0)
	top.picture.material = _outline_light if _merge > 0.0 else null
	var dim = Color.WHITE.lerp(MERGE_DIM, _merge)
	_halves[1].picture.modulate = dim
	_halves[1].ground.modulate = dim
