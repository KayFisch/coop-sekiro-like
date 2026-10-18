class_name SyncBond
extends Node
## The sync mode itself, the players' second phase (core/sync_rules.gd, Bifrons's fight): once
## their sync is full, each gets a sign at their feet that they can join. Standing together
## (within Tuning "sync_connect_distance", both on the floor) they're bound: each takes on some
## of the other's color from the feet up (white into black, black into white: across the floor
## line on the mirrored screen), and their swords become sabres. Moving apart (past
## "sync_break_distance") or the sync mode ending unbinds them. How they move bound is still
## open: for now each moves as ever.
##
## THE PAIR'S STRIKE: each holds attack to draw their sabre back (Player._process_draw()); fully
## drawn, a small cue. Once both are, "sync_cue_delay" after the later one, the big cue: both let
## go on it (within "sync_release_window" either side) and they land a heavy strike together. His
## guard can't stop it: parried, it still costs him a normal hit's sync and he reels
## (ColumnaBifrons.take_pair_strike()). Out of sync, each lets go a weak strike of their own (a
## normal attack, met by his guard as ever) and they lose "pair_miss_loss" sync.
## Bound, his strikes of both swords have to be parried by both: a lone parry is only a block
## (StrikePattern).

const STRIKE_DELAY = 0.08  # s from letting go to the blade landing (a slash's windup, about)
const SIGN_COLOR = Color(1.0, 0.35, 0.8)  # the sync energy's pink (SyncWave.COLOR)
const SIGN_EDGE = Color(0.05, 0.03, 0.07, 0.6)
const WEAK_COLOR = Color(0.6, 0.6, 0.62)
const BLEND_SHARE = 0.32  # how far up the body the partner's color flows in, bound...
const BLEND_TIME = 0.45  # ...over this long
const CUE_TIME = 0.28  # s a cue's ring takes to spread and fade
const FLASH_ALPHA = 0.22  # the screen's pink flash on the big cue and a heavy strike
const SLOW_EASE = 0.2  # each frame the time's speed goes this share of the way to where it's headed
const SLOW_TINT = 0.05  # the screen's faint pink while time runs slow

var rules  # the SyncRules it belongs to
var bound = false
var cue_at = -1.0  # now() of the big cue; -1: not both drawn yet
var _time = 0.0
var _bound_at = -100.0
var _full_at = {}  # player -> when their sabre was fully drawn
var _in_time = {}  # player -> they let go on the big cue
var _spoiled = false  # one let go out of sync: no big cue for the other this time
var _cue_shown = false
var _lost = false  # this try has cost its sync already (one loss, however many let go)
var _resolve_at = -1.0  # when the pair's strike lands (both let go on the cue)
var _rings = []  # [player or null, at, color, born, radius]: cue rings and puffs
var _marks = {}  # player -> Node2D drawing their signs (on their visibility layer)
var _floor: Node2D  # the bond along the floor, between them (on every layer)
var _flash: ColorRect
var _flash_left = 0.0


# Its numbers on F2 (core/tuning.gd collects them): the sync rules' page, tab "sync mode".
static func tuning_entries() -> Array:
	return [
		{"page": "sync", "title": "Sync Rules", "scenes": ["levels/threshold/"], "header": "SYNC MODE: BINDING", "tab": "sync mode"},
		{"key": "sync_connect_distance", "label": "bound once you stand this close (px apart)", "default": 30.0, "step": 2.0},
		{"key": "sync_break_distance", "label": "...and apart again past this (px)", "default": 90.0, "step": 5.0},
		{"header": "THE PAIR'S STRIKE"},
		{"key": "sync_charge_time", "label": "attack held: sabre fully drawn back after (s)", "default": 0.45, "step": 0.05},
		{"key": "sync_cue_delay", "label": "both drawn: the big cue this long after the later (s)", "default": 0.15, "step": 0.01},
		{"key": "sync_release_window", "label": "let go on the cue: this close to it, either side (s)", "default": 0.1, "step": 0.01},
		{"key": "sync_strike_reach", "label": "it reaches him from this far (px from his middle; his drift: up to 170)", "default": 200.0, "step": 10.0},
		{"key": "pair_miss_loss", "label": "let go out of sync: your sync lost", "default": 5.0, "step": 1.0},
		{"header": "HIM, IN YOUR SYNC MODE", "column": 1},
		{"key": "sync_mode_tempo", "label": "his waits and pauses, times (slower)", "default": 1.4, "step": 0.1},
		{"key": "sync_strike_reel", "label": "your strike together through his guard: he reels (s)", "default": 0.8, "step": 0.1},
		{"key": "sync_guard_pause", "label": "on guard between his attacks, longer by (s)", "default": 2.0, "step": 0.1},
		{"key": "sync_hold_off", "label": "while you draw back he holds off, at most (s)", "default": 1.5, "step": 0.1},
		{"header": "TIME"},
		{"key": "sync_slow_speed", "label": "while one of you draws back: time's speed (1: as ever)", "default": 1.0, "step": 0.05},
	]


func _ready():
	_floor = Node2D.new()
	_floor.top_level = true
	_floor.z_index = 15
	_floor.draw.connect(_draw_floor)
	add_child(_floor)
	var layer = CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(SIGN_COLOR, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash)


func now() -> float:
	return _time


func _exit_tree():
	Engine.time_scale = Dev.speed  # a fight left mid-draw doesn't stay slow


func _process(delta):
	_time += delta
	var players = _players()
	for p in players:
		if not _marks.has(p):
			var mark = Node2D.new()
			mark.top_level = true
			mark.z_index = 15
			mark.draw.connect(_draw_mark.bind(mark, p))
			add_child(mark)
			_marks[p] = mark
		_marks[p].visibility_layer = p.visibility_layer
		_marks[p].queue_redraw()
	_floor.queue_redraw()
	# Time runs slow while one of the bound draws back (Tuning "sync_slow_speed"; 1: not at all).
	var drawing = bound and players.any(func(p): return p.is_drawing())
	var speed = (Tuning.value("sync_slow_speed") if drawing else 1.0) * Dev.speed  # (the lab's speed too)
	Engine.time_scale = speed if absf(Engine.time_scale - speed) < 0.01 else lerpf(Engine.time_scale, speed, SLOW_EASE)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_flash.color.a = maxf(FLASH_ALPHA * _flash_left / 0.2, SLOW_TINT * (1.0 - Engine.time_scale) * 2.0)
	_rings = _rings.filter(func(r): return _time - r[3] < CUE_TIME)
	if players.size() < 2:
		_unbind()
		return
	var gap = absf(players[0].global_position.x - players[1].global_position.x)
	if not bound:
		if rules.sync_mode and gap <= Tuning.value("sync_connect_distance") \
				and players.all(func(p): return p.is_on_floor() and not p.is_staggered()):
			_bind(players)
	elif not rules.sync_mode or gap > Tuning.value("sync_break_distance"):
		_unbind()
	if bound:
		_follow_charges(players)


func _players() -> Array:
	return GameManager.players.filter(func(p): return is_instance_valid(p) and p.hp > 0.0)


func _bind(players: Array):
	bound = true
	_bound_at = _time
	_reset_strike()
	for p in players:
		p.bond = self
		p.set_sabre(true)
		_ring(p, p.global_position + Vector2(0.0, p.body.size.y / 2.0), SIGN_COLOR, 46.0)
	Sfx.play("launch", -2.0)
	Sfx.play("call_go", -4.0)
	if is_instance_valid(rules.boss):
		rules.boss.shake(6.0)
	_flash_left = 0.12


func _unbind():
	if not bound:
		return
	bound = false
	_reset_strike()
	for p in GameManager.players:
		if is_instance_valid(p):
			p.bond = null
			p.set_sabre(false)


func _reset_strike():
	cue_at = -1.0
	_full_at.clear()
	_in_time.clear()
	_spoiled = false
	_cue_shown = false
	_lost = false
	_resolve_at = -1.0


# Each sabre drawn back all the way: a small cue. Both: the big cue, a moment after the later.
func _follow_charges(players: Array):
	for p in players:
		if p.draw_share() >= 1.0 and not _full_at.has(p):
			_full_at[p] = _time
			_ring(p, null, SIGN_COLOR, 16.0)
			Sfx.play("call_tick", -6.0)
		elif not p.is_drawing() and not _in_time.has(p):
			_full_at.erase(p)
	if cue_at < 0.0 and not _spoiled and _full_at.size() == 2:
		cue_at = maxf(_full_at.values()[0], _full_at.values()[1]) + Tuning.value("sync_cue_delay")
		_cue_shown = false
	if cue_at >= 0.0 and _time >= cue_at and not _cue_shown:
		_cue_shown = true
		for p in players:
			_ring(p, null, SIGN_COLOR, 44.0)
		Sfx.play("call_go", -2.0)
		_flash_left = 0.1
	var window = Tuning.value("sync_release_window")
	if cue_at >= 0.0 and _time > cue_at + window and _resolve_at < 0.0:
		# The window's over and not both let go on it: whoever did strikes alone, out of sync.
		for p in _in_time:
			_weak(p)
		_spoiled = true
		cue_at = -1.0
		_in_time.clear()
	if _resolve_at >= 0.0 and _time >= _resolve_at:
		_resolve_at = -1.0
		_strike_together(players)
	if _spoiled and players.all(func(p): return not p.is_drawing()):
		_reset_strike()


# A sabre let go (Player._process_draw()): on the big cue, or out of sync.
func released(p, _share: float):
	var window = Tuning.value("sync_release_window")
	var in_time = cue_at >= 0.0 and not _spoiled and absf(_time - cue_at) <= window
	Dev.pair_release(p, _time - cue_at if cue_at >= 0.0 else -99.0, in_time)
	if in_time:
		_in_time[p] = true
		if _in_time.size() == 2:
			_resolve_at = _time + STRIKE_DELAY
		return
	_weak(p)
	_spoiled = true
	cue_at = -1.0
	for other in _in_time:
		_weak(other)
	_in_time.clear()
	_full_at.erase(p)


# Out of sync: a weak strike of their own (a normal attack on him, as ever), and sync lost.
func _weak(p):
	if not _lost:
		_lost = true
		rules.pair_missed()
	_ring(p, null, WEAK_COLOR, 22.0)
	Sfx.play("chip", -4.0)
	get_tree().create_timer(STRIKE_DELAY).timeout.connect(func():
		var boss = rules.boss
		if is_instance_valid(boss) and is_instance_valid(p) and boss.hp > 0.0 \
				and boss.distance_to(p) <= Tuning.value("sync_strike_reach"):
			boss.take_damage(0.0, p))


# Both let go on the big cue: one heavy strike, if he's within their reach.
func _strike_together(players: Array):
	_reset_strike()
	var boss = rules.boss
	var near = players.filter(func(p): return is_instance_valid(boss) and boss.distance_to(p) <= Tuning.value("sync_strike_reach"))
	for p in players:
		_ring(p, null, Color.WHITE, 52.0)
	if near.is_empty() or boss.hp <= 0.0:
		Sfx.play("slash", 0.0)
		return
	_flash_left = 0.2
	boss.take_pair_strike(near[0])


func _ring(p, at, color: Color, radius: float):
	_rings.append([p, at, color, _time, radius])


# --- Drawing ---

# A player's signs: the sign at their feet while they can join; bound, the partner's color flowing
# up into their body; the cues at their sabre's point.
func _draw_mark(mark: Node2D, p):
	if not is_instance_valid(p):
		return
	var feet = p.global_position + Vector2(0.0, p.body.size.y / 2.0)
	if rules.sync_mode and not bound:
		var pulse = 0.5 + 0.5 * sin(_time * TAU * 2.0)
		mark.draw_set_transform(feet, 0.0, Vector2(1.0, 0.3))
		mark.draw_arc(Vector2.ZERO, 22.0 + 6.0 * pulse, 0.0, TAU, 32, SIGN_EDGE, 6.0, true)
		mark.draw_arc(Vector2.ZERO, 22.0 + 6.0 * pulse, 0.0, TAU, 32, Color(SIGN_COLOR, 0.6 + 0.4 * pulse), 3.0, true)
		mark.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 3:
			var rise = fmod(_time * 1.5 + i / 3.0, 1.0)
			var at = feet + Vector2((i - 1) * 7.0, -rise * 26.0)
			mark.draw_circle(at, 2.5, Color(SIGN_COLOR, 1.0 - rise))
	if bound:
		var partner = _partner_of(p)
		if partner != null:
			var size = p.body.size * p.body.scale
			var height = size.y * BLEND_SHARE * clampf((_time - _bound_at) / BLEND_TIME, 0.0, 1.0)
			var color = partner.body.color
			var left = p.global_position.x - size.x / 2.0
			mark.draw_rect(Rect2(left, feet.y - height, size.x, height), color)
			mark.draw_rect(Rect2(left, feet.y - height - 4.0, size.x, 4.0), Color(color, 0.5))
		if _full_at.has(p) and p.is_drawing():
			mark.draw_circle(p.blade_point(1.0), 4.0, SIGN_COLOR)
	for r in _rings:
		if r[0] != p:
			continue
		var t = (_time - r[3]) / CUE_TIME
		var at = r[1] if r[1] != null else p.blade_point(1.0)
		var radius = lerpf(4.0, r[4], t)
		mark.draw_arc(at, radius, 0.0, TAU, 32, Color(SIGN_EDGE, SIGN_EDGE.a * (1.0 - t)), 6.0, true)
		mark.draw_arc(at, radius, 0.0, TAU, 32, Color(r[2], 1.0 - t), 3.0, true)


# Bound: a pink line along the floor between them, the brighter on the big cue.
func _draw_floor():
	if not bound:
		return
	var players = _players()
	if players.size() < 2:
		return
	var y = rules.boss.ARENA_FLOOR_Y if is_instance_valid(rules.boss) else 600.0
	var a = Vector2(players[0].global_position.x, y)
	var b = Vector2(players[1].global_position.x, y)
	var glow = 0.45 + 0.25 * sin(_time * TAU)
	if cue_at >= 0.0 and _time >= cue_at:
		glow = 1.0
	_floor.draw_line(a, b, Color(SIGN_COLOR, glow), 4.0, true)


func _partner_of(p):
	for other in _players():
		if other != p:
			return other
	return null
