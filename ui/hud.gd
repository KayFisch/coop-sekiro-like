extends CanvasLayer
## Top-of-screen HUD of a fight on sync as life (GameManager.rules), plus the end-of-game
## overlay: the two sync meters meet in the middle, the players' filling out to the left, his to
## the right, and under each its side's posture (P1's and P2's, his). The meters are polled
## every frame; the overlay reacts to GameManager.state_changed.
## On canvas layer 2 (hud.tscn): over the mirrored screen (ui/mirror_view.gd, layer 1).

const BAR_BG_COLOR = Color(0.15, 0.15, 0.2)
# The two meters, each this wide, side by side from the middle.
const DUEL_HALF_WIDTH = 300.0
const DUEL_HEIGHT = 18.0
const TEAM_COLOR = Color(0.9, 0.88, 0.8)
const TEAM_SYNC_MODE_COLOR = Color(1.0, 0.78, 0.2)
const CHAOS_COLOR = Color(1.0, 0.2, 0.25)
const BOSS_SYNC_COLOR = Color(0.55, 0.54, 0.5)  # like the players', in the background
const TICK_COLOR = Color(1, 1, 1, 0.5)
# Posture: a thin bar under the sync meter on each side, P1's and P2's on the left, his on the
# right, full out to the end like the sync meters.
const POSTURE_HEIGHT = 8.0
const POSTURE_GAP = 3.0
const POSTURE_COLOR = Color(0.75, 0.75, 0.8)
const POSTURE_LOW_COLOR = Color(1.0, 0.55, 0.2)  # a quarter left: the next blocks break it

var _overlay: ColorRect
var _overlay_label: Label
var _duel = {}  # team_fill, boss_fill, ticks, labels


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_sync_duel(root)
	_build_controls_hint(root)
	_build_overlay(root)
	GameManager.state_changed.connect(_on_state_changed)


func _process(_delta):
	if GameManager.rules != null:
		_update_sync_duel(GameManager.rules)


# Sync as life: the players' meter on the left, filling out from the middle; his on the right,
# full to the right end, emptying toward the middle. Ticks: where the players' chaos ends and
# where their sync mode does (both move with Tuning).
func _build_sync_duel(root):
	var w = DUEL_HALF_WIDTH
	var box = _anchored_box(root, 0.5, -w, w)
	_label(box, Vector2(0, 0), "P1 + P2")
	var boss_name = _label(box, Vector2(w, 0), "")
	boss_name.size = Vector2(w, 20)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rect(box, Vector2(0, 24), Vector2(2.0 * w, DUEL_HEIGHT), BAR_BG_COLOR)
	_duel.team_fill = _rect(box, Vector2(w, 24), Vector2(0, DUEL_HEIGHT), TEAM_COLOR)
	_duel.boss_fill = _rect(box, Vector2(w, 24), Vector2(0, DUEL_HEIGHT), BOSS_SYNC_COLOR)
	_duel.chaos_tick = _rect(box, Vector2(0, 22), Vector2(2, DUEL_HEIGHT + 4), TICK_COLOR)
	_duel.mode_tick = _rect(box, Vector2(0, 22), Vector2(2, DUEL_HEIGHT + 4), TICK_COLOR)
	# Posture bars: one row per player on the left, his on the right of the first row.
	var y = 24.0 + DUEL_HEIGHT + POSTURE_GAP
	var players = GameManager.players.duplicate()
	players.sort_custom(func(a, b): return a.player_id < b.player_id)
	_duel.postures = []  # [actor, fill, grows_left]
	for i in players.size():
		var row_y = y + i * (POSTURE_HEIGHT + POSTURE_GAP)
		_rect(box, Vector2(0, row_y), Vector2(w, POSTURE_HEIGHT), BAR_BG_COLOR)
		var fill = _rect(box, Vector2(0, row_y), Vector2(w, POSTURE_HEIGHT), POSTURE_COLOR)
		var tag = _label(box, Vector2(-26, row_y - 5), "P%d" % players[i].player_id, 12)
		tag.modulate = Color(1, 1, 1, 0.7)
		_duel.postures.append([players[i], fill, true])
	_rect(box, Vector2(w, y), Vector2(w, POSTURE_HEIGHT), BAR_BG_COLOR)
	var boss_fill = _rect(box, Vector2(w, y), Vector2(w, POSTURE_HEIGHT), POSTURE_COLOR)
	_duel.postures.append([null, boss_fill, false])
	# How fast posture comes back just now (it follows sync): the players' left of their bars,
	# his right of his.
	_duel.team_regen = _label(box, Vector2(-112, y - 5), "", 12)
	_duel.boss_regen = _label(box, Vector2(2.0 * w + 8, y - 5), "", 12)
	for label in [_duel.team_regen, _duel.boss_regen]:
		label.modulate = Color(1, 1, 1, 0.7)
	_rect(box, Vector2(w - 1, 18), Vector2(2, y - 18 + players.size() * (POSTURE_HEIGHT + POSTURE_GAP)), Color.WHITE)
	var state_y = y + maxi(players.size(), 1) * (POSTURE_HEIGHT + POSTURE_GAP) + 2.0
	_duel.team_state = _label(box, Vector2(0, state_y), "", 16)
	_duel.boss_state = _label(box, Vector2(w, state_y), "", 16)
	_duel.boss_state.size = Vector2(w, 20)
	_duel.boss_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_duel.boss_name = boss_name


func _update_sync_duel(rules):
	var w = DUEL_HALF_WIDTH
	var team = w * rules.team_share()
	_duel.team_fill.position.x = w - team
	_duel.team_fill.size.x = team
	_duel.boss_fill.size.x = w * rules.boss_share()
	_duel.chaos_tick.position.x = w - w * Tuning.value("chaos_exit") / 100.0 - 1.0
	_duel.mode_tick.position.x = w - w * Tuning.value("sync_mode_exit") / 100.0 - 1.0
	for entry in _duel.postures:
		var actor = entry[0] if entry[0] != null else GameManager.boss
		if not is_instance_valid(actor):
			continue
		var share = rules.posture_share(actor)
		var fill: ColorRect = entry[1]
		fill.size.x = w * share
		fill.position.x = w - fill.size.x if entry[2] else w
		fill.color = POSTURE_COLOR if share > 0.25 else POSTURE_LOW_COLOR
		if share < 1.0 and not rules.regenerating(actor):
			fill.color = fill.color.darkened(0.45)  # not coming back yet: an attack, in or out, too recent
	var flicker = fmod(Time.get_ticks_msec() / 1000.0, 0.3) < 0.15
	if rules.team_chaos:
		_duel.team_fill.color = CHAOS_COLOR if flicker else CHAOS_COLOR.darkened(0.5)
		_duel.team_state.text = "CHAOS: no blocking, a hit kills"
		_duel.team_state.modulate = CHAOS_COLOR
	elif rules.sync_mode:
		_duel.team_fill.color = TEAM_SYNC_MODE_COLOR
		var bound = rules.bond != null and rules.bond.bound
		_duel.team_state.text = "BOUND: hold attack together, let go on the big cue" if bound 			else "SYNC MODE: stand together to bind"
		_duel.team_state.modulate = TEAM_SYNC_MODE_COLOR
	else:
		_duel.team_fill.color = TEAM_COLOR
		_duel.team_state.text = ""
	if rules.boss_chaos:
		_duel.boss_fill.color = CHAOS_COLOR if flicker else CHAOS_COLOR.darkened(0.5)
		_duel.boss_state.text = "SPLIT: the next hit kills"
		_duel.boss_state.modulate = CHAOS_COLOR
	else:
		_duel.boss_fill.color = BOSS_SYNC_COLOR
		_duel.boss_state.text = ""
	if is_instance_valid(GameManager.boss):
		_duel.boss_name.text = GameManager.boss.get_display_name()
		_duel.boss_regen.text = "regen %d%%" % roundi(100.0 * rules.regen_share(GameManager.boss))
	if not GameManager.players.is_empty():
		_duel.team_regen.text = "regen %d%%" % roundi(100.0 * rules.regen_share(GameManager.players[0]))


func _build_controls_hint(root):
	var hint = Label.new()
	hint.text = "P1: A/D move · W jump · R-Shift dash · Space attack · ↑ + Space upslash · S + Space (air) downslash" \
		+ " · L-Shift block/parry · S drop\n" \
		+ "P2 (pad): stick move · %s · up / down + attack: upslash, (air) downslash\n" % Pads.LAYOUTS[Pads.layout].buttons \
		+ "Dash + attack: dash-slash. Into your partner's upslash: launch · press as the ring closes" \
		+ " · Downslash onto their upslash: pogo clash      F1: switches · F2: tuning · Esc: boss select"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = 16.0
	hint.offset_right = -16.0
	hint.offset_top = -52.0
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
