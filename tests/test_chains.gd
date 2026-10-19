extends "res://tests/test_case.gd"
## The chains mode on Columna Bifrons (Moves "bifrons_mode" "chains"; attacks/chain.gd, THE CHAINS
## in columna_bifrons.gd): a motif repeated until his posture is low or the chain has run its
## length, then a finale that's never chance; the breath after it, and the next chain at whoever
## attacks him in it; a motif's end breaking his guard ("bifrons_guard_break" motif_end). The
## players can't lose; a player parries a strike by having pressed block just before it lands.

const LEFT = -1
const RIGHT = 1

var boss
var left  # his left sword's player
var right  # his right sword's
var middle = 0.0  # where he stands at the start


# Two repetitions a chain, his posture never "low" (unless a test says so).
func _setup(hold = true):
	set_move("bifrons_stand_in", "off")
	set_move("bifrons_mode", "chains")
	set_number("bifrons_chain_reps_min", 2.0)
	set_number("bifrons_chain_reps_max", 2.0)
	set_number("bifrons_chain_posture", 0.0)
	await load_scene("res://levels/threshold/threshold.tscn")
	boss = GameManager.boss
	boss.dev_hold = hold
	boss.dev_still = true
	left = boss.own_ward(LEFT)
	right = boss.own_ward(RIGHT)
	middle = boss.global_position.x
	for p in [left, right]:
		p.invincible = true


# Him back in the middle, the two where they're asked (px from him), everything fresh.
func _place(left_x = -110.0, right_x = 110.0):
	while boss.state != BaseBoss.State.IDLE or boss._handed != "":
		await get_tree().physics_frame
	boss.global_position.x = middle
	left.global_position.x = middle + left_x
	right.global_position.x = middle + right_x
	await wait(0.3)
	var rules = GameManager.rules
	for p in [left, right]:
		p.velocity = Vector2.ZERO
		p._invuln_timer = 0.0
		p._stagger_timer = 0.0
	for actor in [left, right, boss]:
		rules._posture[actor] = rules.posture_max(actor)
		rules._busy_at[actor] = -100.0
	rules.team = rules.team_max() * 0.5
	rules.team_chaos = false
	rules.boss_chaos = false
	rules.sync_mode = false


# Runs a chain (and a finale of its own after it) to its end, each player in `parrying` parrying
# every blade at them. Returns {"stagger", "names": the attacks in turn, "chain", "windows": [blade,
# breaks] for every window a parry opened}.
func _run(chain_name: String, parrying: Array) -> Dictionary:
	var chain = boss.find_attack(chain_name)
	boss.dev_next = chain_name
	boss.timer = 0.0
	var names = []
	var windows = []
	var opened = boss._open_from.duplicate()
	var began = false
	var stagger = 0.0
	for i in 1500:
		await get_tree().physics_frame
		for blade in [LEFT, RIGHT]:
			if boss._open_from[blade] != opened[blade]:
				opened[blade] = boss._open_from[blade]
				windows.append([blade, boss._open_breaks[blade]])
		if boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			began = true
			var attack_name = boss.current_attack.get_attack_name()
			if names.is_empty() or names.back() != attack_name:
				names.append(attack_name)
			for p in parrying:
				if boss.time_to_strike(p) < 0.05:
					p.parry_press_time = p.now()  # pressed block just now
		elif began and boss.state == BaseBoss.State.STAGGER:
			stagger = boss.timer
			break
		elif began and boss.state == BaseBoss.State.IDLE and boss._handed == "":
			break
	check(began, chain_name + ": he runs it")
	return {"stagger": stagger, "names": names, "chain": chain, "windows": windows}


func test_motif_then_the_finale():
	await _setup()
	await _place()
	var run = await _run("CHAIN_RRL", [])
	var chain = run.chain
	check(chain._swords[0] == RIGHT, "it starts with the player he's turned to (at first: his right sword's)")
	check(chain._reps_done == 2, "its length run: two repetitions (%d)" % chain._reps_done)
	check(chain._marks.count(0) == 3 and chain._marks.count(1) == 3, "...the motif twice, three strikes each")
	check(chain._swords.slice(0, 3) == chain._swords.slice(3, 6), "...the same way round both times")
	check(chain._finale == "CROSSING", "pep, not pressed: the crossing, which changes the formation (%s)" % chain._finale)
	check(chain._marks.count(-1) == 3, "...its three strikes, in the chain")
	check(run.names == ["CHAIN_RRL"], "...and nothing after it")


func test_low_posture_brings_the_double_strike():
	await _setup()
	set_number("bifrons_chain_posture", 101.0)  # always "low"
	await _place()
	var run = await _run("CHAIN_RLRL", [])
	check(run.chain._reps_done == 1, "pressed: the finale after the first repetition")
	check(run.chain._finale == "BOTH", "...the double strike, their chance to stagger him")
	check(run.chain._marks.count(-1) == 1, "...one strike of both")


func test_in_ppe_the_gate_leap_follows():
	await _setup()
	set_number("bifrons_chain_reps_min", 1.0)
	set_number("bifrons_chain_reps_max", 1.0)
	await _place(-100.0, -130.0)
	check(boss.is_ppe(), "both on his left: ppe")
	var run = await _run("CHAIN_RRL", [left, right])
	check(run.chain._finale == "GATE_LEAP", "ppe, not pressed: the gate leap (%s)" % run.chain._finale)
	check(run.names == ["CHAIN_RRL", "GATE_LEAP"], "...which comes right after the chain, though he's held (%s)" % [run.names])
	near(run.stagger, 0.5 + 0.2 * 9, 0.05, "all parried: staggered for the chain's 3 parries and the gate leap's 6")


# He attacks on his own: after a chain, the breath (he doesn't attack), and the next chain starts
# with the other player.
func test_the_breath():
	await _setup(false)
	set_number("bifrons_chain_reps_min", 1.0)
	set_number("bifrons_chain_reps_max", 1.0)
	set_number("bifrons_chain_posture", 101.0)  # the double strike: no change of formation
	set_number("bifrons_breath_min", 1.0)
	set_number("bifrons_breath_max", 1.0)
	await _place()
	var starts = []  # [anim_time, the first strike's sword] of each chain
	var ended = []  # anim_time each one was over
	var was = boss.state
	var middled = false
	for i in 900:
		await get_tree().physics_frame
		if was in [BaseBoss.State.IDLE, BaseBoss.State.RECOVER] and boss.state == BaseBoss.State.TELEGRAPH:
			starts.append([boss.anim_time, boss.current_attack._swords[0]])
		if was == BaseBoss.State.ATTACKING and boss.state != BaseBoss.State.ATTACKING:
			ended.append(boss.anim_time)
		if not ended.is_empty() and starts.size() == 1 and boss._wants_middle():
			middled = true
		was = boss.state
		if starts.size() == 2:
			break
	check(starts.size() == 2 and ended.size() >= 1, "two chains, one after the other")
	if starts.size() == 2 and not ended.is_empty():
		var pause = starts[1][0] - ended[0]
		near(pause, Tuning.value("bifrons_recover_time") + 1.0, 0.05, "between them his recovery and the breath")
		check(starts[1][1] == -starts[0][1], "the second starts with the other player")
	check(middled, "in the breath he heads for the middle of the room")


func test_toward_the_middle():
	await _setup()
	var room_middle = (BaseBoss.ARENA_LEFT + BaseBoss.ARENA_RIGHT) / 2.0
	boss.global_position.x = room_middle + 300.0
	left.global_position.x = room_middle + 400.0
	right.global_position.x = room_middle + 450.0
	near(boss._toward_middle(), room_middle, 0.5, "nobody on the way: to the middle")
	left.global_position.x = room_middle + 150.0
	near(boss._toward_middle(), room_middle + 150.0 + boss.FIT_DISTANCE, 0.5, "a player on the way: no nearer than FIT_DISTANCE")
	left.global_position.x = room_middle + 260.0
	near(boss._toward_middle(), room_middle + 300.0, 0.5, "one right up against him on the way: he stays")


# A hit at his guard in the breath calls up the next chain at once, at the attacker; not while
# the dev tools hold him.
func test_attacked_in_the_breath():
	for held in [false, true]:
		await _setup(false)
		set_number("bifrons_chain_reps_min", 1.0)
		set_number("bifrons_chain_reps_max", 1.0)
		set_number("bifrons_chain_posture", 101.0)
		set_number("bifrons_breath_min", 3.0)
		set_number("bifrons_breath_max", 3.0)
		await _place(-100.0, 100.0)
		var first_over = false
		for i in 900:
			await get_tree().physics_frame
			if boss.state == BaseBoss.State.ATTACKING:
				first_over = true
			elif first_over and boss.state == BaseBoss.State.IDLE:
				break
		check(first_over and boss.state == BaseBoss.State.IDLE, "a chain, and then the breath")
		boss.dev_hold = held
		await wait(0.3)
		left.global_position.x = boss.global_position.x - 90.0  # in reach of him (the double strike threw them)
		left.velocity = Vector2.ZERO
		await frames(2)
		await tap(left, "attack")
		var answered = false
		for i in 30:  # half a second, well inside the breath
			await get_tree().physics_frame
			if boss.state == BaseBoss.State.TELEGRAPH:
				answered = true
				check(boss.current_attack._swords[0] == LEFT, "the answer's first strike is at the attacker")
				break
		check(answered != held, "attacked in the breath, %s: %s" % ["held" if held else "free", "no answer" if held else "the next chain at once"])


func test_a_motifs_end_breaks_his_guard():
	await _setup()
	set_move("bifrons_guard_break", "motif_end")
	await _place()
	var run = await _run("CHAIN_RRL", [left, right])
	var motif_windows = run.windows.slice(0, 6)
	var breaks = motif_windows.map(func(w): return w[1])
	check(breaks == [false, false, true, false, false, true], "all parried: only each repetition's last parry breaks it (%s)" % [breaks])
	check(boss._break_flash_until > 0.0, "...and he flashes white")
	await _place()
	run = await _run("CHAIN_RRL", [left])
	check(not run.windows.is_empty() and run.windows.all(func(w): return not w[1]), "one of them not parrying: windows, but no break")
	set_move("bifrons_guard_break", "on")
	await _place()
	run = await _run("CHAIN_RRL", [left, right])
	check(run.windows.size() >= 6 and run.windows.all(func(w): return w[1]), "on: every parry breaks it")


# The switch used to be on / off: a saved one keeps what it was.
func test_a_saved_switch_is_kept():
	var entry = Moves.ENTRIES.filter(func(e): return e.key == "bifrons_guard_break")[0]
	check(Moves.read_saved(entry, false) == "off", "saved off: off")
	check(Moves.read_saved(entry, true) == "on", "saved on: on")
	check(Moves.read_saved(entry, "motif_end") == "motif_end", "the new value")
	check(Moves.read_saved(entry, "nonsense") == null, "anything else: dropped")
