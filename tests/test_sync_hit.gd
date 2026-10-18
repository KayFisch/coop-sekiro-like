extends "res://tests/test_case.gd"
## The partner's hit (StrikePattern "THE PARTNER'S HIT", F2 tab "sync hit"): when a parry's
## window opens and closes, who it's for, the energy sent to the partner, and whether the guard
## falls (Moves "bifrons_guard_break").

const LEFT = -1

var boss
var p1
var p2


func _setup(guard_breaks: bool):
	set_move("bifrons_stand_in", "off")
	set_move("bifrons_guard_break", guard_breaks)
	set_number("sync_window_delay", 0.2)
	set_number("sync_beat_time", 0.1)
	set_number("sync_window_late", 0.2)
	await load_scene("res://levels/threshold/threshold.tscn")
	boss = GameManager.boss
	boss.dev_hold = true
	p1 = GameManager.players[0]
	p2 = GameManager.players[1]
	await wait(0.3)


func test_window_timing():
	await _setup(true)
	near(StrikePattern.window_delay(), 0.2, 0.0001, "it opens after sync_window_delay")
	near(StrikePattern.window_time(), 0.3, 0.0001, "it's open for the beat and after it")
	var start = boss.anim_time
	boss.break_guard(LEFT, StrikePattern.window_time(), StrikePattern.window_delay(), p1)
	var waves = get_tree().current_scene.get_children().filter(func(n): return n.get_script() == SyncWave)
	check(waves.size() == 1 and waves[0].to == p2, "one energy wave, to the partner")
	var seen = []  # [time since the parry, open]
	while boss.anim_time - start < 0.6:
		seen.append([boss.anim_time - start, boss.is_open(LEFT)])
		await get_tree().physics_frame
	var opened = seen.filter(func(s): return s[1])
	check(not opened.is_empty(), "the window opens")
	if not opened.is_empty():
		near(opened.front()[0], 0.2, 0.034, "...0.2 s after the parry")
		near(opened.back()[0], 0.5, 0.034, "...and closes 0.3 s later")
	boss.break_guard(LEFT, 0.3, 0.0, p1)
	await frames(1)
	check(boss.window_for(p2) == LEFT, "the window is the partner's")
	check(boss.window_for(p1) == 0, "...not the parrier's")


func test_guard_falls_or_holds():
	await _setup(true)
	boss.break_guard(LEFT, 0.5, 0.0, p1)
	await frames(2)
	check(not boss.is_guarding(LEFT), "guard_break on: the guard is down in the window")
	await _setup(false)
	await wait(0.4)
	var guarding = boss.is_guarding(LEFT)
	boss.break_guard(LEFT, 0.5, 0.0, p1)
	await frames(2)
	check(boss.is_open(LEFT), "guard_break off: the window still opens")
	check(boss.is_guarding(LEFT) == guarding, "...but the guard stays as it was")
