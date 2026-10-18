class_name BeatRing
extends Node2D
## The beat-ring, a second prototype for between the bosses (docs/beat_ring.md): Columna
## Bifrons's fight without him. The players stand in his room, split as in the mirrored boss
## fight (P1 above, P2 in the reflection below), and move freely. Around the middle of the floor
## line lies a circle, only to look at: where a thing meets it is where, and when, it's best
## answered (its beat); it lights up as one does.
## His own patterns come (ColumnaBifrons.ATTACKS, at his tempo), each strike as a thing flying
## level at chest height at the player its sword fights, from that player's side of the circle,
## seen only in their half:
## - a yellow arrowhead: parry it (when it's at your guard), or it hits you;
## - green arrowheads, one each at once (his strikes with both swords): parry together;
## - between patterns, a grey shard: hit it on your own (along its cut); shards never hit anyone.
## A parried yellow arrowhead sends a violet shard to the partner (Moves "ring_relay"): it comes
## up where the parry was and runs along the circle, over the parrier's half, through the line
## and on along the partner's half, until it's hit (missed, it fades out on its way to the line).
## It meets the partner's side of the circle as long after the parry as the partner's hit comes
## after a parry in the boss fight (Tuning "sync_window_delay", "sync_beat_time"). It's very
## fast over the parrier's half and slows down from the line on, to come slowly where it's to be
## hit (Tuning "ring_relay_slow"); the longer way when the two are on one side, so faster still.
## Sides: as with him, the two stand diagonally, one on each side of the circle. His crossing puts
## them on one side: a green arrow for one of them, then a heavy pair for both on the other's
## side (dash over). His leap brings them apart again, as a sweep: a green arrow slanting down at
## one, through the middle into the other's half and up to the circle's other side.
## Now and then a bar slides in along the floor (low: jump it; high: stay under it). A sync meter
## is the run's life. Every number is on F2 (the ring's page).

const Orb = preload("ring_orb.gd")  # a thing coming at a player
const StandIn = preload("ring_stand_in.gd")  # testing alone

enum Kind { PARRY, SHARD, PAIR, SWEEP, RELAY, CHARGE }

const CENTER = Vector2(576.0, 600.0)  # the middle of the floor line, the circle's center
const FLOOR_Y = 600.0
const CHEST = 28.0  # above the floor: where things fly, at a standing player's chest
const SIZE = 12.0  # a thing's
const TOUCH = 16.0  # a thing this much past its size from a player's center reaches them
const PARRY_REACH = 46.0  # a thing this close to a player's center is at their guard: parryable
const SWORD_REACH = 36.0  # px from the middle of a swinging blade at which a shard is hit
const SPAWN_X = 760.0  # from the middle, out to the side: things start out of sight
const ARROW_LENGTH = 46.0  # the green arrows'
const HEAVY_SIZE = 1.5  # the crossing's heavy pair is this much bigger...
const HEAVY_LOSS = 2.0  # ...and costs this much more taken
const RELAY_EARLY = 0.05  # s before its beat a violet shard counts as at its meeting point
const RELAY_TRAIL = 0.07  # s: a violet shard's trail reaches back to where it was this long ago
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
const STAND_IN_SWORD = 52.0  # px it stands inside a shard's meeting point, facing out at it
const STAND_IN_GUARD = 20.0  # ...and inside an arrowhead's

const COLOR_PARRY = StrikePattern.COLOR
const COLOR_SHARD = Color(0.7, 0.7, 0.76)  # grey: a shard to hit on your own
const COLOR_RELAY = ColumnaBifrons.COLOR_SYNC_BEAT  # violet: one your partner's parry sent you
const COLOR_TOGETHER = StrikePattern.COLOR_TOGETHER  # green: it takes both of you
const COLOR_BAR = Color(0.55, 0.55, 0.62)
const COLOR_CIRCLE = Color(1, 1, 1, 0.22)
const COLOR_METER = Color(0.9, 0.88, 0.8)
const COLOR_EMPTY = Color(1.0, 0.2, 0.25)
const BAR_SIZE = Vector2(360.0, 16.0)

var tally = {}  # what happened, by the text shown: counted for the end of a run
var _players = []  # P1, P2: lane 0 and lane 1
var _time = -LEAD_IN
var _sides = [-1.0, 1.0]  # per lane: the side of the circle that player belongs on now
var _plan_sides = [-1.0, 1.0]  # ...and as planned, LOOKAHEAD ahead
var _changes = []  # [run time, sides]: when the sides change (planned with the crossing or the sweep)
var _plan_until = 0.0  # run time up to which things are planned
var _beats = []  # planned beats: the circle lights up on each
var _waiting = []  # planned things not out yet: [spawn time, node], sorted
var _orbs = []
var _bars = []
var _pairs = {}  # pair id -> how many of its two were parried
var _next_pair = 0
var _meter = 50.0
var _combo = 0
var _best = 0
var _over = false
var _circle: Node2D
var _bar: ColorRect
var _combo_label: Label
var _over_label: Label


# Its numbers on F2 (core/tuning.gd collects them): a page of its own, in the ring.
static func tuning_entries() -> Array:
	return [
		{"page": "ring", "title": "Beat Ring", "scenes": ["levels/ring/"], "header": "HIS PATTERNS", "tab": "ring"},
		{"key": "ring_unit", "label": "seconds per unit of his waits (his own: 0.2)", "default": 0.2, "step": 0.01},
		{"key": "ring_gap", "label": "units between two of his patterns", "default": 5.0, "step": 1.0},
		{"key": "ring_extra_chance", "label": "between two: chance of a grey shard or a bar", "default": 0.4, "step": 0.05},
		{"key": "ring_bar_share", "label": "of those, a bar", "default": 0.15, "step": 0.05},
		{"header": "SIZES AND SPEEDS"},
		{"key": "ring_radius", "label": "the circle's radius (px)", "default": 140.0, "step": 10.0},
		{"key": "ring_orb_speed", "label": "an arrowhead, a shard or a green arrow (px/s)", "default": 380.0, "step": 20.0},
		{"key": "ring_sweep_speed", "label": "a sweep (px/s)", "default": 520.0, "step": 20.0},
		{"key": "ring_bar_speed", "label": "a bar (px/s)", "default": 300.0, "step": 20.0},
		{"key": "ring_relay_slow", "label": "a violet shard where it's to be hit (px/s)", "default": 600.0, "step": 50.0},
		{"key": "ring_relay_brake", "label": "...slowing to that from the line on, over at least (px)", "default": 140.0, "step": 10.0},
		{"key": "ring_perfect", "label": "perfect: this close to its beat (s, either side)", "default": 0.07, "step": 0.01},
		{"key": "ring_good", "label": "good: this close (s)", "default": 0.16, "step": 0.01},
		{"header": "THE METER (OF 100)", "column": 1},
		{"key": "ring_start", "label": "at the start", "default": 50.0, "step": 5.0},
		{"key": "ring_perfect_gain", "label": "perfect: gained", "default": 4.0, "step": 1.0},
		{"key": "ring_good_gain", "label": "good: gained", "default": 2.0, "step": 1.0},
		{"key": "ring_ok_gain", "label": "taken anywhere else: gained", "default": 1.0, "step": 1.0},
		{"key": "ring_sweep_gain", "label": "a sweep parried by both: gained on top", "default": 6.0, "step": 1.0},
		{"key": "ring_pair_gain", "label": "both of a pair parried: gained on top", "default": 6.0, "step": 1.0},
		{"key": "ring_hit_loss", "label": "hit by an arrowhead, the sweep or a bar: lost (heavy pair: x2)", "default": 10.0, "step": 1.0},
		{"key": "ring_block_loss", "label": "an orb blocked, not parried: lost", "default": 4.0, "step": 1.0},
		{"key": "ring_relay_gain", "label": "a violet shard hit (a sync hit): gained on top", "default": 3.0, "step": 1.0},
		{"key": "ring_miss_loss", "label": "a violet shard not hit: lost", "default": 2.0, "step": 1.0},
		{"key": "ring_lost_loss", "label": "one nobody took: lost", "default": 3.0, "step": 1.0},
	]


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
	while not _changes.is_empty() and _changes[0][0] <= _time:
		_sides = _changes.pop_front()[1]
	_plan()
	while not _waiting.is_empty() and _waiting[0][0] <= _time:
		_launch(_waiting.pop_front()[1])
	for orb in _orbs.duplicate():
		_fly(orb)
	for bar in _bars.duplicate():
		_slide(bar, delta)
	while _beats.size() > 1 and _beats[1] <= _time:
		_beats.pop_front()
	_circle.queue_redraw()
	_update_ui()


func radius() -> float:
	return Tuning.value("ring_radius")


# How far from the middle, sideways, a level thing meets the circle (at chest height)...
func meet_x() -> float:
	var r = radius()
	return sqrt(maxf(r * r - CHEST * CHEST, 0.0))


# ...and the angle of that point above the floor line, seen from the middle.
func chest_angle() -> float:
	return asin(clampf(CHEST / radius(), 0.0, 1.0))


func unit() -> float:
	return Tuning.value("ring_unit")


# --- What comes when: his patterns ---

# One of his series after another, chosen as he would (by weight, in pep with the two on two
# sides, in ppe with both on one), and maybe a grey shard or a bar in between.
func _plan():
	while _plan_until < _time + LOOKAHEAD:
		var at = maxf(_plan_until, 0.0)
		var stacked = _plan_sides[0] == _plan_sides[1]
		var choice = _pick("ppe" if stacked else "pep")
		match choice:
			"CROSSING":
				at = _plan_crossing(at)
			"SWEEP", "LEAP":
				at = _plan_sweep(at, choice)
			_:
				at = _plan_strikes(ColumnaBifrons.ATTACKS[choice].strikes, at)
		if randf() < Tuning.value("ring_extra_chance"):
			at += Tuning.value("ring_gap") * unit() / 2.0
			var lane = randi() % 2
			if Moves.on("ring_bars") and randf() < Tuning.value("ring_bar_share"):
				var from = -1.0 if randf() < 0.5 else 1.0
				var high = randf() < 0.5
				for bar_lane in ([0, 1] if randf() < 0.3 else [lane]):
					_plan_bar(bar_lane, at, high, from)
			else:
				_plan_orb(Kind.SHARD, lane, at, _plan_sides[lane])
		_plan_until = at + Tuning.value("ring_gap") * unit()


# His choice, by the weights of his ATTACKS in that situation: the strike series, his crossing
# (from two sides to one), his sweep (stays on two sides) and his leap (from one side to two).
func _pick(situation: String) -> String:
	var names = []
	var weights = []
	for attack_name in ColumnaBifrons.ATTACKS:
		var entry = ColumnaBifrons.ATTACKS[attack_name]
		var special = attack_name in ["CROSSING", "SWEEP", "LEAP"]
		if not entry.has("strikes") and not special:
			continue
		if special and not Moves.on("ring_changes"):
			continue
		var weight = ColumnaBifrons.weight_in(attack_name, situation)
		if weight > 0.0:
			names.append(attack_name)
			weights.append(weight)
	if names.is_empty():
		return "DOUBLE"
	var roll = randf() * weights.reduce(func(a, b): return a + b, 0.0)
	for i in names.size():
		roll -= weights[i]
		if roll <= 0.0:
			return names[i]
	return names.back()


# A series of his strikes: each sword's at the player it fights (his left one P1, or mirrored),
# from their side; both swords at once, a green pair.
func _plan_strikes(strikes: Array, at: float) -> float:
	var flip = randf() < 0.5
	for strike in strikes:
		at += strike[0] * unit()
		var kind = strike[2] if strike.size() > 2 else StrikePattern.CUT
		if kind == StrikePattern.PUSH:
			continue
		if strike[1] == StrikePattern.BOTH:
			if Moves.on("ring_pairs"):
				for lane in 2:
					_plan_orb(Kind.PAIR, lane, at, _plan_sides[lane], _next_pair)
				_next_pair += 1
		else:
			var lane = 0 if strike[1] == StrikePattern.LEFT else 1
			if flip:
				lane = 1 - lane
			_plan_orb(Kind.PARRY, lane, at, _plan_sides[lane])
	return at


# His crossing, at his tempo: a green arrow for one of them, from their side; then, where the
# other one is, a heavy pair for both. The one the arrow was for has to get over (dash): from
# then on both are on one side.
func _plan_crossing(at: float) -> float:
	var over = randi() % 2
	var to = _plan_sides[1 - over]
	for strike in ColumnaBifrons.ATTACKS["CROSSING"].strikes:
		at += strike[0] * unit()
		var kind = strike[2] if strike.size() > 2 else StrikePattern.CUT
		if kind == StrikePattern.CHARGE:
			_plan_orb(Kind.CHARGE, over, at, _plan_sides[over])
			_changes.append([at, [to, to]])
		elif strike[1] == StrikePattern.BOTH:
			for lane in 2:
				_plan_orb(Kind.PAIR, lane, at, to, _next_pair, true)
			_next_pair += 1
	_plan_sides = [to, to]
	return at


# His sweep (two sides, staying so) or his leap (one side to two): a sweep that comes slanting at
# one of them from their side and goes on through the middle to the circle's other side for the
# other. On one side, that one has to get over.
func _plan_sweep(at: float, attack_name: String) -> float:
	at += (Leap.WINDUP_UNITS if attack_name == "LEAP" else Sweep.WINDUP_UNITS) * unit()
	var first = randi() % 2
	var side = _plan_sides[first]
	var sweep = _plan_orb(Kind.SWEEP, first, at, side)
	var sides = [side, side]
	sides[1 - first] = -side
	if sides != _plan_sides:
		_changes.append([at - 1.0, sides])  # the other one should be on their way
		_changes.sort_custom(func(x, y): return x[0] < y[0])
		_plan_sides = sides
	return sweep.second_beat()


func _plan_orb(kind: int, lane: int, beat: float, side: float, pair = -1, heavy = false):
	var orb = Orb.new()
	orb.ring = self
	orb.kind = kind
	orb.lane = lane
	orb.first = lane
	orb.beat = beat
	orb.side = side
	orb.pair = pair
	orb.heavy = heavy
	orb.speed = Tuning.value("ring_sweep_speed" if kind == Kind.SWEEP else "ring_orb_speed")
	var start = SPAWN_X - meet_x()
	if kind == Kind.SWEEP:
		start = SPAWN_X / cos(chest_angle()) - radius()
		_beats.append(orb.second_beat())
	_beats.append(beat)
	_beats.sort()
	_queue(beat - start / orb.speed, orb)
	return orb


func _plan_bar(lane: int, at: float, high: bool, from: float):
	var bar = Bar.new()
	bar.lane = lane
	bar.high = high
	bar.way = -from  # from the left wall it goes right
	bar.speed = Tuning.value("ring_bar_speed")
	bar.position = Vector2(CENTER.x + from * 700.0, FLOOR_Y - (HIGH_CLEAR + BAR_HIGH.y / 2.0 if high else BAR_LOW.y / 2.0))
	_queue(at, bar)


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


# --- Things flying ---

# Where it is. A level one: on its way across at chest height. The sweep: slanting down at the
# middle, and past it (through the line, in the other's half) rising out again, mirrored. A violet
# shard: along the circle.
func _place(orb):
	match orb.kind:
		Kind.SWEEP:
			var out = Vector2(orb.side * cos(chest_angle()), -sin(chest_angle()))  # from the middle to where it comes from
			var from_middle = radius() + orb.speed * (orb.beat - _time)
			if from_middle >= 0.0:
				orb.position = CENTER + out * from_middle
			else:
				orb.position = CENTER + Vector2(-out.x, out.y) * -from_middle
		Kind.RELAY:
			orb.position = arc_point(orb.side, orb.travelled(_time))
		_:
			orb.position = Vector2(CENTER.x + orb.side * (meet_x() + orb.speed * (orb.beat - _time)), FLOOR_Y - CHEST)
	orb.queue_redraw()


# A point on the circle, `u` radians along a violet shard's way from where it was born on `side`
# (at chest height): up over that half to the line on the far side, then (in the other half)
# back over it to the line on the near side.
func arc_point(side: float, u: float) -> Vector2:
	var a = chest_angle()
	var phi: float
	if u <= PI - a:
		phi = PI - a - u if side < 0.0 else a + u
	else:
		var w = u - (PI - a)
		phi = w if side < 0.0 else PI - w
	return CENTER + radius() * Vector2(cos(phi), -sin(phi))


func _fly(orb):
	if orb.done:
		if orb.kind == Kind.RELAY and not orb.split:
			_place(orb)  # a violet shard missed runs on along the circle as it fades
		else:
			orb.position += orb.drift * get_physics_process_delta_time()
		orb.modulate.a = maxf(orb.modulate.a - 2.5 * get_physics_process_delta_time(), 0.0)
		if orb.modulate.a <= 0.0:
			_orbs.erase(orb)
			orb.queue_free()
		return
	_place(orb)
	match orb.kind:
		Kind.SWEEP:
			_sweep(orb)
			return
		Kind.RELAY:
			_relay(orb)
			return
	var p = _players[orb.lane]
	var off = absf(_time - orb.beat)
	if orb.kind == Kind.SHARD:
		# A shard is a target, not an attack: it never hits anyone.
		if _struck(orb, p, orb.position):
			_answer(orb, off, "HIT")
			_end(orb, Vector2.ZERO)
	elif _at_guard(orb, p) and p.is_perfect_parry():
		p.on_perfect_parry(orb.kind != Kind.PARRY)
		_answer(orb, off, "PARRY")
		_end(orb, Vector2(orb.side * 300.0, -80.0))  # knocked back the way it came
		if orb.kind == Kind.PARRY and Moves.on("ring_relay"):
			_send_relay(orb)
		if orb.kind == Kind.PAIR:
			_pairs[orb.pair] = _pairs.get(orb.pair, 0) + 1
			if _pairs[orb.pair] == 2:
				_gain("ring_pair_gain", orb, "TOGETHER")
				Sfx.play("counter_hit", -8.0)
	elif _touches(orb, p):
		if p.is_blocking():
			Sfx.play("chip")
			_lose("ring_block_loss", orb, "BLOCKED")
		else:
			_taken(orb, p)
		_end(orb, Vector2.ZERO)
	if not orb.done and (orb.position.x - CENTER.x) * orb.side < -meet_x():
		_lose("ring_lost_loss", orb, "LOST")  # across the circle and out: nobody took it
		_end(orb, Vector2(-orb.side * orb.speed, 0.0))


# --- The violet shard: the partner's hit after a parry ---

# From a parry to its shard's beat: the boss fight's, from the parry to the middle of the sync
# hit's beat (StrikePattern.window_delay(): his guard opens; Tuning "sync_beat_time": the beat's
# length). 0.18 and 0.12: 0.24 s.
func relay_delay() -> float:
	return StrikePattern.window_delay() + Tuning.value("sync_beat_time") / 2.0


# ...and how long after its beat it can still be hit: as long as his guard would stay open.
func relay_late() -> float:
	return StrikePattern.window_delay() + StrikePattern.window_time() - relay_delay()


# A yellow arrowhead parried: a violet shard for the partner, born where the parry was (on that
# side of the circle). It runs along the circle so as to meet it on the partner's side (where
# they belong just now) relay_delay() later: half the circle when they're on the other side, the
# long way round when they're on the same one. Fast, then slowing down (_pace_relay()).
func _send_relay(parried):
	var shard = Orb.new()
	shard.ring = self
	shard.kind = Kind.RELAY
	shard.lane = parried.lane  # seen in the parrier's half first
	shard.first = parried.lane
	shard.target = 1 - parried.lane
	shard.side = parried.side
	shard.meet = _sides[shard.target]
	var a = chest_angle()
	shard.meet_u = PI if shard.meet != shard.side else TAU - 2.0 * a
	shard.end_u = TAU - a
	shard.born = _time
	shard.beat = _time + relay_delay()
	_pace_relay(shard)
	_launch(shard)


# Its pace: fast over the parrier's half, then slowing down, from the line on but over at least
# "ring_relay_brake" px, to "ring_relay_slow" where it's to be hit; past that it glides on toward
# the line, slower and slower. Slowing down, its speed eases from the one to the other in time (a
# smoothstep), so it covers that stretch at their mean. How fast it has to be before is what makes
# it meet the circle on its beat.
func _pace_relay(shard):
	var time = relay_delay()
	var slow = minf(Tuning.value("ring_relay_slow") / radius(), 0.5 * shard.meet_u / time)  # radians/s
	shard.brake_u = maxf(minf(PI - chest_angle(), shard.meet_u - Tuning.value("ring_relay_brake") / radius()), 0.0)
	var before = shard.brake_u
	var braking = shard.meet_u - shard.brake_u
	# before / fast + 2 * braking / (fast + slow) = time, solved for fast:
	var b = time * slow - before - 2.0 * braking
	var fast = (-b + sqrt(b * b + 4.0 * time * before * slow)) / (2.0 * time)
	shard.speed = fast
	shard.slow = slow
	shard.brake_time = 2.0 * braking / (fast + slow)


func _relay(orb):
	var partner = _players[orb.target]
	if orb.lane != orb.target and orb.travelled(_time) > PI - chest_angle():
		# Through the line: into the partner's half.
		orb.lane = orb.target
		orb.visibility_layer = partner.visibility_layer
	var off = _time - orb.beat
	if orb.lane == orb.target or off >= -RELAY_EARLY:
		# The partner's blade: where the shard is, or (it's quick) where it meets the circle, near
		# its beat.
		var near_beat = off >= -RELAY_EARLY and off <= relay_late()
		var meeting = arc_point(orb.side, orb.meet_u)
		if _struck(orb, partner, orb.position) or (near_beat and _struck(orb, partner, meeting)):
			var perfect = Tuning.value("sync_beat_time") / 2.0
			_answer(orb, absf(off), "SYNC HIT", perfect, maxf(relay_late(), RELAY_EARLY))
			_gain("ring_relay_gain", orb, "")
			_end(orb, Vector2.ZERO)
			return
	if off > relay_late():  # his guard would be closed again
		_lose("ring_miss_loss", orb, "MISSED")
		_end(orb, Vector2.ZERO)


# --- The sweep ---

# It reaches the first player, goes through the middle into the other's half and reaches them.
# Each parries it as it comes (it flies on either way). On its way down it hits the first one if
# they don't; through the line it can't hit anyone (it would come from behind). Both parried: a
# bonus.
func _sweep(orb):
	var second = orb.beat - _time + radius() / orb.speed <= 0.0  # past the middle
	if second and orb.lane == orb.first:
		if not orb.answered.has(orb.first):
			_lose("ring_lost_loss", orb, "MISSED")
		orb.lane = 1 - orb.first
		orb.visibility_layer = _players[orb.lane].visibility_layer
		_sparks(orb, COLOR_TOGETHER, 6)
	var p = _players[orb.lane]
	if not orb.answered.has(orb.lane):
		var beat = orb.second_beat() if second else orb.beat
		if _at_guard(orb, p) and p.is_perfect_parry():
			orb.answered[orb.lane] = true
			p.on_perfect_parry(true)
			_answer(orb, absf(_time - beat), "PARRY")
			if orb.answered.size() == 2:
				_gain("ring_sweep_gain", orb, "SWEPT TOGETHER")
				Sfx.play("counter_hit", -8.0)
		elif not second and _touches(orb, p):
			orb.answered[orb.lane] = false
			_taken(orb, p)
	if second and orb.position.distance_to(CENTER) > radius() + 60.0:
		if not orb.answered.has(orb.lane):
			_lose("ring_lost_loss", orb, "MISSED")
		_end(orb, Vector2(-orb.side * cos(chest_angle()), -sin(chest_angle())) * orb.speed)


# --- Answers ---

func _answer(orb, off: float, what: String, perfect = -1.0, good = -1.0):
	if perfect < 0.0:
		perfect = Tuning.value("ring_perfect")
	if good < 0.0:
		good = Tuning.value("ring_good")
	if off <= perfect:
		Sfx.play("on_beat", -4.0)
		_sparks(orb, Color.WHITE, 16)
		_gain("ring_perfect_gain", orb, "PERFECT " + what)
	elif off <= good:
		_sparks(orb, orb.color().lerp(Color.WHITE, 0.4), 10)
		_gain("ring_good_gain", orb, "GOOD")
	else:
		_sparks(orb, orb.color(), 6)
		_gain("ring_ok_gain", orb, what)
	if orb.kind == Kind.SHARD or orb.kind == Kind.RELAY:
		Sfx.play("sync_hit", -4.0)
		orb.split = true


func _taken(orb, p):
	p.take_damage(0.0, (p.global_position - orb.position).normalized() * 220.0 + Vector2(0.0, -120.0))
	_lose("ring_hit_loss", orb, "TAKEN", HEAVY_LOSS if orb.heavy else 1.0)


func _end(orb, drift: Vector2):
	orb.done = true
	orb.drift = drift
	orb.queue_redraw()


func _touches(orb, p) -> bool:
	return orb.position.distance_to(p.global_position) <= SIZE + TOUCH


func _at_guard(orb, p) -> bool:
	return orb.position.distance_to(p.global_position) <= PARRY_REACH


# A swinging blade of the player's within reach of `at`, from a swing that hasn't tried this one.
func _struck(orb, p, at: Vector2) -> bool:
	var point = p.active_sword_point()
	if point == null or p.swing_serial == orb.serial:
		return false
	if point.distance_to(at) > SWORD_REACH + SIZE:
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

# text: shown over it ("" adds to an answer already shown).
func _gain(key: String, orb, text: String):
	_meter = minf(_meter + Tuning.value(key), METER_MAX)
	if text == "":
		return
	orb.result = text
	_combo += 1
	_best = maxi(_best, _combo)
	_popup(orb.position + Vector2(0.0, -30.0), orb.visibility_layer, text, Color.WHITE)


func _lose(key: String, orb, text: String, times = 1.0):
	orb.result = text
	_combo = 0
	_meter = maxf(_meter - Tuning.value(key) * times, 0.0)
	_popup(orb.position + Vector2(0.0, -30.0), orb.visibility_layer, text, COLOR_EMPTY)
	_check_over()


func _check_over():
	if _meter <= 0.0 and not Moves.on("ring_endless") and not _over:
		_over = true
		Sfx.play("game_over")
		var perfect = tally.get("PERFECT PARRY", 0) + tally.get("PERFECT HIT", 0)
		_over_label.text = "RUN OVER after %.0f s, best combo %d, %d perfect, %d sync hits\nR to run again · Esc menu" \
			% [maxf(_time, 0.0), _best, perfect, tally.get("PERFECT SYNC HIT", 0) + tally.get("SYNC HIT", 0)]
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
	hint.text = "Yellow: parry · grey: hit · violet: hit (your partner's parry sent it) · green: both of you" \
		+ " · best on the circle · one on each side, until a green arrow sends you to one side      F1 F2 Esc"
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


# The circle around the middle, only to look at: it lights up as a thing meets it. (The floor
# line halves it; the mirror makes it whole.)
class Circle extends Node2D:
	var ring

	func _draw():
		var light = 0.0
		if not ring._beats.is_empty() and ring._beats[0] <= ring._time:
			light = exp(-(ring._time - ring._beats[0]) / 0.12)
		var color = BeatRing.COLOR_CIRCLE.lerp(Color(1, 1, 1, 0.6), light)
		draw_arc(BeatRing.CENTER, ring.radius(), PI, TAU, 64, color, 2.0 + 2.0 * light, true)


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
