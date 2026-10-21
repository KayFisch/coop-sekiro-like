class_name HitterStandIn
extends Node
## Testing alone (Moves "bifrons_stand_in": "left" is P1, "right" P2): plays one of the two players
## against the Heavy Hitter, by pressing that player's own buttons, so everything that happens to them
## is the game's own. It goes to stand in front of the blade of its layer: from his pommel side over
## him (between his chains), or under him in a stomp leap. It meets each of his strikes at it with a
## parry, a block or nothing (by chance, F2 "hitter_stand_in_parry" / "_block"), jumps the mirror
## breaking open under it (crack.gd), and strikes when its partner's parry opens its window (a sync
## hit). It re-forms when that helps (F2 "hitter_stand_in_reform": how often), going over him to his
## other side: in the rage's roar, if its pattern is the hard one for their formation, and after a
## flip that leaves it at his pommel. In the players' sync mode it goes to its partner to bind, and
## bound it draws back when they do and lets go on the big cue (as Bifrons's stand-in does).

enum Plan { NOTHING, PARRY, BLOCK }

# --- Tuning ---
const PARRY_LEAD = 0.08  # s before a strike lands that it presses block to parry (the window is 0.133 s)
const BLOCK_LEAD = 0.35  # ...and to only block: too early for a parry
# When its partner's parry opens its window, it strikes that often, after a reaction of up to
# REACT_TIME (a hit lands about 0.1 s after the press: some on the beat, some after it).
const SYNC_HIT_CHANCE = 0.75
const REACT_TIME = 0.08
const DISTANCE = 105.0  # from his center: where it stands
const SLACK = 14.0  # it starts walking once it's this far off, and stops when it's there
# Over him, from his pommel side: it runs at him, jumps from JUMP_FROM (his center), and dashes on once
# it rises slower than DASH_AT_RISE (px/s): over his body (100 high) and down on the other side.
const JUMP_FROM = 135.0
const DASH_AT_RISE = 150.0
const JUMP_HOLD = 0.3  # s it holds jump: a full jump
const CRACK_LEAD = 0.1  # s before the mirror breaks open under it that it jumps
const DASH_THROUGH_FROM = 70.0  # sync mode, him between it and its partner: it dash-slashes through from this close
const LET_GO_WITHIN = 0.02  # s from a beat that it lets a dash-slash's charge go (Player._release_charge())

var boss  # the HeavyHitter it belongs to

var _player = null  # the player it's playing right now
var _buttons = ""  # that player's input set ("p1_" or "p2_")
var _held = {}  # action name -> true while the stand-in holds it down
var _plan = Plan.NOTHING  # for his next strike at it
var _last_due = INF
var _walk = 0.0  # the way it's walking: -1, 1, or 0
var _window = false  # its window was open last frame
var _strike_in = -1.0  # s until it presses attack, or < 0: no strike coming
var _jump_for = 0.0  # s it still holds jump
var _dash_for = 0  # frames it still holds dash
var _dashed = false  # this jump over him has had its dash
var _let_go = false  # bound: it has let go while its partner still draws back
var _dash_wait = 0.0  # s until it may dash-slash through him again
var _over_to = 0  # re-forming: the side of him it's going over to (0: not)
var _rage_seen = false  # the rage under way has had its decision
var _ways_seen = []  # the blade's way in its layer and its partner's, last frame (a flip: its own alone changes)


func _physics_process(delta):
	var player = _played()
	var buttons = player.action("") if player != null else ""
	if player != _player or buttons != _buttons:
		# Another player to play, or other buttons (Moves "swap_controls"): start over.
		_release_all()
		_player = player
		_buttons = buttons
		_plan = Plan.NOTHING
		_last_due = INF
		_walk = 0.0
		_window = false
		_strike_in = -1.0
		_jump_for = 0.0
		_dash_for = 0
		_over_to = 0
		_rage_seen = false
		_ways_seen = []
	if player == null:
		return
	_defend(player)
	_strike(player, delta)
	_jump(player, delta)
	_reform(player)
	_move(player, delta)


func _exit_tree():
	_release_all()  # a held button would outlast the fight


# The player it plays, while there's a fight to play them in.
func _played():
	if boss == null or boss.hp <= 0.0 or GameManager.state != GameManager.GameState.PLAYING:
		return null
	var player = boss.stand_in_player()
	return player if player != null and not player.is_dead() else null


# His strikes at it: a new one coming gets its plan, and block is pressed when the plan says.
func _defend(player):
	var due = boss.time_to_strike(player)
	if due != INF and (_last_due == INF or due > _last_due):
		var roll = -1.0 if boss.in_sync_mode() else randf()  # in sync mode: always a parry
		var parry = Tuning.value("hitter_stand_in_parry")
		_plan = Plan.PARRY if roll < parry else (Plan.BLOCK if roll < parry + Tuning.value("hitter_stand_in_block") else Plan.NOTHING)
		_hold(player, "block", false)
	_last_due = due
	var lead = -1.0
	if _plan == Plan.PARRY:
		lead = PARRY_LEAD
	elif _plan == Plan.BLOCK:
		lead = BLOCK_LEAD
	_hold(player, "block", due <= lead)


# Its sword: its window newly open gets a sync hit (by chance), after a reaction. The press is let
# go the frame after, so the next one counts as a new press.
func _strike(player, delta: float):
	if boss.is_bound():
		_strike_bound(player)
		return
	if player.is_charging():
		_hold(player, "attack", absf(Beat.offset_to_beat()) > LET_GO_WITHIN)  # a dash-slash: let go on a beat
		return
	_hold(player, "attack", false)
	var window = boss.window_for(player)
	if window and not _window and randf() < SYNC_HIT_CHANCE:
		_strike_in = randf() * REACT_TIME
	_window = window
	if _strike_in < 0.0:
		return
	_strike_in -= delta
	if _strike_in < 0.0 and not _held.get(player.action("block"), false):
		_hold(player, "attack", true)


# Bound: attack held while its partner draws back, let go on the big cue (or when the partner lets
# go first).
func _strike_bound(player):
	var bond = boss.rules.bond
	var partner = player.partner()
	var drawing = partner != null and partner.is_drawing()
	if not drawing:
		_let_go = false
	var hold = drawing and not _let_go
	if bond.cue_at >= 0.0 and bond.now() >= bond.cue_at:
		hold = false
	if _held.get(player.action("block"), false):
		hold = false
	if not hold and player.is_drawing():
		_let_go = drawing  # let go while the partner still draws: not again until they have too
	_hold(player, "attack", hold)


# Its jumps: off the floor as the mirror breaks open under it; the dash of a jump over him.
func _jump(player, delta: float):
	if _dash_for > 0:
		_dash_for -= 1
		_hold(player, "dash", _dash_for > 0)
	if _jump_for > 0.0:
		_jump_for -= delta
		_hold(player, "jump", _jump_for > 0.0)
		return
	if not player.is_on_floor():
		return
	for crack in boss.get_tree().get_nodes_in_group("hitter_cracks"):
		if crack.time_to_break(player) <= CRACK_LEAD:
			_press_jump(player)
			return


func _press_jump(player):
	_jump_for = JUMP_HOLD
	_dashed = false
	_hold(player, "jump", true)


# Re-forming, when it helps (by chance): in the rage's roar, if the pattern is the hard one for their
# formation (the pendulum apart, the cross together), and when a flip has left it at his pommel. Either
# way: over him to his other side.
func _reform(player):
	var partner = player.partner()
	var side = boss.side_of(player)
	if boss.rage == "raging":
		if not _rage_seen and boss.state == BaseBoss.State.TELEGRAPH:
			_rage_seen = true
			var apart = partner != null and boss.side_of(partner) != side
			if boss.rage_cross != apart and randf() < Tuning.value("hitter_stand_in_reform"):
				_over_to = -side
	else:
		_rage_seen = false
	var ways = [boss.way_of(player), boss.way_of(partner) if partner != null else 0]
	var flipped = _ways_seen.size() == 2 and ways[0] != _ways_seen[0] and ways[1] == _ways_seen[1]
	_ways_seen = ways
	if flipped and boss.rage == "" and not boss.at_blade(player) and randf() < Tuning.value("hitter_stand_in_reform"):
		_over_to = -side
	if _over_to == side or not boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
		_over_to = 0  # there, or it's over


# Its feet: in front of his blade, at its distance; from his pommel side over him (or under him in a
# stomp leap), and when re-forming. In his chains it stays where it is meanwhile. In sync mode: to its
# partner.
func _move(player, delta: float):
	var away = boss.side_of(player)
	var distance = boss.distance_to(player)
	if boss.in_sync_mode() and player.partner() != null:
		var gap = player.partner().global_position.x - player.global_position.x
		_walk = signf(gap) if absf(gap) > Tuning.value("sync_connect_distance") * 0.5 else 0.0
		# He's between them: up to him, then a dash-slash through him.
		_dash_wait = maxf(_dash_wait - delta, 0.0)
		var between = signf(boss.global_position.x - player.global_position.x) == signf(gap) and absf(gap) > distance
		var dash = between and distance < DASH_THROUGH_FROM and _dash_wait <= 0.0 and not boss.is_bound()
		if dash:
			_dash_wait = 0.6
			_hold(player, "attack", true)
			_dash_for = 2
			_hold(player, "dash", true)
	elif _over_to != 0 or (not boss.at_blade(player) and (boss.airborne or boss.state in [BaseBoss.State.IDLE, BaseBoss.State.RECOVER])):
		# At his pommel, or re-forming: over to his other side, at him and on.
		_walk = -away
		if not boss.airborne and player.is_on_floor() and _jump_for <= 0.0 and distance <= JUMP_FROM:
			_press_jump(player)
		if not player.is_on_floor() and not _dashed and player.velocity.y > -DASH_AT_RISE:
			_dashed = true
			_dash_for = 2
			_hold(player, "dash", true)
	elif absf(distance - DISTANCE) > SLACK:
		_walk = -away if distance > DISTANCE else away
	elif _walk != 0.0 and (distance - DISTANCE) * _walk * away >= 0.0:
		_walk = 0.0  # there
	_hold(player, "left", _walk < 0.0)
	_hold(player, "right", _walk > 0.0)


# Presses or lets go of one of the player's buttons, if that's a change.
func _hold(player, button: String, down: bool):
	var action = player.action(button)
	if down == _held.get(action, false):
		return
	_held[action] = down
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_all():
	for action in _held:
		if _held[action]:
			Input.action_release(action)
	_held = {}
