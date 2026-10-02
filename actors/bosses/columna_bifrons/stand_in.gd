class_name BifronsStandIn
extends Node
## Testing alone (Moves "bifrons_stand_in"): plays one of the two players in the fight with
## Columna Bifrons, so one person can play the other. It presses that player's own buttons, so
## everything that happens to them is the game's own: it walks to keep its distance to him,
## meets each of his strikes with a parry, a block or nothing (by chance), and when its health
## is low it runs off to drink a potion. It never attacks.

enum Plan { NOTHING, PARRY, BLOCK }

# --- Tuning ---
# What it does with a strike of his, decided as the strike comes up: perfect parried this
# often, only blocked that often (chip damage), and the rest hit.
const PARRY_CHANCE = 0.75
const BLOCK_CHANCE = 0.15
const PARRY_LEAD = 0.08  # s before a strike lands that it presses block to parry (the window is 0.133 s)
const BLOCK_LEAD = 0.35  # ...and to only block: too early for a parry
# Where it stands, from his center: where a player's sword would reach him, and not so close
# that he steps back (ColumnaBifrons.CROWD_DISTANCE). With its partner on the same side of him
# it stands closer if it's the one in front (so the partner's sword reaches him from behind
# it), and right behind the partner if it isn't. It starts walking once it's SLACK off, and
# stops when it's there.
const DISTANCE = 95.0
const DISTANCE_IN_FRONT = 74.0
const DISTANCE_BEHIND = 42.0  # from its partner (a player is 40 wide)
const SLACK = 12.0
# Below FLEE_HP, with a potion left, it runs away from him, FLEE_DISTANCE or to the wall, and
# drinks. Then it comes back.
const FLEE_HP = 20.0
const FLEE_DISTANCE = 480.0
const WALL_NEAR = 30.0  # this close to the arena's edge it's at the wall
const POTION_RETRY = 0.3  # s between two tries at the potion (a hit can swallow one)

var boss  # the ColumnaBifrons it belongs to

var _player = null  # the player it's playing right now
var _buttons = ""  # that player's input set ("p1_" or "p2_")
var _held = {}  # action name -> true while the stand-in holds it down
var _plan = Plan.NOTHING  # for his next strike at it
var _last_due = INF
var _walk = 0.0  # the way it's walking: -1, 1, or 0
var _fleeing = false
var _potion_wait = 0.0


func _physics_process(delta):
	var player = _played()
	var buttons = player._action("") if player != null else ""
	if player != _player or buttons != _buttons:
		# Another player to play, or other buttons (Moves "swap_controls"): start over.
		_release_all()
		_player = player
		_buttons = buttons
		_plan = Plan.NOTHING
		_last_due = INF
		_walk = 0.0
		_fleeing = false
	if player == null:
		return
	_defend(player)
	_move(player, delta)


func _exit_tree():
	_release_all()  # a held button would outlast the fight


# The player it plays, while there's a fight to play them in.
func _played():
	if boss == null or boss.hp <= 0.0 or GameManager.state != GameManager.GameState.PLAYING:
		return null
	var player = boss.stand_in_player()
	return player if player != null and player.hp > 0.0 else null


# His strikes at it: a new one coming gets its plan, and block is pressed when the plan says.
func _defend(player):
	var due = boss.time_to_strike(player)
	if due != INF and (_last_due == INF or due > _last_due):
		var roll = randf()
		_plan = Plan.PARRY if roll < PARRY_CHANCE else (Plan.BLOCK if roll < PARRY_CHANCE + BLOCK_CHANCE else Plan.NOTHING)
		_hold(player, "block", false)
	_last_due = due
	var lead = -1.0
	if _plan == Plan.PARRY:
		lead = PARRY_LEAD
	elif _plan == Plan.BLOCK:
		lead = BLOCK_LEAD
	_hold(player, "block", due <= lead)


# Its feet: to its distance from him, or away from him to drink.
func _move(player, delta: float):
	var away = signf(player.global_position.x - boss.global_position.x)
	if away == 0.0:
		away = 1.0
	var distance = boss.distance_to(player)
	_potion_wait = maxf(_potion_wait - delta, 0.0)
	_hold(player, "potion", false)
	if player.potions > 0 and player.hp < FLEE_HP:
		_fleeing = true
	elif not player.is_drinking():
		_fleeing = false
	if _fleeing:
		var x = player.global_position.x
		var at_wall = x < boss.ARENA_LEFT + WALL_NEAR or x > boss.ARENA_RIGHT - WALL_NEAR
		if player.is_drinking():
			_walk = 0.0
		elif distance < FLEE_DISTANCE and not at_wall:
			_walk = away
		else:
			_walk = 0.0
			if _potion_wait <= 0.0:
				_potion_wait = POTION_RETRY
				_hold(player, "potion", true)
	else:
		var want = DISTANCE
		var partner = boss.partner_of(player)
		if partner != null and boss.side_of(partner) == boss.side_of(player):
			var theirs = boss.distance_to(partner)
			want = DISTANCE_IN_FRONT if theirs > distance else maxf(theirs + DISTANCE_BEHIND, DISTANCE)
		if absf(distance - want) > SLACK:
			_walk = -away if distance > want else away
		elif _walk != 0.0 and (distance - want) * _walk * away >= 0.0:
			_walk = 0.0  # there
	_hold(player, "left", _walk < 0.0)
	_hold(player, "right", _walk > 0.0)


# Presses or lets go of one of the player's buttons, if that's a change.
func _hold(player, button: String, down: bool):
	var action = player._action(button)
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
