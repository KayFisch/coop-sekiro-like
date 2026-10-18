extends GymLevel
## The two-player gym: the ways the players' movement meets, station by station.
##  1 LAUNCH     bells at 200 / 280 / 340 / 400 / 460 up: how high does a launch take you?
##  2 CLIFF      330 px up: out of reach alone, in reach launched. The one launched up strikes
##               the switch up top, which opens a way up for the one left below.
##  3 WEIGHT     free-standing weighted pans and a ledge 330 up between them: can weight alone
##               get you there?
##  4 TARGETS    dummies up to 380 up, for strikes out of a launch.
##  5 CHIMNEY    380 wide: too wide to wall-jump alone; climbable with chimney clashes.
##  6 RELAY      bells to aim at, a 640 pit beyond a solo jump, and a high ledge over a lantern
##               field, for relaying straight down into a pogo chain.
##  7 PARTNER    a 700 spike pit with a pillar in the middle: stand on it, and be pogoed off.
## (F1 switches any of these abilities off, to compare.)

const CLIFF = Vector2(1150, 1650)
const CLIFF_HEIGHT = 330.0
const PANS_LEFT = Vector2(1800, 2150)
const PANS_RIGHT = Vector2(2230, 2580)
const PAN_STEP = 90.0  # one player's weight moves them a lot
const PAN_MAX = 100.0  # both on one pan: 100 down (still on screen), the other 100 up
const PRIZE_HEIGHT = 330.0
const WIDE_CHIMNEY = Vector2(5030, 5410)  # its inside: 170 px for each to fly before they meet (20 px bodies)
const WIDE_CHIMNEY_TOP = -250.0
const ENTRANCE = 56.0  # the gap under the chimney's left wall: walk in, but no jumping through it
const RELAY_PIT = Vector2(6400, 7040)
const DROP_LEDGE = Vector2(7250, 270)  # x, top
const LANTERN_FIELD = Vector2(7360, 7900)
const PARTNER_PIT = Vector2(8100, 8800)

var _stairs: Array = []  # the cliff's hidden way up, opened by the switch


func room_name() -> String:
	return "DUO GYM  (2 players)"


func player_count() -> int:
	return 2


func _build():
	bounds = Rect2(0, -500, 9100, 1220)
	var double = Player.JUMP_HEIGHT + Player.DOUBLE_JUMP_HEIGHT
	solid(0, bounds.position.y, 24, GROUND_Y - bounds.position.y)
	solid(bounds.end.x - 24, bounds.position.y, 24, GROUND_Y - bounds.position.y)

	# 1 LAUNCH
	respawn_point = Vector2(100, GROUND_Y - PLAYER_HALF)
	checkpoint(100)
	station(50, "1 · LAUNCH", "One upslashes (↑ + attack),\nthe other dash-slashes into them:\nthe dasher shoots up.\n" \
		+ "Strike the bells: how high\ndoes it take you?", GROUND_Y - 330)
	var bell_x = 480.0
	for h in [200, 280, 340, 400, 460]:
		target(Vector2(bell_x, GROUND_Y - h), GymTarget.Mode.BELL, "%d" % h)
		bell_x += 130.0
	height_mark(300, 1130, GROUND_Y - Player.LAUNCH_HEIGHT, "launch %d" % roundi(Player.LAUNCH_HEIGHT))
	height_mark(300, 1130, GROUND_Y - double, "double jump %d" % roundi(double))

	# 2 CLIFF
	ground(0, PANS_LEFT.x)
	solid(CLIFF.x, GROUND_Y - CLIFF_HEIGHT, CLIFF.y - CLIFF.x, CLIFF_HEIGHT)
	measure(Vector2(CLIFF.x - 12, GROUND_Y), Vector2(CLIFF.x - 12, GROUND_Y - CLIFF_HEIGHT))
	label(Vector2(CLIFF.x + 20, GROUND_Y - CLIFF_HEIGHT - 110), "2 · CLIFF", 22)
	label(Vector2(CLIFF.x + 20, GROUND_Y - CLIFF_HEIGHT - 80),
		"Launch up. Strike the switch up here:\nit opens a way up for your partner.", 13, COLOR_HINT)
	var switch = target(Vector2(CLIFF.y - 50, GROUND_Y - CLIFF_HEIGHT - 30), GymTarget.Mode.SWITCH, "switch")
	switch.activated.connect(_open_stairs)
	for step in [[1040, GROUND_Y - 110], [920, GROUND_Y - 220]]:
		var s = ledge(step[0], step[1], 100)
		s.visible = false
		s.get_child(0).disabled = true
		_stairs.append(s)
	checkpoint(CLIFF.y - 120, GROUND_Y - CLIFF_HEIGHT)

	# 3 WEIGHT
	var pans = WeighedPans.new()
	pans.setup(PANS_LEFT, PANS_RIGHT, GROUND_Y, PAN_STEP, PAN_MAX, GROUND_Y - 360)
	add_child(pans)
	ledge(PANS_LEFT.y - 20, GROUND_Y - PRIZE_HEIGHT, PANS_RIGHT.x - PANS_LEFT.y + 40)
	measure(Vector2(PANS_LEFT.y + 40, GROUND_Y), Vector2(PANS_LEFT.y + 40, GROUND_Y - PRIZE_HEIGHT))
	checkpoint(PANS_LEFT.x - 50)
	station(PANS_LEFT.x - 60, "3 · WEIGHT", "Each player on a pan weighs 1, in the air 0; the heavier pan sinks %d per unit (max %d).\n" \
		% [PAN_STEP, PAN_MAX] + "Can weight get one of you onto the ledge (%d up) without a launch?" % PRIZE_HEIGHT, GROUND_Y - 460)
	ground(PANS_RIGHT.y, RELAY_PIT.x)
	ground(RELAY_PIT.y, bounds.end.x)

	# 4 TARGETS
	station(4150, "4 · TARGETS", "Dummies 60, 240 and 380 up:\nstrike them out of a launch.", GROUND_Y - 430)
	target(Vector2(4300, GROUND_Y - 60), GymTarget.Mode.DUMMY, "60 up")
	target(Vector2(4480, GROUND_Y - 240), GymTarget.Mode.DUMMY, "240 up")
	target(Vector2(4660, GROUND_Y - 380), GymTarget.Mode.DUMMY, "380 up")

	# 5 CHIMNEY: walk in under the left wall; out at the top onto the walkway.
	var inner = WIDE_CHIMNEY.y - WIDE_CHIMNEY.x
	solid(WIDE_CHIMNEY.x - 40, WIDE_CHIMNEY_TOP, 40, GROUND_Y - ENTRANCE - WIDE_CHIMNEY_TOP)
	solid(WIDE_CHIMNEY.y, WIDE_CHIMNEY_TOP, 40, GROUND_Y - WIDE_CHIMNEY_TOP)
	solid(WIDE_CHIMNEY.y + 40, WIDE_CHIMNEY_TOP, 300, 24)
	target(Vector2((WIDE_CHIMNEY.x + WIDE_CHIMNEY.y) / 2.0, WIDE_CHIMNEY_TOP + 30), GymTarget.Mode.BELL, "the top")
	measure(Vector2(WIDE_CHIMNEY.x, GROUND_Y - 150), Vector2(WIDE_CHIMNEY.y, GROUND_Y - 150), "%d" % inner)
	checkpoint((WIDE_CHIMNEY.x + WIDE_CHIMNEY.y) / 2.0)
	checkpoint(WIDE_CHIMNEY.y + 180, WIDE_CHIMNEY_TOP)
	label(Vector2(WIDE_CHIMNEY.y + 60, 120), "5 · CHIMNEY", 22)
	label(Vector2(WIDE_CHIMNEY.y + 60, 150), "%d wide: too wide to wall-jump up alone.\n" % inner \
		+ "One on each wall, jump off together: you clash\nin the middle and bounce back to your walls, higher.", 13, COLOR_HINT)

	# 6 RELAY
	checkpoint(5850)
	target(Vector2(5980, GROUND_Y - 300), GymTarget.Mode.BELL, "straight up")
	target(Vector2(6230, GROUND_Y - 240), GymTarget.Mode.BELL, "up and across")
	measure(Vector2(RELAY_PIT.x, GROUND_Y - 24), Vector2(RELAY_PIT.y, GROUND_Y - 24),
		"%d · past a solo jump: relay over" % (RELAY_PIT.y - RELAY_PIT.x))
	station(5800, "6 · RELAY", "One holds attack and dashes (a dash-slash), lets go on a beat: 1. The other parries as the blades\n" \
		+ "meet: 2. On 3 they strike, aiming with the stick (4 ways, down too): the dasher is thrown, and at\nthe top on 4 can dash again. Air jump not.",
		GROUND_Y - 470)
	ledge(RELAY_PIT.y + 30, GROUND_Y - 110, 90)
	ledge(RELAY_PIT.y + 130, GROUND_Y - 220, 90)
	ledge(DROP_LEDGE.x, DROP_LEDGE.y, 110)
	checkpoint(RELAY_PIT.y + 60)
	spikes(LANTERN_FIELD.x, LANTERN_FIELD.y, GROUND_Y)
	for x in [7450.0, 7630.0, 7810.0]:
		target(Vector2(x, GROUND_Y - 130), GymTarget.Mode.LANTERN)
	label(Vector2(DROP_LEDGE.x - 20, DROP_LEDGE.y - 150), "Down: from up here, relay\nstraight down onto the lanterns\nand pogo across.", 13, COLOR_HINT)

	# 7 PARTNER
	checkpoint(PARTNER_PIT.x - 60)
	spikes(PARTNER_PIT.x, PARTNER_PIT.y, GROUND_Y)
	var middle = (PARTNER_PIT.x + PARTNER_PIT.y) / 2.0
	pillar(middle - 20, 40, 60)
	checkpoint(PARTNER_PIT.y + 80)
	measure(Vector2(PARTNER_PIT.x, GROUND_Y + 30), Vector2(PARTNER_PIT.y, GROUND_Y + 30))
	station(PARTNER_PIT.x - 60, "7 · PARTNER POGO", "One stands on the pillar; the other pogos off them\n" \
		+ "(down + attack in the air) to get across.", GROUND_Y - 430)


# --- 2: the switch opens the stairs ---

func _open_stairs():
	for s in _stairs:
		s.visible = true
		s.get_child(0).set_deferred("disabled", false)
