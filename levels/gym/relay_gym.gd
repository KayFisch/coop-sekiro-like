extends GymLevel
## The relay gym: trying the rhythm relay (Moves "relay_rhythm") alone. Player 2 is a bot
## (RelayBot) that parries every dash-slash at it right as the blades meet and throws the dasher
## up exactly on beat 3. The readout up top says how far apart the beats really came, and how far
## off beat 4 your own move was. Strike a lever ("bot here") to call the bot to that station.
##  1 BELLS   at the top of the throw: strike one on 4.
##  2 POGO    a lantern just under the top, and a ledge only a pogo off it reaches, if it comes
##            on 4 (any later and you've fallen too far).
##  3 LEDGE   a tower just under the top: dash onto it on 4 (earlier you're still below its
##            edge, later you've fallen past it).

# Where the bot stands at each station; the dasher meets it from the left.
const BELLS_X = 820.0
const POGO_X = 1800.0
const LEDGE_X = 2800.0
const LEVER_LEAD = 330.0  # a station's lever and checkpoint stand this far left of the bot
# The top of an upward throw: the dasher's feet this high above the ground, on beat 4.
const TOP = Player.RELAY_SPEED * Player.RHYTHM_THROW_TIME  # reached a little before beat 4, then the hang
const DASHER_OFFSET = 55.0  # the dasher's center, left of the bot's, when the blades meet (40-70)
# 2 POGO: the lantern's top is this far under the feet at the top; the ledge is this far under
# where a pogo from the very top takes you, so the pogo has to come within ~POGO_SLACK px of it.
# And the lantern only takes a downslash pressed at most POGO_TOLERANCE off beat 4 (the pogo's
# own box would take one pressed up to 150 ms early, and a second try after a miss).
const LANTERN_DROP = 6.0
const POGO_SLACK = 10.0
const POGO_LEDGE_WIDTH = 200.0
const POGO_TOLERANCE = 0.05
# 3 LEDGE: the tower's top is this far under the feet at the top: a dash from ~65 ms before beat
# 4 (the hang's start) to ~70 ms after it (the hang's end, then falling these few px) clears its edge.
const LEDGE_SLACK = 4.0
const TOWER_GAP = 30.0  # from the bot's center to the tower's face
const TOWER_WIDTH = 300.0
const NEEDED = ["dash", "dash_slash", "momentum_relay", "relay_rhythm", "pogo_environment"]

var _bot: RelayBot
var _readout: Label
var _times = {}  # beat number -> when it came (s)
var _last_state = ""
var _last_pogo = -100.0
var _result = ""


func room_name() -> String:
	return "RELAY GYM  (P2 is a bot)"


func player_count() -> int:
	return 2


func _build():
	bounds = Rect2(0, -500, LEDGE_X + TOWER_GAP + TOWER_WIDTH + 24.0, 1220)
	solid(0, bounds.position.y, 24, GROUND_Y - bounds.position.y)
	solid(bounds.end.x - 24, bounds.position.y, 24, GROUND_Y - bounds.position.y)
	ground(0, bounds.end.x)
	var top_y = GROUND_Y - TOP  # the dasher's feet at the top
	respawn_point = Vector2(BELLS_X - LEVER_LEAD + 60.0, GROUND_Y - PLAYER_HALF)
	station(60, "RHYTHM RELAY", "Dash-slash into P2 (dash + attack).\n" \
		+ "1 windup  ·  2 parry  ·  3 strike  ·  4 top\nOne beat = %d ms.\n" % roundi(Player.RHYTHM_BEAT * 1000.0) \
		+ "Strike a lever to call the bot to that station.\nR: back to the checkpoint.", GROUND_Y - 360)
	_readout = screen_label()

	# 1 BELLS
	_station_lever(BELLS_X, "1 · BELLS", "Strike a bell on 4.")
	height_mark(BELLS_X - 300.0, BELLS_X + 200.0, top_y, "top of the throw %d (beat 4)" % roundi(TOP))
	for dx in [-115.0, -55.0, 5.0]:
		target(Vector2(BELLS_X + dx, top_y - PLAYER_HALF), GymTarget.Mode.BELL, "4")

	# 2 POGO: down + attack onto the lantern on 4, up onto the ledge.
	_station_lever(POGO_X, "2 · POGO ON 4", "Pogo off the lantern (down + attack)\nright at the top: only then\ndoes it take you onto the ledge.")
	var lantern = target(Vector2(POGO_X - DASHER_OFFSET, top_y + LANTERN_DROP + 12.0), GymTarget.Mode.LANTERN, "only on 4")
	lantern.pogo_filter = _pogo_on_4
	var ledge_y = top_y - Player.POGO_HEIGHT + POGO_SLACK
	ledge(POGO_X - DASHER_OFFSET - POGO_LEDGE_WIDTH / 2.0, ledge_y, POGO_LEDGE_WIDTH)
	height_mark(POGO_X - 300.0, POGO_X + 160.0, top_y, "top %d" % roundi(TOP))

	# 3 LEDGE: dash right onto the tower on 4.
	_station_lever(LEDGE_X, "3 · DASH ON 4", "Dash right onto the tower\nright at the top.")
	solid(LEDGE_X + TOWER_GAP, top_y + LEDGE_SLACK, TOWER_WIDTH, TOP - LEDGE_SLACK)
	height_mark(LEDGE_X - 300.0, LEDGE_X + TOWER_GAP, top_y, "top %d" % roundi(TOP))
	label(Vector2(LEDGE_X + TOWER_GAP + 40.0, top_y - 60.0), "made it!", 18, COLOR_CHECKPOINT)

	# Before the players, so its presses reach them the same frame.
	_bot = RelayBot.new()
	_bot.home_x = BELLS_X
	add_child(_bot)


# A station's heading, its checkpoint, and a lever that calls the bot to it.
func _station_lever(bot_x: float, title: String, hint: String):
	var x = bot_x - LEVER_LEAD
	station(x - 40.0, title, hint, GROUND_Y - 300.0)
	checkpoint(x + 60.0)
	var lever = target(Vector2(x, GROUND_Y - 28.0), GymTarget.Mode.DUMMY, "bot here")
	lever.struck.connect(func(_p, _amount, _kind): _call_bot(bot_x))


func _call_bot(x: float):
	_bot.home_x = x
	players[1].global_position = Vector2(x, GROUND_Y - PLAYER_HALF)
	players[1].velocity = Vector2.ZERO
	Sfx.play("call_tick")


func _ready():
	super()
	_bot.dasher = players[0]
	_bot.anchor = players[1]
	_call_bot(BELLS_X)
	_show()


func _on_respawned(p):
	if p == players[1]:
		p.global_position.x = _bot.home_x


func _physics_process(delta):
	super(delta)
	var p1 = players[0]
	var state = p1.movement_state()
	if state != _last_state:
		_beat_changed(_last_state, state)
		_last_state = state
	if p1._pogo_time != _last_pogo:
		_last_pogo = p1._pogo_time
		_beat_move("pogo", p1._downslash_time)
	# Beat 4: the tick in the hang at the top (whether or not a move cut the throw short).
	if _times.has(3) and not _times.has(4) and _now() >= p1.rhythm_top_time:
		_times[4] = _now()
	_show()


# Beats 1 to 3, from the dasher's movement: windup, locked, thrown; and a dash after them, as
# the move on 4.
func _beat_changed(was: String, now: String):
	var t = _now()
	if now == "dash-slash windup":
		_times = {1: t}
		_result = ""
	elif now == "clash" and _times.has(1):
		_times[2] = t
	elif was == "clash" and _times.has(2):
		if now == "relay boost":
			_times[3] = t
		else:
			_result = "dropped: no strike on beat 3"
	if now == "dash":
		_beat_move("dash", players[0]._dash_press_time)  # seen here a frame or two after the press


# A move of the dasher's after the throw, pressed at time t: how far off beat 4 it came.
func _beat_move(what: String, t: float, note = ""):
	if not _times.has(3) or t - _times[3] > 1.0:
		return
	_result = "%s on 4: %+d ms%s" % [what, roundi((t - players[0].rhythm_top_time) * 1000.0), note]


# The lantern's rule: only a downslash pressed close to beat 4 bounces off it.
func _pogo_on_4(p) -> bool:
	var off = p._downslash_time - p.rhythm_top_time
	if absf(off) <= POGO_TOLERANCE:
		return true
	if p == players[0]:
		_beat_move("pogo", p._downslash_time, "  (too far off: ±%d ms)" % roundi(POGO_TOLERANCE * 1000.0))
	return false


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _show():
	var lines = []
	var missing = NEEDED.filter(func(key): return not Moves.on(key))
	if not missing.is_empty():
		lines.append("F1, switch on: %s" % ", ".join(missing))
	var parts = []
	for beat in [2, 3, 4]:
		if _times.has(beat) and _times.has(beat - 1):
			parts.append("%d→%d  %d ms" % [beat - 1, beat, roundi((_times[beat] - _times[beat - 1]) * 1000.0)])
	lines.append("   ".join(parts) if not parts.is_empty() else "–")
	if _result != "":
		lines.append(_result)
	_readout.text = "\n".join(lines)
	_readout.modulate = Color(1.0, 0.6, 0.5) if not missing.is_empty() else COLOR_LABEL
