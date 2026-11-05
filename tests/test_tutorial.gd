extends "res://tests/test_case.gd"
## The tutorial (levels/tutorial/tutorial.gd, docs/tutorial.md): each step goes on once what it
## asks is there and not before, a hit starts its count over, a step can be skipped, the lab's
## dev_hold holds him, the HUD points out the meter a step talks of, and two stand-ins get through
## all of it.

const TUTORIAL = "res://levels/tutorial/tutorial.tscn"
const Step = preload("res://levels/tutorial/tutorial.gd").Step

var tutorial
var boss
var rules
var p1
var p2


func _setup(hold = true):
	set_move("bifrons_stand_in", "off")
	set_number("tutorial_read_time", 0.3)
	set_number("tutorial_pause", 0.4)
	await load_scene(TUTORIAL)
	tutorial = get_tree().current_scene
	boss = GameManager.boss
	rules = GameManager.rules
	p1 = GameManager.players[0]
	p2 = GameManager.players[1]
	boss.dev_hold = hold  # (the lab's: he attacks only once it's let go)


# An event of the fight's log, as the game sends it.
func _event(kind: String, player = 0, times = 1, data = {}):
	for i in times:
		var all = {"player": player}
		all.merge(data)
		Dev.note(kind, all)


# A player at a place for a few frames (the floor or the air: nothing pulls them away meanwhile).
func _put(p, at: Vector2):
	for i in 3:
		p.global_position = at
		p.velocity = Vector2.ZERO
		await get_tree().physics_frame


func test_each_step_goes_on_once_met_and_not_before():
	await _setup()
	check(tutorial.step == Step.MOVE, "it starts with moving")
	for i in 2:
		await _put(p1, tutorial.mark_point(1, i))
	await _put(p2, tutorial.mark_point(2, 0))
	check(tutorial.step == Step.MOVE, "...not on before both have reached both marks")
	await _put(p2, tutorial.mark_point(2, 1))
	await frames(2)
	check(tutorial.step == Step.DASH, "...on once they have")
	for i in 2:
		for p in [p1, p2]:
			p._dash_timer = 0.1
		await frames(2)
		for p in [p1, p2]:
			p._dash_timer = 0.0
		await frames(2)
	check(tutorial.step == Step.PARRY, "dashed twice each: on")
	_event("parry", 1, 2)
	_event("parry", 2, 2)
	_event("block", 1)
	await frames(2)
	check(tutorial.step == Step.PARRY, "parrying: not on before both have blocked as well")
	_event("block", 2)
	await frames(2)
	check(tutorial.step == Step.COLORS, "...on once each has parried and blocked")
	_event("parry", 1, 3)
	_event("parry", 2, 3)
	await frames(2)
	check(tutorial.step == Step.HALVES, "yellow and red: on")
	_event("parry", 1, 3)
	_event("parry", 2, 3)
	await frames(2)
	check(tutorial.step == Step.DASH_PARRY, "the halves: on")
	var x = boss.global_position.x
	await _put(p1, Vector2(x + 80.0, p1.global_position.y))
	await frames(2)
	check(tutorial.step == Step.DASH_PARRY, "dash-parry: not on before both have gone through him")
	await _put(p2, Vector2(x - 80.0, p2.global_position.y))
	await frames(2)
	check(tutorial.step == Step.SYNC_HIT, "...on once both have")
	_event("sync_hit", 1, 2, {"on_beat": false})
	_event("sync_hit", 2, 2, {"on_beat": true})
	await frames(2)
	check(tutorial.step == Step.SYNC_HIT, "the sync hit: not on before one of each is on the beat")
	_event("sync_hit", 1, 1, {"on_beat": true})
	await frames(2)
	check(tutorial.step == Step.SYNC_LIFE, "...on")
	near(rules.team_share() * 100.0, Tuning.value("tutorial_life_from"), 0.5, "sync is life: their sync low to start with")
	rules._set_team(rules.team_max() * (Tuning.value("tutorial_life_to") - 2.0) / 100.0)
	await frames(2)
	check(tutorial.step == Step.SYNC_LIFE, "...not on short of half")
	rules._set_team(rules.team_max() * Tuning.value("tutorial_life_to") / 100.0)
	await frames(2)
	check(tutorial.step == Step.TOGETHER, "...on, filled up")
	for i in 2:
		boss.state = BaseBoss.State.STAGGER
		await frames(2)
		boss.state = BaseBoss.State.IDLE
		await frames(2)
	check(tutorial.step == Step.SYNC_MODE, "green: on after he has reeled twice")
	check(rules.sync_mode, "the sync mode's step: their sync full")
	_event("pair_strike")
	await frames(2)
	check(tutorial.step == Step.SYNC_MODE, "...not on after one pair strike")
	_event("pair_strike")
	await frames(2)
	check(tutorial.step == Step.DONE, "...done after two")


func test_a_hit_starts_the_step_over():
	await _setup()
	tutorial._begin(Step.PARRY)
	_event("parry", 1, 2)
	check(tutorial.count("parry", 1) == 2, "two parries counted")
	_event("hit", 2)
	check(tutorial.count("parry", 1) == 0, "a hit through: the count starts over")
	await frames(2)
	check(tutorial._text.line_of(1) == tutorial.TEXTS[Step.PARRY][0], "...its words stay, for whoever hasn't read them yet")
	check(not rules.team_chaos and rules.spared, "nobody loses: no chaos")


# The words are said once: a longer one goes on in the shadow half, a short one only above; what's
# the players' together is counted above only.
func test_words_said_once():
	await _setup()
	tutorial._begin(Step.PARRY)
	await frames(2)
	check(tutorial._text.line_of(1) == tutorial.TEXTS[Step.PARRY][0] and tutorial._text.line_of(2) == tutorial.TEXTS[Step.PARRY][1],
		"a longer one: begun above, gone on below")
	tutorial._begin(Step.COLORS)
	await frames(2)
	check(tutorial._text.line_of(1) == tutorial.TEXTS[Step.COLORS][0] and tutorial._text.line_of(2) == "", "a short one: above only")
	tutorial._begin(Step.TOGETHER)
	await frames(2)
	check(tutorial._text._progress[1] != "" and tutorial._text._progress[2] == "", "...their count together: above only")


func test_the_hud_points_out_the_meter():
	await _setup()
	var hud = tutorial.get_node("HUD")
	tutorial._begin(Step.PARRY)
	check(hud._pulse == "posture", "parrying, posture told of: its bars pulse")
	tutorial._begin(Step.SYNC_LIFE)
	check(hud._pulse == "team", "sync is life: the sync meter pulses")
	rules._set_team(0.0)
	check(not rules.team_chaos and rules.team > 0.0, "...their sync low, but never into chaos")
	tutorial._begin(Step.TOGETHER)
	check(hud._pulse == "", "...and none after")


func test_skip():
	await _setup()
	tutorial.skip()
	check(tutorial.step == Step.DASH, "skipped: the next step")
	var tab = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await wait(Tuning.value("tutorial_skip_hold") + 0.2)
	tab.pressed = false
	Input.parse_input_event(tab)
	await frames(2)
	check(tutorial.step == Step.PARRY, "Tab held a moment: skipped too")


func test_dev_hold_holds_him():
	await _setup(true)
	tutorial._begin(Step.PARRY)
	await wait(1.5)
	check(boss.current_attack == null and boss.state == BaseBoss.State.IDLE, "the lab's dev_hold: the tutorial sends him nothing")
	boss.dev_hold = false
	var waited = 0.0
	while boss.current_attack == null and waited < 2.0:
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	check(boss.current_attack != null, "let go: his first attack comes")
	check(boss.current_attack == boss.find_attack("SINGLE"), "...the step's, a single strike")


func test_he_waits_while_they_move():
	await _setup(false)
	await wait(1.5)
	check(tutorial.step == Step.MOVE and boss.current_attack == null, "moving: he doesn't attack")


# Two stand-ins, one for each player, perfect: every step (the moving ones count as done for them).
func test_two_stand_ins_get_through():
	await _setup(false)
	var stand_ins = tutorial.stand_ins()
	stand_ins[0].plays = 2
	var other = BifronsStandIn.new()
	other.boss = boss
	other.plays = 1
	boss.add_child(other)
	tutorial._begin(Step.MOVE)  # the stand-ins set up for it, the new one too
	var seen = [Step.MOVE]
	var waited = 0.0
	while tutorial.step != Step.DONE and waited < 180.0:
		await wait(0.25)
		waited += 0.25
		if tutorial.step != seen.back():
			seen.append(tutorial.step)
	check(tutorial.step == Step.DONE, "two stand-ins: done, after %.0f s (steps: %s; stuck at %d with %s)" % [waited, seen, tutorial.step, tutorial._counts])
