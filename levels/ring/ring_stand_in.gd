extends Node
## Testing alone: plays one of the two (Moves "bifrons_stand_in": "left" is P1, "right" P2) by
## pressing that player's buttons. It walks to where its next thing meets the circle (just past
## it, the way the thing flies: inside for one coming in, outside for the sweep going out), or
## else to its side of the circle; presses parry or attack on the beat, STAND_IN_SKILL of the
## time; it jumps low bars and doesn't jump while a high one is near. It runs before the players,
## so they see a press that same frame.
## (The beat-ring's, levels/ring/ring.gd: BeatRing.StandIn.)

var ring
var lane = -1  # set: it plays that lane, whatever the switch says (two can play both)
var _pressed = {}  # [thing, lane] -> true once it has answered (or chosen not to)
var _jumped = {}
var _held = []
var _walking = ""  # the left or right action it holds down, if any

func _ready():
	process_physics_priority = -10

func _physics_process(_delta):
	for action in _held:
		Input.action_release(action)
	_held.clear()
	var lane = self.lane if self.lane >= 0 else ["off", "left", "right"].find(Moves.value("bifrons_stand_in")) - 1
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
	# Its next meeting: [thing, beat, side of the circle, the thing going out from the middle].
	var next = null
	for orb in ring._orbs:
		if orb.done:
			continue
		var meetings = [[orb.first, orb.beat, orb.side, false]]
		if orb.kind == BeatRing.Kind.RELAY:
			meetings = [[orb.target, orb.beat, orb.meet, false]]
		if orb.kind == BeatRing.Kind.SWEEP:
			meetings.append([1 - orb.first, orb.second_beat(), -orb.side, true])
		for m in meetings:
			if m[0] == lane and m[1] >= ring._time - 0.05 and (next == null or m[1] < next[1]) \
					and not _pressed.has([orb, lane]):
				next = [orb, m[1], m[2], m[3]]
	var side = ring._sides[lane]
	var shard = false
	var to_go = INF
	var inside = BeatRing.STAND_IN_GUARD
	if next != null:
		side = next[2]
		to_go = next[1] - ring._time
		shard = next[0].kind == BeatRing.Kind.SHARD or next[0].kind == BeatRing.Kind.RELAY
		inside = BeatRing.STAND_IN_SWORD if shard else BeatRing.STAND_IN_GUARD
		if next[3]:
			inside = -inside  # it comes from the middle: stand outside, facing in
	var meet_x = BeatRing.CENTER.x + side * ring.meet_x()
	var dx = meet_x - side * inside - p.global_position.x
	var toward = side * (-1.0 if next != null and next[3] else 1.0)  # the way to face: at it
	if shard and to_go < 0.25 and p.facing != toward:
		_hold_walk(p, toward)  # a step toward it turns the player to face it
	else:
		_hold_walk(p, signf(dx) if absf(dx) > 8.0 else 0.0)
	if next != null and to_go <= BeatRing.STAND_IN_PRESS:
		_pressed[[next[0], lane]] = true
		if randf() < BeatRing.STAND_IN_SKILL:
			_press(p, "attack" if shard else "block")
	for key in _pressed.keys():
		if not is_instance_valid(key[0]):
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
