extends "res://tests/test_case.gd"
## The player's feel, measured in a quiet room (Bifrons's, him held still and out of the way):
## running speed, jump height, dash distance, the parry window, a swing's timing. The numbers are
## the player's own constants, so this checks the code does what they say.

var p


func _setup():
	set_move("bifrons_stand_in", "off")
	set_move("dash", true)
	set_move("players_collide", false)
	await load_scene("res://levels/threshold/threshold.tscn")
	var boss = GameManager.boss
	boss.dev_hold = true
	boss.set_physics_process(false)
	boss.global_position.x = 1100.0
	p = GameManager.players[0]
	GameManager.players[1].global_position.x = 900.0
	p.global_position.x = 300.0
	await wait(0.4)


func test_running_speed():
	await _setup()
	hold(p, "right")
	await wait(0.5)
	near(p.velocity.x, p.SPEED, 1.0, "running speed after 0.5 s")
	hold(p, "right", false)


func test_jump_height():
	await _setup()
	var floor_y = p.global_position.y
	hold(p, "jump")  # held: the full jump (let go early, it's cut short)
	var top = floor_y
	for i in 90:
		await get_tree().physics_frame
		top = minf(top, p.global_position.y)
	hold(p, "jump", false)
	# Stepped at 60 Hz the jump peaks about a frame's rise above JUMP_HEIGHT (~6 px).
	check(floor_y - top >= p.JUMP_HEIGHT and floor_y - top <= p.JUMP_HEIGHT + 8.0,
		"jump height, held: %.1f px (JUMP_HEIGHT %.0f, up to a frame's rise more)" % [floor_y - top, p.JUMP_HEIGHT])


func test_dash_distance():
	await _setup()
	var start = p.global_position.x
	hold(p, "dash")
	var went = 0.0
	for i in 30:
		await get_tree().physics_frame
		if p.is_dashing():
			went = p.global_position.x - start
	hold(p, "dash", false)
	near(went, p.DASH_DISTANCE, p.DASH_DISTANCE / 7.0, "distance covered while dashing (px; a frame's worth either way)")


func test_parry_window():
	await _setup()
	await wait(p.PARRY_SPAM_LOCK)
	hold(p, "block")
	await frames(2)
	check(p.is_perfect_parry(), "a block press opens the parry window")
	await wait(p.PARRY_TOLERANCE + 0.05)
	check(not p.is_perfect_parry(), "...for PARRY_TOLERANCE (%.3f s), not longer" % p.PARRY_TOLERANCE)
	check(p.is_blocking(), "held: a block")
	hold(p, "block", false)


func test_swing_timing():
	await _setup()
	hold(p, "attack")
	var step = 1.0 / Engine.physics_ticks_per_second
	var since = -1  # physics frames since the swing began
	var active_from = -1.0
	var active_to = -1.0
	for i in 60:
		await get_tree().physics_frame
		if since < 0 and p._attack_timer > 0.0:
			since = 0
		elif since >= 0:
			since += 1
		var t = since * step
		if since >= 0 and p.is_sword_active() and active_from < 0.0:
			active_from = t
		if active_from >= 0.0 and active_to < 0.0 and not p.is_sword_active():
			active_to = t
	hold(p, "attack", false)
	near(active_from, p.ATTACK_WINDUP_TIME, step * 1.5, "the cut starts after the windup")
	near(active_to - active_from, p.ATTACK_ACTIVE_TIME, step * 1.5, "...and lasts ATTACK_ACTIVE_TIME")


# DASH-PARRY (player_body.gd): a perfect parry mid-dash, or a dash up to PASS_WINDOW after one,
# carries the player through the boss's body; any other dash stops at it. The parry is the one
# the boss calls when his blade meets a parrying player (on_perfect_parry()).
func test_dash_parry():
	await _setup()
	var boss = GameManager.boss
	boss.global_position.x = 600.0  # room on his far side (_setup() puts him near the wall)
	GameManager.players[1].global_position.x = 100.0
	var block: Rect2 = boss.body_block()
	check(block.size != Vector2.ZERO, "his body blocks")
	var start = block.position.x - 60.0  # a dash's length short of his far side, not of him
	# A plain dash stops at him.
	await _dash_at(start)
	check(p.global_position.x < block.position.x, "a plain dash stops at his body (x %.0f)" % p.global_position.x)
	# A block press mid-dash doesn't end the dash, and opens the parry window.
	await _ready_to_dash(start)
	hold(p, "dash")
	await frames(2)
	hold(p, "dash", false)
	hold(p, "block")
	await frames(2)
	check(p.is_dashing() and p.is_perfect_parry(), "a block press mid-dash: still dashing, and parrying")
	# His blade meets the parry: through him.
	p.on_perfect_parry(false)
	hold(p, "block", false)
	await wait(0.4)
	check(p.global_position.x > block.end.x, "parried mid-dash: through him (x %.0f)" % p.global_position.x)
	# Parried first, dashed within PASS_WINDOW: through him too.
	await _ready_to_dash(start)
	p.on_perfect_parry(false)
	await _dash_at(start, false)
	check(p.global_position.x > block.end.x, "a dash just after a parry: through him (x %.0f)" % p.global_position.x)
	# Dashed later than that: it stops at him.
	await _ready_to_dash(start)
	p.on_perfect_parry(false)
	await wait(p.PASS_WINDOW + 0.1)
	await _dash_at(start, false)
	check(p.global_position.x < block.position.x, "a dash after PASS_WINDOW stops at him (x %.0f)" % p.global_position.x)
	# Off, nothing goes through.
	set_move("parry_pass", false)
	await _ready_to_dash(start)
	hold(p, "dash")
	await frames(2)
	hold(p, "dash", false)
	await frames(2)
	p.on_perfect_parry(false)
	await wait(0.4)
	check(p.global_position.x < block.position.x, "parry_pass off: parried mid-dash, still no way through (x %.0f)" % p.global_position.x)


# The player at x on the floor, facing right, with the dash back.
func _ready_to_dash(x: float):
	p.global_position.x = x
	p.velocity = Vector2.ZERO
	p.interrupt_movement()
	await wait(p.DASH_COOLDOWN + 0.05)


# A dash to the right from x (placed there first, unless `place` is false), and the time to
# finish it.
func _dash_at(x: float, place = true):
	if place:
		await _ready_to_dash(x)
	hold(p, "dash")
	await frames(2)
	hold(p, "dash", false)
	await wait(0.4)
