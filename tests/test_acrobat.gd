extends "res://tests/test_case.gd"
## The Acrobat, phase 1 (docs/boss_acrobat.md; actors/bosses/acrobat/): his rule (a parried ring goes
## through the mirror to the partner, who alone can strike it back; blocked or hit it stays in its
## layer and nobody can), the strike back (a hit, in the window a sync hit; a stagger only at a
## finale's end), the feint (red only with the real strike), the salto and what it leads to, the
## finales (by what he sees, none three times in a row), the plunge parried together, one ring per
## hand in the air (but in the rally), evading in his breath, his posture broken leaving his sync, and
## every attack of the lab running through.
## The players can't lose; a player parries a blow by having pressed block just before it lands.

const NUMBERS = {
	"acrobat_beat": 0.2, "acrobat_strike_time": 0.15, "acrobat_feint_delay": 0.2,
	"acrobat_throw_flight": 0.35, "acrobat_arc_time": 1.2, "acrobat_arc_height": 90.0, "acrobat_arc_ease": 2.0,
	"acrobat_strike_back_reach": 48.0, "acrobat_stagger_least": 0.5, "acrobat_stagger_per_parry": 0.2,
	"acrobat_posture_max": 200.0, "acrobat_break_stagger": 3.0,
	"sync_window_delay": 0.2, "sync_beat_time": 0.1, "sync_window_late": 0.3, "sync_hit_gain": 4.0,
	"sync_hit_late_gain": 2.0, "their_heavy_damage": 18.0, "their_normal_share": 0.5,
}

var rules
var boss
var p1  # P1: the light layer's player
var p2  # P2: the shadow layer's
var middle = 0.0  # where he stands at the start


func _setup():
	set_move("bifrons_stand_in", "off")
	for key in NUMBERS:
		set_number(key, NUMBERS[key])
	await load_scene("res://levels/acrobat/acrobat_room.tscn")
	rules = GameManager.rules
	boss = GameManager.boss
	boss.dev_hold = true
	boss.dev_still = true
	p1 = boss.player_of(1)
	p2 = boss.player_of(2)
	middle = boss.global_position.x
	for p in [p1, p2]:
		p.invincible = true


# Him on the floor at `x` (from the middle), the two where they're asked (px from him), everything
# fresh: his rings in his hands, no windows, the meters as they start.
func _place(p1_x: float, p2_x: float, x = 0.0):
	for i in 600:
		if boss.state == BaseBoss.State.IDLE:
			break
		await get_tree().physics_frame
	for ring in get_tree().get_nodes_in_group("acrobat_rings"):
		ring.queue_free()
	await wait(0.6)  # the last run's windows closed
	boss.settle()
	boss.global_position = boss.floor_point(middle + x)
	boss._pairs = {1: 2, 2: 2}
	boss._windows = {}
	boss._finales = []
	boss._provoked_by = null
	boss.begin_run()
	boss.timer = 0.5
	p1.global_position.x = boss.global_position.x + p1_x
	p2.global_position.x = boss.global_position.x + p2_x
	await wait(0.3)
	for p in [p1, p2]:
		p.velocity = Vector2.ZERO
		p._invuln_timer = 0.0
		p._stagger_timer = 0.0
	rules.team = rules.team_max() * 0.5
	rules.boss_sync = rules.boss_max()
	rules.team_chaos = false
	rules.boss_chaos = false
	rules.sync_mode = false
	for actor in [p1, p2, boss]:
		rules._posture[actor] = rules.posture_max(actor)
		rules._busy_at[actor] = -100.0
	await frames(2)


# Starts one of his attacks: the lab's way.
func _start(attack_name: String):
	boss.dev_next = attack_name
	boss.timer = 0.0


# The players in `parrying` parry whatever of his is about to land on them.
func _parry(parrying: Array):
	for p in parrying:
		if boss.time_to_strike(p) < 0.05:
			p.parry_press_time = p.now()  # pressed block just now


# The blade of `p` swinging at that ring: a real swing, its cut put where the ring is.
func _swing_at(p, ring):
	if p.active_sword_point() == null:
		if not p.is_swinging():
			hold(p, "attack")
		return
	hold(p, "attack", false)
	p.global_position += ring.point() - p.active_sword_point()


# Runs one of his attacks until it's over or he's staggered: each player in `parrying` parries every
# blow at them, each in `blocking` holds block all through, and with `strike_back` a parried ring is
# struck back by the partner it goes to. Returns {"stagger": how long he's staggered (0: not),
# "rings": every ring thrown, as it was last seen (_seen()), "struck": how many were struck back,
# "windows": [whose, opened by]..., "steps": the steps run, "places": his place as each step began}.
# (Rings are gone once they're back: what's kept is what they were.)
func _run(attack_name: String, parrying: Array, blocking = [], strike_back = false, frames_max = 1500) -> Dictionary:
	for p in blocking:
		hold(p, "block")
	_start(attack_name)
	var result = {"stagger": 0.0, "rings": [], "struck": 0, "windows": [], "steps": [], "places": []}
	var seen = {}
	var rings = {}  # instance id -> what it was last seen as
	var struck = {}
	var began = false
	var step = {}
	for i in frames_max:
		await get_tree().physics_frame
		for ring in get_tree().get_nodes_in_group("acrobat_rings"):
			if ring.stage == AcrobatRing.Stage.DONE:
				continue
			rings[ring.get_instance_id()] = _seen(ring)
			var partner = boss.player_of(ring.layer)
			if strike_back and ring.can_strike(partner) 					and (boss.window_for(partner) or ring._age > 0.6):  # in the window the parry opened, if it's still to come
				_swing_at(partner, ring)
			if ring.stage == AcrobatRing.Stage.STRUCK:
				struck[ring.get_instance_id()] = true
		for p in boss._windows:
			var key = "%d %.3f" % [p.player_id, boss._windows[p].from]
			if not seen.has(key):
				seen[key] = true
				result.windows.append([p, boss._windows[p].by])
		if boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			began = true
			_parry(parrying)
			var now = boss.current_attack._step
			if not is_same(now, step) and not now.is_empty():
				step = now
				result.steps.append(now.do + (":" + now.kind if now.has("kind") else ""))
				result.places.append(boss.place)
		elif began:
			if boss.state == BaseBoss.State.STAGGER:
				result.stagger = boss.timer
			break
	check(began, attack_name + ": he attacks")
	result.rings = rings.values()
	result.struck = struck.size()
	for p in blocking + [p1, p2]:
		hold(p, "block", false)
		hold(p, "attack", false)
	return result


# A ring as it is: whom it's at, a pair or not, how it was met, whose layer it's in...
func _seen(ring) -> Dictionary:
	return {"target": ring.target, "pair": ring.pair, "outcome": ring.outcome, "finale_end": ring.finale_end,
		"volley": ring.volley.size(), "layer": ring.layer, "strikable": ring.strikable}


func _count(p, kind: String) -> int:
	return Dev._stats_of(p)[kind]


# HIS RULE: a ring parried goes through the mirror into the partner's layer, and only the partner can
# strike it; the parry opens the partner's window. Blocked or hit, it stays in its layer, and nobody
# can strike it.
func test_the_arc():
	await _setup()
	await _place(-150.0, 260.0)
	var run = await _run("THROW", [p2])
	check(run.rings.size() == 1, "one ring thrown (%d)" % run.rings.size())
	var ring = run.rings[0] if not run.rings.is_empty() else null
	if ring == null:
		return
	check(ring.target == p2, "...at the farther one")
	check(ring.outcome == AcrobatRing.PARRIED, "...parried (%s)" % ring.outcome)
	check(ring.layer == 1 and ring.strikable, "...through the mirror into P1's layer")
	check([p1, p2] in run.windows, "...and P2's parry opened P1's window (%s)" % [run.windows])
	await _place(-150.0, 260.0)
	_start("THROW")
	var parried_seen = false
	for i in 600:
		await get_tree().physics_frame
		_parry([p2])
		for r in get_tree().get_nodes_in_group("acrobat_rings"):
			if r.stage == AcrobatRing.Stage.ARC and r.strikable:
				parried_seen = true
				check(r.can_strike(p1), "on its way back, P1 (the partner) can strike it")
				check(not r.can_strike(p2), "...P2, who parried it, can't")
		if parried_seen or boss.state == BaseBoss.State.RECOVER:
			break
	check(parried_seen, "the parried ring flew back")
	for outcome in ["blocked", "hit"]:
		await _place(-150.0, 260.0)
		run = await _run("THROW", [], [p2] if outcome == "blocked" else [])
		ring = run.rings[0] if not run.rings.is_empty() else null
		if ring == null:
			check(false, outcome + ": a ring thrown")
			continue
		check(ring.outcome == outcome, "%s: it was %s (%s)" % [outcome, outcome, ring.outcome])
		check(ring.layer == 2 and not ring.strikable, "%s: it stays in P2's layer, and nobody can strike it" % outcome)
		check(run.windows.is_empty(), "%s: no window opens (%s)" % [outcome, run.windows])


# THE STRIKE BACK: the partner's blade meets the parried ring on its way back: it goes at him, a hit
# on him, and in the partner's window a sync hit. Not at a finale's end: no stagger.
func test_strike_back():
	await _setup()
	await _place(-150.0, 260.0)
	var team = rules.team
	var his = rules.boss_sync
	var run = await _run("THROW", [p2], [], true)
	check(run.struck == 1, "P1 struck the ring back (%d)" % run.struck)
	check(rules.boss_sync < his, "...a hit on him (his sync %.1f -> %.1f)" % [his, rules.boss_sync])
	check(rules.team > team, "...in P1's window: a sync hit, the players win sync (%.1f -> %.1f)" % [team, rules.team])
	check(run.stagger == 0.0, "...not a finale's end: no stagger")
	check(boss.pair_count(1) == 2 and boss.pair_count(2) == 2, "...and he has the ring back (%d, %d)" % [boss.pair_count(1), boss.pair_count(2)])


# THE STAGGER, only at a finale's end: the plunge parried together, he stands on their blades and
# flips back off them with a throw; that ring struck back staggers him, 0.5 s and 0.2 s for every blade
# parried in the chain.
func test_plunge_parried_together():
	await _setup()
	await _place(100.0, 160.0, -300.0)  # both on his right: together
	var run = await _run("PLUNGE", [p1, p2], [], true)
	check("plunge" in run.steps, "he plunges (%s)" % [run.steps])
	check(run.places[run.steps.find("plunge")] == AcrobatBody.Place.WALL, "...from a wall")
	check("stand" in run.steps, "parried together: he stands on their blades (%s)" % [run.steps])
	var thrown = run.rings.filter(func(r): return r.finale_end)
	check(thrown.size() == 1, "...and flips back off them with a throw (%d)" % thrown.size())
	check(run.struck >= 1, "...which is struck back")
	near(run.stagger, NUMBERS.acrobat_stagger_least + NUMBERS.acrobat_stagger_per_parry * boss.chain_blades, 0.1,
		"...and staggers him (%d blades)" % boss.chain_blades)
	check(boss.chain_blades >= 3, "the plunge (two) and the throw (one) counted (%d)" % boss.chain_blades)
	await _place(100.0, 160.0, -300.0)
	run = await _run("PLUNGE", [p1])
	check(not "stand" in run.steps, "only one parries: no standing on their blades (%s)" % [run.steps])
	check(run.steps.back() == "dash", "...he dashes away (%s)" % [run.steps])
	check(run.stagger == 0.0, "...no stagger")


# THE FEINT: its rings turn round their axis as it winds up; where a strike would land it only
# twitches, nothing red; the real strike comes a moment later, red only then.
func test_feint():
	await _setup()
	await _place(80.0, 300.0)
	_start("FEINT")
	var started = -1.0
	var red_at = -1.0
	var spun = false
	var t = 0.0
	var due = INF
	for i in 400:
		await get_tree().physics_frame
		if boss.state != BaseBoss.State.ATTACKING:
			if started >= 0.0:
				break
			continue
		if started < 0.0:
			started = t
			due = boss.time_to_strike(p1)
		t += get_physics_process_delta_time()
		spun = spun or absf(boss._hand_spin[1]) > 0.5
		if red_at < 0.0 and boss._hand_tint[1] == boss.COLOR_EXECUTE:
			red_at = t - started
	var normal = 3 * NUMBERS.acrobat_beat
	near(due, normal + NUMBERS.acrobat_feint_delay, 0.03, "the real strike lands a feint's delay after a strike's time")
	check(spun, "its rings turned round their axis as it wound up")
	check(red_at >= normal - 0.02, "nothing red where a strike would come (red at %.2f s, the strike would land at %.2f)" % [red_at, normal])
	near(red_at, normal + NUMBERS.acrobat_feint_delay - NUMBERS.acrobat_strike_time, 0.04, "...red only as the real one drops")


# THE SALTO says what comes: forward with a kick (the whirl), backward with a throw (the throwing
# chain), to a wall (the rally, the plunge), into the line (the dive). Where he lands: the floor, a
# wall, the line.
func test_the_salto():
	await _setup()
	check(boss.salto_steps("WHIRL").back().kind == "kick", "the whirl next: the kick")
	check(boss.salto_steps("THROWING").back().kind == "throw", "the throwing chain next: the throw")
	check(boss.salto_steps("RALLY").back().kind == "wall" and boss.salto_steps("PLUNGE").back().kind == "wall", "a wall finale: to the wall")
	check(boss.salto_steps("DIVE").map(func(s): return s.do) == ["cut", "salto"] and boss.salto_steps("DIVE").back().kind == "line",
		"the dive: the cut, and into the line")
	await _place(90.0, 300.0)
	var run = await _run("SALTO_KICK", [p1])
	check(boss.place == AcrobatBody.Place.FLOOR, "the kick salto lands on the floor")
	check(boss.side_of(p1) < 0, "...beyond the one he flipped over (P1 now on his left)")
	check(_count(p1, "parry") >= 1, "...whose kick P1 parried")
	await _place(-150.0, 260.0)
	run = await _run("SALTO_THROW", [p2])
	check(run.rings.size() == 1 and run.rings[0].target == p2, "the backward salto throws, at the farther one")
	await _place(80.0, 140.0)
	run = await _run("DIVE", [])
	var under = run.steps.find("under")
	check(under >= 0 and run.places[under] == AcrobatBody.Place.LINE, "the dive: in the line (%s)" % [run.places])
	check("upcut" in run.steps and run.steps.back() == "both", "...then the upcut and both hands (%s)" % [run.steps])


# THE FINALES, by what he sees: a ring struck back in the chain, the rally; else together, the dive;
# else apart, the plunge. None three times in a row.
func test_finale_choice():
	await _setup()
	await _place(-120.0, 150.0)
	check(boss.chain_finale() == "PLUNGE", "apart: the plunge (%s)" % boss.finale_reason)
	await _place(100.0, 150.0)
	boss._finales = []
	check(boss.chain_finale() == "DIVE", "together: the dive (%s)" % boss.finale_reason)
	boss._finales = []
	boss._struck_this_chain = true
	check(boss.chain_finale() == "RALLY", "a ring struck back: the rally (%s)" % boss.finale_reason)
	boss._struck_this_chain = false
	boss._finales = ["DIVE", "DIVE"]
	check(boss.chain_finale() == "PLUNGE", "the dive a third time: the next one instead (%s)" % boss.finale_reason)
	boss._finales = ["DIVE", "PLUNGE", "DIVE"]
	check(boss.chain_finale() == "DIVE", "...but not after a break")
	check(Acrobat.fresh_finale("PLUNGE", ["PLUNGE", "PLUNGE"], Acrobat.FINALE_ORDER) == "RALLY", "after the last in the order, the first")


# ONE RING PER HAND in the air, but in the rally: there all four go, a pair at each, as one heavy throw.
func test_rings_in_the_air():
	await _setup()
	await _place(-150.0, 260.0)
	_start("THROWING")
	var fewest = 2
	for i in 900:
		await get_tree().physics_frame
		_parry([p1, p2])
		fewest = mini(fewest, mini(boss.pair_count(1), boss.pair_count(2)))
		if boss.state == BaseBoss.State.RECOVER:
			break
	check(fewest >= 1, "the throwing chain: each hand keeps a ring (fewest %d)" % fewest)
	await _place(-150.0, 260.0)
	var run = await _run("RALLY", [p1, p2])
	check(run.places[run.steps.find("volley")] == AcrobatBody.Place.WALL, "the rally: from a wall")
	var pairs = run.rings.filter(func(r): return r.pair)
	check(pairs.size() == 2 and pairs[0].volley == 2, "...its last throw: a pair at each, as one (%d)" % pairs.size())
	check(pairs.all(func(r): return r.outcome == AcrobatRing.PARRIED), "...parried together: both go through (%s)" % [pairs.map(func(r): return r.outcome)])
	await _place(-150.0, 260.0)
	run = await _run("RALLY", [p1])
	pairs = run.rings.filter(func(r): return r.pair)
	var p1_pair = pairs.filter(func(r): return r.target == p1)
	check(not p1_pair.is_empty() and p1_pair[0].outcome == AcrobatRing.BLOCKED, "only one parries the volley: a block's effect (%s)" % [pairs.map(func(r): return r.outcome)])


# HIS BREATH: a hit meets nothing; he dashes away, and his next chain starts at the attacker. In a
# chain he's open.
func test_breath():
	await _setup()
	await _place(-80.0, 260.0)
	boss.dev_hold = false
	boss.timer = 100.0  # no chain of his own meanwhile
	var his = rules.boss_sync
	var x = boss.global_position.x
	boss.take_damage(10.0, p1)
	check(rules.boss_sync == his, "a hit in his breath costs him nothing")
	await frames(3)
	check(boss.global_position.x > x, "...he's away from P1 (%.0f -> %.0f)" % [x, boss.global_position.x])
	var answered = false
	for i in 120:
		await get_tree().physics_frame
		if boss.state == BaseBoss.State.ATTACKING:
			answered = true
			break
	check(answered, "...and answers at once with a chain")
	if answered:
		var first = boss.current_attack._step
		check(first.get("at") == p1 or first.get("target") == p1, "...its first link at P1 (%s)" % [first.do])
	boss.dev_hold = true
	boss.stagger_now(0.01)  # his answer cut short
	await _place(80.0, 260.0)
	_start("STRIKE")
	await wait(0.2)
	his = rules.boss_sync
	boss.take_damage(10.0, p2)
	check(rules.boss_sync < his, "in a chain he's open: a hit lands")


# HIS POSTURE broken (a placeholder for phase 2): a long stagger, and his sync stays.
func test_posture_break():
	await _setup()
	await _place(-150.0, 260.0)
	_start("STRIKE")
	await wait(0.2)
	rules._posture[boss] = 1.0
	var his = rules.boss_sync
	boss.take_damage(10.0, p1)
	check(boss.state == BaseBoss.State.STAGGER, "broken: he's staggered")
	near(boss.timer, NUMBERS.acrobat_break_stagger, 0.05, "...long")
	near(rules.boss_sync, his - NUMBERS.their_heavy_damage * NUMBERS.their_normal_share, 0.01, "...and his sync stays, but for the hit")
	check(boss.place == AcrobatBody.Place.FLOOR, "...on the floor")


# Every attack in his lab runs through, wherever the players are.
func test_every_attack_runs():
	await _setup()
	for attack_name in Acrobat.ATTACKS:
		await _place(-120.0, 200.0)
		var run = await _run(attack_name, [p1, p2], [], true, 2400)
		check(boss.state in [BaseBoss.State.RECOVER, BaseBoss.State.STAGGER, BaseBoss.State.IDLE],
			"%s: over (%s, %s)" % [attack_name, BaseBoss.State.keys()[boss.state], run.steps])
		check(boss.place == AcrobatBody.Place.FLOOR or attack_name == "CHAIN", "%s: back on the floor (%d)" % [attack_name, boss.place])
