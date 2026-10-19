extends "res://tests/test_case.gd"
## The blade rules of 2026-10-19 on Columna Bifrons ("THE BLADE RULES" in columna_bifrons.gd,
## docs/concept.md "Blade rules: additions"): one parry per blade, a throw by outcome, and the
## stagger from the attack's parries. His attacks run as in the fight (dev_next); a player parries
## a strike by having pressed block just before it lands (_run()). The numbers are set here, so
## the saved F2 values don't matter; posture doesn't come back, so what each landing cost can be
## read off at the end.

const LEFT = -1
const RIGHT = 1
const NUMBERS = {
	"posture_small": 5.0, "posture_medium": 15.0, "posture_large": 30.0,
	"boss_posture_small": 4.0, "boss_posture_medium": 12.0, "boss_posture_large": 24.0,
	"player_posture_max": 100.0, "boss_posture_max": 200.0,
	"player_posture_regen": 0.0, "boss_posture_regen": 0.0,
	"bifrons_parried_throw": 0.5, "bifrons_stagger_least": 0.5, "bifrons_stagger_per_parry": 0.2,
	"coop_parry_stagger": 1.0,
}

var rules
var boss
var left  # the player his left sword fights
var right  # ...and his right
var middle = 0.0  # where he stands at the start


func _setup():
	set_move("bifrons_stand_in", "off")
	for key in NUMBERS:
		set_number(key, NUMBERS[key])
	await load_scene("res://levels/threshold/threshold.tscn")
	rules = GameManager.rules
	boss = GameManager.boss
	boss.dev_hold = true
	boss.dev_still = true
	left = boss.own_ward(LEFT)
	right = boss.own_ward(RIGHT)
	middle = boss.global_position.x


# Him back in the middle, the two where they're asked (px from him), everything fresh: full
# posture, half sync, nothing recent.
func _place(left_x: float, right_x: float):
	while boss.state != BaseBoss.State.IDLE:
		await get_tree().physics_frame
	boss.global_position.x = middle
	left.global_position.x = middle + left_x
	right.global_position.x = middle + right_x
	await wait(0.3)
	_fresh()


func _fresh():
	for p in [left, right]:
		p.velocity = Vector2.ZERO
		p._invuln_timer = 0.0
		p._stagger_timer = 0.0
	rules.team = rules.team_max() * 0.5
	rules.boss_sync = rules.boss_max()
	rules.team_chaos = false
	rules.boss_chaos = false
	rules.sync_mode = false
	for actor in [left, right, boss]:
		rules._posture[actor] = rules.posture_max(actor)
		rules._busy_at[actor] = -100.0


func _lost(actor) -> float:
	return rules.posture_max(actor) - rules.posture_of(actor)


# Runs one of his attacks to its end, each player in `parrying` parrying every strike at them.
# Returns {"stagger": how long he's staggered (0: not), "parried": whose parries counted}.
func _run(attack_name: String, parrying: Array) -> Dictionary:
	var counted = []
	var on_parry = func(p, _kind): counted.append(p)
	boss.parry_success.connect(on_parry)
	boss.dev_next = attack_name
	boss.timer = 0.0
	var began = false
	var stagger = 0.0
	for i in 600:
		await get_tree().physics_frame
		if boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			began = true
			for p in parrying:
				if boss.time_to_strike(p) < 0.05:
					p.parry_press_time = p.now()  # pressed block just now
		elif began:
			if boss.state == BaseBoss.State.STAGGER:
				stagger = boss.timer
			break
	boss.parry_success.disconnect(on_parry)
	check(began, attack_name + ": he attacks")
	return {"stagger": stagger, "parried": counted}


func test_pep_two_normal_strikes():
	await _setup()
	await _place(-110.0, 110.0)
	check(not boss.is_ppe(), "a player on each side: pep")
	var run = await _run("BOTH", [left, right])
	near(run.stagger, 0.9, 0.02, "pep, both parry: staggered 0.5 + 2 x 0.2 s")
	check(run.parried.size() == 2, "...both parries count")
	near(_lost(left), NUMBERS.posture_small, 0.01, "...a normal strike's parry: small posture")
	near(_lost(boss), 2.0 * NUMBERS.boss_posture_small, 0.01, "...him: small, twice")
	await _place(-110.0, 110.0)
	run = await _run("BOTH", [left])
	near(run.stagger, 0.0, 0.001, "pep, one parries: no stagger")
	check(run.parried == [left], "...but the lone parry counts as a parry")
	near(_lost(boss), NUMBERS.boss_posture_small, 0.01, "...costing him a normal parry's posture")
	near(_lost(right), NUMBERS.posture_medium, 0.01, "...and the other is hit by a normal strike")


func test_ppe_parried_together():
	await _setup()
	await _place(-140.0, -100.0)
	check(boss.is_ppe(), "both on his left: ppe")
	var run = await _run("BOTH", [left, right])
	near(run.stagger, 0.9, 0.02, "ppe, both parry: staggered")
	near(_lost(left), NUMBERS.posture_medium, 0.01, "...a heavy strike's parry: medium posture")
	near(_lost(boss), 2.0 * NUMBERS.boss_posture_medium, 0.01, "...him: medium, twice")
	await _place(-140.0, -100.0)
	run = await _run("BOTH", [left])
	near(run.stagger, 0.0, 0.001, "ppe, one parries: no stagger")
	check(run.parried.is_empty(), "...and the lone parry doesn't count")
	near(_lost(boss), 0.0, 0.01, "...it's a block: nothing to him")
	near(_lost(left), NUMBERS.posture_medium, 0.01, "...a heavy block for the parrier")
	near(_lost(right), NUMBERS.posture_large, 0.01, "...and the other is hit, heavy")
	# Off: as before, each parries their own blade.
	set_move("bifrons_blade_parries", false)
	await _place(-140.0, -100.0)
	run = await _run("BOTH", [left])
	check(run.parried == [left], "switch off: the lone parry counts")
	near(_lost(boss), NUMBERS.boss_posture_medium, 0.01, "...a heavy parry, for him too")


func test_both_swords_on_one_player():
	await _setup()
	await _place(-110.0, 420.0)
	boss._turn(RIGHT, true)  # his right sword has turned on the left one's player (LEFT ALONE)
	await frames(2)
	check(boss.ward_of(RIGHT) == left, "both swords on one player")
	var run = await _run("BOTH", [left])
	check(run.parried.is_empty(), "their parry alone doesn't count")
	near(run.stagger, 0.0, 0.001, "...no stagger")
	near(_lost(boss), 0.0, 0.01, "...nothing to him")
	near(_lost(left), NUMBERS.posture_medium, 0.01, "...a heavy block")
	set_move("bifrons_blade_parries", false)
	await _place(-110.0, 420.0)
	boss._turn(RIGHT, true)
	await frames(2)
	run = await _run("BOTH", [left])
	check(run.parried == [left], "switch off: one parry meets both")
	near(_lost(boss), NUMBERS.boss_posture_medium, 0.01, "...costing him a heavy parry")
	boss._turn(RIGHT, false)


func test_leap_by_where_they_stand():
	await _setup()
	await _place(-70.0, 70.0)
	var run = await _run("LEAP", [left])
	check(run.parried == [left], "the leap between them (pep): a lone parry counts")
	near(_lost(boss), NUMBERS.boss_posture_small, 0.01, "...a normal strike's, for him")
	await _place(-70.0, 70.0)
	run = await _run("LEAP", [left, right])
	near(run.stagger, 0.9, 0.02, "both parry the leap: staggered 0.5 + 2 x 0.2 s")


func test_throw_by_outcome():
	await _setup()
	await _place(-110.0, 110.0)
	var p = left
	# [knock, throws]: both swords on one player; a plain cut, which has no throw of its own.
	var hits = {"throw": [1.5, true], "cut": [1.0, false]}
	for on in [true, false]:
		set_move("bifrons_throw_by_outcome", on)
		for kind in hits:
			var full = boss.BLADE_KNOCKBACK * hits[kind][0]
			var wants = {"parry": 0.0, "block": boss.BLOCKED_KNOCKBACK * hits[kind][0], "hit": full}
			if on and hits[kind][1]:
				wants = {"parry": full * NUMBERS.bifrons_parried_throw, "block": full, "hit": full}
			for how in wants:
				_fresh()
				if how == "block":
					hold(p, "block")
				var judged = {"blade": LEFT, "under": [p], "parriers": [p] if how == "parry" else [], "parried": how == "parry"}
				boss.land(judged, false, hits[kind][0], true, hits[kind][1])
				hold(p, "block", false)
				near(absf(p.velocity.x), wants[how], 1.0, "%s, %s, switch %s: thrown back" % [kind, how, "on" if on else "off"])
				if wants[how] > 0.0:
					check(p.velocity.x < 0.0, "%s, %s: away from him" % [kind, how])


func test_stagger_from_the_attack():
	await _setup()
	await _place(-110.0, 110.0)
	var run = await _run("QUAD", [left, right])
	check(run.parried.size() == 5, "QUAD, all parried: 3 strikes and both blades of the last (%d)" % run.parried.size())
	near(run.stagger, 0.5 + 0.2 * 5, 0.02, "...staggered 0.5 + 5 x 0.2 s")
	await _place(-110.0, 110.0)
	run = await _run("BOTH", [left, right])
	near(run.stagger, 0.9, 0.02, "the next attack counts from its own start")
	set_move("bifrons_chain_stagger", false)
	await _place(-110.0, 110.0)
	run = await _run("QUAD", [left, right])
	near(run.stagger, NUMBERS.coop_parry_stagger, 0.02, "switch off: the sync rules' one number")


# Chaos (no sync): no blocking, but a parry still parries (Nicho, 2026-10-19: it seemed not to).
func test_parry_in_chaos():
	await _setup()
	await _place(-110.0, 110.0)
	rules._set_team(0.0)
	check(rules.team_chaos, "no sync: chaos")
	var run = await _run("SINGLE", [left, right])
	check(run.parried.size() == 1, "chaos: a parry still counts")
	check(not left.is_dead() and not right.is_dead(), "...and nobody is dead")
