class_name KultistStandIn
extends Node
## Testing alone (Moves "bifrons_stand_in", F1 → Fights → "Stand-in"; off by default): plays one
## of the two players in the fight with the Kultist, so one person can play the other. It only
## defends, and presses that player's own buttons, so everything that happens to them is the
## game's own:
## - each blow of his at it (his staff, the bolt, a spell: Kultist.time_to_strike()) it meets with
##   a perfect parry, a block or nothing, by chance (Kultist.stand_in_parry_chance,
##   stand_in_block_chance, in the inspector);
## - while a fire of his is coming or burning it goes to the safe place in the middle, and so
##   stands in the bolt;
## - else it keeps its distance from him (Kultist.stand_in_distance), on its side of him.
## It never attacks, and doesn't bind in the players' sync mode.

enum Plan { NOTHING, PARRY, BLOCK }

const PARRY_LEAD = 0.08  # s before a blow lands that it presses block to parry (the window is 0.133 s)
const BLOCK_LEAD = 0.35  # ...and to only block: too early for a parry
const SLACK = 12.0  # px off where it wants to be before it starts walking (it stops once there)
const SAFE_SLACK = 40.0  # ...from the middle of the safe place, while a fire is coming
const WALL_ROOM = 20.0  # px: it doesn't want to stand closer to a wall than this

var boss  # the Kultist it belongs to

var _player = null  # the player it's playing right now
var _buttons = ""  # that player's input set ("p1_" or "p2_")
var _held = {}  # action name -> true while the stand-in holds it down
var _plan = Plan.NOTHING  # for his next blow at it
var _last_due = INF
var _walk = 0.0  # the way it's walking: -1, 1, or 0


func _physics_process(_delta):
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
	if player == null:
		return
	_defend(player)
	_move(player)


func _exit_tree():
	_release_all()  # a held button would outlast the fight


# The player it plays, while there's a fight to play them in.
func _played():
	if boss == null or boss.hp <= 0.0 or GameManager.state != GameManager.GameState.PLAYING:
		return null
	var player = boss.stand_in_player()
	return player if player != null and not player.is_dead() else null


# His blows at it: a new one coming gets its plan, and block is pressed when the plan says.
func _defend(player):
	var due = boss.time_to_strike(player)
	if due != INF and (_last_due == INF or due > _last_due):
		var roll = randf()
		var parry = boss.stand_in_parry_chance
		_plan = Plan.PARRY if roll < parry else (Plan.BLOCK if roll < parry + boss.stand_in_block_chance else Plan.NOTHING)
		_hold(player, "block", false)
	_last_due = due
	var lead = -1.0
	if _plan == Plan.PARRY:
		lead = PARRY_LEAD
	elif _plan == Plan.BLOCK:
		lead = BLOCK_LEAD
	_hold(player, "block", due <= lead)


# Its feet: into the safe place while a fire of his is coming or burning; else to its distance
# from him, on its side of him.
func _move(player):
	var x = player.global_position.x
	var goal: float
	var slack = SLACK
	if boss.fire_coming():
		goal = KultistFireAndLightning.middle()
		slack = SAFE_SLACK
	else:
		var away = signf(x - boss.global_position.x)
		if away == 0.0:
			away = 1.0
		goal = boss.global_position.x + away * boss.stand_in_distance
	goal = clampf(goal, BaseBoss.ARENA_LEFT + WALL_ROOM, BaseBoss.ARENA_RIGHT - WALL_ROOM)
	var off = goal - x
	if absf(off) > slack:
		_walk = signf(off)
	elif _walk != 0.0 and off * _walk <= 0.0:
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
