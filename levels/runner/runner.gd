class_name BeatRunner
extends Node2D
## The beat-runner, a prototype for between the bosses (docs/beat_runner.md). The screen is split
## as in the mirrored boss fight: P1 above, P2 in the reflection below. Nobody walks: both run on
## the spot while the world goes by, and things come at them on a beat, each for one of them and
## seen only in their half:
## - a yellow orb: parry it. With Moves "runner_relay" the parry sends it on to the partner: it
##   comes down at them as a violet shard, fast.
## - a violet shard: hit it with the sword before it reaches you (it splits); best on its beat.
## - a green orb, one for each of you at once: parry together.
## - a grey block on the floor, now and then: jump it.
## What comes when: Columna Bifrons's own patterns (ColumnaBifrons.ATTACKS), his strikes turned
## into orbs at his tempo, and between them (Moves "runner_patterns" on "mixed") shards and
## blocks. A sync meter is the run's life: what gets through empties it, parries and hits fill
## it. Every number is on F2 (in this level its page is the runner's). For testing alone a
## stand-in plays one of the two (Moves "bifrons_stand_in": "left" is P1, "right" P2; StandIn).

enum Kind { PARRY, SHARD, COOP, BLOCK }

const ANCHOR_X = 330.0  # where both players run on the spot
const FLOOR_Y = 600.0
const CHEST = 8.0  # orbs and shards fly at a player's chest: this far above their center
const CONTACT_X = 22.0  # in front of a player's center: where an orb meets them
const SHARD_SPOT = 64.0  # in front of a player's center: where a shard comes to the sword
const SHARD_EARLY = 0.2  # s before its beat a shard can be hit...
const SHARD_LATE = 0.12  # ...and after it, before it reaches the player
const ON_BEAT = 0.07  # s either side of its beat: a hit on the beat
const SWORD_REACH = 36.0  # px from the middle of a swinging blade at which a shard is hit
const SPAWN_X = 1230.0  # off the right edge
const LOB_HEIGHT = 150.0  # a shard sent on by a parry arcs this high...
const LOB_REACH = 140.0  # ...and this far out, before it comes down at the partner
const RADIUS = 12.0
# The stand-in: answers this share of what comes at it, pressing parry, attack or jump this long
# before the thing's beat (a swing lands 0.08 s after its press).
const STAND_IN_SKILL = 0.85
const STAND_IN_LEAD = {Kind.PARRY: 0.07, Kind.COOP: 0.07, Kind.SHARD: 0.07, Kind.BLOCK: 0.2}
const STAND_IN_BUTTON = {Kind.PARRY: "block", Kind.COOP: "block", Kind.SHARD: "attack", Kind.BLOCK: "jump"}
const BLOCK_SIZE = Vector2(30.0, 36.0)
const MAX_RALLY = 4  # Moves "runner_rally": shard and orb back and forth at most this often
# Moves "runner_rally": a hit sends an orb back only if the parrier has room to parry it: nothing
# of theirs to parry or jump for this long after it's due (a blade is back at rest 0.33 s after
# its hit lands, and the parry press comes a moment before the orb). The relay doesn't ask: every
# parry sends its shard, and whether the partner hits it is up to them.
const RELAY_ROOM = 0.4
const LOOKAHEAD = 4.0  # s of the run planned ahead
const LEAD_IN = 2.0  # s before the first thing lands
const POST_GAP = 150.0  # the scenery: a post this often, going by
const POST_COUNT = 10
const METER_MAX = 100.0

const COLOR_PARRY = StrikePattern.COLOR
const COLOR_SHARD = ColumnaBifrons.COLOR_SYNC_BEAT
const COLOR_COOP = StrikePattern.COLOR_TOGETHER
const COLOR_BLOCK = Color(0.55, 0.55, 0.62)
const COLOR_POST = Color(1, 1, 1, 0.07)
const COLOR_METER = Color(0.9, 0.88, 0.8)
const COLOR_EMPTY = Color(1.0, 0.2, 0.25)
const BAR_SIZE = Vector2(360.0, 16.0)

var _players = []  # P1, P2: lane 0 and lane 1
var _time = -LEAD_IN  # run time: 0 is the first beat that can land
var _plan_until = 0.0  # run time up to which things are planned
var _waiting = []  # planned things not yet out: [spawn time, Thing], sorted
var _things = []  # things out
var _pairs = {}  # coop id -> how many of its two orbs were parried
var _next_pair = 0
var _meter = 50.0
var _combo = 0
var _best = 0
var _over = false
var _tick_at = 0.0  # Moves "runner_metronome": the next tick
var _posts = []
var _bar: ColorRect
var _status: Label
var _combo_label: Label
var _over_label: Label


# Its numbers on F2 (core/tuning.gd collects them): a page of its own, in the runner.
static func tuning_entries() -> Array:
	return [
		{"page": "runner", "title": "Beat Runner", "scenes": ["levels/runner/"], "header": "TEMPO", "tab": "runner"},
		{"key": "runner_unit", "label": "seconds per unit of a pattern's waits (Bifrons: 0.2)", "default": 0.2, "step": 0.01},
		{"key": "runner_gap", "label": "units between two patterns", "default": 5.0, "step": 1.0},
		{"key": "runner_relay_units", "label": "a parry until the partner's shard is due (units)", "default": 2.0, "step": 1.0},
		{"key": "runner_speedup", "label": "speed-up: this many % quicker every 20 s", "default": 5.0, "step": 1.0},
		{"header": "SPEEDS (PX/S)"},
		{"key": "runner_orb_speed", "label": "an orb (parry it)", "default": 420.0, "step": 20.0},
		{"key": "runner_shard_speed", "label": "a shard (hit it)", "default": 650.0, "step": 20.0},
		{"key": "runner_scroll_speed", "label": "the world going by", "default": 300.0, "step": 20.0},
		{"key": "runner_block_speed", "label": "a block (jump it)", "default": 560.0, "step": 20.0},
		{"header": "THE METER (OF 100)", "column": 1},
		{"key": "runner_start", "label": "at the start", "default": 50.0, "step": 5.0},
		{"key": "runner_parry_gain", "label": "a parry: gained", "default": 2.0, "step": 1.0},
		{"key": "runner_hit_gain", "label": "a shard hit: gained", "default": 3.0, "step": 1.0},
		{"key": "runner_beat_gain", "label": "a shard hit on the beat: gained", "default": 5.0, "step": 1.0},
		{"key": "runner_coop_gain", "label": "both orbs of a pair parried: gained on top", "default": 6.0, "step": 1.0},
		{"key": "runner_hit_loss", "label": "something got through: lost", "default": 10.0, "step": 1.0},
		{"key": "runner_block_loss", "label": "an orb blocked, not parried: lost", "default": 4.0, "step": 1.0},
		{"key": "runner_miss_loss", "label": "a shard from the partner not hit: lost", "default": 2.0, "step": 1.0},
		{"header": "BETWEEN PATTERNS (MIXED)", "column": 1},
		{"key": "runner_extra_chance", "label": "chance of a shard or a block", "default": 0.4, "step": 0.05},
		{"key": "runner_block_share", "label": "of those, a block", "default": 0.3, "step": 0.05},
	]


func _ready():
	process_physics_priority = 100  # after the players: they're put back on the spot each frame
	for p in GameManager.players:
		_players.append(p)
	_players.sort_custom(func(a, b): return a.player_id < b.player_id)
	for p in _players:
		p.running_on = true
		p.facing = 1.0
	_meter = Tuning.value("runner_start")
	_build_scenery()
	_build_ui()
	var stand_in = StandIn.new()
	stand_in.runner = self
	add_child(stand_in)


func _physics_process(delta):
	for p in _players:
		p.global_position.x = ANCHOR_X
		p.velocity.x = 0.0
		p.facing = 1.0
	_scroll_scenery()
	if _over:
		if Input.is_action_just_pressed("restart"):
			GameManager.restart()
		return
	_time += delta
	_plan()
	while not _waiting.is_empty() and _waiting[0][0] <= _time:
		_launch(_waiting.pop_front()[1])
	for thing in _things.duplicate():
		_fly(thing)
	_metronome()
	_update_ui()


# --- What comes when ---

# Plans patterns up to LOOKAHEAD ahead: one of Bifrons's, then (in "mixed") maybe a shard or a
# block, then a gap.
func _plan():
	while _plan_until < _time + LOOKAHEAD:
		var unit = _unit()
		var at = _plan_until
		var pattern = _pick_pattern()
		var flip = randf() < 0.5  # his left sword is P1's lane, or P2's
		for strike in pattern:
			at += strike[0] * unit
			var sword = strike[1]
			var kind = strike[2] if strike.size() > 2 else StrikePattern.CUT
			if kind == StrikePattern.PUSH:
				_plan_thing(Kind.BLOCK, _lane(sword, flip), at)
			elif sword == StrikePattern.BOTH:
				var pair = _next_pair
				_next_pair += 1
				_plan_thing(Kind.COOP, 0, at, pair)
				_plan_thing(Kind.COOP, 1, at, pair)
			else:
				_plan_thing(Kind.PARRY, _lane(sword, flip), at)
		if Moves.value("runner_patterns") == "mixed" and randf() < Tuning.value("runner_extra_chance"):
			at += Tuning.value("runner_gap") * unit / 2.0
			if Moves.on("runner_blocks") and randf() < Tuning.value("runner_block_share"):
				var lanes = [0, 1] if randf() < 0.5 else [randi() % 2]
				for lane in lanes:
					_plan_thing(Kind.BLOCK, lane, at)
			else:
				_plan_thing(Kind.SHARD, randi() % 2, at)
		_plan_until = at + Tuning.value("runner_gap") * unit


# One of Bifrons's series (the ones with strikes), by their weight in pep.
func _pick_pattern() -> Array:
	var names = []
	var weights = []
	for attack_name in ColumnaBifrons.ATTACKS:
		var entry = ColumnaBifrons.ATTACKS[attack_name]
		if not entry.has("strikes"):
			continue
		var weight = ColumnaBifrons.weight_in(attack_name, "pep")
		if weight > 0.0:
			names.append(attack_name)
			weights.append(weight)
	var roll = randf() * weights.reduce(func(a, b): return a + b, 0.0)
	for i in names.size():
		roll -= weights[i]
		if roll <= 0.0:
			return ColumnaBifrons.ATTACKS[names[i]].strikes
	return ColumnaBifrons.ATTACKS[names.back()].strikes


func _lane(sword: int, flip: bool) -> int:
	var lane = 0 if sword == StrikePattern.LEFT else 1
	return 1 - lane if flip else lane


# Seconds per unit of a pattern's waits: Bifrons's tempo, quicker as the run goes on with Moves
# "runner_speedup".
func _unit() -> float:
	var unit = Tuning.value("runner_unit")
	if Moves.on("runner_speedup"):
		unit *= pow(1.0 - Tuning.value("runner_speedup") / 100.0, maxf(_time, 0.0) / 20.0)
	return unit


func _plan_thing(kind: int, lane: int, beat: float, pair = -1):
	var thing = Thing.new()
	thing.kind = kind
	thing.lane = lane
	thing.beat = beat
	thing.pair = pair
	thing.speed = Tuning.value("runner_block_speed") if kind == Kind.BLOCK else \
		Tuning.value("runner_shard_speed" if kind == Kind.SHARD else "runner_orb_speed")
	var meets = SHARD_SPOT if kind == Kind.SHARD else CONTACT_X
	var spawn = beat - (SPAWN_X - ANCHOR_X - meets) / thing.speed
	_waiting.append([spawn, thing])
	_waiting.sort_custom(func(a, b): return a[0] < b[0])


func _launch(thing):
	add_child(thing)
	thing.visibility_layer = _players[thing.lane].visibility_layer  # seen in its player's half only
	_things.append(thing)
	_place(thing)


# --- Things flying ---

func _place(thing):
	var p = _players[thing.lane]
	var chest = p.global_position.y - CHEST
	var to_go = thing.beat - _time  # s until its beat
	match thing.kind:
		Kind.PARRY, Kind.COOP:
			thing.position = Vector2(ANCHOR_X + CONTACT_X + thing.speed * to_go, chest)
		Kind.BLOCK:
			thing.position = Vector2(ANCHOR_X + CONTACT_X + thing.speed * to_go, FLOOR_Y - BLOCK_SIZE.y / 2.0)
		Kind.SHARD:
			if thing.lob_from >= 0.0:
				# Sent on by a parry: up and out from where it was parried, and down at the sword.
				var u = clampf((_time - thing.lob_from) / (thing.beat - thing.lob_from), 0.0, 1.0)
				var x = lerpf(ANCHOR_X + CONTACT_X, ANCHOR_X + SHARD_SPOT, u) + LOB_REACH * sin(PI * u)
				thing.position = Vector2(x, chest - LOB_HEIGHT * sin(PI * u))
			if to_go >= 0.0 and thing.lob_from < 0.0:
				thing.position = Vector2(ANCHOR_X + SHARD_SPOT + thing.speed * to_go, chest)
			elif to_go < 0.0:
				var late = clampf(-to_go / SHARD_LATE, 0.0, 1.0)
				thing.position = Vector2(lerpf(ANCHOR_X + SHARD_SPOT, ANCHOR_X + CONTACT_X, late), chest)
	thing.queue_redraw()


func _fly(thing):
	if thing.done:
		var on = thing.speed if thing.kind == Kind.BLOCK else Tuning.value("runner_scroll_speed")
		thing.position.x -= on * get_physics_process_delta_time()
		if thing.position.x < -60.0 or _time > thing.done_at + 1.0:
			_things.erase(thing)
			thing.queue_free()
		return
	_place(thing)
	var p = _players[thing.lane]
	match thing.kind:
		Kind.PARRY, Kind.COOP:
			if _time >= thing.beat:
				_meet_orb(thing, p)
		Kind.BLOCK:
			if _time >= thing.beat:
				_meet_block(thing, p)
		Kind.SHARD:
			if _time >= thing.beat - SHARD_EARLY and _struck(thing, p):
				_split(thing, p)
			elif _time >= thing.beat + SHARD_LATE:
				_shard_through(thing, p)


# An orb reaches its player: parried, blocked or taken.
func _meet_orb(thing, p):
	_finish(thing)
	if p.is_perfect_parry():
		p.on_perfect_parry(thing.kind == Kind.COOP)
		_sparks(thing, COLOR_PARRY.lerp(Color.WHITE, 0.5), 12)
		_gain("runner_parry_gain", thing, "PARRY")
		if thing.kind == Kind.COOP:
			_pairs[thing.pair] = _pairs.get(thing.pair, 0) + 1
			if _pairs[thing.pair] == 2:
				_gain("runner_coop_gain", thing, "TOGETHER")
				Sfx.play("counter_hit", -8.0)
		elif Moves.on("runner_relay"):
			_send_shard(1 - thing.lane, thing.rally)
	elif p.is_blocking():
		Sfx.play("chip")
		_sparks(thing, COLOR_BLOCK, 6)
		_lose("runner_block_loss", thing, "BLOCKED")
	else:
		p.take_damage(Vector2(-160.0, -120.0))
		_lose("runner_hit_loss", thing, "HIT")


# When a shard sent on now would be due.
func _relay_due() -> float:
	return _time + Tuning.value("runner_relay_units") * _unit()


# True if nothing for that lane to parry or jump comes between now and RELAY_ROOM after `due`.
func _has_room(lane: int, due: float) -> bool:
	var coming = _things.duplicate()
	for planned in _waiting:
		coming.append(planned[1])
	for thing in coming:
		if thing.lane == lane and not thing.done and thing.kind != Kind.SHARD \
				and thing.beat > _time and thing.beat <= due + RELAY_ROOM:
			return false
	return true


# A parried orb goes on to the partner: a shard arcing over to them, due after the relay time.
func _send_shard(lane: int, rally: int):
	var shard = Thing.new()
	shard.kind = Kind.SHARD
	shard.lane = lane
	shard.lob_from = _time
	shard.beat = _relay_due()
	shard.speed = Tuning.value("runner_shard_speed")
	shard.sent = true
	shard.rally = rally + 1
	_launch(shard)


# A swinging blade of its player's within reach of the shard, from a swing that hasn't hit yet.
func _struck(thing, p) -> bool:
	var point = p.active_sword_point()
	if point == null or p.swing_serial == thing.serial:
		return false
	if point.distance_to(thing.position) > SWORD_REACH + RADIUS:
		return false
	thing.serial = p.swing_serial
	return true


func _split(thing, _p):
	_finish(thing)
	thing.split = true
	var on_beat = absf(_time - thing.beat) <= ON_BEAT
	Sfx.play("sync_hit", -4.0)
	if on_beat:
		Sfx.play("on_beat", -4.0)
	_sparks(thing, COLOR_SHARD.lerp(Color.WHITE, 0.4), 14 if on_beat else 8)
	_gain("runner_beat_gain" if on_beat else "runner_hit_gain", thing, "ON THE BEAT" if on_beat else "HIT")
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(3.0)
	if thing.sent and Moves.on("runner_rally") and thing.rally < MAX_RALLY \
			and _has_room(1 - thing.lane, _relay_due()):
		_return_orb(1 - thing.lane, thing.rally)


# Moves "runner_rally": the split shard's half goes back to the one who parried, as an orb.
func _return_orb(lane: int, rally: int):
	var orb = Thing.new()
	orb.kind = Kind.PARRY
	orb.lane = lane
	orb.beat = _time + Tuning.value("runner_relay_units") * _unit()
	orb.speed = 2.0 * LOB_REACH / (orb.beat - _time)
	orb.rally = rally
	_launch(orb)


# A shard nobody hit: one sent on by the partner's parry was a chance missed; any other hits.
func _shard_through(thing, p):
	_finish(thing)
	if thing.sent:
		_lose("runner_miss_loss", thing, "MISSED")
	else:
		p.take_damage(Vector2(-160.0, -120.0))
		_lose("runner_hit_loss", thing, "HIT")


func _meet_block(thing, p):
	_finish(thing)
	var feet = p.global_position.y + p.body.size.y / 2.0
	if feet > FLOOR_Y - BLOCK_SIZE.y + 4.0:
		p.take_damage(Vector2(-120.0, -260.0))
		_lose("runner_hit_loss", thing, "TRIPPED")
	else:
		_show(thing, "JUMP", COLOR_BLOCK.lightened(0.4))


func _finish(thing):
	thing.done = true
	thing.done_at = _time
	thing.queue_redraw()


# --- The meter ---

func _gain(key: String, thing, text: String):
	_combo += 1
	_best = maxi(_best, _combo)
	_meter = minf(_meter + Tuning.value(key), METER_MAX)
	_show(thing, text, Color.WHITE)


func _lose(key: String, thing, text: String):
	_combo = 0
	_meter = maxf(_meter - Tuning.value(key), 0.0)
	_show(thing, text, COLOR_EMPTY)
	if _meter <= 0.0 and not Moves.on("runner_endless"):
		_over = true
		Sfx.play("game_over")
		_over_label.text = "RUN OVER after %.0f s, best combo %d\nR to run again · Esc menu" % [maxf(_time, 0.0), _best]
		_over_label.visible = true


func _metronome():
	if not Moves.on("runner_metronome") or _time < _tick_at:
		return
	var beat = 4.0 * _unit()
	_tick_at = (floorf(_time / beat) + 1.0) * beat
	Sfx.play("call_tick", -12.0)


# --- Looks ---

# Text over the player whose thing it was, in their half only.
func _show(thing, text: String, color: Color):
	thing.result = text
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.size = Vector2(160, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(ANCHOR_X - 80.0, FLOOR_Y - 110.0)
	label.visibility_layer = thing.visibility_layer
	label.z_index = 20
	if thing.visibility_layer == MirrorView.SHADOW:
		# Shown in the reflection: written upside down, so it reads the right way up there.
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(1.0, -1.0)
	add_child(label)
	var tween = label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


func _sparks(thing, color: Color, count: int):
	for i in count:
		var spark = ColorRect.new()
		spark.size = Vector2(4, 4)
		spark.color = color.lerp(Color.WHITE, randf() * 0.5)
		spark.position = thing.position
		spark.visibility_layer = thing.visibility_layer
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)
		var fly = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0)
		var tween = spark.create_tween().set_parallel()
		tween.tween_property(spark, "position", thing.position + fly, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(spark.queue_free)


# Posts going by: the world moving, the players running.
func _build_scenery():
	for i in POST_COUNT:
		var post = ColorRect.new()
		post.size = Vector2(3.0, 380.0)
		post.color = COLOR_POST
		post.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(post)
		_posts.append(post)


func _scroll_scenery():
	var span = POST_GAP * POST_COUNT
	var moved = Tuning.value("runner_scroll_speed") * maxf(_time + LEAD_IN, 0.0)
	for i in _posts.size():
		_posts[i].position = Vector2(fposmod(i * POST_GAP - moved, span) - POST_GAP, FLOOR_Y - 380.0)


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
	_status = Label.new()
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.anchor_right = 1.0
	_status.offset_left = 16.0
	_status.offset_top = -30.0
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.6)
	_status.text = "Yellow: parry · violet: hit it · green: parry together · grey: jump" \
		+ "      F1: switches (Runner) · F2: numbers · Esc: menu"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status)
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


# Testing alone: plays one of the two (Moves "bifrons_stand_in": "left" is P1, "right" P2) by
# pressing that player's buttons, as BifronsStandIn does in Bifrons's fight: parry for orbs,
# attack for shards, jump for blocks, STAND_IN_LEAD before each one's beat, STAND_IN_SKILL of
# the time (the rest it lets through). It runs before the players, so they see a press that
# same frame; a press is let go the frame after.
class StandIn extends Node:
	var runner
	var _answered = {}  # thing -> true once it has pressed (or chosen not to) for it
	var _held = []

	func _ready():
		process_physics_priority = -10

	func _physics_process(_delta):
		for action in _held:
			Input.action_release(action)
		_held.clear()
		var lane = ["off", "left", "right"].find(Moves.value("bifrons_stand_in")) - 1
		if lane < 0 or runner._over or lane >= runner._players.size():
			return
		var p = runner._players[lane]
		for thing in runner._things:
			if thing.lane != lane or thing.done or _answered.has(thing):
				continue
			if thing.beat - runner._time > BeatRunner.STAND_IN_LEAD[thing.kind]:
				continue
			_answered[thing] = true
			if randf() < BeatRunner.STAND_IN_SKILL:
				var action = p.action(BeatRunner.STAND_IN_BUTTON[thing.kind])
				Input.action_press(action)
				_held.append(action)
		for thing in _answered.keys():
			if not is_instance_valid(thing) or thing.done:
				_answered.erase(thing)

	func _exit_tree():
		for action in _held:
			Input.action_release(action)


# One thing coming at a player: an orb, a shard or a block, drawn in its kind's color. Placed by
# the runner each frame (BeatRunner._place()) as a function of the run time.
class Thing extends Node2D:
	var kind = 0
	var lane = 0
	var beat = 0.0  # run time it meets its player
	var speed = 0.0
	var pair = -1  # a coop orb: its pair's id
	var lob_from = -1.0  # a shard sent on by a parry: the run time it was sent
	var sent = false
	var rally = 0
	var serial = -1  # the swing that last tried it
	var done = false
	var done_at = 0.0
	var split = false
	var result = ""  # what became of it: the text shown ("PARRY", "HIT", ...)

	func _draw():
		match kind:
			BeatRunner.Kind.PARRY, BeatRunner.Kind.COOP:
				var color = BeatRunner.COLOR_COOP if kind == BeatRunner.Kind.COOP else BeatRunner.COLOR_PARRY
				if done:
					color = Color(color, 0.25)
				draw_circle(Vector2.ZERO, BeatRunner.RADIUS, color)
				draw_circle(Vector2.ZERO, BeatRunner.RADIUS * 0.45, Color(1, 1, 1, color.a))
			BeatRunner.Kind.SHARD:
				var r = BeatRunner.RADIUS * 1.2
				var color = BeatRunner.COLOR_SHARD
				if split:
					# Two halves, apart.
					draw_colored_polygon(PackedVector2Array([Vector2(-4, -r - 6), Vector2(-r - 4, -6), Vector2(-4, -6)]), color)
					draw_colored_polygon(PackedVector2Array([Vector2(4, r + 6), Vector2(r + 4, 6), Vector2(4, 6)]), color)
					return
				if done:
					color = Color(color, 0.25)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)]), color)
			BeatRunner.Kind.BLOCK:
				var size = BeatRunner.BLOCK_SIZE
				draw_rect(Rect2(-size / 2.0, size), BeatRunner.COLOR_BLOCK)
				draw_rect(Rect2(-size.x / 2.0, -size.y / 2.0, size.x, 3.0), Color(1, 1, 1, 0.6))
