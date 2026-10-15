extends GymLevel
## Horologium, the first level of the coop platformer: a clock tower where everything strikes on
## one clock (Beat, 150 BPM). Built for the default kit (F1 defaults: no double jump, no walls,
## no ledge grab); every size comes from the player's constants. A checkpoint takes only once
## both players stand in it (checkpoint_needs_all).
##  0 ANTECHAMBER  flat; the click, and a practice bell: strike it on the 1, see how far off.
##  1 HAMMERWORKS  a low corridor of hammers (BeatHammer): a) one on the 1, b) a wave on 1, 2,
##                 3, 4 to follow at an easy run, c) a canon: two on the 1 and the 3 with a gap
##                 between them for one player only.
##  2 BELL SHAFT   a) warm-up: two sets of beat steps taking turns, jump on the change. b) the
##                 climb: landings L0-L3, each with a bell; between them steps for P1 and for P2
##                 that only the partner's bell calls (BeatBell): "I ring, you climb".
##  3 PENDULUMS    two pendulums whose sweep is too wide to cross alone between passes; a
##                 parry from a balcony holds one for a bar while the partner runs under it.
##  4 BELFRY       the great bell: both strike it on the same 1.

const Hammer = preload("res://levels/obstacles/beat_hammer.gd")
const Pendulum = preload("res://levels/obstacles/beat_pendulum.gd")

const BPM = 150.0  # see core/beat.gd for why
const BEAT = 60.0 / BPM
const JUMP = Player.JUMP_HEIGHT  # 136
const RUN = Player.SPEED  # 360 px/s
const BODY_W = Player.BODY_SIZE.x  # 20

# 1 HAMMERWORKS
const CORRIDOR = Vector2(900, 2850)  # x from, to
const CLEARANCE = 120.0  # the corridor's height: under a jump (no hopping) and room under a hammer at rest
const HAMMER_A_X = 1250.0
const WAVE_X = 1750.0  # the wave's first hammer
const WAVE_RUN = 0.75  # the wave moves one hammer a beat at this fraction of a full run...
const WAVE_SPACING = WAVE_RUN * RUN * BEAT  # ...so they're this far apart (108)
const CANON_X = 2450.0  # the first canon hammer's left side
const CANON_WIDTH = 100.0  # wide, so passing both inside one window (~0.95 beat) takes more than a run and a dash
const CANON_GAP = 3.0 * BODY_W  # room for one player between them (60), not for two side by side

# 2 BELL SHAFT
const WARMUP_X = 2950.0  # the first warm-up step's left side
const WARMUP_RISE = JUMP - 40.0  # 96 between steps: an easy jump
const WARMUP_STEPS = 4
const WARMUP_SPACING = 120.0  # step to step, sideways
const STEP_WIDTH = 80.0
const SHAFT_X = 3400.0  # its inside, from the left wall...
const SHAFT_W = 420.0  # ...this wide
const L0_Y = GROUND_Y - (WARMUP_STEPS + 1) * WARMUP_RISE  # the shaft's floor: one rise above the last warm-up step
const STEP_RISE = JUMP - 20.0  # 116: landing to step to landing, a jump each with some room to spare
const SECTION = 2.0 * STEP_RISE  # 232 between landings: two jumps; out of reach of a partner's shoulders (40 + 136)
const LANDING_W = 120.0
const SHAFT_STEP_W = 70.0

# 3 PENDULUMS
const Y3 = L0_Y - 3.0 * SECTION  # the top corridor's floor, level with L3
const HALL = 640.0  # floor to ceiling, where the pendulums hang
const BALCONY = JUMP - 16.0  # 120: a jump up; the blade arrives here at its turning points
const PEND_LENGTH = HALL - Pendulum.BLADE_RADIUS - 10.0  # the blade's bottom skims 10 px over the floor
const PEND_X = [4400.0, 5500.0]
const BALCONY_W = 150.0
const BALCONY_SHY = 15.0  # a balcony ends this short of the turning point: the blade reaches a player at its edge just before the 2 / the 4 (~0.25 beat)

# 4 BELFRY
const BELFRY_X = 6100.0  # its checkpoint, clear of the last pendulum's balcony
const BELL_X = 6350.0
const ROOM_END = 6750.0
const GREAT_BELL_SIZE = 3.0

var _rung = {}  # player id -> the downbeat they last rang the great bell on
var _done = false
var _resets = 0
var _clock: Node2D  # the great clock pendulum in the background
var _finish: Label


func room_name() -> String:
	return "HOROLOGIUM  (2 players)"


func player_count() -> int:
	return 2


func _build():
	bounds = Rect2(0, Y3 - HALL - 160.0, ROOM_END, GROUND_Y - (Y3 - HALL - 160.0) + 120.0)
	checkpoint_needs_all = true
	Beat.start(BPM, self)
	_clock = Node2D.new()
	_clock.draw.connect(_draw_clock)
	add_child(_clock)
	solid(0, bounds.position.y, 24, bounds.size.y)
	solid(ROOM_END - 24, bounds.position.y, 24, bounds.size.y)
	_antechamber()
	_hammerworks()
	_bell_shaft()
	_pendulums()
	_belfry()
	_hud()


# --- 0 ANTECHAMBER ---

func _antechamber():
	ground(0, SHAFT_X)
	respawn_point = Vector2(120, GROUND_Y - PLAYER_HALF)
	checkpoint(120)
	station(60, "0 · ANTECHAMBER", "Everything here beats in the same time.\n" \
		+ "Strike the bell on the 1 (the big dot, top right):\nit shows how far off you were.  M: click off / on", GROUND_Y - 330)
	var bell = BeatBell.new()
	bell.position = Vector2(560, GROUND_Y - PLAYER_HALF)
	bell.caption = "practice"
	add_child(bell)


# --- 1 HAMMERWORKS ---

func _hammerworks():
	solid(CORRIDOR.x, GROUND_Y - CLEARANCE - 400.0, CORRIDOR.y - CORRIDOR.x, 400.0)
	measure(Vector2(CORRIDOR.x + 30, GROUND_Y), Vector2(CORRIDOR.x + 30, GROUND_Y - CLEARANCE))
	label(Vector2(CORRIDOR.x + 20, GROUND_Y - CLEARANCE - 120), "1 · HAMMERWORKS", 22)

	# a) One hammer on the 1: go under it on the 2, 3 or 4.
	checkpoint(980)
	_hammer(HAMMER_A_X, [1], 0)
	label(Vector2(1100, GROUND_Y - CLEARANCE - 80), "a) on the 1: go on the 2, 3, 4", 13, COLOR_HINT)

	# b) A wave: 1, 2, 3, 4 one after the other, one hammer a beat at an easy run.
	checkpoint(1560)
	for i in 4:
		_hammer(WAVE_X + i * WAVE_SPACING, [1], i)
	measure(Vector2(WAVE_X, GROUND_Y - CLEARANCE + 14), Vector2(WAVE_X + WAVE_SPACING, GROUND_Y - CLEARANCE + 14))
	label(Vector2(1640, GROUND_Y - CLEARANCE - 80), "b) a wave on 1 2 3 4: follow it", 13, COLOR_HINT)

	# c) A canon: two wide hammers on the 1 and the 3, room for one between them. One goes on
	# the 2 and the 4, the other a turn later.
	checkpoint(2260)
	var first = CANON_X + CANON_WIDTH / 2.0
	var second = CANON_X + CANON_WIDTH + CANON_GAP + CANON_WIDTH / 2.0
	_hammer(first, [1, 3], 0, CANON_WIDTH)
	_hammer(second, [1, 3], 0, CANON_WIDTH)
	measure(Vector2(CANON_X + CANON_WIDTH, GROUND_Y - 60), Vector2(CANON_X + CANON_WIDTH + CANON_GAP, GROUND_Y - 60))
	label(Vector2(2300, GROUND_Y - CLEARANCE - 80), "c) canon, on the 1 and the 3: room for one between", 13, COLOR_HINT)


func _hammer(x: float, pattern: Array, offset: int, width = 56.0):
	var h = Hammer.new()
	h.position = Vector2(x, GROUND_Y)
	h.pattern = pattern
	h.offset = offset
	h.width = width
	h.clearance = CLEARANCE
	obstacle(h)


# --- 2 BELL SHAFT ---

func _bell_shaft():
	label(Vector2(CORRIDOR.y + 20, L0_Y - 140), "2 · BELL SHAFT", 22)

	# a) Warm-up: two sets of steps taking turns every two beats; jump on the change.
	checkpoint(2920)
	for i in WARMUP_STEPS:
		var s = BeatStep.new()
		s.position = Vector2(WARMUP_X + i * WARMUP_SPACING, GROUND_Y - (i + 1) * WARMUP_RISE)
		s.width = STEP_WIDTH
		s.pattern = [1, 2] if i % 2 == 0 else [3, 4]
		obstacle(s)
	height_mark(WARMUP_X - 40, WARMUP_X, GROUND_Y - WARMUP_RISE, "%d" % roundi(WARMUP_RISE))
	label(Vector2(WARMUP_X - 40, GROUND_Y - 300), "a) on 1 2 / on 3 4:\njump on the change", 13, COLOR_HINT)

	# The shaft: its floor L0 on a block, walls, landings L1 (right), L2 (left), L3 (right,
	# out to the pendulums).
	var top = Y3 - HALL
	pillar(SHAFT_X, SHAFT_W, GROUND_Y - L0_Y)
	solid(SHAFT_X - 40, top, 40, L0_Y - 200 - top)  # left wall, open above L0 for the way in
	solid(SHAFT_X - 40, top - 200, SHAFT_W + 80, 200)  # the ceiling
	var landings = [L0_Y, L0_Y - SECTION, L0_Y - 2.0 * SECTION, L0_Y - 3.0 * SECTION]
	var left = SHAFT_X
	var right = SHAFT_X + SHAFT_W - LANDING_W
	var landing_x = [left, right, left, right]  # L0 is the whole floor; its bell stands left
	for k in range(1, 4):
		ledge(landing_x[k], landings[k], LANDING_W)
	# b) Steps in each section, one for each player at different places: [section][owner] -> x.
	var step_x = [
		{1: SHAFT_X + 100, 2: SHAFT_X + 200},  # L0 -> L1 (right)
		{1: SHAFT_X + 250, 2: SHAFT_X + 160},  # L1 -> L2 (left)
		{1: SHAFT_X + 200, 2: SHAFT_X + 100},  # L2 -> L3 (right)
	]
	var steps = []  # per section
	for k in 3:
		var here = []
		for who in [1, 2]:
			var s = BeatStep.new()
			s.mode = BeatStep.Mode.CALL
			s.owner_id = who
			s.width = SHAFT_STEP_W
			s.position = Vector2(step_x[k][who], landings[k] - STEP_RISE)
			obstacle(s)
			here.append(s)
		steps.append(here)
	# A bell on every landing, calling the partner's steps of the sections it begins or ends.
	for k in 4:
		var bell = BeatBell.new()
		var x = landing_x[k] + (24.0 if landing_x[k] == left else LANDING_W - 24.0)
		bell.position = Vector2(x, landings[k] - PLAYER_HALF)
		bell.caption = "L%d" % k
		for section in [k - 1, k]:
			if section >= 0 and section < 3:
				bell.calls.append_array(steps[section])
		add_child(bell)
	checkpoint(SHAFT_X + 60, L0_Y)
	measure(Vector2(SHAFT_X + SHAFT_W - 10, L0_Y), Vector2(SHAFT_X + SHAFT_W - 10, landings[1]))
	measure(Vector2(SHAFT_X + 10, landings[1]), Vector2(SHAFT_X + 10, landings[1] - STEP_RISE))
	height_mark(SHAFT_X, SHAFT_X + 90, L0_Y - BODY_W * 2.0 - JUMP, "on a partner: %d" % roundi(2.0 * BODY_W + JUMP))
	height_mark(SHAFT_X, SHAFT_X + 90, L0_Y - Player.LAUNCH_HEIGHT, "launch %d" % roundi(Player.LAUNCH_HEIGHT))
	label(Vector2(SHAFT_X + 20, top + 20), "b) a bell on the 1 calls your partner's steps\n" \
		+ "for a bar: you ring, they climb.\nRing on every 1 to keep them.", 13, COLOR_HINT)


# --- 3 PENDULUMS ---

func _pendulums():
	ground(SHAFT_X + SHAFT_W, ROOM_END, Y3)
	solid(SHAFT_X + SHAFT_W + 40, Y3 - HALL - 200, ROOM_END - SHAFT_X - SHAFT_W - 40, 200)  # the ceiling
	label(Vector2(3900, Y3 - HALL + 30), "3 · PENDULUMS", 22)
	label(Vector2(3900, Y3 - HALL + 60), "Too wide to cross alone between two passes.\n" \
		+ "Parry it from a balcony (block as it arrives on the 2 / the 4):\n" \
		+ "it holds for a bar, and your partner runs under it.", 13, COLOR_HINT)
	# Where the blade turns: its middle at the height of a player standing on a balcony.
	var drop = HALL - BALCONY - PLAYER_HALF
	var amplitude = acos(drop / PEND_LENGTH)
	var reach = PEND_LENGTH * sin(amplitude)
	checkpoint(3900, Y3)
	for i in PEND_X.size():
		var x = PEND_X[i]
		if i > 0:
			checkpoint(x - reach - BALCONY_W - 60.0, Y3)
		var p = Pendulum.new()
		p.position = Vector2(x, Y3 - HALL)
		p.length = PEND_LENGTH
		p.amplitude = amplitude
		obstacle(p)
		# The balconies, just outside the turning points: the blade arrives at their inner ends.
		ledge(x - reach - BALCONY_SHY - BALCONY_W, Y3 - BALCONY, BALCONY_W)
		ledge(x + reach + BALCONY_SHY, Y3 - BALCONY, BALCONY_W)
		# How wide the blade sweeps the floor at a player's height, between passes 2 beats apart.
		var low = acos((HALL - Pendulum.BLADE_RADIUS - PLAYER_SIZE.y) / PEND_LENGTH)
		var sweep = PEND_LENGTH * sin(low) + Pendulum.BLADE_RADIUS + BODY_W / 2.0
		measure(Vector2(x - sweep, Y3 - 12), Vector2(x + sweep, Y3 - 12),
			"%d swept · %d run + dash in 2 beats" % [roundi(2.0 * sweep), roundi(RUN * (2.0 * BEAT - Player.DASH_TIME) + Player.DASH_DISTANCE)])
		measure(Vector2(x + reach + 60, Y3), Vector2(x + reach + 60, Y3 - BALCONY))


# --- 4 BELFRY ---

func _belfry():
	checkpoint(BELFRY_X, Y3)
	label(Vector2(BELFRY_X, Y3 - HALL + 30), "4 · BELFRY", 22)
	label(Vector2(BELFRY_X, Y3 - HALL + 60), "Both strike the great bell on the same 1.", 13, COLOR_HINT)
	var bell = BeatBell.new()
	bell.size_factor = GREAT_BELL_SIZE
	bell.position = Vector2(BELL_X, Y3 - 60.0)
	bell.rung.connect(_on_great_bell)
	add_child(bell)


func _on_great_bell(player, downbeat: int):
	_rung[player.player_id] = downbeat
	if _done or _rung.size() < players.size() or _rung.values().min() != _rung.values().max():
		return
	_done = true
	Sfx.play("big_bell", 2.0)
	_finish.text = "HOROLOGIUM\nrung together on the 1\n\n%s   ·   %d resets\n\nEsc: back to the menu" \
		% [_time_text(Beat.time()), _resets]
	_finish.visible = true


func _time_text(t: float) -> String:
	return "%d:%04.1f" % [floori(t / 60.0), fmod(t, 60.0)]


func _on_respawned(_player):
	_resets += 1


# --- The clock: the beat display, and the great pendulum in the background ---

func _hud():
	var layer = CanvasLayer.new()
	add_child(layer)
	var display = BeatDisplay.new()
	display.position = Vector2(get_viewport().get_visible_rect().size.x - 230.0, 14.0)
	layer.add_child(display)
	_finish = Label.new()
	_finish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finish.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_finish.add_theme_font_size_override("font_size", 30)
	_finish.add_theme_constant_override("outline_size", 8)
	_finish.add_theme_color_override("font_outline_color", Color.BLACK)
	_finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finish.visible = false
	layer.add_child(_finish)


const CLOCK_LENGTH = 420.0  # the background pendulum: from above the screen's top...
const CLOCK_SWING = 0.32  # ...out this far (radians) to one side on every beat
const CLOCK_COLOR = Color(1, 1, 1, 0.06)


func _process(_delta):
	var cam = get_viewport().get_camera_2d()
	if cam:
		_clock.global_position = cam.get_screen_center_position() + Vector2(0, -360.0 / cam.zoom.y)
	_clock.queue_redraw()


# One side per beat: out to the left on the 1, the right on the 2, ...
func _draw_clock():
	var angle = -CLOCK_SWING * cos(PI * Beat.beats_at(Beat.time())) if Beat.running else 0.0
	var bob = Vector2(sin(angle), cos(angle)) * CLOCK_LENGTH
	_clock.draw_line(Vector2.ZERO, bob, CLOCK_COLOR, 6.0)
	_clock.draw_circle(bob, 46.0, CLOCK_COLOR)
	for side in [-1.0, 1.0]:
		var tip = Vector2(sin(CLOCK_SWING * side), cos(CLOCK_SWING * side)) * (CLOCK_LENGTH + 60.0)
		_clock.draw_line(tip * 0.94, tip, CLOCK_COLOR, 3.0)
