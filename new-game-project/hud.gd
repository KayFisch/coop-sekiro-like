extends CanvasLayer
## Top-of-screen HUD (player health pips, sync meter, boss bar) plus the end-of-game overlay.
## Bars are polled every frame; the overlay reacts to GameManager.state_changed.

const PIP_SIZE = Vector2(28, 14)
const PIP_GAP = 6.0
const BAR_HEIGHT = 16.0
const SYNC_BAR_WIDTH = 260.0
const BOSS_BAR_WIDTH = 280.0
const EMPTY_COLOR = Color(0.2, 0.2, 0.25)
const BAR_BG_COLOR = Color(0.15, 0.15, 0.2)
const SYNC_COLOR = Color(0.3, 0.8, 1.0)
const SYNC_HOT_COLOR = Color(1.0, 0.85, 0.3)
const SYNC_MAX_COLOR = Color(1.0, 0.4, 0.9)
const BOSS_COLOR = Color(0.9, 0.2, 0.25)

var _rows: Array = []  # one Dictionary per player: player, pips, status
var _sync_fill: ColorRect
var _sync_mult: Label
var _boss_fill: ColorRect
var _boss_label: Label
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
		# Each pip is one hit; chip damage empties half a pip.
		for i in row.pips.size():
			row.pips[i].size.x = PIP_SIZE.x * clampf(p.hp - i, 0.0, 1.0)
		if p.is_grabbed:
			row.status.text = "GRABBED!"
			row.status.modulate = Color(1.0, 0.6, 0.2)
		else:
			row.status.text = ""

	var sync = GameManager.sync_value
	var mult = GameManager.damage_multiplier()
	_sync_fill.size.x = SYNC_BAR_WIDTH * sync / GameManager.SYNC_MAX
	if mult >= 2.0:
		_sync_fill.color = SYNC_MAX_COLOR
	elif mult > 1.0:
		_sync_fill.color = SYNC_HOT_COLOR
	else:
		_sync_fill.color = SYNC_COLOR
	_sync_mult.text = "x%.1f" % mult
	_sync_mult.modulate = _sync_fill.color if mult > 1.0 else Color.WHITE

	var boss = GameManager.boss
	if is_instance_valid(boss):
		_boss_fill.size.x = BOSS_BAR_WIDTH * boss.hp / boss.MAX_HP
		_boss_label.text = "BOSS  %.1f / %d" % [boss.hp, boss.MAX_HP]


func _build_player_rows(root):
	var players = get_tree().get_nodes_in_group("players")
	players.sort_custom(func(a, b): return a.player_id < b.player_id)
	for i in players.size():
		var p = players[i]
		var y = 12.0 + i * 24.0
		_label(root, Vector2(16, y - 3), "P%d" % p.player_id)
		var pips = []  # the fill rects; each sits on an empty background rect
		var pip_count = int(p.MAX_HP)
		for j in pip_count:
			var pos = Vector2(48 + j * (PIP_SIZE.x + PIP_GAP), y)
			_rect(root, pos, PIP_SIZE, EMPTY_COLOR)
			pips.append(_rect(root, pos, PIP_SIZE, p.body_color))
		var status = _label(root, Vector2(48 + pip_count * (PIP_SIZE.x + PIP_GAP) + 6, y - 3), "")
		_rows.append({"player": p, "pips": pips, "status": status})


func _build_sync_bar(root):
	var width = SYNC_BAR_WIDTH + 60.0
	var box = _anchored_box(root, 0.5, -width / 2, width / 2)
	_label(box, Vector2(0, 0), "SYNC")
	_rect(box, Vector2(0, 24), Vector2(SYNC_BAR_WIDTH, BAR_HEIGHT), BAR_BG_COLOR)
	_sync_fill = _rect(box, Vector2(0, 24), Vector2(0, BAR_HEIGHT), SYNC_COLOR)
	# Threshold ticks for the 1.5x and 2x multipliers.
	for threshold in [75.0, 95.0]:
		var x = SYNC_BAR_WIDTH * threshold / GameManager.SYNC_MAX
		_rect(box, Vector2(x - 1, 20), Vector2(2, BAR_HEIGHT + 8), Color(1, 1, 1, 0.6))
	_sync_mult = _label(box, Vector2(SYNC_BAR_WIDTH + 10, 20), "x1.0", 18)


func _build_boss_bar(root):
	var box = _anchored_box(root, 1.0, -BOSS_BAR_WIDTH - 16.0, -16.0)
	_boss_label = _label(box, Vector2(0, 0), "BOSS")
	_rect(box, Vector2(0, 24), Vector2(BOSS_BAR_WIDTH, BAR_HEIGHT), BAR_BG_COLOR)
	_boss_fill = _rect(box, Vector2(0, 24), Vector2(BOSS_BAR_WIDTH, BAR_HEIGHT), BOSS_COLOR)


func _build_controls_hint(root):
	var hint = Label.new()
	hint.text = "P1: A/D move · W jump · Q/E dash · Space attack · L-Ctrl block/parry · S drop      " \
		+ "P2 (pad): stick move · A jump · LB/RB dash · X attack · RT block/parry"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = 16.0
	hint.offset_right = -16.0
	hint.offset_top = -20.0
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


func _label(parent, pos: Vector2, text: String, font_size = 14) -> Label:
	var l = Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
