class_name BeatRing
extends Node2D
## The beat-ring, a second prototype for between the bosses (docs/beat_ring.md). The players
## stand in a room like his, split as in the mirrored boss fight (P1 above, P2 in the reflection
## below), and move freely. Around the middle of the floor line lies a circle, only to look at:
## where a thing meets it is where, and when, it's best answered (its beat). Things come from
## anywhere above the floor at that middle, each for one player and seen only in their half:
## - a yellow orb: parry it (it has to reach you); a violet shard: hit it with the sword;
## - green orbs, one each at once: parry together.
## Answered right on the circle (its beat) is "perfect", near it "good", anywhere else it still
## counts a little. One nobody answers flies through the middle into the partner's half (Moves
## "ring_pass_through") and meets the circle there once more, on its way out: the partner can
## still take it, but only perfectly on that beat.
## Now and then a bar slides in along the floor from a side: a low one to jump, a high one not
## to jump into. A sync meter is the run's life. Every number is on F2 (the ring's page).

enum Kind { PARRY, SHARD, PAIR }
enum Phase { IN, THROUGH }  # coming at the middle in its own half; gone through into the partner's

const CENTER = Vector2(576.0, 600.0)  # the middle of the floor line, the circle's center
const FLOOR_Y = 600.0
const RADIUS = 12.0  # an orb's
const TOUCH = 16.0  # an orb this much past its radius from a player's center reaches them
const PARRY_REACH = 46.0  # an orb this close to a player's center is at their guard: parryable
const SWORD_REACH = 36.0  # px from the middle of a swinging blade at which a shard is hit
const SPAWN_DISTANCE = 780.0  # from the middle: things start out of sight
const ANGLES = Vector2(14.0, 166.0)  # degrees above the floor things come from (0: from the right)
const MARK_TIME = 1.0  # s before its beat a thing marks where it'll meet the circle
const LEAD_IN = 2.0  # s before the first beat
const LOOKAHEAD = 3.0  # s planned ahead
const BAR_LOW = Vector2(30.0, 36.0)  # on the floor: jump it
const BAR_HIGH = Vector2(44.0, 26.0)  # its bottom HIGH_CLEAR above the floor: don't jump into it
const HIGH_CLEAR = 60.0  # a standing player is 40 tall; a jump goes 136
const METER_MAX = 100.0
# The stand-in: answers this share of what comes at it (as BeatRunner's does).
const STAND_IN_SKILL = 0.85
const STAND_IN_PRESS = 0.07  # s before a beat it presses parry or attack
const STAND_IN_RISE = {Kind.PARRY: 30.0, Kind.PAIR: 30.0, Kind.SHARD: 50.0}  # reach above its center
const STAND_IN_SWORD = 52.0  # px it stands off a shard's meeting point, facing it

const COLOR_PARRY = StrikePattern.COLOR
const COLOR_SHARD = ColumnaBifrons.COLOR_SYNC_BEAT
const COLOR_PAIR = StrikePattern.COLOR_TOGETHER
const COLOR_BAR = Color(0.55, 0.55, 0.62)
const COLOR_CIRCLE = Color(1, 1, 1, 0.22)
const COLOR_METER = Color(0.9, 0.88, 0.8)
const COLOR_EMPTY = Color(1.0, 0.2, 0.25)
const BAR_SIZE = Vector2(360.0, 16.0)

var _players = []  # P1, P2: lane 0 and lane 1
var _time = -LEAD_IN
var _next_beat = 0  # the next beat to plan
var _lane_free = [0.0, 0.0]  # per lane: the first beat time it may get a thing again
var _waiting = []  # planned things not out yet: [spawn time, node], sorted
var _orbs = []
var _bars = []
var _pairs = {}  # pair id -> how many of its two orbs were parried
var _next_pair = 0
var _meter = 50.0
var _combo = 0
var _best = 0
var _over = false
var tally = {}  # what happened, by the text shown: counted for the end of a run
var _circle: Node2D
var _bar: ColorRect
var _combo_label: Label
var _over_label: Label


func _ready():
	for p in GameManager.players:
		_players.append(p)
	_players.sort_custom(func(a, b): return a.player_id < b.player_id)
	_meter = Tuning.value("ring_start")
	_circle = Circle.new()
	_circle.ring = self
	add_child(_circle)
	_build_ui()
	var stand_in = StandIn.new()
	stand_in.ring = self
	add_child(stand_in)


func _physics_process(delta):
	if _over:
		if Input.is_action_just_pressed("restart"):
			GameManager.restart()
		return
	_time += delta
	_plan()
	while not _waiting.is_empty() and _waiting[0][0] <= _time:
		_launch(_waiting.pop_front()[1])
	for orb in _orbs.duplicate():
		_fly(orb)
	for bar in _bars.duplicate():
		_slide(bar, delta)
	_circle.queue_redraw()
	_update_ui()


func beat_length() -> float:
	return Tuning.value("ring_beat")


func radius() -> float:
	return Tuning.value("ring_radius")


# --- What comes when ---

# Every beat: maybe an orb or a shard for a player whose last one is far enough back, maybe a
# green pair for both; and maybe a bar.
func _plan():
	while _next_beat * beat_length() < _time + LOOKAHEAD:
		var beat = _next_beat * beat_length()
		_next_beat += 1
		if beat < 0.0:
			continue
		var gap = Tuning.value("ring_lane_gap") * beat_length()
		var both_free = _lane_free[0] <= beat and _lane_free[1] <= beat
		if Moves.on("ring_pairs") and both_free and randf() < Tuning.value("ring_pair_chance"):
			var angle = randf_range(ANGLES.x, ANGLES.y)
			for lane in 2:
				_plan_orb(Kind.PAIR, lane, beat, angle, _next_pair)
				_lane_free[lane] = beat + gap
			_next_pair += 1
		else:
			for lane in 2:
				if _lane_free[lane] <= beat and randf() < Tuning.value("ring_density"):
					var kind = Kind.SHARD if randf() < Tuning.value("ring_shard_share") else Kind.PARRY
					_plan_orb(kind, lane, beat, randf_range(ANGLES.x, ANGLES.y))
					_lane_free[lane] = beat + gap
		if Moves.on("ring_bars") and randf() < Tuning.value("ring_bar_chance"):
			var lanes = [0, 1] if randf() < 0.3 else [randi() % 2]
			var high = randf() < 0.5
			var from = -1.0 if randf() < 0.5 else 1.0
			for lane in lanes:
				_plan_bar(lane, beat, high, from)


func _plan_orb(kind: int, lane: int, beat: float, angle: float, pair = -1):
	var orb = Orb.new()
	orb.ring = self
	orb.kind = kind
	orb.lane = lane
	orb.home = lane
	orb.beat = beat
	orb.pair = pair
	orb.speed = Tuning.value("ring_orb_speed")
	orb.dir = Vector2(cos(deg_to_rad(angle)), -sin(deg_to_rad(angle)))
	_queue(beat - (SPAWN_DISTANCE - radius()) / orb.speed, orb)


func _plan_bar(lane: int, beat: float, high: bool, from: float):
	var bar = Bar.new()
	bar.lane = lane
	bar.high = high
	bar.way = -from  # from the left wall it goes right
	bar.speed = Tuning.value("ring_bar_speed")
	bar.position = Vector2(CENTER.x + from * 700.0, FLOOR_Y - (HIGH_CLEAR + BAR_HIGH.y / 2.0 if high else BAR_LOW.y / 2.0))
	_queue(beat, bar)


func _queue(at: float, node):
	_waiting.append([at, node])
	_waiting.sort_custom(func(a, b): return a[0] < b[0])


func _launch(node):
	add_child(node)
	node.visibility_layer = _players[node.lane].visibility_layer  # seen in its player's half only
	if node is Orb:
		_orbs.append(node)
		_place(node)
	else:
		_bars.append(node)


# --- Orbs ---

# Where it is: coming at the middle, and past it (through the line) going out again, mirrored.
func _place(orb):
	var to_circle = orb.beat - _time  # s until it meets the circle on its way in
	var from_middle = radius() + orb.speed * to_circle  # px from the middle, < 0 once past it
	if from_middle >= 0.0:
		orb.position = CENTER + orb.dir * from_middle
	else:
		orb.position = CENTER + Vector2(-orb.dir.x, orb.dir.y) * -from_middle
	orb.queue_redraw()


func _fly(orb):
	if orb.done:
		orb.position += orb.drift * get_physics_process_delta_time()
		orb.modulate.a = maxf(orb.modulate.a - 2.5 * get_physics_process_delta_time(), 0.0)
		if orb.modulate.a <= 0.0:
			_orbs.erase(orb)
			orb.queue_free()
		return
	_place(orb)
	var past = orb.position.distance_to(CENTER) if orb.phase == Phase.THROUGH else -1.0
	if orb.phase == Phase.IN and orb.beat - _time + radius() / orb.speed <= 0.0:
		_through(orb)  # it reached the middle unanswered
		return
	var p = _players[orb.lane]
	if orb.phase == Phase.IN:
		_meet_in(orb, p)
	else:
		_meet_through(orb, p, past)


# On its way in: answered anywhere, best on the circle; a body it reaches unanswered is hit.
func _meet_in(orb, p):
	var off = absf(_time - orb.beat)
	if orb.kind == Kind.SHARD:
		if _struck(orb, p):
			_answer(orb, off, "HIT")
		elif _touches(orb, p):
			_taken(orb, p)
		return
	if _at_guard(orb, p) and p.is_perfect_parry():
		p.on_perfect_parry(orb.kind == Kind.PAIR)
		_answer(orb, off, "PARRY")
		if orb.kind == Kind.PAIR:
			_pairs[orb.pair] = _pairs.get(orb.pair, 0) + 1
			if _pairs[orb.pair] == 2:
				_gain("ring_pair_gain", orb, "TOGETHER")
				Sfx.play("counter_hit", -8.0)
		return
	if not _touches(orb, p):
		return
	if p.is_blocking():
		Sfx.play("chip")
		_lose("ring_block_loss", orb, "BLOCKED")
		_end(orb, Vector2(0.0, -60.0))
	else:
		_taken(orb, p)


# Gone through into the partner's half: only a perfect answer on its beat there takes it; it
# can't hurt anyone any more. Past the circle unanswered: lost.
func _meet_through(orb, p, past: float):
	var beat = orb.beat + 2.0 * radius() / orb.speed  # it meets the circle again, going out
	var on_beat = absf(_time - beat) <= Tuning.value("ring_perfect")
	if on_beat:
		var taken = _struck(orb, p) if orb.kind == Kind.SHARD else (_at_guard(orb, p) and p.is_perfect_parry())
		if taken:
			if orb.kind != Kind.SHARD:
				p.on_perfect_parry(false)
			Sfx.play("on_beat", -4.0)
			_sparks(orb, Color.WHITE, 16)
			_gain("ring_pass_gain", orb, "CAUGHT!")
			_end(orb, Vector2.ZERO)
			return
	if _time > beat + Tuning.value("ring_perfect") and past > radius():
		_lose("ring_lost_loss", orb, "LOST")
		_end(orb, Vector2(-orb.dir.x, orb.dir.y) * orb.speed)


# It reached the middle: through into the partner's half (Moves "ring_pass_through"), or lost.
func _through(orb):
	if not Moves.on("ring_pass_through"):
		_lose("ring_lost_loss", orb, "LOST")
		_end(orb, Vector2.ZERO)
		return
	orb.phase = Phase.THROUGH
	orb.lane = 1 - orb.lane
	orb.visibility_layer = _players[orb.lane].visibility_layer
	_sparks(orb, Color.WHITE, 6)


func _answer(orb, off: float, what: String):
	if off <= Tuning.value("ring_perfect"):
		Sfx.play("on_beat", -4.0)
		_sparks(orb, Color.WHITE, 16)
		_gain("ring_perfect_gain", orb, "PERFECT " + what)
	elif off <= Tuning.value("ring_good"):
		_sparks(orb, orb.color().lerp(Color.WHITE, 0.4), 10)
		_gain("ring_good_gain", orb, "GOOD")
	else:
		_sparks(orb, orb.color(), 6)
		_gain("ring_ok_gain", orb, what)
	if orb.kind == Kind.SHARD:
		Sfx.play("sync_hit", -4.0)
		orb.split = true
	_end(orb, Vector2.ZERO)


func _taken(orb, p):
	p.take_damage(0.0, (p.global_position - orb.position).normalized() * 220.0 + Vector2(0.0, -120.0))
	_lose("ring_hit_loss", orb, "TAKEN")
	_end(orb, Vector2.ZERO)


func _end(orb, drift: Vector2):
	orb.done = true
	orb.drift = drift
	orb.queue_redraw()


func _touches(orb, p) -> bool:
	return orb.position.distance_to(p.global_position) <= RADIUS + TOUCH


func _at_guard(orb, p) -> bool:
	return orb.position.distance_to(p.global_position) <= PARRY_REACH


# A swinging blade of the player's within reach, from a swing that hasn't tried this one yet.
func _struck(orb, p) -> bool:
	var point = p.active_sword_point()
	if point == null or p.swing_serial == orb.serial:
		return false
	if point.distance_to(orb.position) > SWORD_REACH + RADIUS:
		return false
	orb.serial = p.swing_serial
	return true


# --- Bars ---

func _slide(bar, delta: float):
	bar.position.x += bar.way * bar.speed * delta
	var p = _players[bar.lane]
	if not bar.done:
		var size = BAR_HIGH if bar.high else BAR_LOW
		var mine = Rect2(bar.position - size / 2.0, size)
		var theirs = Rect2(p.global_position - p.body.size / 2.0, p.body.size)
		if mine.intersects(theirs):
			bar.done = true
			p.take_damage(0.0, Vector2(bar.way * 200.0, -150.0))
			_combo = 0
			_meter = maxf(_meter - Tuning.value("ring_hit_loss"), 0.0)
			_popup(p.global_position + Vector2(0.0, -70.0), bar.visibility_layer, "BAR", COLOR_EMPTY)
			_check_over()
	if absf(bar.position.x - CENTER.x) > 760.0:
		_bars.erase(bar)
		bar.queue_free()


# --- The meter ---

func _gain(key: String, orb, text: String):
	_combo += 1
	_best = maxi(_best, _combo)
	_meter = minf(_meter + Tuning.value(key), METER_MAX)
	_popup(orb.position + Vector2(0.0, -30.0), orb.visibility_layer, text, Color.WHITE)


func _lose(key: String, orb, text: String):
	_combo = 0
	_meter = maxf(_meter - Tuning.value(key), 0.0)
	_popup(orb.position + Vector2(0.0, -30.0), orb.visibility_layer, text, COLOR_EMPTY)
	_check_over()


func _check_over():
	if _meter <= 0.0 and not Moves.on("ring_endless") and not _over:
		_over = true
		Sfx.play("game_over")
		var perfect = tally.get("PERFECT PARRY", 0) + tally.get("PERFECT HIT", 0)
		_over_label.text = "RUN OVER after %.0f s, best combo %d, %d perfect, %d caught through the line\nR to run again · Esc menu" \
			% [maxf(_time, 0.0), _best, perfect, tally.get("CAUGHT!", 0)]
		_over_label.visible = true


# --- Looks ---

func _popup(at: Vector2, layer: int, text: String, color: Color):
	tally[text] = tally.get(text, 0) + 1
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.size = Vector2(180, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = at - Vector2(90.0, 12.0)
	label.visibility_layer = layer
	label.z_index = 20
	if layer == MirrorView.SHADOW:
		# Shown in the reflection: written upside down, so it reads the right way up there.
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(1.0, -1.0)
	add_child(label)
	var tween = label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 26.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


func _sparks(orb, color: Color, count: int):
	for i in count:
		var spark = ColorRect.new()
		spark.size = Vector2(4, 4)
		spark.color = color.lerp(Color.WHITE, randf() * 0.5)
		spark.position = orb.position
		spark.visibility_layer = orb.visibility_layer
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)
		var fly = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0)
		var tween = spark.create_tween().set_parallel()
		tween.tween_property(spark, "position", orb.position + fly, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(spark.queue_free)


func _build_ui():
	var layer = CanvasLayer.new()
	layer.layer = 2  # over the mirrored screen
	add_child(layer)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var box = Control.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -BAR_SIZE.x / 2.0
	box.offset_top = 8.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var label = Label.new()
	label.text = "SYNC"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	var back = ColorRect.new()
	back.position = Vector2(0, 24)
	back.size = BAR_SIZE
	back.color = Color(0.15, 0.15, 0.2)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(back)
	_bar = ColorRect.new()
	_bar.position = Vector2(0, 24)
	_bar.size = BAR_SIZE
	_bar.color = COLOR_METER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar)
	_combo_label = Label.new()
	_combo_label.position = Vector2(BAR_SIZE.x + 10.0, 20.0)
	_combo_label.add_theme_font_size_override("font_size", 18)
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_combo_label)
	var hint = Label.new()
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = 16.0
	hint.offset_top = -30.0
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.text = "Yellow: parry · violet: hit · green: parry together · best on the circle · low bar: jump · high bar: stay down" \
		+ "      F1 · F2 · Esc"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	_over_label = Label.new()
	_over_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_over_label.add_theme_font_size_override("font_size", 32)
	_over_label.add_theme_constant_override("outline_size", 8)
	_over_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_over_label.visible = false
	_over_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_over_label)


func _update_ui():
	_bar.size.x = BAR_SIZE.x * _meter / METER_MAX
	_bar.color = COLOR_EMPTY if _meter < 20.0 and fmod(_time, 0.3) < 0.15 else COLOR_METER
	_combo_label.text = "x%d   (best %d)" % [_combo, _best] if _combo > 0 else "best %d" % _best


# The circle around the middle, only to look at: it lights up on every beat. (The floor line
# halves it; the mirror makes it whole.)
class Circle extends Node2D:
	var ring

	func _draw():
		var beat = ring.beat_length()
		var since = fposmod(ring._time, beat) / beat
		var light = 1.0 - since
		var color = BeatRing.COLOR_CIRCLE.lerp(Color(1, 1, 1, 0.6), light * light)
		draw_arc(BeatRing.CENTER, ring.radius(), PI, TAU, 64, color, 2.0 + 2.0 * light * light, true)


# An orb, a shard or one of a green pair, coming at the middle. Placed by the ring each frame
# (BeatRing._place()) as a function of the time. Before its beat it marks where it'll meet the
# circle.
class Orb extends Node2D:
	var ring
	var kind = 0
	var lane = 0  # whose it is now (it changes going through the line)
	var home = 0  # whose it was first
	var beat = 0.0  # when it meets the circle on its way in
	var speed = 0.0
	var dir = Vector2.UP  # from the middle out to where it comes from
	var pair = -1
	var phase = 0
	var serial = -1  # the swing that last tried it
	var done = false
	var split = false
	var drift = Vector2.ZERO  # done: how it drifts off as it fades

	func color() -> Color:
		match kind:
			BeatRing.Kind.SHARD:
				return BeatRing.COLOR_SHARD
			BeatRing.Kind.PAIR:
				return BeatRing.COLOR_PAIR
		return BeatRing.COLOR_PARRY

	func _draw():
		var c = color()
		if not done and phase == BeatRing.Phase.IN:
			var to_go = beat - ring._time
			if to_go > 0.0 and to_go < BeatRing.MARK_TIME:
				var meet = BeatRing.CENTER + dir * ring.radius() - position
				draw_arc(meet, BeatRing.RADIUS + 6.0 + 10.0 * to_go, 0.0, TAU, 24, Color(c, 0.7 * (1.0 - to_go)), 2.0, true)
		if kind == BeatRing.Kind.SHARD:
			var r = BeatRing.RADIUS * 1.2
			if split:
				draw_colored_polygon(PackedVector2Array([Vector2(-4, -r - 6), Vector2(-r - 4, -6), Vector2(-4, -6)]), c)
				draw_colored_polygon(PackedVector2Array([Vector2(4, r + 6), Vector2(r + 4, 6), Vector2(4, 6)]), c)
				return
			draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)]), c)
			return
		draw_circle(Vector2.ZERO, BeatRing.RADIUS, c)
		draw_circle(Vector2.ZERO, BeatRing.RADIUS * 0.45, Color.WHITE)


# A bar sliding along the floor from one side to the other: low (jump it) or high (stay down).
class Bar extends Node2D:
	var lane = 0
	var high = false
	var way = 1.0
	var speed = 0.0
	var done = false

	func _draw():
		var size = BeatRing.BAR_HIGH if high else BeatRing.BAR_LOW
		draw_rect(Rect2(-size / 2.0, size), BeatRing.COLOR_BAR)
		var edge = -size.y / 2.0 if not high else size.y / 2.0 - 3.0
		draw_rect(Rect2(-size.x / 2.0, edge, size.x, 3.0), Color(1, 1, 1, 0.6))


# Testing alone: plays one of the two (Moves "bifrons_stand_in": "left" is P1, "right" P2) by
# pressing that player's buttons. It walks to where its next thing meets the circle (beside it,
# facing it, for a shard), jumps for one that meets it high up, presses parry or attack on the
# beat, STAND_IN_SKILL of the time; and it jumps low bars and doesn't jump while a high one is
# near. It runs before the players, so they see a press that same frame.
class StandIn extends Node:
	var ring
	var _pressed = {}  # thing -> true once it has answered (or chosen not to)
	var _jumped = {}
	var _held = []
	var _walking = ""  # the left or right action it holds down, if any

	func _ready():
		process_physics_priority = -10

	func _physics_process(_delta):
		for action in _held:
			Input.action_release(action)
		_held.clear()
		var lane = ["off", "left", "right"].find(Moves.value("bifrons_stand_in")) - 1
		if lane < 0 or ring._over or lane >= ring._players.size():
			_hold_walk(null, 0.0)
			return
		var p = ring._players[lane]
		var high_bar_near = false
		for bar in ring._bars:
			if bar.lane != lane or bar.done:
				continue
			var gap = (p.global_position.x - bar.position.x) * bar.way  # > 0: it's coming at them
			if bar.high and gap > -40.0 and gap < 200.0:
				high_bar_near = true
			if not bar.high and gap > 0.0 and gap < 75.0 and not _jumped.has(bar):
				_jumped[bar] = true
				_press(p, "jump")
		var next = null
		for orb in ring._orbs:
			if orb.lane == lane and not orb.done and orb.phase == BeatRing.Phase.IN \
					and orb.beat >= ring._time - 0.05 and (next == null or orb.beat < next.beat):
				next = orb
		if next == null:
			_hold_walk(p, 0.0)
			return
		var meet = BeatRing.CENTER + next.dir * ring.radius()
		var goal = meet.x
		if next.kind == BeatRing.Kind.SHARD:
			goal -= signf(meet.x - p.global_position.x) * BeatRing.STAND_IN_SWORD
		var dx = goal - p.global_position.x
		var to_go = next.beat - ring._time
		var toward = signf(meet.x - p.global_position.x)
		if next.kind == BeatRing.Kind.SHARD and to_go < 0.25 and p.facing != toward and toward != 0.0:
			_hold_walk(p, toward)  # a step toward it turns the player to face it
		else:
			_hold_walk(p, signf(dx) if absf(dx) > 8.0 else 0.0)
		# High up: it jumps so as to be at that height on the beat.
		var rise = p.global_position.y - meet.y - BeatRing.STAND_IN_RISE[next.kind]
		if rise > 0.0 and not _jumped.has(next) and not high_bar_near:
			var speed = sqrt(2.0 * p.GRAVITY * p.JUMP_HEIGHT)
			var h = minf(rise, p.JUMP_HEIGHT)
			var up = (speed - sqrt(maxf(speed * speed - 2.0 * p.GRAVITY * h, 0.0))) / p.GRAVITY
			if to_go <= up + 0.02:
				_jumped[next] = true
				_press(p, "jump")
		if to_go <= BeatRing.STAND_IN_PRESS and not _pressed.has(next):
			_pressed[next] = true
			if randf() < BeatRing.STAND_IN_SKILL:
				_press(p, "attack" if next.kind == BeatRing.Kind.SHARD else "block")
		for key in _pressed.keys():
			if not is_instance_valid(key):
				_pressed.erase(key)
		for key in _jumped.keys():
			if not is_instance_valid(key):
				_jumped.erase(key)

	# Holds left or right (or neither) for its player.
	func _hold_walk(p, way: float):
		var want = ""
		if p != null and way != 0.0:
			want = p._action("right" if way > 0.0 else "left")
		if want == _walking:
			return
		if _walking != "":
			Input.action_release(_walking)
		_walking = want
		if want != "":
			Input.action_press(want)

	func _press(p, button: String):
		var action = p._action(button)
		Input.action_press(action)
		_held.append(action)

	func _exit_tree():
		for action in _held:
			Input.action_release(action)
		if _walking != "":
			Input.action_release(_walking)
