class_name ChimneyBot
extends Node
## Plays player 2 in the wall gym's coop chimney as player 1's mirror image: while player 1 is
## inside, it keeps player 2 at player 1's mirror position (left for right), outside a clash, and
## copies each of player 1's wall jumps off the mirrored wall, so the two wall jumps meet in the
## middle. It copies the wall jump itself, not the jump button: pressing the button only worked
## if player 2 was stuck to its wall, which needs the stick held into it. Player 1's other jump
## presses it copies as presses (with player 1's timing), so the chimney clash still needs player
## 1 to press jump as they meet. Being a frame late (it runs before the players), it takes over
## player 1's timing (on time or not), so the rhythm judges player 1 alone. It still holds the
## mirrored left/right, so player 2 faces the right way: add it before the players.

var leader  # player 1
var follower  # player 2, the one it plays
var center_x = 0.0  # the chimney's middle: the mirror line
var inside = Vector2.ZERO  # the chimney's inner x range: it mirrors while the leader is in it

var _held = {}  # action name -> true while held down
var _leader_jump = -100.0  # the leader's last wall jump seen


func _physics_process(_delta):
	if leader == null or follower == null:
		return
	var x = leader.global_position.x
	var active = x > inside.x and x < inside.y
	var jumped = leader.wall_beat_time != _leader_jump
	_leader_jump = leader.wall_beat_time
	var free = not leader.is_held() and not follower.is_held()
	if active:
		follower._jump_press_time = leader._jump_press_time
	if active and free:
		if jumped:
			# Off the mirrored wall: player 1 jumped off the wall on -dir, so this one's on +dir.
			follower._wall_chain = true
			follower._wall_jump(leader._wall_jump_dir)
			follower.wall_jump_off = leader.wall_jump_off
			follower.wall_jump_strong = leader.wall_jump_strong
			follower.wall_jump_moment = leader.wall_jump_moment
		follower.global_position = Vector2(2.0 * center_x - x, leader.global_position.y)
		follower.velocity = Vector2(-leader.velocity.x, leader.velocity.y)
	_hold("left", active and _leader_holds("right"))
	_hold("right", active and _leader_holds("left"))


func _leader_holds(button: String) -> bool:
	return Input.is_action_pressed(leader.action(button))


func _hold(button: String, down: bool):
	var action = follower.action(button)
	if down and not _held.get(action, false):
		Input.action_press(action)
		_held[action] = true
	elif not down and _held.get(action, false):
		Input.action_release(action)
		_held[action] = false


func _exit_tree():
	for action in _held:
		if _held[action]:
			Input.action_release(action)
