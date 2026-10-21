extends "res://tests/test_case.gd"
## The Heavy Hitter, phase 1 (docs/boss_heavy_hitter.md; actors/bosses/heavy_hitter/): each head
## going for its own player (both at the blade: one heavy strike, parried together or a lone parry is
## a block; one each side: a normal blade strike and a jab), when the mirror cracks and what the crack
## does (in the other half, on the floor, not in a jump), open while he attacks and guarded in his
## breath, the motif by the field, the stagger after a finale, his pommel side, the turn in his breath,
## the stomp leap, the weapon's colors and the screen halves; and the rage (its pattern by the
## formation, every strike heavy in both layers, the exhaustion, the alignment it leaves, his sync and
## posture), phase 2 (unlocked by the rage, the flip in one layer, the flip as his finale, provoking).
## The players can't lose; a player parries a strike by having pressed block just before it lands.

const LEFT = -1
const RIGHT = 1
const NUMBERS = {
	"hitter_beat": 0.3, "hitter_reps_min": 1.0, "hitter_reps_max": 1.0,
	"hitter_stagger_least": 0.5, "hitter_stagger_per_parry": 0.2,
	"hitter_posture_max": 200.0, "hitter_pommel_posture": 2.0,
	"hitter_roar_time": 1.0, "hitter_rage_strikes": 2.0, "hitter_rage_beats": 3.0,
	"hitter_flip_time": 0.3, "hitter_flip_windup": 5.0, "hitter_together_stale": 2.0,
	"hitter_crack_delay": 0.3, "hitter_crack_reach": 70.0,
	"boss_posture_small": 5.0, "boss_posture_medium": 15.0,
	"sync_window_delay": 0.2, "sync_beat_time": 0.1, "sync_window_late": 0.2, "sync_hit_gain": 4.0,
	"their_heavy_damage": 18.0, "their_normal_share": 0.5,
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
	await load_scene("res://levels/heavy_hitter/hitter_room.tscn")
	rules = GameManager.rules
	boss = GameManager.boss
	boss.dev_hold = true
	boss.dev_still = true
	p1 = boss.player_of(1)
	p2 = boss.player_of(2)
	middle = boss.global_position.x
	for p in [p1, p2]:
		p.invincible = true


# Him back in the middle, his blade `way` in both layers, the two where they're asked (px from him),
# everything fresh.
func _place(p1_x: float, p2_x: float, way = RIGHT):
	while boss.state != BaseBoss.State.IDLE:
		await get_tree().physics_frame
	await wait(0.6)  # the last run's windows closed
	boss.global_position = Vector2(middle, boss.home_position.y)
	p1.global_position.x = middle + p1_x
	p2.global_position.x = middle + p2_x
	await wait(0.3)
	for layer in [1, 2]:
		boss._ways[layer] = way
		boss._poses[layer] = boss.POSE_LEVEL
	boss.stop_sweeps()
	boss._turned_at = -100.0
	boss._windows = {}
	boss._pommel_hitter = null
	boss._provoked = {}
	boss.rage = ""
	boss.phase = 1
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


# Runs one of his attacks until it's over or he's staggered, each player in `parrying` parrying every
# strike at them, each in `blocking` holding block all through. Returns {"stagger": how long he's
# staggered (0: not), "windows": [whose, opened by] for every window a parry opened, "cracks": the
# layers whose blade cracked the mirror, "attack": it}.
func _run(attack_name: String, parrying: Array, blocking = []) -> Dictionary:
	var attack = boss.find_attack(attack_name)
	for p in blocking:
		hold(p, "block")
	_start(attack_name)
	var windows = []
	var seen = {}
	var cracks = []
	var began = false
	var stagger = 0.0
	for i in 1200:
		await get_tree().physics_frame
		for p in boss._windows:
			var key = "%d %.3f" % [p.player_id, boss._windows[p].from]
			if not seen.has(key):
				seen[key] = true
				windows.append([p, boss._windows[p].by])
		for crack in get_tree().get_nodes_in_group("hitter_cracks"):
			if not seen.has(crack):
				seen[crack] = true
				cracks.append(crack.from_layer)
		if boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			began = true
			_parry(parrying)
		elif began:
			if boss.state == BaseBoss.State.STAGGER:
				stagger = boss.timer
			break
	check(began, attack_name + ": he attacks")
	for p in blocking:
		hold(p, "block", false)
	return {"stagger": stagger, "windows": windows, "cracks": cracks, "attack": attack}


func _count(p, kind: String) -> int:
	return Dev._stats_of(p)[kind]


# THE RULES, 1: both at the blade, the heads strike together. Both parry: a co-op parry, a window each
# (a hit in it a sync hit), no crack. Only one parries: a block's effect, no window, and the other's
# blade goes through into the floor: the mirror cracks from their layer.
func test_unisono():
	await _setup()
	await _place(100.0, 130.0)
	check(boss.field() == "together", "both on his blade's side: the together field (%s)" % boss.field())
	var parries = [_count(p1, "parry"), _count(p2, "parry")]
	var run = await _run("BLADE", [p1, p2])
	check(_count(p1, "parry") == parries[0] + 1 and _count(p2, "parry") == parries[1] + 1, "both parried")
	check(run.windows.size() == 2 and [p1, p2] in run.windows and [p2, p1] in run.windows,
		"...a window each, opened by the partner's parry (%s)" % [run.windows])
	check(run.cracks.is_empty(), "...and no crack (%s)" % [run.cracks])
	await _place(100.0, 130.0)
	_start("TOGETHER")
	var hit = false
	for i in 600:
		await get_tree().physics_frame
		_parry([p1, p2])
		if not hit and boss.window_for(p1) and boss.state == BaseBoss.State.ATTACKING:
			hit = true
			var before = rules.team
			boss.take_damage(1.0, p1)
			near(rules.team - before, NUMBERS.sync_hit_gain, 0.01, "a hit in the window as it opens: a sync hit, on the beat")
		if boss.state == BaseBoss.State.RECOVER:
			break
	check(hit, "...the window opened while he was still attacking")
	await _place(100.0, 130.0)
	var blocks = _count(p1, "block")
	var hits = _count(p2, "hit")
	run = await _run("BLADE", [p1])
	check(_count(p1, "block") == blocks + 1, "only one parries: it has a block's effect")
	check(_count(p2, "hit") == hits + 1, "...the other is hit")
	check(run.windows.is_empty(), "...and no window opens (%s)" % [run.windows])
	check(run.cracks == [2], "...and the mirror cracks from the one who was hit (%s)" % [run.cracks])


# THE RULES, 1: one each side, each head goes for its own player: a normal blade strike in the
# blade's layer only (the other layer's weapon holds), and then a jab in the pommel's. A lone parry of
# each is a parry, and opens the partner's window.
func test_one_each_side_two_normal_strikes():
	await _setup()
	await _place(-100.0, 110.0)
	check(boss.field() == "split", "one each side: the split field (%s)" % boss.field())
	var parries = _count(p2, "parry")
	var held = true
	_start("BLADE")
	var windows = []
	for i in 600:
		await get_tree().physics_frame
		_parry([p2])
		if boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			held = held and boss._targets[1] == boss.POSE_LEVEL
		for p in boss._windows:
			if not [p, boss._windows[p].by] in windows:
				windows.append([p, boss._windows[p].by])
		if boss.state == BaseBoss.State.RECOVER:
			break
	check(held, "P1's weapon holds while the blade comes down on P2")
	check(_count(p2, "parry") == parries + 1, "P2's lone parry of it is a parry")
	check(windows == [[p1, p2]], "...and opens P1's window (%s)" % [windows])
	await _place(-100.0, 110.0)
	var run = await _run("POMMEL", [p1])
	check(run.windows == [[p2, p1]], "the jab at P1, parried: P2's window (%s)" % [run.windows])


# THE RULES, 2: when the mirror cracks. A blade nothing stopped goes into the floor; stopped is
# parried, or blocked while the other layer's was parried.
func test_when_the_mirror_cracks():
	await _setup()
	await _place(-100.0, 110.0)
	var run = await _run("BLADE", [p2])
	check(run.cracks.is_empty(), "one each side, P2 parries the blade: nothing cracks (%s)" % [run.cracks])
	await _place(-100.0, 110.0)
	run = await _run("BLADE", [])
	check(run.cracks == [2], "...P2 hit: it cracks from P2's layer (%s)" % [run.cracks])
	await _place(100.0, 130.0)
	run = await _run("BLADE", [p1], [p2])
	check(run.cracks.is_empty(), "both at the blade, P1 parries, P2 blocks: the parry holds it, nothing cracks (%s)" % [run.cracks])
	await _place(100.0, 130.0)
	run = await _run("BLADE", [], [p1, p2])
	run.cracks.sort()
	check(run.cracks == [1, 2], "...both only block: it cracks from both (%s)" % [run.cracks])
	await _place(-100.0, -130.0)
	run = await _run("BLADE", [])
	run.cracks.sort()
	check(run.cracks == [1, 2], "both at the pommel: a blade strike comes down in both, into nothing (%s)" % [run.cracks])


# The crack breaks open in the other half, where the blade went in, after a moment: it hits that
# half's player on the floor near it, not in a jump; never the player of the layer it came from.
func test_the_crack():
	await _setup()
	await _place(-200.0, 150.0)  # P2 where P1's blade comes down
	var hits = [_count(p1, "hit"), _count(p2, "hit")]
	boss._crack(1)
	var crack = get_tree().get_nodes_in_group("hitter_cracks").back()
	check(crack.into_layer() == 2 and crack.visibility_layer == MirrorView.SHADOW, "P1's blade cracks into P2's half")
	await wait(0.2)
	check(_count(p2, "hit") == hits[1], "...not at once")
	await wait(0.3)
	check(_count(p2, "hit") == hits[1] + 1, "...as it breaks open: P2 on the floor near it is hit")
	await _place(-200.0, 150.0)
	hits = [_count(p1, "hit"), _count(p2, "hit")]
	boss._crack(1)
	crack = get_tree().get_nodes_in_group("hitter_cracks").back()
	while crack.time_to_break(p2) > 0.1:
		await get_tree().physics_frame
	hold(p2, "jump")
	await wait(0.25)
	hold(p2, "jump", false)
	await wait(0.6)
	check(_count(p2, "hit") == hits[1], "P2 jumping as it breaks open: not hit")
	await _place(150.0, 400.0)
	hits = [_count(p1, "hit"), _count(p2, "hit")]
	boss._crack(1)
	await wait(0.7)
	check(_count(p1, "hit") == hits[0], "P1 on it, in the half it came from: not hit")
	check(_count(p2, "hit") == hits[1], "P2 far off: not hit")


# THE RULES, 4: open while he attacks (a hit lands, it costs his sync), guarded in his breath (his
# guard parries or blocks it: no sync lost).
func test_open_while_attacking_guarded_in_the_breath():
	await _setup()
	await _place(100.0, 130.0)
	check(boss.is_guarding(), "between his chains, the weapon level: guarding")
	var before = rules.boss_sync
	boss.take_damage(10.0, p1)
	near(rules.boss_sync, before, 0.01, "a hit in his breath: his guard meets it, no sync lost")
	check(rules.posture_of(boss) < rules.posture_max(boss), "...parried or blocked: it costs his posture")
	await _place(100.0, 130.0)
	_start("TOGETHER")
	while boss.state != BaseBoss.State.TELEGRAPH:
		await get_tree().physics_frame
	check(not boss.is_guarding(), "his chain's windup: no guard")
	before = rules.boss_sync
	boss.take_damage(10.0, p1)
	near(before - rules.boss_sync, NUMBERS.their_heavy_damage * NUMBERS.their_normal_share, 0.01, "...a hit lands, and costs his sync")


# THE FIELDS, THE CHAINS: the motif is the field's, never chance; the finale by what he sees.
func test_the_motif_by_the_field():
	await _setup()
	var verbs = {"HAMMER": HitterSwings.HAMMER, "STOMP": HitterSwings.STOMP}
	for setup in [[100.0, 130.0, "together", "HAMMER"], [-100.0, 110.0, "split", "STOMP"], [-100.0, -130.0, "pommel", "STOMP"]]:
		await _place(setup[0], setup[1])
		boss._together_for = 0
		var run = await _run("CHAIN", [])
		check(run.attack._motifs == [setup[2]], "%s field: its motif (%s)" % [setup[2], run.attack._motifs])
		check(run.attack._links.back().verb == verbs[setup[3]], "...and the finale %s (%s)" % [setup[3], boss.finale_reason])


# He decides only at a repetition's end: the field changed by then, the next one is the new field's.
func test_the_field_changing_in_a_chain():
	await _setup()
	set_number("hitter_reps_min", 2.0)
	set_number("hitter_reps_max", 2.0)
	await _place(100.0, 130.0)
	var chain = boss.find_attack("CHAIN")
	_start("CHAIN")
	while boss.state != BaseBoss.State.ATTACKING:
		await get_tree().physics_frame
	p2.global_position.x = middle - 120.0  # over to his pommel side, mid-repetition
	while chain._motifs.size() < 2 and boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
		await get_tree().physics_frame
	check(chain._motifs == ["together", "split"], "together first, then split, as it is at the first one's end (%s)" % [chain._motifs])
	while boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
		await get_tree().physics_frame


# THE CHAINS: a finale parried together staggers him 0.5 s and 0.2 s for each blade parried in the
# chain (a co-op parry: two); a motif parried together, on its own, doesn't.
func test_the_stagger():
	await _setup()
	boss._together_for = 0
	await _place(100.0, 130.0)
	var run = await _run("CHAIN", [p1, p2])
	near(run.stagger, 0.5 + 0.2 * 8, 0.05, "the together motif and the hammer, all parried together: four blades twice over")
	await _place(100.0, 130.0)
	run = await _run("TOGETHER", [p1, p2])
	near(run.stagger, 0.0, 0.001, "the motif alone, parried together: no finale, no stagger")
	await _place(100.0, 130.0)
	run = await _run("HAMMER", [p1])
	near(run.stagger, 0.0, 0.001, "the hammer, one of them parrying: a block's effect, no stagger")


# Breaks his posture with a hit from P1 in a chain's windup, the dev tools letting him rage
# (`rages`) or not. Returns his sync just before.
func _break_posture(rages = true) -> float:
	_start("TOGETHER")
	while boss.state != BaseBoss.State.TELEGRAPH:
		await get_tree().physics_frame
	rules._posture[boss] = 1.0
	var before = rules.boss_sync
	boss.dev_hold = not rages
	boss.take_damage(10.0, p1)
	boss.dev_hold = true
	return before


# THE RAGE: posture broken, he rages at once: the pattern that's hard for their formation (apart: the
# pendulum, parallel; together: the cross, diagonal), shown by the weapon from the roar's start. His
# sync stays, his posture holds, and phase 2 begins. Not while the dev tools hold him.
func test_the_rage_by_the_formation():
	await _setup()
	await _place(-100.0, 110.0)
	check(boss.phase == 1, "phase 1 at first")
	var before = await _break_posture()
	check(boss.current_attack != null and boss.current_attack.get_attack_name() == "RAGE_PENDULUM",
		"apart, his posture broken: the pendulum (%s)" % (boss.current_attack.get_attack_name() if boss.current_attack else "nothing"))
	check(boss.rage == "raging" and boss.state == BaseBoss.State.TELEGRAPH, "...at once, the roar first")
	near(before - rules.boss_sync, NUMBERS.their_heavy_damage * NUMBERS.their_normal_share, 0.01, "...his sync stays, but for the hit's own cost")
	check(boss.phase == 2, "...and phase 2 begins")
	await frames(2)
	check(not boss.is_diagonal(), "...the weapon parallel, the same in both halves")
	boss.take_damage(10.0, p2)
	near(rules.posture_of(boss), rules.posture_max(boss), 0.01, "...and nothing costs his posture meanwhile")
	await _place(100.0, 130.0)
	await _break_posture()
	check(boss.current_attack.get_attack_name() == "RAGE_CROSS", "together: the cross (%s)" % boss.current_attack.get_attack_name())
	await frames(2)
	check(boss.is_diagonal() and boss.way_in(1) == LEFT, "...the weapon diagonal: the nearer one's layer turned")
	await _place(100.0, 130.0)
	await _break_posture(false)
	check(boss.rage == "" and boss.current_attack.get_attack_name() == "TOGETHER", "the dev tools holding him: no rage")
	near(rules.posture_of(boss), rules.posture_max(boss), 0.01, "...his posture only full again")


# THE RAGE: every strike in both layers, so heavy (a lone parry has a block's effect), from side to
# side; where nothing stopped a blade the mirror cracks. Apart, the pendulum: the one at the blade
# parries alone and the partner's blade breaks through under them. He's exhausted after it.
func test_the_pendulum_apart():
	await _setup()
	await _place(-100.0, 110.0)
	var blocks = [_count(p1, "block"), _count(p2, "block")]
	var run = await _run("RAGE_PENDULUM", [p1, p2])
	var links = run.attack._links
	check(links.size() == 2 and links.all(func(l): return l.layers == [1, 2]), "both strikes in both layers (%s)" % [links.map(func(l): return l.layers)])
	check(_count(p2, "block") == blocks[1] + 1 and _count(p1, "block") == blocks[0] + 1,
		"each one's lone parry, P2's of the first and P1's of the second: a block's effect")
	check(run.cracks == [1, 2], "the first cracks from P1's layer (under P2), the second from P2's (under P1) (%s)" % [run.cracks])
	check(not boss.is_diagonal() and boss.way_in(1) == LEFT, "...from side to side, and still parallel after it")
	near(run.stagger, NUMBERS.hitter_stagger_least, 0.05, "exhausted after it; no blade parried that counted")


# THE RAGE: apart, the cross is the easy one: parried together, then both blades into nothing, each
# breaking through under the partner. The exhaustion: longer by each blade parried; the alignment
# stays diagonal, his posture full.
func test_the_cross_apart():
	await _setup()
	await _place(-100.0, 110.0)
	var run = await _run("RAGE_CROSS", [p1, p2])
	check(run.windows.size() == 2, "the first parried together: a window each (%s)" % [run.windows])
	run.cracks.sort()
	check(run.cracks == [1, 2], "the second into nothing in both layers (%s)" % [run.cracks])
	near(run.stagger, NUMBERS.hitter_stagger_least + NUMBERS.hitter_stagger_per_parry * 2, 0.05, "exhausted: one co-op parry, two blades")
	check(boss.is_diagonal(), "the alignment stays as the cross left it: diagonal")
	near(rules.posture_of(boss), rules.posture_max(boss), 0.01, "his posture full after it")
	while boss.state == BaseBoss.State.STAGGER:
		await get_tree().physics_frame
	check(boss.rage == "", "back on his feet: the rage is over")


# PHASE 2 begins with his first rage (or F1 hitter_phase2): the together field too long ends in the
# flip, not the stomp leap.
func test_phase_2():
	await _setup()
	await _place(100.0, 130.0)
	boss._together_for = int(NUMBERS.hitter_together_stale) - 1
	check(boss.chain_finale() == "STOMP", "phase 1: the together field too long, the stomp leap")
	boss.phase = 2
	boss._together_for = int(NUMBERS.hitter_together_stale) - 1
	check(boss.chain_finale() == "FLIP", "phase 2: the flip")
	set_move("hitter_phase2", true)
	await _setup()
	check(boss.phase == 2, "F1 hitter_phase2: phase 2 from the start")
	set_move("hitter_phase2", false)


# THE FLIP: in one layer only (the nearer player's), a sweep flat through him that meets that player as
# it passes them: a normal strike, a lone parry is a parry and opens the partner's window; no crack.
func test_the_flip():
	await _setup()
	await _place(100.0, 130.0)
	var parries = _count(p1, "parry")
	var hits = _count(p2, "hit")
	var run = await _run("FLIP", [p1])
	check(boss.way_in(1) == LEFT and boss.way_in(2) == RIGHT, "the nearer one's layer flipped, the other's not")
	check(boss.field() == "split", "...together turned split (%s)" % boss.field())
	check(_count(p1, "parry") == parries + 1 and _count(p2, "hit") == hits, "it met P1, who parried it; not P2")
	check(run.windows == [[p2, p1]], "...a lone parry, P2's window (%s)" % [run.windows])
	check(run.cracks.is_empty(), "...and no crack (%s)" % [run.cracks])
	await _place(250.0, 130.0)
	hits = _count(p1, "hit")
	run = await _run("FLIP", [])
	check(boss.way_in(2) == LEFT and _count(p1, "hit") == hits, "P2 nearer now: P2's layer; P1 out of reach, not met")


# THE FLIP as his finale: together turns split, then a blade strike after a long windup. Whoever has to
# goes over, and the two parry it together: staggered, as after the great hammer.
func test_the_flip_finale():
	await _setup()
	await _place(100.0, 130.0)
	_start("FLIP_FINALE")
	var stagger = 0.0
	var moved = false
	for i in 1200:
		await get_tree().physics_frame
		if boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			_parry([p1, p2])
			if not moved and boss.way_in(1) == LEFT:
				moved = true
				check(boss.field() == "split", "the flip: together turned split")
				p1.global_position.x = middle - 100.0  # over to the other side
		elif moved:
			if boss.state == BaseBoss.State.STAGGER:
				stagger = boss.timer
			break
	check(moved, "P1's layer flipped")
	near(stagger, 0.5 + 0.2 * 3, 0.05, "re-formed and parried together: staggered (the flip, and a co-op parry)")


# PROVOKING (phase 2): a hit that lands on his pommel side angers that head at once; the layer flips
# toward the hitter only as the repetition ends, before he decides: split turns together, and the next
# repetition is the together field's. In phase 1 it doesn't.
func test_provoking():
	await _setup()
	set_number("hitter_reps_min", 2.0)
	set_number("hitter_reps_max", 2.0)
	for phase in [1, 2]:
		await _place(-100.0, 110.0)  # P1 at his pommel, P2 at his blade
		boss.phase = phase
		var chain = boss.find_attack("CHAIN")
		_start("CHAIN")
		while boss.state != BaseBoss.State.ATTACKING:
			await get_tree().physics_frame
		boss.take_damage(10.0, p1)
		if phase == 1:
			check(boss._provoked.is_empty(), "phase 1: a hit on his pommel side provokes nothing")
		else:
			check(boss._provoked.has(1) and boss._head_angry(LEFT), "phase 2: it provokes that head, red at once")
			await wait(1.0)
			check(boss.way_in(1) == RIGHT and boss._head_angry(LEFT), "...still red, no flip mid-repetition")
		while chain._motifs.size() < 2 and boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			_parry([p1, p2])
			await get_tree().physics_frame
		var want = ["split", "split"] if phase == 1 else ["split", "together"]
		check(chain._motifs == want, "phase %d: the motifs %s (%s)" % [phase, want, chain._motifs])
		if phase == 2:
			check(boss.way_in(1) == LEFT and boss._provoked.is_empty(), "...P1's layer flipped toward P1 as it ended; the provocation spent")
		while boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			await get_tree().physics_frame


# Hits on his pommel side cost him twice the posture (F2 hitter_pommel_posture), and anger that
# head; so does a parried jab, which opens the partner's window.
func test_his_pommel_side():
	await _setup()
	await _place(-100.0, 110.0)  # P1 at his pommel, P2 at his blade
	_start("TOGETHER")
	while boss.state != BaseBoss.State.TELEGRAPH:
		await get_tree().physics_frame
	var full = rules.posture_max(boss)
	boss.take_damage(10.0, p2)
	near(full - rules.posture_of(boss), NUMBERS.boss_posture_medium, 0.01, "a hit at his blade's side: a hit's posture")
	var before = rules.posture_of(boss)
	boss.take_damage(10.0, p1)
	near(before - rules.posture_of(boss), 2.0 * NUMBERS.boss_posture_medium, 0.01, "...on his pommel side: twice that")
	check(boss.anim_time < boss._angry_until[LEFT], "...and the head on that side is red")
	await _place(-100.0, 110.0)
	before = rules.posture_of(boss)
	var lost = [0.0]  # as it's parried: his own strikes don't hold his posture's coming back
	var on_parry = func(_p, _kind): lost[0] = before - rules.posture_of(boss)
	boss.parry_success.connect(on_parry)
	var run = await _run("POMMEL", [p1])
	boss.parry_success.disconnect(on_parry)
	near(lost[0], 2.0 * NUMBERS.boss_posture_small, 0.01, "a parried jab: twice a parry's posture")
	check(run.windows == [[p2, p1]], "...and it opens the partner's window (%s)" % [run.windows])


# THE TURN, as his breath begins: to the side with more of them; with one each side, to whoever hit
# his pommel side last, else round anyway.
func test_the_turn():
	await _setup()
	await _place(-100.0, -130.0)
	boss._face_the_players()
	check(boss._ways[1] == LEFT and boss._ways[2] == LEFT, "both at his pommel: he turns to them")
	await _place(100.0, 130.0)
	boss._face_the_players()
	check(boss._ways[1] == RIGHT, "both at his blade: he stays")
	await _place(-100.0, 110.0)
	boss._face_the_players()
	check(boss._ways[1] == LEFT and boss._ways[2] == LEFT, "one each side, no pommel hitter: round anyway")
	await _place(-100.0, 110.0)
	boss._pommel_hitter = p2  # (P2 has since gone over to his blade's side)
	boss._face_the_players()
	check(boss._ways[1] == RIGHT, "one each side, the last pommel hitter at his blade now: he stays")
	await _place(-100.0, 110.0)
	await _run("BLADE", [])
	while boss.state != BaseBoss.State.IDLE:
		await get_tree().physics_frame
	check(boss._ways[1] == LEFT and boss.is_turning(), "after an attack, as his breath begins, he does it himself")


# The stomp leap: up, round in the air, down as a blade strike on the side behind him. The one at his
# blade who goes under him meanwhile is in front of it with the other: together, and parried together
# it staggers him (a finale). Nobody moving: split again, the roles turned round.
func test_the_stomp_leap():
	await _setup()
	await _place(100.0, -110.0)  # P1 at his blade, P2 at his pommel
	_start("STOMP")
	while not boss.airborne:
		await get_tree().physics_frame
	hold(p1, "left")
	while p1.global_position.x > middle - 80.0 and boss.airborne:
		await get_tree().physics_frame
	hold(p1, "left", false)
	check(p1.global_position.x <= middle - 80.0, "P1 got under him while he was in the air")
	check(boss._ways[1] == LEFT and boss._ways[2] == LEFT, "...he's turned round in the air")
	check(boss.field() == "together", "...so both are in front of the blade (%s)" % boss.field())
	var stagger = 0.0
	while boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
		_parry([p1, p2])
		await get_tree().physics_frame
	if boss.state == BaseBoss.State.STAGGER:
		stagger = boss.timer
	near(stagger, 0.5 + 0.2 * 2, 0.05, "parried together as he lands: staggered")
	await _place(110.0, -110.0)
	var run = await _run("STOMP", [])
	check(boss._ways[1] == LEFT and boss.field() == "split", "nobody moving: split, the roles turned round (%s)" % boss.field())
	check(run.cracks == [2], "...the blade comes down on P2 only, and through: it cracks from P2's layer (%s)" % [run.cracks])


# ITS COLORS: the axe head in the color of whom it's aimed at (both at the blade: one half each), the
# butt in the color of the player at the pommel; the same in both halves.
func test_the_colors():
	await _setup()
	await _place(100.0, 130.0)
	var aims = boss._aim_colors()
	var c1 = boss.COLOR_SWORD.lerp(p1.player_color, boss.AIM_TINT)
	var c2 = boss.COLOR_SWORD.lerp(p2.player_color, boss.AIM_TINT)
	check(aims[0] == c1 and aims[1] == c2, "both at the blade: the axe in both colors")
	check(aims[2] == boss.COLOR_SWORD and aims[3] == boss.COLOR_SWORD, "...the butt, aimed at nobody: steel")
	await _place(-100.0, 110.0)
	aims = boss._aim_colors()
	check(aims[0] == c2 and aims[1] == c2 and aims[2] == c1 and aims[3] == c1, "one each side: the axe in P2's color, the butt in P1's")
	check(boss._parts[1].axe_back.color == boss._parts[2].axe_back.color, "...the same in both halves")


# Each half of the mirrored screen shows its own layer's weapon; one-sided, both are drawn.
func test_the_halves():
	set_move("mirror_view", true)
	await _setup()
	await frames(3)
	check(boss._weapons[1].visibility_layer == MirrorView.LIGHT, "P1's weapon in the light half")
	check(boss._weapons[2].visibility_layer == MirrorView.SHADOW, "P2's in the shadow half")
	set_move("mirror_view", false)
	await frames(3)
	check(boss._weapons[1].visibility_layer == MirrorView.WORLD and boss._weapons[2].visibility_layer == MirrorView.WORLD,
		"mirror off: both drawn")
	check(not is_equal_approx(boss._weapons[1].position.y, boss._weapons[2].position.y), "...a little apart, so both show")
