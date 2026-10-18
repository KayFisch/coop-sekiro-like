extends "res://tests/test_case.gd"
## The player's moves the levels are built on, each tried in an empty room (tests/rooms/): the
## dash-slash, a hit's knockback, the launch, the pogo clash and the pogo points, the wall jump
## and its rhythm, the chimney clash, the ledge grab, and the rhythm relay.
## The numbers are the player's own constants, so this checks the code does what they say.

const ROOM = "res://tests/rooms/open_room.tscn"

var level
var p1
var p2
var step = 1.0 / 60.0


func _room():
	await load_scene(ROOM)
	level = get_tree().current_scene
	p1 = level.players[0]
	p2 = level.players[1]
	step = 1.0 / Engine.physics_ticks_per_second
	_place(p2, 2000.0)  # out of the way, unless a test wants the partner


# Puts a player at x, standing on the floor (or with its middle at y, in the air), still.
func _place(p, x: float, y = INF):
	p.global_position = Vector2(x, level.GROUND_Y - level.PLAYER_HALF if y == INF else y)
	p.velocity = Vector2.ZERO
	p.interrupt_movement()


# Lifted off the floor (_place() in the air), the player still had it under its feet a frame
# ago: a jump this soon is a ground jump (coyote time). Waits it out.
func _coyote_gone(p):
	await wait(p.COYOTE_TIME + step)


# Waits physics frames until `condition` holds, at most `timeout` s; true if it came. It looks
# after each frame, so what follows always starts on one (a press then is seen on the next).
func _until(condition: Callable, timeout: float) -> bool:
	var waited = 0.0
	while true:
		await get_tree().physics_frame
		waited += step
		if condition.call():
			return true
		if waited > timeout:
			return false
	return false


# The highest the player gets (the smallest y) over the next `seconds`.
func _top_over(p, seconds: float) -> float:
	var top = p.global_position.y
	var waited = 0.0
	while waited < seconds:
		await get_tree().physics_frame
		waited += step
		top = minf(top, p.global_position.y)
	return top


# The world's walls for a test: a block `w` wide whose left face is at x, from the floor up
# `height` px.
func _wall(x: float, height: float, w = 40.0):
	level.solid(x, level.GROUND_Y - height, w, height)


func test_dash_slash():
	await _room()
	_place(p1, 400.0)
	await wait(0.2)
	var start = p1.global_position.x
	hold(p1, "dash")
	hold(p1, "attack")
	await frames(2)
	hold(p1, "dash", false)
	hold(p1, "attack", false)
	check(p1.movement_state() == "dash-slash windup", "dash + attack: the dash-slash winds up (%s)" % p1.movement_state())
	var windup = step  # its first frame, the one the press was seen on
	var still = true
	while p1.movement_state() == "dash-slash windup" and windup < 1.0:
		windup += step
		still = still and absf(p1.global_position.x - start) < 1.0
		await get_tree().physics_frame
	check(still, "held in place through the windup")
	near(windup, p1.DASH_SLASH_WINDUP, 2.5 * step, "the windup lasts DASH_SLASH_WINDUP (s)")
	var from = p1.global_position.x
	var went = 0.0
	while p1.movement_state() == "dash-slash":
		went = p1.global_position.x - from
		await get_tree().physics_frame
	near(went, p1.DASH_DISTANCE, p1.DASH_DISTANCE / 7.0, "then the dash covers DASH_DISTANCE (px; a frame's worth either way)")


func test_hit_knockback():
	await _room()
	_place(p1, 600.0)
	await wait(0.3)
	var hits = []
	p1.damaged.connect(func(p): hits.append(p))
	p1.take_damage(Vector2(-300.0, -200.0))
	check(hits.size() == 1, "a hit lands")
	hold(p1, "right")
	await wait(p1.KNOCKBACK_TIME * 0.6)
	check(p1.velocity.x < 0.0, "knocked back: the stick can't steer against it for KNOCKBACK_TIME")
	p1.take_damage(Vector2(300.0, -200.0))
	check(hits.size() == 1, "right after a hit, another doesn't land (HIT_INVULN_TIME)")
	await wait(p1.HIT_INVULN_TIME)
	p1.take_damage()
	check(hits.size() == 2, "...after HIT_INVULN_TIME it does")
	hold(p1, "right", false)


func test_launch():
	await _room()
	set_move("players_collide", false)
	_place(p1, 400.0)
	_place(p2, 500.0)
	p1.facing = 1.0
	p2.facing = -1.0
	await wait(0.2)
	var launches = []
	p1.launched.connect(func(p): launches.append(p))
	var floor_y = p1.global_position.y
	hold(p1, "dash")
	hold(p1, "attack")
	await frames(2)
	hold(p1, "dash", false)
	hold(p1, "attack", false)
	# The partner upslashes as it comes: near the windup's end, just before the blades meet.
	await wait(p1.DASH_SLASH_WINDUP - 0.1)
	hold(p2, "up")
	await tap(p2, "attack")
	var top = await _top_over(p1, 1.0)
	hold(p2, "up", false)
	check(launches.size() == 1, "a dash-slash into the partner's upslash: a launch")
	check(floor_y - top >= p1.LAUNCH_HEIGHT * 0.9, "...up %.0f px (LAUNCH_HEIGHT %.0f)" % [floor_y - top, p1.LAUNCH_HEIGHT])


func test_pogo_clash():
	await _room()
	set_move("players_collide", false)
	_place(p2, 600.0)
	_place(p1, 600.0, level.GROUND_Y - level.PLAYER_HALF - 62.0)  # its feet ~22 px over the partner's head
	await frames(2)  # off the floor a frame: attack + down is a downslash
	var clashes = []
	p1.pogo_clashed.connect(func(p): clashes.append(p))
	var from = p1.global_position.y
	hold(p2, "up")
	hold(p2, "attack")
	hold(p1, "down")
	hold(p1, "attack")
	await frames(2)
	for button in ["up", "attack"]:
		hold(p2, button, false)
	for button in ["down", "attack"]:
		hold(p1, button, false)
	var top = await _top_over(p1, 0.6)
	check(clashes.size() == 1, "a downslash onto the partner's upslash: a pogo clash")
	check(from - top >= p1.POGO_HEIGHT * 0.7, "...bouncing up %.0f px (POGO_HEIGHT %.0f)" % [from - top, p1.POGO_HEIGHT])


# A downslash in the air at x, feet 20 px over `top_y`: the highest the player gets after it.
func _downslash_over(x: float, top_y: float) -> float:
	_place(p1, x, top_y - level.PLAYER_HALF - 20.0)
	await frames(2)  # off the floor a frame: attack + down is a downslash
	hold(p1, "down")
	hold(p1, "attack")
	await frames(2)
	hold(p1, "down", false)
	hold(p1, "attack", false)
	return await _top_over(p1, 0.6)


func test_pogo_points():
	await _room()
	var lantern_top = level.GROUND_Y - 200.0
	level.target(Vector2(600.0, lantern_top + 12.0), GymTarget.Mode.LANTERN)  # 24 px tall
	var from = lantern_top - level.PLAYER_HALF - 20.0
	var top = await _downslash_over(600.0, lantern_top)
	check(from - top >= p1.POGO_HEIGHT * 0.7, "a lantern is a pogo point: up %.0f px (POGO_HEIGHT %.0f)" % [from - top, p1.POGO_HEIGHT])
	level.spikes(860.0, 940.0, level.GROUND_Y)
	var pogo_before = p1.pogo_time
	await _downslash_over(900.0, level.GROUND_Y - level.SPIKE_HEIGHT)
	check(p1.pogo_time == pogo_before, "spikes aren't: a downslash over them doesn't bounce")


func test_wall_jump():
	await _room()
	set_move("wall", "slide")
	set_move("wall_jump", true)
	_wall(700.0, 760.0)
	_place(p1, 660.0, level.GROUND_Y - 500.0)  # in the air, left of the wall
	hold(p1, "right")
	check(await _until(func(): return p1.movement_state() == "wall slide", 1.0), "flying into a wall, holding toward it: sliding down it")
	hold(p1, "right", false)
	check(p1.facing == -1.0, "...facing away from it")
	await _coyote_gone(p1)
	var from = p1.global_position.y
	await tap(p1, "jump")
	check(p1.velocity.x <= -p1.WALL_JUMP_PUSH * 0.9, "a wall jump pushes off, away from the wall")
	var top = await _top_over(p1, p1.WALL_FLIGHT_TIME)
	# Steered back into the wall it jumped off: that one is spent until you land.
	hold(p1, "right")
	var touched = false
	var stuck = false
	for i in 45:
		await get_tree().physics_frame
		top = minf(top, p1.global_position.y)
		touched = touched or p1.global_position.x >= 700.0 - level.PLAYER_SIZE.x / 2.0 - 1.0
		stuck = stuck or p1.movement_state() == "wall slide"
	hold(p1, "right", false)
	near(from - top, p1.WALL_JUMP_HEIGHT, 12.0, "...and up WALL_JUMP_HEIGHT (px)")
	check(touched and not stuck, "back at the wall it jumped off, in the air: it doesn't take you again")


func test_wall_rhythm():
	await _room()
	set_move("wall", "slide")
	set_move("wall_jump", true)
	set_move("wall_rhythm", true)
	# A narrow shaft: a wall jump's own flight crosses it (WALL_FLIGHT_TIME), no steering needed.
	var left_face = 640.0
	var right_face = left_face + 120.0
	_wall(left_face - 40.0, 760.0)
	_wall(right_face, 760.0)
	_place(p1, right_face - 20.0, level.GROUND_Y - 300.0)
	hold(p1, "right")
	check(await _until(func(): return p1.movement_state() == "wall slide", 1.0), "on the right wall")
	hold(p1, "right", false)
	await _coyote_gone(p1)
	await tap(p1, "jump")
	check(p1.wall_jump_strong, "a climb's first wall jump is always a full one")
	var contact = p1._wall_contact_time
	check(await _until(func(): return p1._wall_contact_time != contact, 1.0), "flew to the left wall")
	await tap(p1, "jump")
	check(p1.wall_jump_strong, "pressed as it hits the wall: a full one (%+.0f ms off)" % (p1.wall_jump_off * 1000.0))
	contact = p1._wall_contact_time
	check(await _until(func(): return p1._wall_contact_time != contact, 1.0), "flew back to the right wall")
	await wait(p1.WALL_RHYTHM_TOLERANCE + 0.08)
	await tap(p1, "jump")
	check(not p1.wall_jump_strong, "pressed late (%+.0f ms off): a weak one" % (p1.wall_jump_off * 1000.0))


func test_wall_rhythm_on_the_clock():
	await _room()
	set_move("wall", "slide")
	set_move("wall_jump", true)
	set_move("wall_rhythm", true)
	Beat.start(120.0, level)
	# A narrow shaft at 120 BPM: its own flight takes half a beat. The first wall jump comes at
	# no particular moment; the flights after it are steered onto the clock's half-beats.
	var left_face = 640.0
	var right_face = left_face + level.PLAYER_SIZE.x + p1.WALL_JUMP_PUSH * 0.25
	_wall(left_face - 40.0, 760.0)
	_wall(right_face, 760.0)
	_place(p1, right_face - 20.0, level.GROUND_Y - 300.0)
	hold(p1, "right")
	check(await _until(func(): return p1.movement_state() == "wall slide", 1.0), "on the right wall")
	hold(p1, "right", false)
	await _coyote_gone(p1)
	await wait(0.13)  # off the clock's grid
	await tap(p1, "jump")
	var off = []  # ms from the nearest half-beat, at each wall reached
	for i in 4:
		var contact = p1._wall_contact_time
		if not await _until(func(): return p1._wall_contact_time != contact, 1.0):
			break
		var halves = Beat.beats_at(Beat.time()) * 2.0
		off.append(roundi(absf(halves - roundf(halves)) * Beat.beat_length() / 2.0 * 1000.0))
		await tap(p1, "jump")
	check(off.size() == 4, "four walls reached (%d)" % off.size())
	check(off.size() == 4 and off[2] <= roundi(2000.0 * step) and off[3] <= roundi(2000.0 * step),
		"from the third wall on, reached on a half-beat of the clock (ms off: %s)" % str(off))


func test_chimney_clash():
	await _room()
	set_move("wall", "slide")
	set_move("wall_jump", true)
	set_move("chimney_clash", true)
	# Two walls, each player's wall jump flying half the way: they meet in the middle.
	var left_face = 640.0
	var right_face = left_face + 240.0
	_wall(left_face - 40.0, 760.0)
	_wall(right_face, 760.0)
	_place(p1, left_face + 20.0, level.GROUND_Y - 300.0)
	_place(p2, right_face - 20.0, level.GROUND_Y - 300.0)
	hold(p1, "left")
	hold(p2, "right")
	check(await _until(func(): return p1.movement_state() == "wall slide" and p2.movement_state() == "wall slide", 1.0),
		"each on a wall, facing the other")
	hold(p1, "left", false)
	hold(p2, "right", false)
	await _coyote_gone(p1)
	hold(p1, "jump")
	hold(p2, "jump")
	await frames(2)
	hold(p1, "jump", false)
	hold(p2, "jump", false)
	check(await _until(func(): return absf(p2.global_position.x - p1.global_position.x) <= level.PLAYER_SIZE.x + 8.0, 1.0),
		"the two wall jumps meet in the middle")
	var before = p1.chimney_clash_time
	hold(p1, "jump")
	hold(p2, "jump")
	var clashed = await _until(func(): return p1.chimney_clash_time != before, 0.25)
	hold(p1, "jump", false)
	hold(p2, "jump", false)
	check(clashed, "both press jump as they meet: a chimney clash")
	check(p1.velocity.x < 0.0 and p2.velocity.x > 0.0, "...each flying back to its own wall")


func test_ledge_grab():
	await _room()
	set_move("ledge_grab", true)
	var top_y = level.GROUND_Y - 100.0
	level.solid(700.0, top_y, 300.0, 100.0)
	_place(p1, 670.0)
	await wait(0.2)
	hold(p1, "right")
	await tap(p1, "jump")
	check(await _until(func(): return p1.movement_state() == "ledge", 1.5), "jumping at a wall whose top is in reach: hanging from its edge")
	check(await _until(func(): return p1.movement_state() == "climbing", 0.5), "...holding toward it: climbing up")
	check(await _until(func(): return p1.movement_state() == "ground", 1.0), "...and standing")
	hold(p1, "right", false)
	check(p1.global_position.x > 700.0 and p1.global_position.y < top_y, "...on top of it")


func test_rhythm_relay():
	await _room()
	set_move("players_collide", false)
	set_move("relay", true)
	_place(p1, 400.0)
	_place(p2, 520.0)
	p1.facing = 1.0
	p2.facing = -1.0
	await wait(0.2)
	var relays = []
	p1.relayed.connect(func(p): relays.append(p))
	# 1: the dash-slash charges while attack is held, and is let go on a beat.
	hold(p1, "dash")
	hold(p1, "attack")
	await frames(2)
	hold(p1, "dash", false)
	check(p1.movement_state() == "dash-slash charge", "a rhythm dash-slash charges while attack is held (%s)" % p1.movement_state())
	await wait(Beat.beat_length())  # the charge started the clock
	check(await _until(func(): return absf(Beat.offset_to_beat()) <= step / 2.0, 2.0), "a beat comes")
	hold(p1, "attack", false)  # (letting go is seen this same frame: a frame past the beat)
	check(await _until(func(): return p1.movement_state() != "dash-slash charge", 0.1), "let go")
	var beat_1 = p1.relay_beat
	check(beat_1 >= 0 and p1.movement_state() == "dash-slash windup", "let go on a beat, that's 1: the run comes for 2 (%s)" % p1.movement_state())
	# 2: the partner parries as the blades meet, on the 2 (a press is seen a frame after it).
	check(await _until(func(): return Beat.time() >= Beat.beat_time(beat_1 + 1) - 0.06 - step, 1.0), "the 2 comes")
	hold(p2, "block")
	check(await _until(func(): return p1.movement_state() == "clash", 0.3), "the anchor's parry on 2 locks the blades")
	hold(p2, "block", false)
	# 3: the anchor strikes on the 3, aiming up; the dasher flies to the top by the 4.
	hold(p2, "up")
	var from = p1.global_position.y
	check(await _until(func(): return Beat.time() >= Beat.beat_time(beat_1 + 2) - 2.5 * step, 1.0), "the 3 comes")
	await tap(p2, "attack")
	check(p1.movement_state() == "relay boost", "the strike on 3 throws the dasher (%s)" % p1.movement_state())
	var top = await _top_over(p1, Beat.beat_length() * 1.2)
	hold(p2, "up", false)
	near(from - top, p1.RHYTHM_THROW_HEIGHT, 12.0, "...up RHYTHM_THROW_HEIGHT (px) by the 4")
	check(relays.size() == 1, "one relay")
