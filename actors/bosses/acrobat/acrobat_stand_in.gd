class_name AcrobatStandIn
extends Node
## Testing alone (Moves "bifrons_stand_in": "left" is P1, "right" P2): plays one of the two players
## against the Acrobat, by pressing that player's own buttons, so everything that happens to them is
## the game's own. It keeps after him (at DISTANCE, on its side), meets each of his blows at it (a
## strike, a kick, a ring) with a parry, a block or nothing (by chance, F2 "acrobat_stand_in_parry" /
## "_block"), strikes when its partner's parry opens its window (a sync hit), and strikes back a ring
## its partner parried as it passes in front of it (F2 "acrobat_stand_in_strike_back": how often),
## going to meet it. In the players' sync mode it goes to its partner to bind, and bound it draws back
## when they do and lets go on the big cue (as the Heavy Hitter's stand-in does).

enum Plan { NOTHING, PARRY, BLOCK }

# --- Tuning ---
const PARRY_LEAD = 0.08  # s before a blow lands that it presses block to parry (the window is 0.133 s)
const BLOCK_LEAD = 0.35  # ...and to only block: too early for a parry
const SYNC_HIT_CHANCE = 0.75  # its window opening, it strikes that often...
const REACT_TIME = 0.08  # ...after a reaction of up to this
const DISTANCE = 70.0  # from his center: where it stands (he is narrow: its blade reaches him from here)
const SLACK = 16.0  # it starts walking once it's this far off, and stops when it's there
const SWORD_AHEAD = Vector2(34.0, -12.0)  # about where its blade cuts, in front of it
const STRIKE_WHEN = 40.0  # px: a ring this near that spot, it swings
const MEET_AHEAD = 30.0  # going to meet a ring, it stands this far behind its way, facing him

var boss  # the Acrobat it belongs to

var _player = null  # the player it's playing right now
var _buttons = ""  # that player's input set ("p1_" or "p2_")
var _held = {}  # action name -> true while the stand-in holds it down
var _plan = Plan.NOTHING  # for his next blow at it
var _last_due = INF
var _walk = 0.0  # the way it's walking: -1, 1, or 0
var _window = false  # its window was open last frame
var _strike_in = -1.0  # s until it presses attack, or < 0: no strike coming
var _rings = {}  # ring -> true if it will strike it back (decided once, as it can first)
var _let_go = false  # bound: it has let go while its partner still draws back


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
		_rings = {}
	if player == null:
		return
	_defend(player)
	var ring = _ring_to_strike(player)
	_strike(player, ring, delta)
	_move(player, ring)


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
		var roll = -1.0 if boss.in_sync_mode() else randf()  # in sync mode: always a parry
		var parry = Tuning.value("acrobat_stand_in_parry")
		_plan = Plan.PARRY if roll < parry else (Plan.BLOCK if roll < parry + Tuning.value("acrobat_stand_in_block") else Plan.NOTHING)
		_hold(player, "block", false)
	_last_due = due
	var lead = -1.0
	if _plan == Plan.PARRY:
		lead = PARRY_LEAD
	elif _plan == Plan.BLOCK:
		lead = BLOCK_LEAD
	_hold(player, "block", due <= lead)


# A ring its partner parried, in its layer now, that it will strike back (decided once per ring).
func _ring_to_strike(player):
	var chosen = null
	for ring in boss.get_tree().get_nodes_in_group("acrobat_rings"):
		if not ring.can_strike(player):
			continue
		if not _rings.has(ring):
			_rings[ring] = randf() < Tuning.value("acrobat_stand_in_strike_back")
		if _rings[ring] and chosen == null:
			chosen = ring
	for ring in _rings.keys():
		if not is_instance_valid(ring):
			_rings.erase(ring)
	return chosen


# Its sword: a ring to strike back passing in front of it; its window newly open gets a sync hit (by
# chance), after a reaction. The press is let go the frame after, so the next one counts as new.
func _strike(player, ring, delta: float):
	if boss.is_bound():
		_strike_bound(player)
		return
	_hold(player, "attack", false)
	if ring != null and not _held.get(player.action("block"), false):
		var ahead = player.global_position + Vector2(SWORD_AHEAD.x * _toward(player), SWORD_AHEAD.y)
		if ring.point().distance_to(ahead) <= STRIKE_WHEN:
			_hold(player, "attack", true)
			return
	var window = boss.window_for(player)
	if window and not _window and randf() < SYNC_HIT_CHANCE:
		_strike_in = randf() * REACT_TIME
	_window = window
	if _strike_in < 0.0:
		return
	_strike_in -= delta
	if _strike_in < 0.0 and not _held.get(player.action("block"), false):
		_hold(player, "attack", true)


# The way it faces: at him.
func _toward(player) -> float:
	return 1.0 if boss.global_position.x >= player.global_position.x else -1.0


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


# Its feet: to meet a ring it will strike back (so it passes in front of it); else after him, at its
# distance, on its side. In sync mode: to its partner.
func _move(player, ring):
	var x = player.global_position.x
	var goal = x
	if boss.in_sync_mode() and player.partner() != null:
		goal = player.partner().global_position.x
		if absf(goal - x) < Tuning.value("sync_connect_distance") * 0.5:
			goal = x
	elif ring != null:
		goal = ring.point().x - _toward(player) * MEET_AHEAD
	else:
		var side = -_toward(player)
		goal = boss.global_position.x + side * DISTANCE
	if absf(goal - x) > SLACK:
		_walk = signf(goal - x)
	elif _walk != 0.0 and (goal - x) * _walk <= 0.0:
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
