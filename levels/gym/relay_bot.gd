class_name RelayBot
extends Node
## Plays the anchor in the relay gym, so one person can try the relay alone: it stands at its
## spot, parries every dash-slash that comes at it right as the blades meet, and strikes exactly
## on beat 3, aiming AIM. It presses the player's own buttons (like BifronsStandIn), so
## everything that happens is the game's own. It has to run before the players each frame, or
## they'd miss its presses: add it before them.

const Player = preload("res://actors/player/player.gd")

const PARRY_LEAD = 0.05  # s before the blades meet that it presses block (a frame early at least:
# the dasher checks for the parry before the anchor has registered a press that same frame)
const BLOCK_HOLD = 0.15  # s it keeps block held after
const HOME_SLACK = 16.0  # px off its spot before it walks back
const AIM = "up"  # the way it throws the dasher: "up", "down", "left" or "right"

var dasher  # the player it parries
var anchor  # the player it plays
var home_x = 0.0

var _held = {}  # action name -> true while held down
var _block_left = 0.0
var _struck = false  # this relay's strike is pressed


func _physics_process(delta):
	if anchor == null or dasher == null:
		return
	_release("attack")  # a strike is one frame's press
	_block_left = maxf(_block_left - delta, 0.0)
	var walk = 0.0
	if anchor._hold_kind == Player.Hold.RELAY_ANCHOR:
		_hold(AIM, true)
		var beat_3 = Beat.beat_time(dasher.relay_beat + 2)
		if not _struck and Beat.time() >= beat_3 - delta / 2.0:
			_hold("attack", true)
			_struck = true
	else:
		_struck = false
		_hold(AIM, false)
		var contact = dasher._predict_contact(anchor)
		if contact >= 0.0 and contact <= PARRY_LEAD + delta and _block_left <= 0.0:
			_release("block")  # a fresh press, or it's no parry
			_block_left = BLOCK_HOLD
		elif _block_left <= 0.0 and contact < 0.0:
			var off = home_x - anchor.global_position.x
			if absf(off) > HOME_SLACK and anchor.is_on_floor():
				walk = signf(off)
	_hold("block", _block_left > 0.0)
	_hold("left", walk < 0.0)
	_hold("right", walk > 0.0)


func _hold(button: String, down: bool):
	var action = anchor.action(button)
	if down and not _held.get(action, false):
		Input.action_press(action)
		_held[action] = true
	elif not down and _held.get(action, false):
		Input.action_release(action)
		_held[action] = false


func _release(button: String):
	_hold(button, false)


func _exit_tree():
	for action in _held:
		if _held[action]:
			Input.action_release(action)
