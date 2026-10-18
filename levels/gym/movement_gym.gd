extends GymLevel
## The single-player gym: one player's movement, station by station, at measured distances, to
## find out what it can do and which directions are worth building levels around.
##  1 RUN       a flat track with 100 px ticks: speed and acceleration.
##  2 HEIGHT    pillars at 96 / jump / 180 / 220 / 260 / 310.
##  3 DISTANCE  gaps of 160 / 280 / 400 / 520 / 640 over pits.
##  4 DASH      a low tunnel (no jumping) with holes of 100 / 140 / 180 under it.
##  5 CLIMB     one-way ledges 110 apart, one jump each.
##  6 SWORD     dummies on the ground, 150 up and 260 up: slash, upslash, dash-slash.
##  7 WALLS     a chimney 130 wide (wall jump up it), and a tall wall to slide down.
##  8 LEDGES    pillars of 180 / 200 / 280 / 330: just past jumping, in reach of a ledge grab.
##  9 POGO      a spike pit with lanterns (pogo points) over it.
## 10 FALL      lantern stairs up to a perch, then a drop to a small safe spot among spikes.
## (F1 switches any of these abilities off, to compare.)

const PILLAR_X = [760, 900, 1040, 1180, 1320, 1460]
const PILLAR_WIDTH = 90.0
const GAPS = [[1850, 2010], [2170, 2450], [2610, 3010], [3170, 3690], [3850, 4490]]  # pits
const GAP_HINTS = ["a hop", "full running jump", "+ dash", "?", "?"]
const TUNNEL = Vector2(4760, 5620)  # the low ceiling's span
const TUNNEL_CLEARANCE = 64.0
const HOLES = [[4900, 5000], [5150, 5290], [5420, 5600]]
const SINGLE_STEP = 110.0
const CHIMNEY = Vector2(7060, 7170)  # the narrow chimney's inside: 90 px of travel for a 20 px body, in a wall jump's flight reach (~108)
const CHIMNEY_TOP = -300.0
const ENTRANCE = 56.0  # the gap under the chimney's left wall: walk in, but no jumping through it
const TALL_WALL = Vector2(7700, 100)  # x, top
const LEDGE_PILLARS = [[7950, 180], [8170, 200], [8390, 280], [8610, 330]]
const LANTERN_PIT = Vector2(8900, 9800)
const LANTERN_STAIRS = [Vector2(10800, 480), Vector2(10950, 390), Vector2(11100, 300), Vector2(11250, 210)]
const PERCH = Vector2(11350, 180)  # x, top
const SAFE_SPOT = Vector2(11780, 11840)


func room_name() -> String:
	return "MOVEMENT GYM  (1 player)"


func _build():
	bounds = Rect2(0, -500, 12300, 1220)
	var jump = Player.JUMP_HEIGHT

	# Walls, and the floor with its pits.
	solid(0, bounds.position.y, 24, GROUND_Y - bounds.position.y)
	solid(bounds.end.x - 24, bounds.position.y, 24, GROUND_Y - bounds.position.y)
	var floor_from = 0.0
	for pit in GAPS + HOLES:
		ground(floor_from, pit[0])
		floor_from = pit[1]
	ground(floor_from, bounds.end.x)

	# 1 RUN
	respawn_point = Vector2(100, GROUND_Y - PLAYER_HALF)
	checkpoint(100)
	station(60, "1 · RUN", "Top speed %d px/s; full speed in ~%.2f s, stopped in ~%.2f s. Ticks every 100 px." \
		% [Player.SPEED, Player.SPEED / Player.GROUND_ACCEL, Player.SPEED / Player.GROUND_DECEL])
	for d in range(1, 7):
		label(Vector2(100 + d * 100 - 8, GROUND_Y + 6), "%d" % (d * 100), 11, COLOR_HINT)

	# 2 HEIGHT
	var heights = [96.0, jump, 180.0, 220.0, 260.0, 310.0]
	var names = ["", "= jump", "", "", "", "?"]
	for i in PILLAR_X.size():
		pillar(PILLAR_X[i], PILLAR_WIDTH, heights[i])
		label(Vector2(PILLAR_X[i] + 4, GROUND_Y - heights[i] - 40), "%d\n%s" % [roundi(heights[i]), names[i]], 12)
	height_mark(730, 1560, GROUND_Y - jump, "jump %d" % roundi(jump))
	station(740, "2 · HEIGHT", "Pillars are labeled with their height. Which ones can you stand on? Which need precise timing?",
		GROUND_Y - 440)

	# 3 DISTANCE
	station(1700, "3 · DISTANCE", "Gaps over pits. How far does a running jump take you, and a dash after it? Each ledge is a checkpoint.")
	var segment_starts = [1650.0]
	for i in GAPS.size():
		var pit = GAPS[i]
		measure(Vector2(pit[0], GROUND_Y - 24), Vector2(pit[1], GROUND_Y - 24), "%d · %s" % [pit[1] - pit[0], GAP_HINTS[i]])
		segment_starts.append(pit[1])
	for x in segment_starts:
		checkpoint(x + 80)

	# 4 DASH
	solid(TUNNEL.x, 300, TUNNEL.y - TUNNEL.x, GROUND_Y - TUNNEL_CLEARANCE - 300)
	station(4520, "4 · DASH", "Low ceiling: no real jumps. A dash covers %d px in %.2f s, ignoring gravity. Holes: 100 / 140 / 180." \
		% [Player.DASH_DISTANCE, Player.DASH_TIME], 170)
	for hole in HOLES:
		measure(Vector2(hole[0], GROUND_Y + 30), Vector2(hole[1], GROUND_Y + 30))
	checkpoint(5075)
	checkpoint(5355)

	# 5 CLIMB
	for k in range(1, 6):
		var x = 5790.0 if k % 2 == 1 else 5900.0
		ledge(x, GROUND_Y - SINGLE_STEP * k, 100)
	measure(Vector2(5775, GROUND_Y), Vector2(5775, GROUND_Y - SINGLE_STEP), "%d" % SINGLE_STEP)
	checkpoint(5700)
	label(Vector2(6215, 230), "5 · CLIMB", 22)
	label(Vector2(6215, 260), "Ledges %d apart, one jump each.\nS drops through a ledge." % SINGLE_STEP, 13, COLOR_HINT)

	# 6 SWORD
	target(Vector2(6620, GROUND_Y - 28))
	target(Vector2(6720, GROUND_Y - 150), GymTarget.Mode.DUMMY, "150 up")
	target(Vector2(6820, GROUND_Y - 260), GymTarget.Mode.DUMMY, "260 up")
	station(6560, "6 · SWORD", "Slash %d · upslash (↑ + attack) %d · dash-slash %d.\nTargets say what hit them." \
		% [Player.ATTACK_DAMAGE, Player.UPSLASH_DAMAGE, Player.DASH_SLASH_DAMAGE], GROUND_Y - 430)

	# 7 WALLS: walk in under the chimney's left wall, climb out at the top onto the walkway, and
	# drop down beside the tall wall.
	var inner = CHIMNEY.y - CHIMNEY.x
	solid(CHIMNEY.x - 40, CHIMNEY_TOP, 40, GROUND_Y - ENTRANCE - CHIMNEY_TOP)
	solid(CHIMNEY.y, CHIMNEY_TOP, 40, GROUND_Y - CHIMNEY_TOP)
	solid(CHIMNEY.y + 40, CHIMNEY_TOP, 360, 24)
	solid(TALL_WALL.x, TALL_WALL.y, 60, GROUND_Y - TALL_WALL.y)
	measure(Vector2(CHIMNEY.x, GROUND_Y - 150), Vector2(CHIMNEY.y, GROUND_Y - 150), "%d" % inner)
	checkpoint((CHIMNEY.x + CHIMNEY.y) / 2.0)
	checkpoint(CHIMNEY.y + 200, CHIMNEY_TOP)
	label(Vector2(CHIMNEY.y + 60, 140), "7 · WALLS", 22)
	label(Vector2(CHIMNEY.y + 60, 170), "Walk in under the left wall. The chimney is %d wide:\n" % inner \
		+ "wall jump from side to side up to the top.\nThen drop beside the tall wall and press into it: slide down\n" \
		+ "(F1: wall off / slide). Jump off it.", 13, COLOR_HINT)

	# 8 LEDGES
	for p in LEDGE_PILLARS:
		pillar(p[0], 120, p[1])
		label(Vector2(p[0] + 4, GROUND_Y - p[1] - 40), "%d" % p[1], 12)
	height_mark(7920, 8740, GROUND_Y - jump - Player.LEDGE_REACH_UP - PLAYER_HALF, "jump + grab")
	checkpoint(7880)
	station(7900, "8 · LEDGES", "Past jump height, but in reach of a ledge grab: press into the pillar.\n" \
		+ "Hanging: up or toward climbs, jump jumps, down or away lets go.", GROUND_Y - 470)

	# 9 POGO
	spikes(LANTERN_PIT.x, LANTERN_PIT.y, GROUND_Y)
	var lx = LANTERN_PIT.x + 130.0
	while lx < LANTERN_PIT.y:
		target(Vector2(lx, GROUND_Y - 100), GymTarget.Mode.LANTERN)
		lx += 180.0
	checkpoint(LANTERN_PIT.x - 50)
	checkpoint(LANTERN_PIT.y + 70)
	station(LANTERN_PIT.x - 40, "9 · POGO", "In the air, down + attack: bounce off the lanterns (pogo points; spikes don't bounce you).\n" \
		+ "F1 decides whether a pogo gives back your dash.", GROUND_Y - 400)

	# 10 FALL
	for pos in LANTERN_STAIRS:
		target(pos, GymTarget.Mode.LANTERN)
	solid(PERCH.x, PERCH.y, 200, 24)
	spikes(PERCH.x + 250, SAFE_SPOT.x, GROUND_Y)
	spikes(SAFE_SPOT.y, SAFE_SPOT.y + 260, GROUND_Y)
	measure(Vector2(SAFE_SPOT.x, GROUND_Y + 30), Vector2(SAFE_SPOT.y, GROUND_Y + 30), "safe")
	checkpoint(10710)
	checkpoint(PERCH.x + 100, PERCH.y)
	checkpoint(SAFE_SPOT.y + 400)
	label(Vector2(10760, 40), "10 · FALL", 22)
	label(Vector2(10760, 70), "Pogo up the lanterns to the perch, then drop to the safe spot.", 13, COLOR_HINT)
