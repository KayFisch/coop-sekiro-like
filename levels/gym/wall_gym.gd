extends GymLevel
## The wall gym: wall jumps in rhythm (Moves "wall_rhythm", see WALL RHYTHM in player.gd). A
## metronome (BPM) starts ticking on your first wall jump of a climb and stops when you land.
## From then on, a wall jump pressed as you hit the wall is a full one, early or late a weak
## one: mashing or hanging on sinks you. Every shaft's width follows from BPM, so the walls
## make the rhythm. The readout up top lists your last wall jumps, ms off hitting the wall.
## With Moves "wall_log" on, every climb is logged for analysis (WallLog).
##  1 WIDE     a beat's flight from wall to wall (WIDE_BEATS). Too far for the wall
##             jump's own flight (WALL_FLIGHT_TIME): hold toward the far wall.
##  2 NARROW   half as wide: twice as fast, on every tick and between, no steering needed.
##  3 COOP     too wide to climb alone. Player 2 is a bot that mirrors you on the far wall
##             (ChimneyBot); jump off together, hold toward the middle, press jump as you meet
##             (a chimney clash): you wall-jump off each other, back to your walls. Twice the
##             wide shaft: each half is one, with your partner as its far wall.

const BPM = 120.0  # the level's tempo: the shafts' widths follow from it
const WALL = 40.0  # a wall's thickness
const TOP_Y = -500.0  # the walls' tops
const CAP = 160.0  # a one-way ledge on top of each wall, reaching out of the shaft: the last jump flies over the wall's top, and this catches you
# Each shaft is exactly its beats wide at BPM (late presses catch up, see WALL RHYTHM).
const WIDE_BEATS = 1.0  # the wide shaft's flight, in beats
const NARROW_BEATS = 0.5
const BODY = 2.0 * PLAYER_HALF
const WIDE_X = 300.0
const NARROW_X = 800.0
const COOP_X = 1350.0
const ENTRANCE = 56.0  # the gap under each shaft's left wall: walk in, but no jumping through it
const NEEDED = ["wall", "wall_jump", "wall_rhythm", "chimney_clash"]
const READOUT_JUMPS = 8

var _metronome: Metronome
var _coop = 0.0  # the coop chimney's width
var _bot: ChimneyBot
var _readout: Label
var _log: WallLog
var _jumps: Array = []  # [ms off its moment, full jump] for the last wall jumps
var _last_jump = -100.0
var _clashes = 0
var _last_clash = -100.0


func room_name() -> String:
	return "WALL GYM  (P2 is a bot in the coop chimney)"


func player_count() -> int:
	return 2


# A gap's width from wall to wall that a wall jump crosses in `beats` beats: the player's body,
# plus the ground it flies (WALL_JUMP_PUSH) in that time.
func _gap(beats: float) -> float:
	return BODY + Player.WALL_JUMP_PUSH * beats * 60.0 / BPM


func _build():
	_metronome = Metronome.new()
	_metronome.bpm = BPM
	add_child(_metronome)
	var wide = _gap(WIDE_BEATS)
	var narrow = _gap(NARROW_BEATS)
	# The coop chimney: two wide shafts, the partners meeting (touching) in the middle, each the
	# other one's far wall. Too wide to cross alone.
	_coop = 2.0 * wide
	bounds = Rect2(0, TOP_Y - 300.0, COOP_X + WALL + _coop + WALL + 300.0, GROUND_Y - TOP_Y + 420.0)
	solid(0, bounds.position.y, 24, GROUND_Y - bounds.position.y)
	solid(bounds.end.x - 24, bounds.position.y, 24, GROUND_Y - bounds.position.y)
	ground(0, bounds.end.x)
	respawn_point = Vector2(120, GROUND_Y - PLAYER_HALF)
	station(60, "WALL RHYTHM", "Metronome: %d BPM.\n" % roundi(BPM) \
		+ "Your first wall jump starts it,\nlanding stops it. Then jump as you hit the wall: a full\njump. Early or late: a weak one.\nWalk in under the left walls.", GROUND_Y - 380)
	_readout = screen_label()

	_log = WallLog.new()
	_log.metronome = _metronome
	_log.top_y = TOP_Y
	add_child(_log)
	_shaft(WIDE_X, wide, "1 · WIDE", "a beat across.\nHold toward the far wall", "wide")
	_shaft(NARROW_X, narrow, "2 · NARROW", "half as wide: twice as fast,\nno steering needed", "narrow")
	_shaft(COOP_X, _coop, "3 · COOP", "too wide alone. Jump off with your\nmirror (P2), hold toward the middle,\npress jump as you meet (chimney\nclash): you wall-jump off each other.\nHold back toward your wall, jump as you hit it.", "coop")

	# Before the players, so its presses reach them the same frame.
	_bot = ChimneyBot.new()
	_bot.center_x = COOP_X + WALL + _coop / 2.0
	_bot.inside = Vector2(COOP_X + WALL, COOP_X + WALL + _coop)
	add_child(_bot)


# Two walls `width` apart (inside), with a way in under the left one. `log_name`: what the
# climb log calls it.
func _shaft(x: float, width: float, title: String, hint: String, log_name: String):
	_log.shafts.append([log_name, x - CAP, x + WALL + width + WALL + CAP])
	solid(x, TOP_Y, WALL, GROUND_Y - ENTRANCE - TOP_Y)
	solid(x + WALL + width, TOP_Y, WALL, GROUND_Y - TOP_Y)
	ledge(x - CAP, TOP_Y, CAP)
	ledge(x + WALL + width + WALL, TOP_Y, CAP)
	measure(Vector2(x + WALL, GROUND_Y - 150.0), Vector2(x + WALL + width, GROUND_Y - 150.0), "%d" % roundi(width))
	label(Vector2(x - 20.0, TOP_Y - 110.0), title, 22)
	label(Vector2(x - 20.0, TOP_Y - 80.0), hint, 13, COLOR_HINT)
	checkpoint(x - 80.0)


func _ready():
	super()
	_log.player = players[0]
	_bot.leader = players[0]
	_bot.follower = players[1]
	players[1].wall_rhythm_sound = false
	_park_bot()


# Player 2 waits on the coop chimney's floor until player 1 comes in.
func _park_bot():
	players[1].global_position = Vector2(COOP_X + WALL + _coop - PLAYER_HALF - 10.0, GROUND_Y - PLAYER_HALF)
	players[1].velocity = Vector2.ZERO


func _on_respawned(p):
	if p == players[1]:
		_park_bot()


func _physics_process(delta):
	super(delta)
	var p1 = players[0]
	if p1.wall_beat_time != _last_jump:
		_last_jump = p1.wall_beat_time
		_jumps.append([roundi(p1.wall_jump_off * 1000.0), p1.wall_jump_strong])
		if _jumps.size() > READOUT_JUMPS:
			_jumps.pop_front()
	if p1.chimney_clash_time != _last_clash:
		_last_clash = p1.chimney_clash_time
		_clashes += 1
		_jumps.append([roundi(p1.wall_jump_off * 1000.0), p1.wall_jump_strong])
		if _jumps.size() > READOUT_JUMPS:
			_jumps.pop_front()
	_show()


func _show():
	var lines = []
	var missing = NEEDED.filter(func(key): return not Moves.on(key))
	if not missing.is_empty():
		lines.append("F1, switch on: %s" % ", ".join(missing))
	var parts = []
	for j in _jumps:
		parts.append("%+d%s" % [j[0], " ✓" if j[1] else " weak"])
	lines.append("wall jumps (ms off hitting the wall or partner): " + ("   ".join(parts) if not parts.is_empty() else "–"))
	lines.append("%d BPM · on time within ±%d ms   ·   chimney clashes: %d" % [roundi(BPM), roundi(Player.WALL_RHYTHM_TOLERANCE * 1000.0), _clashes])
	var logged = _log.summary()
	if logged != "":
		lines.append(logged)
	_readout.text = "\n".join(lines)
	_readout.modulate = Color(1.0, 0.6, 0.5) if not missing.is_empty() else COLOR_LABEL
