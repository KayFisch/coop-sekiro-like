extends CanvasLayer
## Top-of-screen HUD (player health bars and potions, sync meter, boss bar) plus the
## end-of-game overlay. Bars are polled every frame; the overlay reacts to GameManager.state_changed.

const BAR_HEIGHT = 16.0
const PLAYER_BAR_WIDTH = 160.0
const PLAYER_BAR_HEIGHT = 14.0
const POTION_SIZE = 12.0
const POTION_GAP = 6.0
const SYNC_BAR_WIDTH = 260.0
const BOSS_BAR_WIDTH = 240.0
const BAR_BG_COLOR = Color(0.15, 0.15, 0.2)
const HP_BG_COLOR = Color(0.3, 0.04, 0.06)
const HP_COLOR = Color(1.0, 0.15, 0.2)
const POTION_COLOR = Color(0.35, 0.95, 0.55)
const POTION_USED_COLOR = Color(0.3, 0.3, 0.33)
const SYNC_LOW_COLOR = Color(0.45, 0.45, 0.48)  # the gold bar starts out grey...
const SYNC_HIGH_COLOR = Color(1.0, 0.78, 0.2)  # ...and warms to gold as sync fills
const SEPARATOR_COLOR = Color(1, 1, 1, 0.2)

var _rows: Array = []  # one Dictionary per player: player, fill, hp_label, potions, status
var _sync_fill: ColorRect
var _sync_mult: Label
var _boss_fill: ColorRect
var _boss_hp_label: Label
var _boss_name: Label
var _overlay: ColorRect
var _overlay_label: Label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_player_rows(root)
	_build_sync_bar(root)
	_build_boss_bar(root)
	_build_controls_hint(root)
	_build_overlay(root)
	GameManager.state_changed.connect(_on_state_changed)


func _process(_delta):
	for row in _rows:
		var p = row.player
		if not is_instance_valid(p):
			continue
		row.fill.size.x = PLAYER_BAR_WIDTH * clampf(p.hp / p.MAX_HP, 0.0, 1.0)
		row.hp_label.text = "%d" % int(ceil(p.hp))
		for i in row.potions.size():
			var style: StyleBoxFlat = row.potions[i].get_theme_stylebox("panel")
			var color = POTION_COLOR if i < p.potions else POTION_USED_COLOR
			if style.bg_color != color:  # only restyle (and redraw) on change
				style.bg_color = color
		if p.is_grabbed:
			row.status.text = "GRABBED!"
			row.status.modulate = Color(1.0, 0.6, 0.2)
		elif p.is_staggered():
			row.status.text = "STAGGERED"
			row.status.modulate = Color(0.75, 0.75, 0.75)
		elif p.is_drinking():
			row.status.text = "DRINKING"
			row.status.modulate = POTION_COLOR
		else:
			row.status.text = ""

	var sync = GameManager.sync_value
	var mult = GameManager.damage_multiplier()
	var fraction = sync / GameManager.SYNC_MAX
	_sync_fill.size.x = SYNC_BAR_WIDTH * fraction
	_sync_fill.color = SYNC_LOW_COLOR.lerp(SYNC_HIGH_COLOR, fraction)
	_sync_mult.text = "x%.1f" % mult
	_sync_mult.modulate = SYNC_HIGH_COLOR if mult > 1.0 else Color.WHITE

	var boss = GameManager.boss
	if is_instance_valid(boss):
		_boss_fill.size.x = BOSS_BAR_WIDTH * clampf(boss.hp / boss.get_max_hp(), 0.0, 1.0)
		_boss_name.text = boss.get_display_name()
		_boss_hp_label.text = "%d" % int(ceil(boss.hp))


func _build_player_rows(root):
	var players = get_tree().get_nodes_in_group("players")
	players.sort_custom(func(a, b): return a.player_id < b.player_id)
	for i in players.size():
		var p = players[i]
		var y = 12.0 + i * 24.0
		var name_label = _label(root, Vector2(16, y - 3), "P%d" % p.player_id)
		name_label.modulate = p.body_color.lightened(0.3)
		_rect(root, Vector2(48, y), Vector2(PLAYER_BAR_WIDTH, PLAYER_BAR_HEIGHT), HP_BG_COLOR)
		var fill = _rect(root, Vector2(48, y), Vector2(PLAYER_BAR_WIDTH, PLAYER_BAR_HEIGHT), HP_COLOR)
		var x = 48.0 + PLAYER_BAR_WIDTH + 6.0
		var hp_label = _label(root, Vector2(x, y - 3), "")
		x += 36.0
		var potions = []
		for j in p.POTION_CHARGES:
			potions.append(_circle(root, Vector2(x, y + 1), POTION_SIZE, POTION_COLOR))
			x += POTION_SIZE + POTION_GAP
		var status = _label(root, Vector2(x + 4, y - 3), "")
		_rows.append({"player": p, "fill": fill, "hp_label": hp_label, "potions": potions, "status": status})
		if i < players.size() - 1:
			# Thin divider between this player's row and the next.
			_rect(root, Vector2(16, y + PLAYER_BAR_HEIGHT + 4), Vector2(x + 60 - 16, 1), SEPARATOR_COLOR)


func _build_sync_bar(root):
	var width = SYNC_BAR_WIDTH + 60.0
	var box = _anchored_box(root, 0.5, -width / 2, width / 2)
	_label(box, Vector2(0, 0), "SYNC")
	_rect(box, Vector2(0, 24), Vector2(SYNC_BAR_WIDTH, BAR_HEIGHT), BAR_BG_COLOR)
	_sync_fill = _rect(box, Vector2(0, 24), Vector2(0, BAR_HEIGHT), SYNC_LOW_COLOR)
	# Threshold ticks for the 1.5x and 2x multipliers.
	for threshold in [75.0, 95.0]:
		var x = SYNC_BAR_WIDTH * threshold / GameManager.SYNC_MAX
		_rect(box, Vector2(x - 1, 20), Vector2(2, BAR_HEIGHT + 8), Color(1, 1, 1, 0.6))
	_sync_mult = _label(box, Vector2(SYNC_BAR_WIDTH + 10, 20), "x1.0", 18)


func _build_boss_bar(root):
	var box = _anchored_box(root, 1.0, -BOSS_BAR_WIDTH - 60.0, -16.0)
	_boss_name = _label(box, Vector2(0, 0), "BOSS")
	_rect(box, Vector2(0, 24), Vector2(BOSS_BAR_WIDTH, BAR_HEIGHT), HP_BG_COLOR)
	_boss_fill = _rect(box, Vector2(0, 24), Vector2(BOSS_BAR_WIDTH, BAR_HEIGHT), HP_COLOR)
	_boss_hp_label = _label(box, Vector2(BOSS_BAR_WIDTH + 6, 22), "")


func _build_controls_hint(root):
	var hint = Label.new()
	hint.text = "P1: A/D move · W jump · ←/→ dash · Space attack · ↑ + Space upslash · L-Ctrl block/parry · F potion · S drop" \
		+ "      Esc: boss select\n" \
		+ "P2 (pad): stick move · A jump · LB/RB dash · X attack · stick up + X upslash · RT block/parry · Y potion" \
		+ "      Dash + attack: dash-slash · dash-slash into your partner's upslash: launch"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = 16.0
	hint.offset_right = -16.0
	hint.offset_top = -36.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)


func _build_overlay(root):
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.65)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	root.add_child(_overlay)

	_overlay_label = Label.new()
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 40)
	_overlay.add_child(_overlay_label)


func _on_state_changed(new_state):
	match new_state:
		GameManager.GameState.GAME_OVER:
			_overlay_label.text = "Game Over — Press R to restart"
			_overlay.visible = true
		GameManager.GameState.VICTORY:
			_overlay_label.text = "Victory!\nTime: %s\nPress R to play again" \
				% _format_time(GameManager.elapsed_time)
			_overlay.visible = true
		_:
			_overlay.visible = false


func _format_time(seconds: float) -> String:
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]


func _anchored_box(root, anchor_x: float, left: float, right: float) -> Control:
	var box = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_left = anchor_x
	box.anchor_right = anchor_x
	box.offset_left = left
	box.offset_right = right
	box.offset_top = 6.0
	box.offset_bottom = 50.0
	root.add_child(box)
	return box


func _rect(parent, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var r = ColorRect.new()
	r.position = pos
	r.size = rect_size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


# A filled circle: a Panel whose own StyleBoxFlat is fully rounded (recolor via its bg_color).
func _circle(parent, pos: Vector2, diameter: float, color: Color) -> Panel:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(diameter / 2))
	var c = Panel.new()
	c.position = pos
	c.size = Vector2(diameter, diameter)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_theme_stylebox_override("panel", style)
	parent.add_child(c)
	return c


func _label(parent, pos: Vector2, text: String, font_size = 14) -> Label:
	var l = Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
