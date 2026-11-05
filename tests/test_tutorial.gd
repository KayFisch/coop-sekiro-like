extends "res://tests/test_case.gd"
## The tutorial (levels/tutorial/tutorial.gd, docs/tutorial.md): each step goes on once what it
## asks is there and not before, a hit starts its count over, a step can be skipped, the lab's
## dev_hold holds him, and two stand-ins get through all of it.

const TUTORIAL = "res://levels/tutorial/tutorial.tscn"
const Step = preload("res://levels/tutorial/tutorial.gd").Step

var tutorial
var boss
var rules


func _setup(hold = true):
	set_move("bifrons_stand_in", "off")
	set_number("tutorial_read_time", 0.3)
	set_number("tutorial_pause", 0.4)
	await load_scene(TUTORIAL)
	tutorial = get_tree().current_scene
	boss = GameManager.boss
	rules = GameManager.rules
	boss.dev_hold = hold  # (the lab's: he attacks only once it's let go)


# An event of the fight's log, as the game sends it.
func _event(kind: String, player = 0, times = 1):
	for i in times:
		Dev.note(kind, {"player": player})


func test_each_step_goes_on_once_met_and_not_before():
	await _setup()
	check(tutorial.step == Step.PARRY, "it starts with parrying")
	_event("parry", 1, 2)
	_event("parry", 2, 2)
	_event("block", 1)
	await frames(2)
	check(tutorial.step == Step.PARRY, "...not on before both have blocked as well")
	_event("block", 2)
	await frames(2)
	check(tutorial.step == Step.COLORS, "...on once each has parried and blocked")
	_event("parry", 1, 3)
	_event("parry", 2, 2)
	await frames(2)
	check(tutorial.step == Step.COLORS, "yellow and red: not on with one parry short")
	_event("parry", 2)
	await frames(2)
	check(tutorial.step == Step.HALVES, "...on")
	_event("parry", 1, 3)
	_event("parry", 2, 3)
	await frames(2)
	check(tutorial.step == Step.SYNC_HIT, "the halves: on")
	_event("sync_hit", 1, 2)
	_event("sync_hit", 2, 1)
	await frames(2)
	check(tutorial.step == Step.SYNC_HIT, "the sync hit: not on before both ways")
	_event("sync_hit", 2)
	await frames(2)
	check(tutorial.step == Step.TOGETHER, "...on")
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
	_event("parry", 1, 2)
	check(tutorial.count("parry", 1) == 2, "two parries counted")
	_event("hit", 2)
	check(tutorial.count("parry", 1) == 0, "a hit through: the count starts over")
	await frames(2)
	check(tutorial._text.line_of(1) == tutorial.TEXTS[Step.PARRY], "...its words stay, for whoever hasn't read them yet")
	check(not rules.team_chaos and rules.spared, "nobody loses: no chaos")


func test_skip():
	await _setup()
	tutorial.skip()
	check(tutorial.step == Step.COLORS, "skipped: the next step")
	var tab = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await wait(Tuning.value("tutorial_skip_hold") + 0.2)
	tab.pressed = false
	Input.parse_input_event(tab)
	await frames(2)
	check(tutorial.step == Step.HALVES, "Tab held a moment: skipped too")


func test_dev_hold_holds_him():
	await _setup(true)
	await wait(1.5)
	check(boss.current_attack == null and boss.state == BaseBoss.State.IDLE, "the lab's dev_hold: the tutorial sends him nothing")
	boss.dev_hold = false
	var waited = 0.0
	while boss.current_attack == null and waited < 2.0:
		await get_tree().physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	check(boss.current_attack != null, "let go: his first attack comes")
	check(boss.current_attack == boss.find_attack("SINGLE"), "...the step's, a single strike")


# Two stand-ins, one for each player, perfect: all six steps.
func test_two_stand_ins_get_through():
	await _setup(false)
	var stand_ins = tutorial.stand_ins()
	stand_ins[0].plays = 2
	var other = BifronsStandIn.new()
	other.boss = boss
	other.plays = 1
	boss.add_child(other)
	tutorial._begin(Step.PARRY)  # the stand-ins set up for it, the new one too
	var seen = [Step.PARRY]
	var waited = 0.0
	while tutorial.step != Step.DONE and waited < 150.0:
		await wait(0.25)
		waited += 0.25
		if tutorial.step != seen.back():
			seen.append(tutorial.step)
	check(tutorial.step == Step.DONE, "two stand-ins: done, after %.0f s (steps: %s; stuck at %d with %s)" % [waited, seen, tutorial.step, tutorial._counts])
