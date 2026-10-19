extends "res://tests/test_case.gd"
## The gate leap (attacks/gate_leap.gd; docs/boss_bifrons_warden.md, "Gate leap"), tried out on
## Columna Bifrons: from ppe back to pep, the sword in the floor a wall, the stagger when it's all
## parried, and the finish on B's side when A is out of his reach (F2 "bifrons_gate_lift": A's time
## to come back). The two start on his left, A (his left sword's player) in front. A player
## parries a blade by having pressed block just before it lands (_run()). They can't lose: what
## each landing costs is the blade rules' test's.

const LEFT = -1
const RIGHT = 1

var boss
var a  # in front: his left sword's player
var b  # behind: his right sword's
var middle = 0.0  # where he stands at the start

# What the per-frame watchers (_run()'s each_frame) saw.
var _seen = {}
var _back_step = 0
var _back_since = 0.0


func _setup():
	set_move("bifrons_stand_in", "off")
	await load_scene("res://levels/threshold/threshold.tscn")
	boss = GameManager.boss
	boss.dev_hold = true
	boss.dev_still = true
	a = boss.own_ward(LEFT)
	b = boss.own_ward(RIGHT)
	middle = boss.global_position.x
	for p in [a, b]:
		p.invincible = true
	_seen = {}
	_back_step = 0


# Him back in the middle, A and B on his left (px from him), everything fresh.
func _place(a_x = -100.0, b_x = -130.0):
	while boss.state != BaseBoss.State.IDLE:
		await get_tree().physics_frame
	boss.global_position.x = middle
	a.global_position.x = middle + a_x
	b.global_position.x = middle + b_x
	await wait(0.3)
	var rules = GameManager.rules
	for p in [a, b]:
		p.velocity = Vector2.ZERO
		p._invuln_timer = 0.0
		p._stagger_timer = 0.0
	for actor in [a, b, boss]:
		rules._posture[actor] = rules.posture_max(actor)
		rules._busy_at[actor] = -100.0
	rules.team = rules.team_max() * 0.5
	rules.team_chaos = false
	rules.boss_chaos = false
	rules.sync_mode = false


# Runs the gate leap to its end, each player in `parrying` parrying every blade at them, and
# `each_frame` (a method's name, if any) called every physics frame with the attack. Returns
# {"stagger": how long he's staggered (0: not), "parries": [[player, kind]] that counted, "gate"}.
func _run(parrying: Array, each_frame = "") -> Dictionary:
	var parries = []
	var on_parry = func(p, kind): parries.append([p, kind])
	boss.parry_success.connect(on_parry)
	var gate = boss.find_attack("GATE_LEAP")
	boss.dev_next = "GATE_LEAP"
	boss.timer = 0.0
	var began = false
	var stagger = 0.0
	for i in 900:
		await get_tree().physics_frame
		if boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			began = true
			for p in parrying:
				if boss.time_to_strike(p) < 0.05:
					p.parry_press_time = p.now()  # pressed block just now
			if each_frame != "":
				call(each_frame, gate)
		elif began:
			if boss.state == BaseBoss.State.STAGGER:
				stagger = boss.timer
			break
	boss.parry_success.disconnect(on_parry)
	check(began, "he does the gate leap")
	return {"stagger": stagger, "parries": parries, "gate": gate}


func _kinds(run: Dictionary, kind: String) -> Array:
	return run.parries.filter(func(pk): return pk[1] == kind).map(func(pk): return pk[0])


func test_from_ppe_to_pep():
	await _setup()
	await _place()
	check(boss.is_ppe(), "both on his left: ppe")
	check(boss.find_attack("GATE_LEAP").fits(boss), "...the gate leap fits")
	await _place(-100.0, 100.0)
	check(not boss.find_attack("GATE_LEAP").fits(boss), "one on each side: it doesn't")
	await _place()
	var run = await _run([], "_watch_sword")
	check(_seen.has("planted"), "A's sword stood in the floor")
	check(_seen.has("wall"), "...and made a wall")
	check(_seen.get("between", false), "...between the two")
	check(not boss.is_planted(LEFT) and boss._walls.is_empty(), "...and is out again")
	check(boss.side_of(a) == RIGHT and boss.side_of(b) == LEFT, "afterwards one on each side: A behind him, B ahead")
	check(run.gate._on_back, "nobody parried: the rip threw A out of his reach, the finish went to B's side")


func _watch_sword(gate):
	if boss.is_planted(LEFT):
		_seen["planted"] = true
		var spot = gate._spot
		if (a.global_position.x - spot) * gate._way < 0.0 and (b.global_position.x - spot) * gate._way > 0.0:
			_seen["between"] = true
	if boss._walls.has(LEFT):
		_seen["wall"] = true


func test_the_sword_is_a_wall():
	await _setup()
	await _place()
	await _run([], "_walk_at_the_sword")
	check(_seen.has("walked"), "A walked at the sword while it stood")
	check(not _seen.has("crossed"), "...and didn't get past it")


# While the wall stands, A walks at it (they're on his left: the spot is to A's left).
func _walk_at_the_sword(gate):
	var standing = boss._walls.has(LEFT)
	hold(a, "left", standing)
	if standing:
		_seen["walked"] = true
		if (a.global_position.x - gate._spot) * gate._way > 0.0:
			_seen["crossed"] = true


func test_all_parried_staggers():
	await _setup()
	await _place()
	var run = await _run([a, b])
	check(_kinds(run, "bifrons_gate_ram").size() == 2, "the ram: both parried it")
	check(_kinds(run, "bifrons_gate_strike") == [b], "the strike as he lands: B's")
	check(_kinds(run, "bifrons_gate_rip") == [a], "the rip: A's")
	check(not run.gate._on_back, "A parried the rip, so stayed in his reach: one sword on each")
	check(_kinds(run, "bifrons_gate_heavy").size() == 2, "...both parried the heavy strike")
	near(run.stagger, 0.5 + 0.2 * 6, 0.03, "staggered 0.5 + 6 x 0.2 s")


func test_on_b_it_takes_both():
	await _setup()
	await _place()
	var run = await _run([b])
	check(run.gate._on_back, "A hit by the rip: both swords on B's side")
	check(_kinds(run, "bifrons_gate_heavy").is_empty(), "...where B's parry alone is a block")
	near(run.stagger, 0.0, 0.001, "...no stagger")
	set_move("bifrons_blade_parries", false)
	await _place()
	run = await _run([b])
	check(_kinds(run, "bifrons_gate_heavy") == [b], "one parry per blade off: B's parry meets both")


# A blocks the rip (thrown as far as by a hit) and dashes back as soon as the throw lets go
# (KNOCKBACK_TIME): in time while the lift is long enough (F2 "bifrons_gate_lift"), and not when
# the swords start down while A is still out there.
func test_a_can_come_back():
	for lift in [Tuning.value("bifrons_gate_lift"), 0.25]:
		await _setup()
		set_number("bifrons_gate_lift", lift)
		await _place()
		var run = await _run([b], "_block_and_come_back")
		check(_seen.has("dashed"), "lift %.2f s: A blocked the rip and dashed back" % lift)
		check(run.gate._on_back == (lift < 0.3), "lift %.2f s: the finish %s" % [lift, "on B's side" if lift < 0.3 else "on each"])


func _block_and_come_back(gate):
	match _back_step:
		0:
			if gate._landed == 2 and gate._rip_at - gate._time < 0.3:
				hold(a, "block")
				_back_step = 1
		1:
			if gate._landed >= 3:
				hold(a, "block", false)
				_back_since = gate._time
				_back_step = 2
		2:
			if gate._time - _back_since >= PlayerBody.KNOCKBACK_TIME:
				hold(a, "dash")
				_back_step = 3
		3:
			hold(a, "dash", false)
			_seen["dashed"] = true
			_back_step = 4


func test_the_ram_shows_in_both_halves():
	set_move("mirror_view", true)
	set_move("mirror_blades", "color")
	await _setup()
	await _place()
	await _run([], "_watch_halves")
	check(_seen.has("ram"), "A's sword, raised at both, stood out in both halves before it went in")
	check(_seen.has("planted"), "...and in the floor")


func _watch_halves(gate):
	if gate._landed == 0 and boss._heavy_shown[LEFT] >= 1.0:
		_seen["ram"] = true
	if boss.is_planted(LEFT) and boss._heavy_shown[LEFT] >= 1.0:
		_seen["planted"] = true
