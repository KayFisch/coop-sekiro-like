extends "res://tests/test_case.gd"
## A window each (Moves "bifrons_coop_windows", A WINDOW EACH in columna_bifrons.gd; docs/concept.md
## "A co-op parry gives both a sync-hit window"): in an attack of both swords every parry that
## counts opens its partner's window; parried together, one each, the energy running both ways,
## and a hit in it while he's staggered is a sync hit. A lone parry with only a block's effect
## opens nothing, nor do the sweep's lone parries. A player parries a strike by having pressed
## block just before it lands (_run()).

const LEFT = -1
const RIGHT = 1
const NUMBERS = {
	"sync_window_delay": 0.2, "sync_beat_time": 0.1, "sync_window_late": 0.2,
	"sync_hit_gain": 4.0, "sync_hit_late_gain": 2.0,
	"bifrons_stagger_least": 0.5, "bifrons_stagger_per_parry": 0.2,
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
	for p in [left, right]:
		p.invincible = true


# Him back in the middle, the two where they're asked (px from him), everything fresh.
func _place(left_x: float, right_x: float):
	while boss.state != BaseBoss.State.IDLE:
		await get_tree().physics_frame
	await wait(0.6)  # the last run's windows closed
	boss.global_position.x = middle
	left.global_position.x = middle + left_x
	right.global_position.x = middle + right_x
	await wait(0.3)
	for p in [left, right]:
		p.velocity = Vector2.ZERO
		p._invuln_timer = 0.0
		p._stagger_timer = 0.0
	rules.team = rules.team_max() * 0.5
	rules.team_chaos = false
	rules.boss_chaos = false
	rules.sync_mode = false
	for actor in [left, right, boss]:
		rules._posture[actor] = rules.posture_max(actor)
		rules._busy_at[actor] = -100.0


# Runs one of his attacks until it's over or he's staggered, each player in `parrying` parrying
# every strike at them. Returns {"stagger": how long he's staggered (0: not), "windows": [blade,
# opened by] for every window a parry opened, "waves": the players energy was sent to}.
func _run(attack_name: String, parrying: Array) -> Dictionary:
	boss.dev_next = attack_name
	boss.timer = 0.0
	var opened = boss._open_from.duplicate()
	var windows = []
	var waves = {}  # wave -> the player it's sent to
	var began = false
	var stagger = 0.0
	for i in 900:
		await get_tree().physics_frame
		for blade in [LEFT, RIGHT]:
			if boss._open_from[blade] != opened[blade]:
				opened[blade] = boss._open_from[blade]
				windows.append([blade, boss._opened_by[blade]])
		for wave in get_tree().current_scene.get_children().filter(func(n): return n.get_script() == SyncWave):
			if not waves.has(wave):
				waves[wave] = wave.to
		if boss.state in [BaseBoss.State.TELEGRAPH, BaseBoss.State.ATTACKING]:
			began = true
			for p in parrying:
				if boss.time_to_strike(p) < 0.05:
					p.parry_press_time = p.now()  # pressed block just now
		elif began:
			if boss.state == BaseBoss.State.STAGGER:
				stagger = boss.timer
			break
	check(began, attack_name + ": he attacks")
	return {"stagger": stagger, "windows": windows, "waves": waves.values()}


func _a_window_each(run: Dictionary) -> bool:
	return run.windows.size() == 2 and [RIGHT, left] in run.windows and [LEFT, right] in run.windows


func test_parried_together_a_window_each():
	await _setup()
	await _place(-110.0, 110.0)
	var run = await _run("BOTH", [left, right])
	check(run.stagger > 0.0, "pep, both parry: staggered")
	check(_a_window_each(run), "...and a window each, opened by the partner's parry (%s)" % [run.windows])
	check(run.waves.size() == 2 and left in run.waves and right in run.waves, "...the energy running both ways")
	while not boss.is_open(LEFT):
		await get_tree().physics_frame
	check(boss.is_open(RIGHT) and boss.state == BaseBoss.State.STAGGER, "both open at once, while he's staggered")
	check(boss.window_for(left) == LEFT and boss.window_for(right) == RIGHT, "...each one's own")
	var before = rules.team
	boss.take_damage(1.0, left)
	boss.take_damage(1.0, right)
	near(rules.team - before, 2.0 * NUMBERS.sync_hit_gain, 0.01, "two hits on the beat: two sync hits")


func test_a_lone_parry():
	await _setup()
	await _place(-110.0, 110.0)
	var run = await _run("BOTH", [left])
	near(run.stagger, 0.0, 0.001, "pep, one parries: no stagger")
	check(run.windows == [[RIGHT, left]], "...but the partner's window opens (%s)" % [run.windows])
	await _place(-140.0, -100.0)
	run = await _run("BOTH", [left])
	check(run.windows.is_empty(), "ppe, one parries: a block's effect, no window (%s)" % [run.windows])
	await _place(-140.0, -100.0)
	run = await _run("BOTH", [left, right])
	check(run.stagger > 0.0 and _a_window_each(run), "ppe, both parry: staggered, a window each (%s)" % [run.windows])


func test_switch_off():
	await _setup()
	set_move("bifrons_coop_windows", false)
	await _place(-110.0, 110.0)
	var run = await _run("BOTH", [left, right])
	check(run.stagger > 0.0 and run.windows.is_empty(), "off: staggered, but no window (%s)" % [run.windows])


func test_the_sweep():
	await _setup()
	await _place(-110.0, 110.0)
	var run = await _run("SWEEP", [left])
	check(run.windows.is_empty(), "a lone parry of the sweep opens nothing (%s)" % [run.windows])
	await _place(-110.0, 110.0)
	run = await _run("SWEEP", [left, right])
	check(run.stagger > 0.0 and _a_window_each(run), "parried by both: staggered, a window each (%s)" % [run.windows])


func test_the_leap():
	await _setup()
	await _place(-140.0, -100.0)
	var run = await _run("LEAP", [left, right])
	check(run.stagger > 0.0 and _a_window_each(run), "the leap parried by both: a window each (%s)" % [run.windows])


# The gate leap's strikes at B and A (3, 4) open a window each already; its heavy strike, parried
# together, two more.
func test_the_gate_leap():
	await _setup()
	await _place(-100.0, -130.0)
	var run = await _run("GATE_LEAP", [left, right])
	check(run.stagger > 0.0, "the gate leap all parried: staggered")
	check(run.windows.size() == 4 and _a_window_each({"windows": run.windows.slice(2)}), "...the heavy strike's: a window each (%s)" % [run.windows])
