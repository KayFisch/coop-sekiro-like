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
##
## THE ONE RULE for the bosses (half_bit()): what is aimed at a player (a blade, a layer of a
## weapon, a hand, an image, a spell) is drawn in that player's half while the halves are two; with
## them one (merged) or the view off, in both, as on the one-sided screen. Every boss asks this, none
## its own way.
##
## MERGED (the sync mode, bound, Moves "sync_merge_view"): the halves become one, in one movement
## with the pair's (SyncBond.flow(): same start, length and curve). The mirror line sinks from the
## middle to a strip along the bottom (Tuning "sync_merge_strip"), the light half taking the rest at
## the same scale; P2 flows up through the line, their reflection draining into it as they fill
## the light half from the feet up. Merged, P2 is in the light half only; the strip shows the
## world's reflection, dimmed, and no player. Nobody is shown twice.

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
# MERGED (see above; how long it takes: Tuning "sync_merge_time", core/sync_bond.gd): P2 in the
# light half with a pale outline, to read on the dark; the strip dimmed out of focus.
const MERGE_OUTLINE = Color(0.85, 0.83, 0.78)
const MERGE_DIM = Color(0.3, 0.3, 0.33)  # the strip, merged: its colors times this
const FLOW_HEIGHT = 110.0  # px above P2's feet the flow fills (or drains) over the merge: body and sabre

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

var _halves = []  # top, bottom: {"frame": Control, "viewport": SubViewport, "picture": TextureRect, "ground": TextureRect}
var _line: ColorRect
var _outline: ShaderMaterial
var _outline_light: ShaderMaterial  # P2's in the light half, merged
var _merge = 0.0  # 0: two halves, 1: one (eased: SyncBond.flow())
# P2 flowing up through the line, merging: a view of the SHADOW layer alone, shown twice, each
# clipped to a band along the line: rising in the light half, draining in the strip.
var _flow: SubViewport
var _rise: Control  # the band in the light half, and its picture
var _drain: Control  # the band in the strip, and its picture
var _colors = {}  # player -> [body, sword] from before the mirror
var _marks = {}  # player -> the Callable marking what they add later


# Its numbers on F2 (core/tuning.gd collects them): the sync rules' page, tab "sync mode".
static func tuning_entries() -> Array:
	return [
		{"page": "sync", "title": "Sync Rules", "scenes": ["levels/threshold/"], "header": "SYNC MODE: MERGED (MIRRORED SCREEN)", "tab": "sync mode"},
		{"key": "sync_merge_strip", "label": "merged: the shadow half a strip this high (px)", "default": 125.0, "step": 5.0},
	]


# THE ONE RULE (see above): the visibility layer for what is aimed at that player (1 or 2).
static func half_bit(player_id: int) -> int:
	if not is_split():
		return WORLD
	return LIGHT if player_id == 1 else SHADOW


# True while the halves are two: on, and not merged (the view in this scene's tree, if any).
static func is_split() -> bool:
	var tree = Engine.get_main_loop() as SceneTree
	var view = tree.get_first_node_in_group("mirror_view") if tree else null
	return view != null and view.split()


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
		var frame = _band()  # the half: what's drawn in it is clipped to it
		var ground = _rect()
		ground.texture = _gradient(SHADOW_FLOOR, SHADOW_BOTTOM) if shadow else _gradient(LIGHT_TOP, LIGHT_FLOOR)
		var viewport = _view(WORLD | (SHADOW if shadow else LIGHT))
		var picture = _rect(viewport, shadow)
		if shadow:
			picture.material = _outline
		frame.add_child(ground)
		frame.add_child(picture)
		add_child(viewport)
		add_child(frame)
		_halves.append({"frame": frame, "viewport": viewport, "picture": picture, "ground": ground})
		if not shadow:
			_flow = _view(SHADOW)
			add_child(_flow)
			_rise = _band()
			_rise.add_child(_rect(_flow, false))
			_rise.get_child(0).material = _outline_light
			add_child(_rise)  # over the light half
	_drain = _band()
	_drain.add_child(_rect(_flow, true))
	_drain.get_child(0).material = _outline
	add_child(_drain)  # over the strip
	_line = ColorRect.new()
	_line.color = LINE_COLOR
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)
	_layout()


# A view of the level's world drawing the visibility layers in `mask`.
func _view(mask: int) -> SubViewport:
	var viewport = SubViewport.new()
	viewport.world_2d = get_viewport().world_2d
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_cull_mask = mask
	return viewport


# A band of the screen; what's in it is cut off at its edges.
func _band() -> Control:
	var band = Control.new()
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return band


# A picture (of `viewport`, upside down if `flipped`; else for a gradient).
func _rect(viewport: SubViewport = null, flipped = false) -> TextureRect:
	var rect = TextureRect.new()
	if viewport:
		rect.texture = viewport.get_texture()
	rect.flip_v = flipped
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _tear_down():
	for half in _halves:
		half.frame.queue_free()
		half.viewport.queue_free()
	_halves.clear()
	for node in [_flow, _rise, _drain, _line]:
		node.queue_free()


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
# is the line between them. Merging, the line sinks; the scale stays.
func _layout():
	var screen = get_viewport().get_visible_rect().size  # in canvas units (1152 x 648)
	var pixels = Vector2(get_tree().root.size)
	var scale = pixels.y / screen.y  # canvas units to the window's pixels: a half is drawn sharp
	_merge = _merged()
	var strip = clampf(Tuning.value("sync_merge_strip"), 0.0, screen.y / 2.0)
	var line = lerpf(screen.y / 2.0, screen.y - strip, _merge)  # the mirror line, from the top
	# The light half's view (and P2's flow) as tall as that half gets, the shadow half's half the
	# screen: neither changes size as they merge.
	var tall = Vector2(screen.x, screen.y - strip)
	var half = Vector2(screen.x, screen.y / 2.0)
	var camera = get_viewport().get_camera_2d()
	var center_x = camera.global_position.x if camera else screen.x / 2.0
	var shake = camera.offset if camera else Vector2.ZERO
	var focus = Vector2(center_x, BaseBoss.ARENA_FLOOR_Y) + shake
	for i in _halves.size():
		var h = _halves[i]
		var size = tall if i == 0 else half
		_aim(h.viewport, size, scale, focus)
		var height = line if i == 0 else screen.y - line
		h.frame.position = Vector2(0.0, 0.0 if i == 0 else line)
		h.frame.size = Vector2(screen.x, height)
		h.ground.size = h.frame.size
		h.picture.size = size
		h.picture.position = Vector2(0.0, height - size.y if i == 0 else 0.0)  # the floor at the line
	_aim(_flow, tall, scale, focus)
	_outline.set_shader_parameter("width", OUTLINE_WIDTH * scale)
	_outline_light.set_shader_parameter("width", OUTLINE_WIDTH * scale)
	_merge_halves(line, screen)
	_line.position = Vector2(0.0, line - LINE_WIDTH / 2.0)
	_line.size = Vector2(screen.x, LINE_WIDTH)


# A view of `size` (canvas units) at the window's pixels, with the floor at its bottom edge.
func _aim(viewport: SubViewport, size: Vector2, scale: float, focus: Vector2):
	var pixels = Vector2i((size * scale).round())
	if viewport.size != pixels:
		viewport.size = pixels
	var k = ZOOM * scale
	viewport.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, Vector2(pixels.x / 2.0, pixels.y) - focus * k)


# How merged the halves are, 0 to 1: the pair's own movement (SyncBond.flow()), with Moves
# "sync_merge_view" on.
func _merged() -> float:
	var rules = GameManager.rules
	if not Moves.on("sync_merge_view") or rules == null or rules.bond == null:
		return 0.0
	return rules.bond.flow()


# MERGED (see above). Merging (or back), P2 isn't in either half's view: the flow shows them, in a
# band rising from the line into the light half and one draining into it in the strip.
func _merge_halves(line: float, screen: Vector2):
	var top = _halves[0]
	var bottom = _halves[1]
	var flowing = _merge > 0.0
	top.viewport.canvas_cull_mask = WORLD | LIGHT
	bottom.viewport.canvas_cull_mask = WORLD | (0 if flowing else SHADOW)
	_flow.render_target_update_mode = SubViewport.UPDATE_ALWAYS if flowing else SubViewport.UPDATE_DISABLED
	var dim = Color.WHITE.lerp(MERGE_DIM, _merge)
	bottom.frame.modulate = dim
	_drain.modulate = dim
	# From P2's feet (in the air, from there) up by FLOW_HEIGHT: the light half filling, the
	# reflection draining. Merged all the way, P2 shows in all of the light half.
	var feet = 0.0
	for p in get_tree().get_nodes_in_group("players"):
		if p.player_id == 2:
			feet = maxf(BaseBoss.ARENA_FLOOR_Y - (p.global_position.y + p.body.size.y / 2.0), 0.0)
	var rise = line if _merge >= 1.0 else minf((feet + _merge * FLOW_HEIGHT) * ZOOM, line)
	var drain = minf((feet + (1.0 - _merge) * FLOW_HEIGHT) * ZOOM, screen.y - line)
	_rise.visible = flowing
	_rise.position = Vector2(0.0, line - rise)
	_rise.size = Vector2(screen.x, rise)
	_rise.get_child(0).size = top.picture.size
	_rise.get_child(0).position = Vector2(0.0, rise - top.picture.size.y)
	_drain.visible = flowing and _merge < 1.0
	_drain.position = Vector2(0.0, line)
	_drain.size = Vector2(screen.x, drain)
	_drain.get_child(0).size = top.picture.size
	_drain.get_child(0).position = Vector2.ZERO
